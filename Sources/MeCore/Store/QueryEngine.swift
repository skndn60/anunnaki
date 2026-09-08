import Foundation
import NaturalLanguage
import SwiftData

/// Result of a query — what entity was matched and all related data.
package enum QueryResult {
    case figure(FigureDossier)
    case place(PlaceDossier)
    case event(EventDossier)
    case figureList(String, [Figure])
    case figureListAnnotated(String, [(Figure, String?)])
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

    private let context: ModelContext

    private struct QueryCache {
        let figures: [Figure]
        let places: [Place]
        let events: [Event]
        let things: [Thing]
        let relationships: [Relationship]
        let alternateNames: [AlternateName]
        let sources: [Source]
        let eras: [Era]
        let figureTypes: [FigureType]
        let images: [ImageAsset]
        let retriever: RetrievalIndex
    }

    private var cache: QueryCache?

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
                prepositionalPrefixes: ["creator of ", "creators of "],
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

        cache = QueryCache(
            figures: context.fetchAll() as [Figure],
            places: context.fetchAll() as [Place],
            events: context.fetchAll() as [Event],
            things: context.fetchAll() as [Thing],
            relationships: context.fetchAll() as [Relationship],
            alternateNames: context.fetchAll() as [AlternateName],
            sources: context.fetchAll() as [Source],
            eras: context.fetchAll() as [Era],
            figureTypes: context.fetchAll() as [FigureType],
            images: context.fetchAll() as [ImageAsset],
            retriever: RetrievalIndex(
                figures: context.fetchAll() as [Figure],
                places: context.fetchAll() as [Place],
                events: context.fetchAll() as [Event],
                things: context.fetchAll() as [Thing],
                alternateNames: context.fetchAll() as [AlternateName]
            )
        )

        defer { cache = nil }

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

        // Gender-based: "female deities", "male figures"
        if let result = matchGenderQuery(text) { return result }

        // "how many X had Y" — uses lemmatized text for verb normalization
        if let result = matchHowManyQuery(text) { return result }

        // "how many [type]" — count entities by type
        if let result = matchHowManyTypeQuery(text) { return result }

        // Image search: "images of X", "pictures of X"
        if let result = matchImageQuery(text) { return result }

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

        if !cleaned.isEmpty {
            if let result = exactEntityMatch(cleaned) { return result }
        }

        return .noMatch(input)
    }

    /// Exact-name lookup only: the input (after prefix stripping) must equal a
    /// canonical name or an alternate name. Never resolves a whole sentence to an
    /// entity — ambiguous input falls through to `.noMatch` (and the LLM fallback).
    private func exactEntityMatch(_ name: String) -> QueryResult? {
        let q = name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return nil }

        let figures = cache!.figures
        let places = cache!.places
        let events = cache!.events
        let things = cache!.things
        let alternateNames = cache!.alternateNames

        if let figure = figures.first(where: { $0.name.lowercased() == q }) {
            return .figure(context.buildFigureDossier(figure))
        }
        if let place = places.first(where: { $0.name.lowercased() == q }) {
            return .place(context.buildPlaceDossier(place))
        }
        if let event = events.first(where: { $0.name.lowercased() == q }) {
            return .event(context.buildEventDossier(event))
        }
        if let thing = things.first(where: { $0.name.lowercased() == q }) {
            return .thing(thing)
        }

        for alt in alternateNames {
            guard alt.name.lowercased() == q else { continue }
            if let figure = alt.figure {
                return .figure(context.buildFigureDossier(figure, matchedAlias: alt.name))
            }
            if let place = alt.place {
                return .place(context.buildPlaceDossier(place))
            }
        }
        return nil
    }

    // MARK: - Pattern Matching Steps

    private func siblingGenderFilter(_ text: String) -> Figure.Gender? {
        let lower = text.lowercased()
        if lower.contains("sister") { return .female }
        if lower.contains("brother") { return .male }
        return nil
    }

    private func matchFigureRelationPossessive(_ text: String) -> QueryResult? {
        for pattern in figureRelationPatterns {
            if let name = extractPossessivePattern(text, suffixes: pattern.possessiveSuffixes) {
                if let figure = resolveFigure(name) {
                    let results = pattern.finder(figure)
                    if pattern.possessiveSuffixes.contains("siblings") {
                        let annotated = findSiblingsAnnotated(of: figure, genderFilter: siblingGenderFilter(text))
                        return .figureListAnnotated(pattern.label(figure.name), annotated)
                    }
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
                    if pattern.possessiveSuffixes.contains("siblings") {
                        let annotated = findSiblingsAnnotated(of: figure, genderFilter: siblingGenderFilter(text))
                        return .figureListAnnotated(pattern.label(figure.name), annotated)
                    }
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
        let eras = cache!.eras
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
            }
        }

        return nil
    }

    private func exactFigure(_ name: String) -> Figure? {
        let figures = cache!.figures
        return figures.first(where: { $0.name.lowercased() == name.lowercased() })
    }

    private func resolveEraByName(_ name: String) -> Era? {
        let eras = cache!.eras
        let q = name.lowercased()
        if let match = eras.first(where: { $0.name.lowercased() == q }) { return match }
        return eras.first(where: { $0.name.lowercased().contains(q) || q.contains($0.name.lowercased()) })
    }

    private func matchListingPatterns(_ text: String) -> QueryResult? {
        let c = cache!

        switch text {
        case "list all figures", "show all figures", "all figures", "list figures", "show figures":
            return .figureList("All Figures", c.figures)
        case "list all places", "show all places", "all places", "list places", "show places":
            return .placeList("All Places", c.places)
        case "list all events", "show all events", "all events", "list events", "show events":
            return .eventList("All Events", c.events)
        case "list all things", "show all things", "all things", "list things", "show things":
            return .thingList("All Things", c.things)
        case "list all sources", "show all sources", "all sources", "list sources", "show sources":
            let names = c.sources.filter { !$0.name.isEmpty }.map { $0.name }
            if names.isEmpty {
                return .answer("No sources in the database.")
            }
            return .answer("Sources:\n" + names.joined(separator: "\n"))
        default:
            break
        }

        // "all deities", "all gods", "all humans", etc.
        let figureTypes = cache!.figureTypes
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

    private func matchGenderQuery(_ text: String) -> QueryResult? {
        let figures = cache!.figures

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

    private func matchHowManyQuery(_ text: String) -> QueryResult? {
        guard text.hasPrefix("how many ") else { return nil }
        let rest = String(text.dropFirst("how many ".count))
        let lemRest = lemmatize(rest)

        for pattern in figureRelationPatterns {
            for (suffix, lemSuffix) in zip(pattern.possessiveSuffixes, pattern.possessiveSuffixes.map({ lemmatize($0) })) {
                var entityName: String?
                if let range = lemRest.range(of: "\(lemSuffix) have "),
                   range.lowerBound == lemRest.startIndex {
                    entityName = String(lemRest[range.upperBound...])
                } else if let match = try? NSRegularExpression(
                    pattern: "^\(NSRegularExpression.escapedPattern(for: lemSuffix)) (?:do|did|does) (.+?) have\\b"
                ).firstMatch(in: lemRest, range: NSRange(lemRest.startIndex..., in: lemRest)),
                   let nameRange = Range(match.range(at: 1), in: lemRest) {
                    entityName = String(lemRest[nameRange])
                }
                if let entityName,
                   let figure = resolveFigure(entityName.trimmingCharacters(in: .punctuationCharacters).trimmingCharacters(in: .whitespaces)) {
                    let results = pattern.finder(figure)
                    let label = "\(figure.name) had \(results.count) \(results.count == 1 ? lemSuffix : suffix)"
                    return .figureList(label, results)
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

        let figureTypes = cache!.figureTypes
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
            let all = cache!.figures
            return .answer("There are \(all.count) figures in the database.")
        }
        if singClean == "place" || sing == "place" {
            let all = cache!.places
            return .answer("There are \(all.count) places in the database.")
        }
        if singClean == "event" || sing == "event" {
            let all = cache!.events
            return .answer("There are \(all.count) events in the database.")
        }
        if singClean == "source" || sing == "source" {
            let all = cache!.sources
            return .answer("There are \(all.count) sources in the database.")
        }
        if singClean == "thing" || sing == "thing" {
            let all = cache!.things
            return .answer("There are \(all.count) things in the database.")
        }

        return nil
    }

    // MARK: - Entity Resolution

    private func resolveFigure(_ name: String) -> Figure? {
        cache!.retriever.resolveFigure(name)
    }


    private func resolveFigureByAlternateName(_ name: String) -> Figure? {
        let altNames = cache!.alternateNames
        let query = name.lowercased()
        if let match = altNames.first(where: { $0.name.lowercased() == query || $0.name.lowercased().contains(query) }) {
            return match.figure
        }
        return nil
    }


    private func resolvePlace(_ name: String) -> Place? {
        cache!.retriever.resolvePlace(name)
    }

    private func resolveEvent(_ name: String) -> Event? {
        cache!.retriever.resolveEvent(name)
    }

    // MARK: - Relationship Finders

    private func findChildren(of figure: Figure) -> [Figure] {
        let relationships = cache!.relationships
        return relationships
            .filter { $0.relationshipType?.category == "parent" && $0.fromFigure?.persistentModelID == figure.persistentModelID }
            .compactMap { $0.toFigure }
    }

    private func findParents(of figure: Figure) -> [Figure] {
        let relationships = cache!.relationships
        return relationships
            .filter { $0.relationshipType?.category == "parent" && $0.toFigure?.persistentModelID == figure.persistentModelID }
            .compactMap { $0.fromFigure }
    }

    private func findSpouses(of figure: Figure) -> [Figure] {
        let relationships = cache!.relationships
        return relationships
            .filter { $0.relationshipType?.category == "partner" && ($0.fromFigure?.persistentModelID == figure.persistentModelID || $0.toFigure?.persistentModelID == figure.persistentModelID) }
            .compactMap { $0.fromFigure?.persistentModelID == figure.persistentModelID ? $0.toFigure : $0.fromFigure }
    }

    private func findSiblings(of figure: Figure) -> [Figure] {
        findSiblingsAnnotated(of: figure, genderFilter: nil).map { $0.0 }
    }

    private func findSiblingsAnnotated(of figure: Figure, genderFilter: Figure.Gender? = nil) -> [(Figure, String?)] {
        let relationships = cache!.relationships
        var seenIDs = Set<PersistentIdentifier>()
        var full: [Figure] = []
        var half: [Figure] = []

        func matchesGender(_ f: Figure) -> Bool {
            genderFilter == nil || f.gender == genderFilter
        }

        for rel in relationships {
            guard rel.relationshipType?.category == "sibling" else { continue }
            if rel.fromFigure?.persistentModelID == figure.persistentModelID,
               let s = rel.toFigure, !seenIDs.contains(s.persistentModelID), matchesGender(s) {
                seenIDs.insert(s.persistentModelID)
                full.append(s)
            } else if rel.toFigure?.persistentModelID == figure.persistentModelID,
                      let s = rel.fromFigure, !seenIDs.contains(s.persistentModelID), matchesGender(s) {
                seenIDs.insert(s.persistentModelID)
                full.append(s)
            }
        }

        let figureParentIDs = Set(findParents(of: figure).map(\.persistentModelID))
        guard !figureParentIDs.isEmpty else { return full.map { ($0, nil) } + half.map { ($0, "half sibling") } }

        let allFigures = Set(cache!.figures)
        for candidate in allFigures {
            guard candidate.persistentModelID != figure.persistentModelID,
                  !seenIDs.contains(candidate.persistentModelID),
                  matchesGender(candidate) else { continue }
            let candidateParentIDs = Set(findParents(of: candidate).map(\.persistentModelID))
            guard !candidateParentIDs.isEmpty else { continue }
            if figureParentIDs == candidateParentIDs {
                seenIDs.insert(candidate.persistentModelID)
                full.append(candidate)
            } else if !figureParentIDs.isDisjoint(with: candidateParentIDs) {
                seenIDs.insert(candidate.persistentModelID)
                half.append(candidate)
            }
        }

        return full.map { ($0, nil) } + half.map { ($0, "half sibling") }
    }

    private func findCreators(of figure: Figure) -> [Figure] {
        let relationships = cache!.relationships
        return relationships
            .filter { $0.relationshipType?.category == "creator" && $0.toFigure?.persistentModelID == figure.persistentModelID }
            .compactMap { $0.fromFigure }
    }

    private func findCreations(of figure: Figure) -> [Figure] {
        let relationships = cache!.relationships
        return relationships
            .filter { $0.relationshipType?.category == "creator" && $0.fromFigure?.persistentModelID == figure.persistentModelID }
            .compactMap { $0.toFigure }
    }

    private func findUncles(of figure: Figure) -> [Figure] {
        let relationships = cache!.relationships
        return relationships
            .filter { $0.relationshipType?.name == "Uncle" && $0.toFigure?.persistentModelID == figure.persistentModelID }
            .compactMap { $0.fromFigure }
    }

    private func findAunts(of figure: Figure) -> [Figure] {
        let relationships = cache!.relationships
        return relationships
            .filter { $0.relationshipType?.name == "Aunt" && $0.toFigure?.persistentModelID == figure.persistentModelID }
            .compactMap { $0.fromFigure }
    }

    private func findCommanders(of figure: Figure) -> [Figure] {
        let relationships = cache!.relationships
        return relationships
            .filter { $0.relationshipType?.name == "Commander" && $0.toFigure?.persistentModelID == figure.persistentModelID }
            .compactMap { $0.fromFigure }
    }

    private func findServants(of figure: Figure) -> [Figure] {
        let relationships = cache!.relationships
        return relationships
            .filter { $0.relationshipType?.name == "Servant" && $0.toFigure?.persistentModelID == figure.persistentModelID }
            .compactMap { $0.fromFigure }
    }

    private func findAllies(of figure: Figure) -> [Figure] {
        let relationships = cache!.relationships
        return relationships
            .filter { $0.relationshipType?.name == "Ally" && ($0.fromFigure?.persistentModelID == figure.persistentModelID || $0.toFigure?.persistentModelID == figure.persistentModelID) }
            .compactMap { $0.fromFigure?.persistentModelID == figure.persistentModelID ? $0.toFigure : $0.fromFigure }
    }

    private func findEnemies(of figure: Figure) -> [Figure] {
        let relationships = cache!.relationships
        return relationships
            .filter { $0.relationshipType?.name == "Enemy" && ($0.fromFigure?.persistentModelID == figure.persistentModelID || $0.toFigure?.persistentModelID == figure.persistentModelID) }
            .compactMap { $0.fromFigure?.persistentModelID == figure.persistentModelID ? $0.toFigure : $0.fromFigure }
    }

    private func findWorshippers(of figure: Figure) -> [Figure] {
        let relationships = cache!.relationships
        return relationships
            .filter { $0.relationshipType?.name == "Worshipper" && $0.toFigure?.persistentModelID == figure.persistentModelID }
            .compactMap { $0.fromFigure }
    }

    private func findEvents(byPlaceName placeName: String) -> [Event] {
        let places = cache!.places
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

        let allImages = cache!.images

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
