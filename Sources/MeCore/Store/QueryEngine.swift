import Foundation
import SwiftData

/// Result of a query — what entity was matched and all related data.
package enum QueryResult {
    case figure(FigureDossier)
    case place(PlaceDossier)
    case event(EventDossier)
    case figureList(String, [Figure])
    case eventList(String, [Event])
    case placeList(String, [Place])
    case answer(String)
    case noMatch(String)
}

/// Resolves natural language queries against the database.
package class QueryEngine {
    private let context: ModelContext

    package init(context: ModelContext) {
        self.context = context
    }

    // MARK: - Pattern Tables

    private struct FigureRelationPattern {
        let possessiveSuffixes: [String]
        let prepositionalPrefixes: [String]
        let label: (String) -> String
        let finder: (Figure) -> [Figure]
    }

    private var figureRelationPatterns: [FigureRelationPattern] {
        [
            FigureRelationPattern(
                possessiveSuffixes: ["children", "sons", "daughters"],
                prepositionalPrefixes: ["children of ", "child of ", "sons of ", "son of ", "daughters of ", "daughter of "],
                label: { "Children of \($0)" },
                finder: { self.findChildren(of: $0) }
            ),
            FigureRelationPattern(
                possessiveSuffixes: ["parents", "father", "mother"],
                prepositionalPrefixes: ["parents of ", "parent of ", "father of ", "mother of "],
                label: { "Parents of \($0)" },
                finder: { self.findParents(of: $0) }
            ),
            FigureRelationPattern(
                possessiveSuffixes: ["spouse", "spouses", "consort", "consorts"],
                prepositionalPrefixes: ["spouse of ", "consort of "],
                label: { "Spouses of \($0)" },
                finder: { self.findSpouses(of: $0) }
            ),
            FigureRelationPattern(
                possessiveSuffixes: ["siblings", "brother", "sister", "sisters", "brothers"],
                prepositionalPrefixes: ["siblings of ", "sibling of ", "brother of ", "sister of "],
                label: { "Siblings of \($0)" },
                finder: { self.findSiblings(of: $0) }
            ),
            FigureRelationPattern(
                possessiveSuffixes: ["creator", "creators"],
                prepositionalPrefixes: ["creator of "],
                label: { "Creators of \($0)" },
                finder: { self.findCreators(of: $0) }
            ),
            FigureRelationPattern(
                possessiveSuffixes: ["creations", "creation"],
                prepositionalPrefixes: ["creations of ", "creation of "],
                label: { "Creations of \($0)" },
                finder: { self.findCreations(of: $0) }
            ),
            FigureRelationPattern(
                possessiveSuffixes: ["uncle", "uncles"],
                prepositionalPrefixes: ["uncle of ", "uncles of "],
                label: { "Uncles of \($0)" },
                finder: { self.findUncles(of: $0) }
            ),
            FigureRelationPattern(
                possessiveSuffixes: ["aunt", "aunts"],
                prepositionalPrefixes: ["aunt of ", "aunts of "],
                label: { "Aunts of \($0)" },
                finder: { self.findAunts(of: $0) }
            ),
            FigureRelationPattern(
                possessiveSuffixes: ["commander", "commanders"],
                prepositionalPrefixes: ["commander of ", "commanders of "],
                label: { "Commanders of \($0)" },
                finder: { self.findCommanders(of: $0) }
            ),
            FigureRelationPattern(
                possessiveSuffixes: ["servant", "servants"],
                prepositionalPrefixes: ["servant of ", "servants of "],
                label: { "Servants of \($0)" },
                finder: { self.findServants(of: $0) }
            ),
            FigureRelationPattern(
                possessiveSuffixes: ["ally", "allies"],
                prepositionalPrefixes: ["ally of ", "allies of "],
                label: { "Allies of \($0)" },
                finder: { self.findAllies(of: $0) }
            ),
            FigureRelationPattern(
                possessiveSuffixes: ["enemy", "enemies"],
                prepositionalPrefixes: ["enemy of ", "enemies of "],
                label: { "Enemies of \($0)" },
                finder: { self.findEnemies(of: $0) }
            ),
            FigureRelationPattern(
                possessiveSuffixes: ["worshipper", "worshippers"],
                prepositionalPrefixes: ["worshipper of ", "worshippers of "],
                label: { "Worshippers of \($0)" },
                finder: { self.findWorshippers(of: $0) }
            ),
        ]
    }

    // MARK: - Public Query API

    package func query(_ input: String) -> QueryResult {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if let result = matchFigureRelationPossessive(text) { return result }
        if let result = matchPlacePossessive(text) { return result }
        if let result = matchEventPossessive(text) { return result }
        if let result = matchFigureRelationPrepositional(text) { return result }

        // Places of figures
        if let figureName = extractPattern(text, patterns: ["places of ", "associated places of "]) {
            if let figure = resolveFigure(figureName) {
                let places = figure.placeAssociations.compactMap { $0.place }
                return .placeList("Places associated with \(figure.name)", places)
            }
        }

        // "what happened at X", "events at X"
        if let placeName = extractPattern(text, patterns: ["happened at ", "events at ", "happened in "]) {
            if let place = resolvePlace(placeName) {
                return .place(context.buildPlaceDossier(place))
            }
        }

        // "figures at X", "figures in X"
        if let placeName = extractPattern(text, patterns: ["figures at ", "figures in "]) {
            if let place = resolvePlace(placeName) {
                let events = findEvents(byPlaceName: place.name)
                let figures = Array(Set(events.flatMap { $0.involvedFigures }))
                return .figureList("Figures at \(place.name)", figures)
            }
        }

        // "place of X", "location of X" for events
        if let eventName = extractPattern(text, patterns: ["place of ", "places of ", "location of ", "locations of "]) {
            if let event = resolveEvent(eventName) {
                let places = event.placeAssociations.compactMap { $0.place }
                if !places.isEmpty {
                    return .placeList("Places of \(event.name)", places)
                }
                return .noMatch(input)
            }
        }

        // "who is also known as X", "known as X"
        if let altName = extractPattern(text, patterns: ["also known as ", "known as "]) {
            if let figure = resolveFigureByAlternateName(altName) {
                let alias = matchedAliasName(for: figure, query: altName)
                return .figure(context.buildFigureDossier(figure, matchedAlias: alias ?? altName))
            }
        }

        // Reign queries: "how long did X reign", "X's reign", "reign of X"
        if let result = matchReignQuery(text) { return result }

        // Duration queries: "duration of X", "how long did X last"
        if let result = matchDurationQuery(text, input: input) { return result }

        // "list all X" / "all X" patterns
        if let result = matchListingPatterns(text) { return result }

        // Domain-based: "gods of the sky", "sky gods", "underworld deities"
        if let result = matchDomainQuery(text) { return result }

        // Gender-based: "female deities", "male figures"
        if let result = matchGenderQuery(text) { return result }

        // Era-based: "figures of the early dynastic period"
        if let result = matchEraQuery(text) { return result }

        // Direct entity match
        if let figure = resolveFigure(text) {
            let alias = matchedAliasName(for: figure, query: text)
            return .figure(context.buildFigureDossier(figure, matchedAlias: alias))
        }
        if let place = resolvePlace(text) {
            return .place(context.buildPlaceDossier(place))
        }
        if let event = resolveEvent(text) {
            return .event(context.buildEventDossier(event))
        }

        // Question prefix stripping
        let cleaned = text
            .replacingOccurrences(of: "what do we know about ", with: "")
            .replacingOccurrences(of: "tell me about ", with: "")
            .replacingOccurrences(of: "who is ", with: "")
            .replacingOccurrences(of: "who was ", with: "")
            .replacingOccurrences(of: "what is ", with: "")
            .replacingOccurrences(of: "where is ", with: "")
            .trimmingCharacters(in: .punctuationCharacters)
            .trimmingCharacters(in: .whitespaces)

        if !cleaned.isEmpty && cleaned != text {
            if let figure = resolveFigure(cleaned) {
                let alias = matchedAliasName(for: figure, query: cleaned)
                return .figure(context.buildFigureDossier(figure, matchedAlias: alias))
            }
            if let place = resolvePlace(cleaned) {
                return .place(context.buildPlaceDossier(place))
            }
            if let event = resolveEvent(cleaned) {
                return .event(context.buildEventDossier(event))
            }
        }

        // Fallback: search descriptions and titles
        if let figure = resolveFigureByFallback(text) {
            return .figure(context.buildFigureDossier(figure))
        }

        return .noMatch(input)
    }

    // MARK: - Pattern Matching Steps

    private func matchFigureRelationPossessive(_ text: String) -> QueryResult? {
        for pattern in figureRelationPatterns {
            if let name = extractPossessivePattern(text, suffixes: pattern.possessiveSuffixes) {
                if let figure = resolveFigure(name) {
                    let results = pattern.finder(figure)
                    return .figureList(pattern.label(figure.name), results)
                }
            }
        }
        return nil
    }

    private func matchFigureRelationPrepositional(_ text: String) -> QueryResult? {
        for pattern in figureRelationPatterns {
            if let name = extractPattern(text, patterns: pattern.prepositionalPrefixes) {
                if let figure = resolveFigure(name) {
                    let results = pattern.finder(figure)
                    return .figureList(pattern.label(figure.name), results)
                }
            }
        }
        return nil
    }

    private func matchPlacePossessive(_ text: String) -> QueryResult? {
        guard let placeName = extractPossessivePattern(text, suffixes: ["events", "figures"]) else { return nil }
        guard let place = resolvePlace(placeName) else { return nil }
        let events = findEvents(byPlaceName: place.name)
        let isEventQuery = text.contains("'s events") || text.contains("'s event")
        if isEventQuery {
            return .eventList("Events at \(place.name)", events)
        } else {
            let figures = Array(Set(events.flatMap { $0.involvedFigures }))
            return .figureList("Figures at \(place.name)", figures)
        }
    }

    private func matchEventPossessive(_ text: String) -> QueryResult? {
        guard let eventName = extractPossessivePattern(text, suffixes: ["figures", "place", "places", "location", "locations"]) else { return nil }
        guard let event = resolveEvent(eventName) else { return nil }
        let isPlaceQuery = text.contains("'s place") || text.contains("'s places") || text.contains("'s location") || text.contains("'s locations")
        if isPlaceQuery {
            let places = event.placeAssociations.compactMap { $0.place }
            if !places.isEmpty {
                return .placeList("Places of \(event.name)", places)
            }
            return .noMatch(text)
        } else {
            return .figureList("Figures in \(event.name)", event.involvedFigures)
        }
    }

    private func matchDurationQuery(_ text: String, input: String) -> QueryResult? {
        let durationPatterns = [
            "duration of the ", "duration of ",
            "how long did the ", "how long did ",
            "how long was the ", "how long was ",
            "how long is the ", "how long is ",
        ]
        let durationSuffix = " last"
        var entityName: String?

        if let name = extractPattern(text, patterns: durationPatterns) {
            entityName = name
        }

        // "third dynasty of ur duration" or "third dynasty of ur lasted" patterns
        if entityName == nil, text.hasSuffix(durationSuffix) || text.hasSuffix("duration") {
            let trimmed = text
                .replacingOccurrences(of: durationSuffix, with: "")
                .replacingOccurrences(of: "duration", with: "")
                .trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty { entityName = trimmed }
        }

        guard let name = entityName else { return nil }

        // Try as an Era
        let eras: [Era] = context.fetchAll()
        if let era = eras.first(where: { $0.name.lowercased() == name.lowercased() }) ?? eras.first(where: { $0.name.lowercased().contains(name.lowercased()) || name.lowercased().contains($0.name.lowercased()) }) {
            return formatEraDuration(era)
        }

        // Try as a Figure (lifespan)
        if let figure = resolveFigure(name) {
            return formatFigureLifespan(figure)
        }

        return nil
    }

    private func formatEraDuration(_ era: Era) -> QueryResult? {
        guard let startYear = era.startDate.year, let endYear = era.endDate.year else {
            return .answer("The \(era.name) has no specific start and end dates recorded.")
        }
        let years = endYear - startYear
        guard years >= 0 else {
            return .answer("The \(era.name) ended before it began according to the recorded dates (\(era.startDate.displayLabel) to \(era.endDate.displayLabel)).")
        }
        let startLabel = era.startDate.displayLabel
        let endLabel = era.endDate.displayLabel
        if years == 0 {
            return .answer("The \(era.name) lasted less than a year according to the recorded dates (\(startLabel) to \(endLabel)).")
        }
        let approx = era.startDate.isApproximate || era.endDate.isApproximate ? "approximately " : ""
        return .answer("The \(era.name) lasted \(approx)\(years.formatted()) years (from \(startLabel) to \(endLabel)).")
    }

    private func formatFigureLifespan(_ figure: Figure) -> QueryResult? {
        guard let birthYear = figure.birthDate.year, let deathYear = figure.deathDate.year else {
            return .answer("\(figure.name) has no specific birth and death dates recorded.")
        }
        let years = deathYear - birthYear
        guard years >= 0 else {
            return .answer("\(figure.name)'s recorded death date (\(figure.deathDate.displayLabel)) is before their birth date (\(figure.birthDate.displayLabel)).")
        }
        let approx = figure.birthDate.isApproximate || figure.deathDate.isApproximate ? "approximately " : ""
        return .answer("\(figure.name) lived for \(approx)\(years.formatted()) years (from \(figure.birthDate.displayLabel) to \(figure.deathDate.displayLabel)).")
    }

    private func matchReignQuery(_ text: String) -> QueryResult? {
        // Possessive: "X's reign" — exact name match only
        if let name = extractPossessivePattern(text, suffixes: ["reign"]) {
            if let figure = exactFigure(name) {
                return formatFigureLifespan(figure)
            }
        }

        // Prepositional: "reign of X" — exact name match only
        if let name = extractPattern(text, patterns: ["the reign of ", "reign of "]) {
            if let figure = exactFigure(name) {
                return formatFigureLifespan(figure)
            }
            if let era = resolveEraByName(name) {
                return formatEraDuration(era)
            }
        }

        // "how long did X reign" — extract X between prefix and " reign"
        if text.hasPrefix("how long did ") && text.hasSuffix(" reign") {
            let startIndex = text.index(text.startIndex, offsetBy: "how long did ".count)
            let endIndex = text.index(text.endIndex, offsetBy: -" reign".count)
            let name = String(text[startIndex..<endIndex]).trimmingCharacters(in: .whitespaces)
            if !name.isEmpty {
                if let figure = exactFigure(name) {
                    return formatFigureLifespan(figure)
                }
                if let era = resolveEraByName(name) {
                    return formatEraDuration(era)
                }
                // Group fallback: "the early sumerian kings"
                let stopWords = Set(["the", "a", "an", "of", "and", "in", "to", "for"])
                let figures: [Figure] = context.fetchAll()
                let queryTerms = name.lowercased().split(separator: " ").filter { !stopWords.contains(String($0)) }.map(String.init)
                guard !queryTerms.isEmpty else { return nil }
                let matched = figures.filter { fig in
                    let desc = fig.figureDescription.lowercased()
                    let domain = fig.domain.lowercased()
                    let title = fig.title.lowercased()
                    let figName = fig.name.lowercased()
                    let eraName = fig.birthDate.era.lowercased()
                    let typeName = fig.figureType?.name.lowercased() ?? ""
                    let matchesAllTerms = queryTerms.allSatisfy { term in
                        desc.contains(term) || domain.contains(term) || title.contains(term) ||
                        figName.contains(term) || typeName.contains(term) || eraName.contains(term)
                    }
                    return matchesAllTerms && (title.contains("king") || desc.contains("king") || domain.contains("king") || typeName == "human")
                }
                if matched.isEmpty { return nil }
                let totalYears = matched.compactMap { fig -> Int? in
                    guard let birth = fig.birthDate.year, let death = fig.deathDate.year else { return nil }
                    return death - birth
                }
                if !totalYears.isEmpty {
                    let avg = totalYears.reduce(0, +) / totalYears.count
                    return .answer("The \(name) reigned on average approximately \(avg.formatted()) years each (based on \(matched.count) figures).")
                }
                return .figureList("\(name.capitalized)", matched)
            }
        }

        return nil
    }

    private func exactFigure(_ name: String) -> Figure? {
        let figures: [Figure] = context.fetchAll()
        return figures.first(where: { $0.name.lowercased() == name.lowercased() })
    }

    private func resolveEraByName(_ name: String) -> Era? {
        let eras: [Era] = context.fetchAll()
        let q = name.lowercased()
        if let match = eras.first(where: { $0.name.lowercased() == q }) { return match }
        return eras.first(where: { $0.name.lowercased().contains(q) || q.contains($0.name.lowercased()) })
    }

    private func matchListingPatterns(_ text: String) -> QueryResult? {
        let allFigures = { self.context.fetchAll() as [Figure] }
        let allPlaces = { self.context.fetchAll() as [Place] }
        let allEvents = { self.context.fetchAll() as [Event] }

        switch text {
        case "list all figures", "show all figures", "all figures", "list figures", "show figures":
            return .figureList("All Figures", allFigures())
        case "list all places", "show all places", "all places", "list places", "show places":
            return .placeList("All Places", allPlaces())
        case "list all events", "show all events", "all events", "list events", "show events":
            return .eventList("All Events", allEvents())
        case "list all sources", "show all sources", "all sources", "list sources", "show sources":
            let sources = (context.fetchAll() as [Source])
            return .figureList("All Sources", sources.compactMap { $0.name.isEmpty ? nil : nil })
        default:
            break
        }

        // "all deities", "all gods", "all humans", etc.
        let figureTypes = context.fetchAll() as [FigureType]
        for ft in figureTypes {
            let ftLower = ft.name.lowercased()
            let prefixes = ["all \(ftLower)s", "all \(ftLower)", "list \(ftLower)s", "list \(ftLower)"]
            let deitiesAliases = ftLower == "deity" ? ["all gods", "all goddesses", "list gods", "list goddesses"] : [String]()
            let allPrefixes = prefixes + deitiesAliases
            for prefix in allPrefixes {
                if text == prefix {
                    return .figureList("All \(ft.name)s", ft.figures)
                }
            }
        }

        return nil
    }

    private func matchDomainQuery(_ text: String) -> QueryResult? {
        let figures: [Figure] = context.fetchAll()

        // "X gods", "gods of X", "deities of X", "X deities"
        let domainPatterns = [
            "gods of the ", "god of the ", "deities of the ", "deity of the ",
            "gods of ", "god of ", "deities of ", "deity of ",
        ]

        if let domain = extractPattern(text, patterns: domainPatterns) {
            let q = domain.lowercased()
            let matched = figures.filter {
                $0.domain.lowercased().contains(q) || q.contains($0.domain.lowercased())
            }
            if !matched.isEmpty {
                return .figureList("\(domain.capitalized) Deities", matched)
            }
        }

        // "sky gods" → domain contains "sky"
        // "underworld gods" → domain contains "underworld"
        // "war gods" → domain contains "war"
        // "wisdom god" → domain contains "wisdom"
        let suffixPatterns = [
            " gods", " goddesses", " deities", " deity", " god", " goddess",
        ]
        for suffix in suffixPatterns {
            if text.hasSuffix(suffix) {
                let query = String(text.dropLast(suffix.count)).trimmingCharacters(in: .whitespaces)
                if !query.isEmpty {
                    let matched = figures.filter {
                        $0.domain.lowercased().contains(query) || $0.name.lowercased().contains(query) ||
                        $0.figureType?.name.lowercased() == query
                    }
                    if !matched.isEmpty {
                        return .figureList("\(query.capitalized) Deities", matched)
                    }
                }
            }
        }

        return nil
    }

    private func matchGenderQuery(_ text: String) -> QueryResult? {
        let figures: [Figure] = context.fetchAll()

        let isFemale = text.hasPrefix("female ") || text.hasPrefix("woman ") || text.hasPrefix("women ")
        let isMale = text.hasPrefix("male ") || text.hasPrefix("man ") || text.hasPrefix("men ")

        guard isFemale || isMale else { return nil }

        let suffix = isFemale ? "female " : "male "
        let remainder = String(text.dropFirst(suffix.count)).trimmingCharacters(in: .whitespaces)

        let targetGender: Figure.Gender = isFemale ? .female : .male

        if remainder.isEmpty || remainder == "figures" || remainder == "deities" || remainder == "gods" || remainder == "goddesses" {
            let matched = figures.filter { $0.gender == targetGender }
            let label = isFemale ? "Female Figures" : "Male Figures"
            return .figureList(label, matched)
        }

        // "female deities" → filter by gender + figureType
        let matched = figures.filter { fig in
            guard fig.gender == targetGender else { return false }
            if remainder == "deities" || remainder == "gods" || remainder == "goddesses" {
                return fig.figureType?.name.lowercased() == "deity"
            }
            return fig.figureType?.name.lowercased() == remainder ||
                   fig.domain.lowercased().contains(remainder)
        }
        let label = isFemale ? "Female \(remainder.capitalized)" : "Male \(remainder.capitalized)"
        return .figureList(label, matched)
    }

    private func matchEraQuery(_ text: String) -> QueryResult? {
        // "figures of the X era", "figures of X", "X figures", "X era figures"
        let eraPatterns = [
            "figures of the ", "figures of ",
            "events of the ", "events of ",
            "kings of the ", "kings of ",
        ]

        if let eraName = extractPattern(text, patterns: eraPatterns) {
            let q = eraName.lowercased()

            if text.contains("figures") || text.contains("kings") {
                let figures: [Figure] = context.fetchAll()
                let matched = figures.filter {
                    $0.birthDate.era.lowercased().contains(q) ||
                    $0.deathDate.era.lowercased().contains(q) ||
                    $0.figureDescription.lowercased().contains(q) ||
                    $0.figureType?.name.lowercased() == q
                }
                if !matched.isEmpty {
                    return .figureList("Figures of \(eraName)", matched)
                }
            }

            if text.contains("events") {
                let events: [Event] = context.fetchAll()
                let matched = events.filter {
                    $0.date.era.lowercased().contains(q) ||
                    $0.eventDescription.lowercased().contains(q) ||
                    $0.era.lowercased().contains(q)
                }
                if !matched.isEmpty {
                    return .eventList("Events of \(eraName)", matched)
                }
            }
        }

        return nil
    }

    // MARK: - Entity Resolution

    private func resolveFigure(_ name: String) -> Figure? {
        let figures = context.fetchAll() as [Figure]
        let query = name.lowercased()

        if let match = figures.first(where: { $0.name.lowercased() == query }) {
            return match
        }
        if let match = figures.first(where: { $0.name.lowercased().contains(query) || query.contains($0.name.lowercased()) }) {
            return match
        }
        return resolveFigureByAlternateName(name)
    }

    private func resolveFigureByFallback(_ name: String) -> Figure? {
        let figures = context.fetchAll() as [Figure]
        let query = name.lowercased()

        if let match = figures.first(where: { $0.title.lowercased().contains(query) || query.contains($0.title.lowercased()) }) {
            return match
        }
        if let match = figures.first(where: { $0.figureDescription.lowercased().contains(query) }) {
            return match
        }
        if let match = figures.first(where: { $0.domain.lowercased().contains(query) }) {
            return match
        }
        return nil
    }

    private func resolveFigureByAlternateName(_ name: String) -> Figure? {
        let altNames = context.fetchAll() as [AlternateName]
        let query = name.lowercased()
        if let match = altNames.first(where: { $0.name.lowercased() == query || $0.name.lowercased().contains(query) }) {
            return match.figure
        }
        return nil
    }

    private func resolvePlace(_ name: String) -> Place? {
        let places = context.fetchAll() as [Place]
        let query = name.lowercased()
        if let match = places.first(where: { $0.name.lowercased() == query }) {
            return match
        }
        return places.first(where: { $0.name.lowercased().contains(query) || query.contains($0.name.lowercased()) })
    }

    private func resolveEvent(_ name: String) -> Event? {
        let events = context.fetchAll() as [Event]
        let query = name.lowercased()
        if let match = events.first(where: { $0.name.lowercased() == query }) {
            return match
        }
        return events.first(where: { $0.name.lowercased().contains(query) || query.contains($0.name.lowercased()) })
    }

    // MARK: - Relationship Finders

    private func findChildren(of figure: Figure) -> [Figure] {
        let relationships = context.fetchAll() as [Relationship]
        return relationships
            .filter { ($0.relationshipType == .father || $0.relationshipType == .mother) && $0.fromFigure?.persistentModelID == figure.persistentModelID }
            .compactMap { $0.toFigure }
    }

    private func findParents(of figure: Figure) -> [Figure] {
        let relationships = context.fetchAll() as [Relationship]
        return relationships
            .filter { ($0.relationshipType == .father || $0.relationshipType == .mother) && $0.toFigure?.persistentModelID == figure.persistentModelID }
            .compactMap { $0.fromFigure }
    }

    private func findSpouses(of figure: Figure) -> [Figure] {
        let relationships = context.fetchAll() as [Relationship]
        return relationships
            .filter { $0.relationshipType == .spouse && ($0.fromFigure?.persistentModelID == figure.persistentModelID || $0.toFigure?.persistentModelID == figure.persistentModelID) }
            .compactMap { $0.fromFigure?.persistentModelID == figure.persistentModelID ? $0.toFigure : $0.fromFigure }
    }

    private func findSiblings(of figure: Figure) -> [Figure] {
        let relationships = context.fetchAll() as [Relationship]
        return relationships
            .filter { $0.relationshipType == .sibling && ($0.fromFigure?.persistentModelID == figure.persistentModelID || $0.toFigure?.persistentModelID == figure.persistentModelID) }
            .compactMap { $0.fromFigure?.persistentModelID == figure.persistentModelID ? $0.toFigure : $0.fromFigure }
    }

    private func findCreators(of figure: Figure) -> [Figure] {
        let relationships = context.fetchAll() as [Relationship]
        return relationships
            .filter { $0.relationshipType == .creator && $0.toFigure?.persistentModelID == figure.persistentModelID }
            .compactMap { $0.fromFigure }
    }

    private func findCreations(of figure: Figure) -> [Figure] {
        let relationships = context.fetchAll() as [Relationship]
        return relationships
            .filter { $0.relationshipType == .creator && $0.fromFigure?.persistentModelID == figure.persistentModelID }
            .compactMap { $0.toFigure }
    }

    private func findUncles(of figure: Figure) -> [Figure] {
        let relationships = context.fetchAll() as [Relationship]
        return relationships
            .filter { $0.relationshipType == .uncle && $0.toFigure?.persistentModelID == figure.persistentModelID }
            .compactMap { $0.fromFigure }
    }

    private func findAunts(of figure: Figure) -> [Figure] {
        let relationships = context.fetchAll() as [Relationship]
        return relationships
            .filter { $0.relationshipType == .aunt && $0.toFigure?.persistentModelID == figure.persistentModelID }
            .compactMap { $0.fromFigure }
    }

    private func findCommanders(of figure: Figure) -> [Figure] {
        let relationships = context.fetchAll() as [Relationship]
        return relationships
            .filter { $0.relationshipType == .commander && $0.toFigure?.persistentModelID == figure.persistentModelID }
            .compactMap { $0.fromFigure }
    }

    private func findServants(of figure: Figure) -> [Figure] {
        let relationships = context.fetchAll() as [Relationship]
        return relationships
            .filter { $0.relationshipType == .servant && $0.toFigure?.persistentModelID == figure.persistentModelID }
            .compactMap { $0.fromFigure }
    }

    private func findAllies(of figure: Figure) -> [Figure] {
        let relationships = context.fetchAll() as [Relationship]
        return relationships
            .filter { $0.relationshipType == .ally && ($0.fromFigure?.persistentModelID == figure.persistentModelID || $0.toFigure?.persistentModelID == figure.persistentModelID) }
            .compactMap { $0.fromFigure?.persistentModelID == figure.persistentModelID ? $0.toFigure : $0.fromFigure }
    }

    private func findEnemies(of figure: Figure) -> [Figure] {
        let relationships = context.fetchAll() as [Relationship]
        return relationships
            .filter { $0.relationshipType == .enemy && ($0.fromFigure?.persistentModelID == figure.persistentModelID || $0.toFigure?.persistentModelID == figure.persistentModelID) }
            .compactMap { $0.fromFigure?.persistentModelID == figure.persistentModelID ? $0.toFigure : $0.fromFigure }
    }

    private func findWorshippers(of figure: Figure) -> [Figure] {
        let relationships = context.fetchAll() as [Relationship]
        return relationships
            .filter { $0.relationshipType == .worshipper && $0.toFigure?.persistentModelID == figure.persistentModelID }
            .compactMap { $0.fromFigure }
    }

    private func findEvents(byPlaceName placeName: String) -> [Event] {
        let places = context.fetchAll() as [Place]
        guard let place = places.first(where: { $0.name.lowercased() == placeName.lowercased() }) else { return [] }
        return place.eventAssociations.compactMap { $0.event }
    }

    private func matchedAliasName(for figure: Figure, query: String) -> String? {
        let q = query.lowercased().trimmingCharacters(in: .punctuationCharacters).trimmingCharacters(in: .whitespaces)
        return figure.alternateNames.first(where: {
            let name = $0.name.lowercased()
            return name == q || name.contains(q) || q.contains(name)
        })?.name
    }

    // MARK: - Helpers

    private func extractPattern(_ text: String, patterns: [String]) -> String? {
        for pattern in patterns {
            if let range = text.range(of: pattern) {
                let extracted = String(text[range.upperBound...]).trimmingCharacters(in: .punctuationCharacters).trimmingCharacters(in: .whitespaces)
                if !extracted.isEmpty { return extracted }
            }
        }
        return nil
    }

    private func extractPossessivePattern(_ text: String, suffixes: [String]) -> String? {
        let lower = text.lowercased()
        for suffix in suffixes {
            let pattern = "'s \(suffix)"
            if let range = lower.range(of: pattern) {
                let extracted = String(lower[..<range.lowerBound]).trimmingCharacters(in: .punctuationCharacters).trimmingCharacters(in: .whitespaces)
                if !extracted.isEmpty { return extracted }
            }
        }
        return nil
    }
}
