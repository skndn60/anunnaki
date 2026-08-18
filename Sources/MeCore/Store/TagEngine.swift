import Foundation

/// Derives a deterministic set of suggested tags for each entity kind from the
/// entity's already-curated structured fields (type, gender, domain, era, source,
/// description). Used by `Migration.ensureAutoTags` to tag entities that have no
/// tags yet. Pure and testable — no model context, no side effects.
package enum TagEngine {

    private static let traditionKeywords: [(keyword: String, tag: String)] = [
        ("Sumerian King List", "sumerian king list"),
        ("Enuma Elish", "enuma elish"),
        ("Book of Enoch", "book of enoch"),
        ("Atra-Hasis", "atrahasis"),
        ("Atrahasis", "atrahasis"),
        ("Epic of Gilgamesh", "epic of gilgamesh"),
        ("Inanna's Descent", "inanna's descent"),
        ("Enlil and Ninlil", "enlil and ninlil"),
        ("Sumerian", "sumerian tradition"),
        ("Babylonian", "babylonian tradition"),
        ("Akkadian", "akkadian tradition"),
    ]

    // MARK: - Figure

    package static func tags(for figure: Figure) -> Set<String> {
        var tags = Set<String>()

        if let typeName = figure.figureType?.name, !typeName.isEmpty {
            tags.insert(figureTypeTag(typeName))
        }

        let typeName = figure.figureType?.name ?? ""
        let isDeity = typeName.caseInsensitiveCompare("Deity") == .orderedSame
        if isDeity {
            switch figure.gender {
            case .male: tags.insert("god")
            case .female: tags.insert("goddess")
            default: break
            }
        }

        for domainTag in domainTags(figure.domain) {
            tags.insert(domainTag)
        }

        if isKing(figure) {
            tags.insert("king")
        }

        if let tradition = traditionTag(from: figure.source) {
            tags.insert(tradition)
        }

        if let era = eraTag(figure.birthDate.era) {
            tags.insert(era)
        }

        return tags
    }

    /// A human or semi-divine figure whose domain describes kingship.
    package static func isKing(_ figure: Figure) -> Bool {
        let typeName = figure.figureType?.name ?? ""
        let rulingKind = typeName.caseInsensitiveCompare("Human") == .orderedSame
            || typeName.caseInsensitiveCompare("Semi-Divine") == .orderedSame
        guard rulingKind else { return false }
        return figure.domain.localizedCaseInsensitiveContains("Kingship")
    }

    package static func figureTypeTag(_ typeName: String) -> String {
        switch typeName.lowercased() {
        case "deity": return "deity"
        case "primordial": return "primordial"
        case "human": return "human"
        case "semi-divine": return "semi-divine"
        case "divine collective": return "divine collective"
        case "archangel": return "archangel"
        case "igigi": return "igigi"
        case "commander": return "watcher"
        default:
            let cleaned = cleanedToken(typeName)
            return cleaned.isEmpty ? "uncategorized" : cleaned
        }
    }

    // MARK: - Place

    package static func tags(for place: Place) -> Set<String> {
        var tags = Set<String>()

        if let typeName = place.placeType?.name, !typeName.isEmpty {
            tags.insert(placeTypeTag(typeName))
        }

        if let tradition = traditionTag(from: place.source) {
            tags.insert(tradition)
        }

        if let region = modernRegionTag(place.modernLocation) {
            tags.insert(region)
        }

        if let historical = historicalRegionTag(place.name) {
            tags.insert(historical)
        }

        return tags
    }

    package static func placeTypeTag(_ typeName: String) -> String {
        let cleaned = cleanedToken(typeName)
        switch cleaned {
        case "body of water": return "body of water"
        case "cosmic realm": return "cosmic realm"
        case "underworld": return "underworld"
        case "ziggurat": return "ziggurat"
        default:
            return cleaned.isEmpty ? "uncategorized" : cleaned
        }
    }

    // MARK: - Event

    package static func tags(for event: Event) -> Set<String> {
        var tags = Set<String>()

        if let typeName = event.eventType?.name, !typeName.isEmpty {
            tags.insert(eventTypeTag(typeName))
        }

        if let era = eraTag(event.era) {
            tags.insert(era)
        }

        if let tradition = traditionTag(from: event.source) {
            tags.insert(tradition)
        }

        return tags
    }

    package static func eventTypeTag(_ typeName: String) -> String {
        switch typeName.lowercased() {
        case "battle": return "battle"
        case "foundation": return "foundation"
        case "destruction": return "destruction"
        case "creation": return "creation"
        case "city founding": return "city founding"
        case "quest": return "quest"
        case "ascension": return "ascension"
        case "descent": return "descent"
        case "death": return "death"
        case "drought": return "drought"
        case "flood": return "flood"
        case "achievement": return "achievement"
        case "business transaction": return "business"
        case "long running build project": return "construction"
        default:
            let cleaned = cleanedToken(typeName)
            return cleaned.isEmpty ? "uncategorized" : cleaned
        }
    }

    // MARK: - Thing

    package static func tags(for thing: Thing) -> Set<String> {
        thingCategoryTags(name: thing.name, description: thing.thingDescription)
    }

    package static func thingCategoryTags(name: String, description: String) -> Set<String> {
        let nameLower = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let text = (name + " " + description).lowercased()

        var tags = Set<String>()

        let checks: [(keywords: [String], tag: String)] = [
            (["atra-hasis", "instructions of suruppak", "descent into the nether", "ascent from the nether"], "literary work"),
            (["seal", "dagger", "lyre", "headdress", "crown", "tablet", "obelis", "standard", "throne", "ram in", "weapon", "archive", "insignia", "chamber", "shrine", "ship", "boat", "ziggurat", "carnelian", "lapis", "bandudu", "mullilu", "sceptre", "tomb", "banner", "vessel"], "artifact"),
            (["truth", "law", "libel", "peace", "fear", "strife", "enmity", "falsehood", "heroism", "power", "counsel", "attention", "weariness", "terror", "victory", "judgment", "straightforwardness", "rejoicing", "troubled heart", "sexual", "tree of life", "purification", "art"], "concept"),
            (["kingship", "godship", "ladyship", "enship", "shepherdship", "scribeship", "priestly", "hierodule", "divine lady", "entertainer", "galatura"], "office"),
            (["art of", "craft", "music"], "craft"),
        ]
        for check in checks {
            if check.keywords.contains(where: { text.contains($0) }) {
                tags.insert(check.tag)
            }
        }

        if nameLower == "me" {
            tags.insert("divine powers")
            tags.insert("concept")
        }
        if nameLower == "the flood" {
            tags.insert("flood")
        }

        return tags
    }

    // MARK: - Shared

    private static let domainStopwords: Set<String> = [
        "a", "an", "and", "as", "at", "by", "for", "from", "in", "of",
        "on", "or", "the", "to", "with", "about",
        "associated", "related", "relating", "pertaining", "concerning",
    ]

    /// Splits a comma-separated domain like `"Sky, Kingship, Authority"` into its
    /// facet tags (`"sky"`, `"kingship"`, `"authority"`). Each facet is further
    /// broken into single words with connectors/stopwords dropped, so prose like
    /// `"associated with farming and fertility"` yields `"farming"`, `"fertility"`.
    /// Empty results and duplicates are dropped.
    package static func domainTags(_ domain: String) -> [String] {
        let phrases = domain.split(whereSeparator: { $0 == "," || $0 == ";" })
        var result: [String] = []
        var seen = Set<String>()
        for phrase in phrases {
            for word in cleanedToken(String(phrase)).split(separator: " ") {
                guard !domainStopwords.contains(String(word)) else { continue }
                let tag = String(word)
                guard seen.insert(tag).inserted else { continue }
                result.append(tag)
            }
        }
        return result
    }

    package static func eraTag(_ era: String) -> String? {
        let cleaned = cleanedToken(era)
        guard !cleaned.isEmpty else { return nil }
        return cleaned
    }

    package static func traditionTag(from source: String) -> String? {
        for entry in traditionKeywords where source.localizedCaseInsensitiveContains(entry.keyword) {
            return entry.tag
        }
        return nil
    }

    private static let regionKeywords: [(keyword: String, tag: String)] = [
        ("United Arab Emirates", "uae"),
        ("Iraq", "iraq"),
        ("Iran", "iran"),
        ("Syria", "syria"),
        ("Turkey", "turkey"),
        ("Lebanon", "lebanon"),
        ("Israel", "israel"),
        ("Jordan", "jordan"),
        ("Oman", "oman"),
        ("Saudi", "saudi arabia"),
        ("Kuwait", "kuwait"),
        ("Bahrain", "bahrain"),
    ]

    package static func modernRegionTag(_ modernLocation: String) -> String? {
        for entry in regionKeywords where modernLocation.localizedCaseInsensitiveContains(entry.keyword) {
            return entry.tag
        }
        return nil
    }

    /// Tags a place by its own name when the name encodes a historical region
    /// that carries no modern-location data (e.g. "Upper Mesopotamia").
    package static func historicalRegionTag(_ name: String) -> String? {
        if name.localizedCaseInsensitiveContains("mesopotamia") {
            return "mesopotamia"
        }
        return nil
    }

    /// Deterministic palette color for a tag name — stable across launches and stores.
    package static func colorHex(for tagName: String) -> String {
        let palette = [
            "FF9500", "007AFF", "FF2D55", "34C759", "AF52DE",
            "FF3B30", "5856D6", "8E8E93", "FFCC00", "5AC8FA",
            "4CD964", "FF6482", "A2845E", "F59E0B", "10B981",
            "6366F1", "EC4899", "14B8A6", "F97316", "0EA5E9",
        ]
        var hash = 0
        for byte in tagName.utf8 {
            hash = (hash &* 31 &+ Int(byte)) & 0x7fff_ffff
        }
        return palette[hash % palette.count]
    }

    /// Normalizes a phrase into a tag token: lowercase, trimmed, single spaces,
    /// trailing periods removed.
    package static func cleanedToken(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        while s.hasSuffix(".") { s.removeLast() }
        s = s.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = s.split(whereSeparator: { $0.isWhitespace })
        return parts.joined(separator: " ").lowercased()
    }
}
