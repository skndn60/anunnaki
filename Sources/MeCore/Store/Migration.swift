import Foundation
import SwiftData

package struct Migration {

    package static let defaultRelationTypes: [(name: String, icon: String, colorHex: String, category: String)] = [
        ("Father", "arrow.down", "007AFF", "parent"),
        ("Mother", "arrow.down", "FF2D55", "parent"),
        ("Spouse", "heart", "FF3B30", "partner"),
        ("Consort", "heart.circle", "AF52DE", "partner"),
        ("Sibling", "arrow.left.arrow.right", "FF9500", "sibling"),
        ("Uncle", "person.line.dotted.person", "55BEF0", "extended_family"),
        ("Aunt", "person.line.dotted.person", "55BEF0", "extended_family"),
        ("Creator", "wand.and.stars", "AF52DE", "creator"),
        ("Commander", "shield.lefthalf.filled", "FFCC00", "military"),
        ("Servant", "hand.raised", "A2845E", "servitude"),
        ("Ally", "person.2.fill", "34C759", "social"),
        ("Enemy", "flame", "FF3B30", "social"),
        ("Worshipper", "heart.circle.fill", "5856D6", "worship"),
    ]

    package static let defaultPlacePlaceRoleTypes: [(name: String, icon: String, colorHex: String)] = [
        ("Located Within", "arrow.down.right.and.arrow.up.left", "34C759"),
        ("Near To", "arrow.triangle.branch", "8E8E93"),
        ("Part Of", "square.on.square", "007AFF"),
        ("Ruled From", "crown.fill", "FFCC00"),
        ("Connected To", "link", "AF52DE"),
        ("Opposed To", "flame", "FF3B30"),
    ]

    package static let defaultEventEventRoleTypes: [(name: String, icon: String, colorHex: String)] = [
        ("Caused", "arrow.right.circle", "FF3B30"),
        ("Motivated", "heart.fill", "FF2D55"),
        ("Precedes", "arrow.forward", "FF9500"),
        ("Follows", "arrow.backward", "5856D6"),
        ("Related To", "link", "007AFF"),
        ("Contradicts", "xmark.circle", "8B8B8B"),
        ("Parallels", "equal.circle", "34C759"),
    ]

    package static let defaultEventPlaceRoleTypes: [(name: String, icon: String, colorHex: String)] = [
        ("Occurred At", "mappin.and.ellipse", "007AFF"),
        ("Started At", "arrow.right.to.line", "34C759"),
        ("Ended At", "arrow.left.to.line", "FF3B30"),
        ("Passed Through", "arrow.triangle.swap", "AF52DE"),
    ]

    package static let defaultFigurePlaceRoleTypes: [(name: String, icon: String, colorHex: String)] = [
        ("Patron Deity", "star.fill", "FF9500"),
        ("Ruler", "crown.fill", "FFCC00"),
        ("Builder", "hammer.fill", "8E8E93"),
        ("Founder", "flag.fill", "34C759"),
        ("Born At", "figure.child", "007AFF"),
        ("Died At", "cross.fill", "FF3B30"),
        ("Resident Of", "house.fill", "AF52DE"),
        ("Imprisoned At", "lock.fill", "1C1C1E"),
        ("Worshipped At", "hands.sparkles.fill", "5856D6"),
        ("Exiled To", "arrow.triangle.swap", "FF6482"),
    ]

    package static func ensureRelationTypesExist(context: ModelContext) {
        let count = (try? context.fetchCount(FetchDescriptor<RelationshipType>())) ?? 0
        guard count == 0 else { return }
        for config in defaultRelationTypes {
            let type = RelationshipType(name: config.name, icon: config.icon, colorHex: config.colorHex, category: config.category)
            context.insert(type)
        }
        try? context.save()
    }

    package static func ensurePlacePlaceRoleTypesExist(context: ModelContext) {
        let count = (try? context.fetchCount(FetchDescriptor<PlacePlaceRoleType>())) ?? 0
        guard count == 0 else { return }
        for config in defaultPlacePlaceRoleTypes {
            let type = PlacePlaceRoleType(name: config.name, icon: config.icon, colorHex: config.colorHex)
            context.insert(type)
        }
        try? context.save()
    }

    package static func ensureEventEventRoleTypesExist(context: ModelContext) {
        let count = (try? context.fetchCount(FetchDescriptor<EventEventRoleType>())) ?? 0
        guard count == 0 else { return }
        for config in defaultEventEventRoleTypes {
            let type = EventEventRoleType(name: config.name, icon: config.icon, colorHex: config.colorHex)
            context.insert(type)
        }
        try? context.save()
    }

    package static func ensureEventPlaceRoleTypesExist(context: ModelContext) {
        let count = (try? context.fetchCount(FetchDescriptor<EventPlaceRoleType>())) ?? 0
        guard count == 0 else { return }
        for config in defaultEventPlaceRoleTypes {
            let type = EventPlaceRoleType(name: config.name, icon: config.icon, colorHex: config.colorHex)
            context.insert(type)
        }
        try? context.save()
    }

    package static func ensureFigurePlaceRoleTypesExist(context: ModelContext) {
        let count = (try? context.fetchCount(FetchDescriptor<FigurePlaceRoleType>())) ?? 0
        guard count == 0 else { return }
        for config in defaultFigurePlaceRoleTypes {
            let type = FigurePlaceRoleType(name: config.name, icon: config.icon, colorHex: config.colorHex)
            context.insert(type)
        }
        try? context.save()
    }

    /// Backfill Commander FigureType + reassign 23 Watcher chiefs from Igigi to Commander.
    package static func ensureCommanderFigureTypeExists(context: ModelContext) {
        let commanderPredicate = #Predicate<FigureType> { $0.name == "Commander" }
        let commanderType: FigureType
        if let existing = try? context.fetch(FetchDescriptor<FigureType>(predicate: commanderPredicate)).first {
            commanderType = existing
        } else {
            let newType = FigureType(name: "Commander", icon: "chevron.left.forwardslash.chevron.right", colorHex: "EF4444")
            context.insert(newType)
            commanderType = newType
        }

        let commanderNames: Set<String> = [
            "Samyaza", "Azazel", "Urakiba", "Rameel", "Kokabiel",
            "Tamiel", "Ramiel", "Danel", "Ezeqeel", "Baraqel",
            "Armaros", "Batarel", "Ananel", "Satarel", "Turiel",
            "Jomjael", "Sariel", "Shamsiel", "Hermani", "Yehadiel"
        ]
        let allFigures = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        for figure in allFigures where commanderNames.contains(figure.name) {
            figure.figureType = commanderType
        }

        // Revert figures that were previously promoted to Commander but are not in the canonical 20
        let nonCommanderNames: Set<String> = ["Penemue", "Gadreel", "Araqiel", "Zaqiel", "Samsapeel"]
        let igigiPredicate = #Predicate<FigureType> { $0.name == "Igigi" }
        if let igigiType = try? context.fetch(FetchDescriptor<FigureType>(predicate: igigiPredicate)).first {
            for figure in allFigures where nonCommanderNames.contains(figure.name) {
                figure.figureType = igigiType
            }
        }
        try? context.save()
    }

    /// Create Hermani and Yehadiel — the two Commander figures missing from the restored snapshot.
    package static func ensureMissingCommanderFiguresExist(context: ModelContext) {
        let existingNames = Set((try? context.fetch(FetchDescriptor<Figure>()))?.map(\.name) ?? [])
        guard !existingNames.contains("Hermani") || !existingNames.contains("Yehadiel") else { return }

        let commanderPredicate = #Predicate<FigureType> { $0.name == "Commander" }
        let commanderType = try? context.fetch(FetchDescriptor<FigureType>(predicate: commanderPredicate)).first

        let watcherDate = MythologicalDate(year: nil, era: "Age of the Watchers", isApproximate: true)
        let unknownDate = MythologicalDate(year: nil, era: "", isApproximate: true)

        let missingFigures: [(name: String, title: String, domain: String, description: String)] = [
            ("Hermani", "Chief of Tens", "Divine Council",
             "One of the twenty chiefs of tens among the Watchers. Also known as Hermoni."),
            ("Yehadiel", "Chief of Tens", "Divine Council",
             "One of the twenty chiefs of tens among the Watchers. Also known as Jehaddiel."),
        ]

        for config in missingFigures {
            guard !existingNames.contains(config.name) else { continue }
            let figure = Figure(
                name: config.name,
                title: config.title,
                figureType: commanderType,
                gender: .male,
                domain: config.domain,
                figureDescription: config.description,
                birthDate: watcherDate,
                deathDate: unknownDate,
                source: "Book of Enoch (1 Enoch)"
            )
            context.insert(figure)
        }

        // Create Commander relationships from Samyaza if not already present
        let samyazaPredicate = #Predicate<Figure> { $0.name == "Samyaza" }
        if let samyaza = try? context.fetch(FetchDescriptor<Figure>(predicate: samyazaPredicate)).first {
            let commanderRelPredicate = #Predicate<RelationshipType> { $0.name == "Commander" }
            let commanderRelType = try? context.fetch(FetchDescriptor<RelationshipType>(predicate: commanderRelPredicate)).first

            let existingRelations = Set((samyaza.outgoingRelationships ?? []).compactMap { $0.toFigure?.name })
            let allFigures = (try? context.fetch(FetchDescriptor<Figure>())) ?? []

            for name in ["Hermani", "Yehadiel"] {
                guard !existingRelations.contains(name),
                      let target = allFigures.first(where: { $0.name == name }) else { continue }
                let rel = Relationship(
                    fromFigure: samyaza,
                    toFigure: target,
                    relationshipType: commanderRelType,
                    source: "Book of Enoch (1 Enoch)"
                )
                context.insert(rel)
            }
        }

        try? context.save()
    }

    /// Backfill the 7 holy archangels from the Book of Enoch if missing.
    package static func ensureArchangelsExist(context: ModelContext) {
        let archangelPredicate = #Predicate<FigureType> { $0.name == "Archangel" }
        let archangelType: FigureType
        if let existing = try? context.fetch(FetchDescriptor<FigureType>(predicate: archangelPredicate)).first {
            archangelType = existing
        } else {
            let newType = FigureType(name: "Archangel", icon: "star.fill", colorHex: "FBBF24")
            context.insert(newType)
            archangelType = newType
        }

        let archangelConfigs: [(name: String, title: String, domain: String, description: String)] = [
            ("Michael", "Chief of the Archangels",
             "Judgment, Binding of the Watchers, Chaos",
             "One of the seven holy archangels. Set over the best part of mankind and over chaos. Tasked with binding Samyaza and the fallen Watchers under the hills of the earth until the day of judgment. Revealed the secret oath to the holy angels."),
            ("Gabriel", "Archangel over Paradise",
             "Paradise, Serpents, Cherubim",
             "One of the seven holy archangels. Set over Paradise, the serpents, and the Cherubim. Tasked with destroying the children of the Watchers (the Nephilim) by setting them against each other in battle."),
            ("Uriel", "Archangel over the World and Tartarus",
             "Cosmos, Tartarus, Heavenly Luminaries",
             "One of the seven holy archangels. Set over the world and over Tartarus. Sent by God to warn Noah of the coming Flood. Revealed astronomical secrets to Enoch, including the movements of the sun, moon, and stars."),
            ("Raphael", "Archangel over the Spirits of Men",
             "Healing, Spirits of Men, Binding of Azazel",
             "One of the seven holy archangels. Set over the spirits of men. Tasked by God with binding Azazel hand and foot, casting him into the darkness of Dudael, and covering him with sharp rocks until the day of judgment."),
            ("Raguel", "Archangel of Vengeance",
             "Vengeance, Luminaries, Fire of Judgment",
             "One of the seven holy archangels. Takes vengeance on the world of the luminaries. In Enoch's vision, Raguel explained that the perpetually burning fire was prepared for the persecution of the luminaries of heaven who transgressed the Lord's command."),
            ("Saraqael", "Archangel over Sinful Spirits",
             "Spirits, Sin, Punishment",
             "One of the seven holy archangels. Set over the spirits who sin in the spirit. Oversees the punishment of fallen angels and errant spirits."),
            ("Remiel", "Archangel over Those Who Rise",
             "Resurrection, Those Who Rise",
             "One of the seven holy archangels. Set over those who rise (the resurrection). Presides over the faithful who are raised to eternal life."),
        ]

        let existingNames = Set((try? context.fetch(FetchDescriptor<Figure>()))?.map(\.name) ?? [])
        let creationDate = MythologicalDate(year: nil, era: "Creation", isApproximate: true)
        let eternalDate = MythologicalDate(year: nil, era: "Eternal", isApproximate: true)

        for config in archangelConfigs {
            guard !existingNames.contains(config.name) else { continue }

            let figure = Figure(
                name: config.name,
                title: config.title,
                figureType: archangelType,
                gender: .male,
                domain: config.domain,
                figureDescription: config.description,
                birthDate: creationDate,
                deathDate: eternalDate,
                source: "Book of Enoch (1 Enoch)"
            )
            context.insert(figure)
        }
        try? context.save()
    }

    /// Extract "Also known as ..." patterns from figure descriptions and register as AlternateNames.
    package static func extractAlternateNamesFromDescriptions(context: ModelContext) {
        let figures = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        let pattern = try! NSRegularExpression(pattern: "\\s*[Aa]lso known as ([^.]+)\\.", options: [])

        for figure in figures {
            let description = figure.figureDescription
            guard !description.isEmpty else { continue }
            guard let match = pattern.firstMatch(in: description, range: NSRange(description.startIndex..., in: description)) else { continue }

            let namesStr = String(description[Range(match.range(at: 1), in: description)!])
            let names = namesStr.components(separatedBy: ", and ")
                .flatMap { $0.components(separatedBy: ", ") }
                .flatMap { $0.components(separatedBy: " and ") }
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }

            let existingNames = Set((figure.alternateNames ?? []).map { $0.name.lowercased() })

            for name in names {
                guard !existingNames.contains(name.lowercased()) else { continue }
                let altName = AlternateName(
                    figure: figure,
                    name: name,
                    tradition: .other,
                    nameType: .spelling,
                    note: ""
                )
                context.insert(altName)
            }

            let fullRange = Range(match.range, in: description)!
            var cleaned = description
            cleaned.removeSubrange(fullRange)
            cleaned = cleaned.trimmingCharacters(in: .whitespaces)
            while cleaned.contains("..") { cleaned = cleaned.replacingOccurrences(of: "..", with: ".") }
            while cleaned.contains("  ") { cleaned = cleaned.replacingOccurrences(of: "  ", with: " ") }
            if !cleaned.hasSuffix(".") { cleaned += "." }
            figure.figureDescription = cleaned
        }
        try? context.save()
    }

    /// Fixes: "handshake" is not a valid SF Symbol. Update existing Ally types to "person.2.fill".
    package static func fixAllyIcon(context: ModelContext) {
        let predicate = #Predicate<RelationshipType> { $0.name == "Ally" && $0.icon == "handshake" }
        let fixQuery = FetchDescriptor<RelationshipType>(predicate: predicate)
        guard let matches = try? context.fetch(fixQuery), !matches.isEmpty else { return }
        for type in matches {
            type.icon = "person.2.fill"
        }
        try? context.save()
    }
}
