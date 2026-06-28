import Foundation
import NaturalLanguage
import SwiftData

/// Result of a query — what entity was matched and all related data.
package enum QueryResult {
    case figure(FigureDossier)
    case place(PlaceDossier)
    case event(EventDossier)
    case figureList(String, [Figure])
    case eventList(String, [Event])
    case placeList(String, [Place])
    case thing(Thing)
    case thingList(String, [Thing])
    case imageList(String, [ImageAsset])
    case answer(String)
    case noMatch(String)
}

/// Resolves natural language queries against the database.
package class QueryEngine {

    package enum EntityRef {
        case figure(Figure)
        case place(Place)
        case event(Event)
        case thing(Thing)
    }
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

        // "how many X had Y" — uses lemmatized text for verb normalization
        if let result = matchHowManyQuery(text) { return result }

        // "how many [type]" — count entities by type
        if let result = matchHowManyTypeQuery(text) { return result }

        // Yes/no and choice questions: "was X a Y", "is X a Y or a Z"
        if let result = matchYesNoQuery(text) { return result }

        // Image search: "images of X", "pictures of X"
        if let result = matchImageQuery(text) { return result }

        // Structured pipeline: extract entity + classify intent from remaining text
        if let result = matchStructuredQuery(text) { return result }

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
        if let thing = resolveThing(text) {
            return .thing(thing)
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
            if let thing = resolveThing(cleaned) {
                return .thing(thing)
            }
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
        guard let startYear = era.startDate.startYear, let endYear = era.endDate.endYear else {
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
        guard let birthYear = figure.birthDate.startYear, let deathYear = figure.deathDate.endYear else {
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
                    guard let birth = fig.birthDate.startYear, let death = fig.deathDate.endYear else { return nil }
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
        case "list all things", "show all things", "all things", "list things", "show things":
            let things = context.fetchAll() as [Thing]
            return .thingList("All Things", things)
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

    private func matchHowManyQuery(_ text: String) -> QueryResult? {
        guard text.hasPrefix("how many ") else { return nil }
        let rest = String(text.dropFirst("how many ".count))
        let lemRest = lemmatize(rest)

        for pattern in figureRelationPatterns {
            for (suffix, lemSuffix) in zip(pattern.possessiveSuffixes, pattern.possessiveSuffixes.map({ lemmatize($0) })) {
                if let range = lemRest.range(of: "\(lemSuffix) have "),
                   range.lowerBound == lemRest.startIndex
                {
                    let entityName = String(lemRest[range.upperBound...])
                        .trimmingCharacters(in: .punctuationCharacters)
                        .trimmingCharacters(in: .whitespaces)
                    if let figure = resolveFigure(entityName) {
                        let results = pattern.finder(figure)
                        let label = "\(figure.name) had \(results.count) \(results.count == 1 ? lemSuffix : suffix)"
                        return .figureList(label, results)
                    }
                }
            }
        }

        return nil
    }

    private func singularize(_ word: String) -> String {
        let lower = word.lowercased()
        if lower.hasSuffix("ies") { return String(lower.dropLast(3)) + "y" }
        if lower.hasSuffix("ses") { return String(lower.dropLast(2)) }
        if lower.hasSuffix("s") && !lower.hasSuffix("ss") { return String(lower.dropLast()) }
        return lower
    }

    private func matchHowManyTypeQuery(_ text: String) -> QueryResult? {
        guard text.hasPrefix("how many ") else { return nil }
        let rest = String(text.dropFirst("how many ".count))
            .replacingOccurrences(of: "[?.,!;:()]", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)

        let noisePatterns = [" do i have", " do we have", " are there", " exist",
                             " in this database", " in the database", " in database",
                             " do you have", " does this database have"]
        var cleaned = rest
        for pattern in noisePatterns {
            cleaned = cleaned.replacingOccurrences(of: pattern, with: "")
        }
        cleaned = cleaned.trimmingCharacters(in: .whitespaces)

        let firstWord = cleaned.components(separatedBy: .whitespaces).first ?? cleaned
        let sing = singularize(firstWord)

        let figureTypes: [FigureType] = context.fetchAll()
        for ft in figureTypes {
            let name = ft.name.lowercased()
            if firstWord == name || sing == name {
                let count = ft.figures.count
                let label = count == 1 ? "There is 1 \(name) in the database." : "There are \(count) \(firstWord) in the database."
                return .answer(label)
            }
        }

        let aliasMap: [String: String] = ["gods": "deity", "goddesses": "deity", "goddess": "deity"]
        if let typeName = aliasMap[firstWord] ?? aliasMap[sing] {
            if let ft = figureTypes.first(where: { $0.name.lowercased() == typeName }) {
                let count = ft.figures.count
                return .answer("There are \(count) \(firstWord) in the database.")
            }
        }

        let singClean = singularize(cleaned)
        if singClean == "figure" || sing == "figure" {
            let all: [Figure] = context.fetchAll()
            return .answer("There are \(all.count) figures in the database.")
        }
        if singClean == "place" || sing == "place" {
            let all: [Place] = context.fetchAll()
            return .answer("There are \(all.count) places in the database.")
        }
        if singClean == "event" || sing == "event" {
            let all: [Event] = context.fetchAll()
            return .answer("There are \(all.count) events in the database.")
        }
        if singClean == "source" || sing == "source" {
            let all: [Source] = context.fetchAll()
            return .answer("There are \(all.count) sources in the database.")
        }
        if singClean == "thing" || sing == "thing" {
            let all: [Thing] = context.fetchAll()
            return .answer("There are \(all.count) things in the database.")
        }

        return nil
    }

    // MARK: - Structured Pipeline (Phase 2)

    private func matchStructuredQuery(_ text: String) -> QueryResult? {
        let stripped = text.replacingOccurrences(of: "[?.,!;:()]", with: " ", options: .regularExpression)
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        let lemText = lemmatize(stripped)

        guard let (entityRef, entityName) = extractEntity(from: text, lemText: lemText) else {
            return nil
        }

        var remaining = lemText
        if let range = remaining.range(of: entityName.lowercased()) {
            remaining.removeSubrange(range)
        }

        let clean = cleanQueryText(remaining)
        guard !clean.isEmpty else { return nil }

        return classifyEntityQuery(clean, entity: entityRef)
    }

    private func extractEntity(from text: String, lemText: String) -> (EntityRef, String)? {
        let tokens = tokenize(lemText)
        let figures: [Figure] = context.fetchAll()
        let places: [Place] = context.fetchAll()
        let events: [Event] = context.fetchAll()
        let things: [Thing] = context.fetchAll()

        var candidates: [(EntityRef, String, String)] = []
        for figure in figures { candidates.append((.figure(figure), figure.name, figure.name.lowercased())) }
        for place in places { candidates.append((.place(place), place.name, place.name.lowercased())) }
        for event in events { candidates.append((.event(event), event.name, event.name.lowercased())) }
        for thing in things { candidates.append((.thing(thing), thing.name, thing.name.lowercased())) }

        candidates.sort { $0.2.count > $1.2.count }

        for (entityRef, displayName, lowerName) in candidates {
            if tokens.contains(lowerName) {
                return (entityRef, displayName)
            }
        }

        if tokens.count >= 2 {
            for i in 0..<(tokens.count - 1) {
                let bigram = "\(tokens[i]) \(tokens[i + 1])"
                for (entityRef, displayName, lowerName) in candidates {
                    if lowerName == bigram { return (entityRef, displayName) }
                }
            }
        }

        return nil
    }

    private func tokenize(_ text: String) -> [String] {
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text
        var tokens: [String] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            tokens.append(String(text[range]))
            return true
        }
        return tokens
    }

    private func cleanQueryText(_ text: String) -> String {
        let helperVerbs: Set<String> = ["be", "have", "do", "can", "could", "will", "would", "shall", "should", "may", "might"]
        let questionWords: Set<String> = ["what", "who", "which", "where", "when", "why"]
        let articles: Set<String> = ["the", "a", "an"]

        let tokens = text.split(separator: " ").map(String.init)
        var filtered: [String] = []

        var i = 0
        while i < tokens.count {
            if tokens[i] == "how" && i + 1 < tokens.count && tokens[i + 1] == "many" {
                filtered.append("how_many")
                i += 2
                continue
            }

            let token = tokens[i]
            if helperVerbs.contains(token) || articles.contains(token) || questionWords.contains(token) {
                i += 1
                continue
            }

            filtered.append(token)
            i += 1
        }

        return filtered.joined(separator: " ")
    }

    private let specificRelationshipTypes: [String: String] = [
        "father": "Father", "mother": "Mother",
        "brother": "Brother", "sister": "Sister",
        "uncle": "Uncle", "aunt": "Aunt",
        "spouse": "Spouse", "consort": "Consort",
        "servant": "Servant", "commander": "Commander",
        "worshipper": "Worshipper", "creator": "Creator",
        "ally": "Ally", "enemy": "Enemy",
    ]

    private func labeledResults(for suffix: String, figure: Figure, pattern: FigureRelationPattern) -> (label: String, results: [Figure]) {
        let lemSuffix = lemmatize(suffix)
        if let typeName = specificRelationshipTypes[lemSuffix] {
            let allResults = pattern.finder(figure)
            let rels: [Relationship] = context.fetchAll()
            let filtered = allResults.filter { fig in
                rels.contains { rel in
                    rel.relationshipType?.name == typeName &&
                    ((rel.fromFigure?.persistentModelID == figure.persistentModelID && rel.toFigure?.persistentModelID == fig.persistentModelID) ||
                     (rel.toFigure?.persistentModelID == figure.persistentModelID && rel.fromFigure?.persistentModelID == fig.persistentModelID))
                }
            }
            return ("\(typeName) of \(figure.name)", filtered)
        }
        return (pattern.label(figure.name), pattern.finder(figure))
    }

    private func classifyEntityQuery(_ cleanText: String, entity: EntityRef) -> QueryResult? {
        let isCount = cleanText.hasPrefix("how_many ")

        for pattern in figureRelationPatterns {
            let lemSuffixes = pattern.possessiveSuffixes.map { lemmatize($0) }
            for (suffix, lemSuffix) in zip(pattern.possessiveSuffixes, lemSuffixes) {
                if cleanText.contains(lemSuffix) || cleanText.contains(suffix) {
                    switch entity {
                    case .figure(let figure):
                        if isCount {
                            let results = pattern.finder(figure)
                            let label = "\(figure.name) had \(results.count) \(results.count == 1 ? lemSuffix : suffix)"
                            return .figureList(label, results)
                        } else {
                            let (label, results) = labeledResults(for: suffix, figure: figure, pattern: pattern)
                            return .figureList(label, results)
                        }
                    case .place, .event, .thing:
                        return nil
                    }
                }
            }
        }

        // Phase 3: word embedding fallback for synonyms (e.g., "kids" → children)
        if let match = bestEmbeddingMatch(for: cleanText) {
            switch entity {
            case .figure(let figure):
                if isCount {
                    let results = match.pattern.finder(figure)
                    let lemSuffix = lemmatize(match.suffix)
                    let label = "\(figure.name) had \(results.count) \(results.count == 1 ? lemSuffix : match.suffix)"
                    return .figureList(label, results)
                } else {
                    let (label, results) = labeledResults(for: match.suffix, figure: figure, pattern: match.pattern)
                    return .figureList(label, results)
                }
            case .place, .event, .thing:
                return nil
            }
        }

        return nil
    }

    // MARK: - Word Embedding (Phase 3)

    private func cosineDistance(_ a: String, _ b: String, embedding: NLEmbedding) -> Double? {
        guard let va = embedding.vector(for: a), let vb = embedding.vector(for: b) else { return nil }
        let dot = zip(va, vb).reduce(0.0) { $0 + $1.0 * $1.1 }
        let na = sqrt(va.reduce(0.0) { $0 + $1 * $1 })
        let nb = sqrt(vb.reduce(0.0) { $0 + $1 * $1 })
        return 1 - (dot / (na * nb))
    }

    private func bestEmbeddingMatch(for cleanText: String) -> (pattern: FigureRelationPattern, suffix: String)? {
        guard let embedding = NLEmbedding.wordEmbedding(for: .english) else { return nil }

        let tokens = cleanText.split(separator: " ").map(String.init)
        let noiseWords: Set<String> = ["i", "me", "my", "want", "number", "list", "their", "its", "give", "show", "tell", "find", "name", "names", "and", "or", "of", "for", "the", "a", "an", "that", "this"]

        var suffixVectors: [(pattern: FigureRelationPattern, suffix: String, vector: [Double])] = []
        for pattern in figureRelationPatterns {
            for suffix in pattern.possessiveSuffixes {
                let lemSuffix = lemmatize(suffix)
                if let vec = embedding.vector(for: lemSuffix) {
                    suffixVectors.append((pattern, suffix, vec))
                }
            }
        }

        var bestResult: (pattern: FigureRelationPattern, suffix: String, distance: Double)?

        for token in tokens {
            let lower = token.lowercased()
            guard !noiseWords.contains(lower) else { continue }
            guard let tokenVec = embedding.vector(for: lower) else { continue }

            let tokenNorm = sqrt(tokenVec.reduce(0.0) { $0 + $1 * $1 })

            for (pattern, suffix, vec) in suffixVectors {
                let dot = zip(tokenVec, vec).reduce(0.0) { $0 + $1.0 * $1.1 }
                let vecNorm = sqrt(vec.reduce(0.0) { $0 + $1 * $1 })
                let distance = 1 - (dot / (tokenNorm * vecNorm))

                let threshold = 0.45

                if distance < threshold {
                    if bestResult == nil || distance < bestResult!.distance {
                        bestResult = (pattern, suffix, distance)
                    }
                }
            }
        }

        return bestResult.map { ($0.pattern, $0.suffix) }
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

    private func resolveThing(_ name: String) -> Thing? {
        let things = context.fetchAll() as [Thing]
        let query = name.lowercased()
        if let match = things.first(where: { $0.name.lowercased() == query }) {
            return match
        }
        return things.first(where: { $0.name.lowercased().contains(query) || query.contains($0.name.lowercased()) })
    }

    // MARK: - Relationship Finders

    private func findChildren(of figure: Figure) -> [Figure] {
        let relationships = context.fetchAll() as [Relationship]
        return relationships
            .filter { $0.relationshipType?.category == "parent" && $0.fromFigure?.persistentModelID == figure.persistentModelID }
            .compactMap { $0.toFigure }
    }

    private func findParents(of figure: Figure) -> [Figure] {
        let relationships = context.fetchAll() as [Relationship]
        return relationships
            .filter { $0.relationshipType?.category == "parent" && $0.toFigure?.persistentModelID == figure.persistentModelID }
            .compactMap { $0.fromFigure }
    }

    private func findSpouses(of figure: Figure) -> [Figure] {
        let relationships = context.fetchAll() as [Relationship]
        return relationships
            .filter { $0.relationshipType?.category == "partner" && ($0.fromFigure?.persistentModelID == figure.persistentModelID || $0.toFigure?.persistentModelID == figure.persistentModelID) }
            .compactMap { $0.fromFigure?.persistentModelID == figure.persistentModelID ? $0.toFigure : $0.fromFigure }
    }

    private func findSiblings(of figure: Figure) -> [Figure] {
        let relationships = context.fetchAll() as [Relationship]
        return relationships
            .filter { $0.relationshipType?.category == "sibling" && ($0.fromFigure?.persistentModelID == figure.persistentModelID || $0.toFigure?.persistentModelID == figure.persistentModelID) }
            .compactMap { $0.fromFigure?.persistentModelID == figure.persistentModelID ? $0.toFigure : $0.fromFigure }
    }

    private func findCreators(of figure: Figure) -> [Figure] {
        let relationships = context.fetchAll() as [Relationship]
        return relationships
            .filter { $0.relationshipType?.category == "creator" && $0.toFigure?.persistentModelID == figure.persistentModelID }
            .compactMap { $0.fromFigure }
    }

    private func findCreations(of figure: Figure) -> [Figure] {
        let relationships = context.fetchAll() as [Relationship]
        return relationships
            .filter { $0.relationshipType?.category == "creator" && $0.fromFigure?.persistentModelID == figure.persistentModelID }
            .compactMap { $0.toFigure }
    }

    private func findUncles(of figure: Figure) -> [Figure] {
        let relationships = context.fetchAll() as [Relationship]
        return relationships
            .filter { $0.relationshipType?.name == "Uncle" && $0.toFigure?.persistentModelID == figure.persistentModelID }
            .compactMap { $0.fromFigure }
    }

    private func findAunts(of figure: Figure) -> [Figure] {
        let relationships = context.fetchAll() as [Relationship]
        return relationships
            .filter { $0.relationshipType?.name == "Aunt" && $0.toFigure?.persistentModelID == figure.persistentModelID }
            .compactMap { $0.fromFigure }
    }

    private func findCommanders(of figure: Figure) -> [Figure] {
        let relationships = context.fetchAll() as [Relationship]
        return relationships
            .filter { $0.relationshipType?.name == "Commander" && $0.toFigure?.persistentModelID == figure.persistentModelID }
            .compactMap { $0.fromFigure }
    }

    private func findServants(of figure: Figure) -> [Figure] {
        let relationships = context.fetchAll() as [Relationship]
        return relationships
            .filter { $0.relationshipType?.name == "Servant" && $0.toFigure?.persistentModelID == figure.persistentModelID }
            .compactMap { $0.fromFigure }
    }

    private func findAllies(of figure: Figure) -> [Figure] {
        let relationships = context.fetchAll() as [Relationship]
        return relationships
            .filter { $0.relationshipType?.name == "Ally" && ($0.fromFigure?.persistentModelID == figure.persistentModelID || $0.toFigure?.persistentModelID == figure.persistentModelID) }
            .compactMap { $0.fromFigure?.persistentModelID == figure.persistentModelID ? $0.toFigure : $0.fromFigure }
    }

    private func findEnemies(of figure: Figure) -> [Figure] {
        let relationships = context.fetchAll() as [Relationship]
        return relationships
            .filter { $0.relationshipType?.name == "Enemy" && ($0.fromFigure?.persistentModelID == figure.persistentModelID || $0.toFigure?.persistentModelID == figure.persistentModelID) }
            .compactMap { $0.fromFigure?.persistentModelID == figure.persistentModelID ? $0.toFigure : $0.fromFigure }
    }

    private func findWorshippers(of figure: Figure) -> [Figure] {
        let relationships = context.fetchAll() as [Relationship]
        return relationships
            .filter { $0.relationshipType?.name == "Worshipper" && $0.toFigure?.persistentModelID == figure.persistentModelID }
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

    // MARK: - Yes/No and Choice Questions

    private func matchYesNoQuery(_ text: String) -> QueryResult? {
        guard text.hasPrefix("was ") || text.hasPrefix("is ") else { return nil }

        let stripped = text.replacingOccurrences(of: "[?.,!;:()]", with: " ", options: .regularExpression)
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        let lemText = lemmatize(stripped)

        guard let (entityRef, entityName) = extractEntity(from: text, lemText: lemText) else { return nil }

        var remaining = lemText
        if let range = remaining.range(of: entityName.lowercased()) {
            remaining.removeSubrange(range)
        }

        let clean = cleanQueryText(remaining)
        guard !clean.isEmpty else { return nil }

        let isChoice = clean.contains(" or ")

        switch entityRef {
        case .figure(let figure):
            let typeName = figure.figureType?.name.lowercased() ?? ""
            let domain = figure.domain.lowercased()
            let description = figure.figureDescription.lowercased()

            if isChoice {
                guard let orRange = clean.range(of: " or ") else { return nil }
                let first = stripLeadingArticle(String(clean[..<orRange.lowerBound]).trimmingCharacters(in: .whitespaces))
                let second = stripLeadingArticle(String(clean[orRange.upperBound...]).trimmingCharacters(in: .whitespaces))
                guard !first.isEmpty, !second.isEmpty else { return nil }

                let matchFirst = typeName == first || domain == first || description.contains(first)
                let matchSecond = typeName == second || domain == second || description.contains(second)

                if matchFirst && !matchSecond {
                    return .answer("\(figure.name) is a \(first.capitalized), not a \(second.capitalized).")
                } else if matchSecond && !matchFirst {
                    return .answer("\(figure.name) is a \(second.capitalized), not a \(first.capitalized).")
                } else {
                    return .answer("\(figure.name) is a \(typeName.capitalized).")
                }
            } else {
                let first = stripLeadingArticle(clean.trimmingCharacters(in: .whitespaces))
                guard !first.isEmpty else { return nil }

                let match = typeName == first || domain == first || description.contains(first)
                if match {
                    return .answer("Yes, \(figure.name) is a \(first.capitalized).")
                } else {
                    return .answer("No, \(figure.name) is a \(typeName.capitalized), not a \(first.capitalized).")
                }
            }

        case .place(let place):
            let typeName = place.placeType?.name.lowercased() ?? ""
            return handleEntityTypeCheck(clean, entityName: place.name, typeName: typeName, isChoice: isChoice)

        case .event(let event):
            let typeName = event.eventType?.name.lowercased() ?? ""
            return handleEntityTypeCheck(clean, entityName: event.name, typeName: typeName, isChoice: isChoice)

        case .thing:
            return nil
        }
    }

    private func handleEntityTypeCheck(_ clean: String, entityName: String, typeName: String, isChoice: Bool) -> QueryResult? {
        if isChoice {
            guard let orRange = clean.range(of: " or ") else { return nil }
            let first = stripLeadingArticle(String(clean[..<orRange.lowerBound]).trimmingCharacters(in: .whitespaces))
            let second = stripLeadingArticle(String(clean[orRange.upperBound...]).trimmingCharacters(in: .whitespaces))
            guard !first.isEmpty, !second.isEmpty else { return nil }

            let matchFirst = typeName == first
            let matchSecond = typeName == second

            if matchFirst && !matchSecond {
                return .answer("\(entityName) is a \(first.capitalized), not a \(second.capitalized).")
            } else if matchSecond && !matchFirst {
                return .answer("\(entityName) is a \(second.capitalized), not a \(first.capitalized).")
            } else {
                return .answer("\(entityName) is a \(typeName.capitalized).")
            }
        } else {
            let first = stripLeadingArticle(clean.trimmingCharacters(in: .whitespaces))
            guard !first.isEmpty else { return nil }

            if typeName == first {
                return .answer("Yes, \(entityName) is a \(first.capitalized).")
            } else {
                return .answer("No, \(entityName) is a \(typeName.capitalized), not a \(first.capitalized).")
            }
        }
    }

    private func stripLeadingArticle(_ s: String) -> String {
        let articles = ["a ", "an ", "the "]
        var result = s
        for article in articles {
            if result.hasPrefix(article) {
                result = String(result.dropFirst(article.count))
                break
            }
        }
        return result
    }

    // MARK: - Helpers

    private func lemmatize(_ text: String) -> String {
        let tagger = NLTagger(tagSchemes: [.lemma])
        tagger.string = text
        var result = ""
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lemma) { tag, range in
            let raw = tag?.rawValue ?? String(text[range])
            if raw.hasSuffix("'s") {
                result += String(raw.dropLast(2))
            } else {
                result += raw
            }
            return true
        }
        return result.lowercased()
    }

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

    private func matchImageQuery(_ text: String) -> QueryResult? {
        let patterns = ["images of ", "pictures of ", "show images of ", "show pictures of ", "image of ", "picture of "]
        guard let name = extractPattern(text, patterns: patterns) else { return nil }

        let allImages: [ImageAsset] = context.fetchAll()

        if let figure = resolveFigure(name) {
            if !figure.images.isEmpty {
                return .imageList("Images of \(figure.name)", figure.images)
            }
        }
        if let place = resolvePlace(name) {
            if !place.images.isEmpty {
                return .imageList("Images of \(place.name)", place.images)
            }
        }
        if let event = resolveEvent(name) {
            if !event.images.isEmpty {
                return .imageList("Images of \(event.name)", event.images)
            }
        }

        let q = name.lowercased()
        let matched = allImages.filter {
            $0.caption.lowercased().contains(q) ||
            $0.filename.lowercased().contains(q) ||
            $0.figures.contains(where: { $0.name.lowercased().contains(q) }) ||
            $0.places.contains(where: { $0.name.lowercased().contains(q) }) ||
            $0.events.contains(where: { $0.name.lowercased().contains(q) })
        }
        if !matched.isEmpty {
            return .imageList("Images matching \"\(name)\"", matched)
        }

        return nil
    }
}
