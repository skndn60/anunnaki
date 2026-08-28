import Foundation
import SwiftData

package struct Migration {

    /// Order-independent pair of PersistentIdentifiers for set membership checks.
    private struct StaticIdentifier: Hashable {
        let a: PersistentIdentifier
        let b: PersistentIdentifier
        init(_ x: PersistentIdentifier, _ y: PersistentIdentifier) {
            if x.hashValue <= y.hashValue { (a, b) = (x, y) }
            else { (a, b) = (y, x) }
        }
    }

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
        let existingNames = Set((try? context.fetch(FetchDescriptor<Figure>()))?.map { $0.name.lowercased() } ?? [])
        guard !existingNames.contains("hermani") || !existingNames.contains("yehadiel") else { return }

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
            guard !existingNames.contains(config.name.lowercased()) else { continue }
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

            let existingRelations = Set((samyaza.outgoingRelationships ?? []).compactMap { $0.toFigure?.name.lowercased() })
            let allFigures = (try? context.fetch(FetchDescriptor<Figure>())) ?? []

            for name in ["Hermani", "Yehadiel"] {
                guard !existingRelations.contains(name.lowercased()),
                      let target = allFigures.first(where: { $0.name.lowercased() == name.lowercased() }) else { continue }
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

        let existingNames = Set((try? context.fetch(FetchDescriptor<Figure>()))?.map { $0.name.lowercased() } ?? [])
        let creationDate = MythologicalDate(year: nil, era: "Creation", isApproximate: true)
        let eternalDate = MythologicalDate(year: nil, era: "Eternal", isApproximate: true)

        for config in archangelConfigs {
            guard !existingNames.contains(config.name.lowercased()) else { continue }

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

    // MARK: - Thing Role Types

    package static let defaultThingFigureRoleTypes: [(name: String, icon: String, colorHex: String)] = [
        ("Owned By", "person.fill", "007AFF"),
        ("Used By", "hand.raised.fill", "34C759"),
        ("Created By", "hammer.fill", "AF52DE"),
        ("Wielded By", "shield.fill", "FF9500"),
        ("Gifted To", "gift.fill", "FF2D55"),
        ("Sacred To", "star.fill", "FFCC00"),
        ("Associated With", "link", "8E8E93"),
    ]

    package static let defaultThingPlaceRoleTypes: [(name: String, icon: String, colorHex: String)] = [
        ("Located At", "mappin.and.ellipse", "007AFF"),
        ("Housed At", "building.2.fill", "34C759"),
        ("Used At", "location.fill", "FF9500"),
        ("Created At", "hammer.fill", "AF52DE"),
        ("Associated With", "link", "8E8E93"),
    ]

    package static let defaultThingEventRoleTypes: [(name: String, icon: String, colorHex: String)] = [
        ("Used In", "bolt.fill", "FF3B30"),
        ("Created During", "hammer.fill", "AF52DE"),
        ("Central To", "target", "FF9500"),
        ("Appears In", "eye.fill", "5856D6"),
        ("Associated With", "link", "8E8E93"),
    ]

    package static func ensureThingFigureRoleTypesExist(context: ModelContext) {
        let count = (try? context.fetchCount(FetchDescriptor<ThingFigureRoleType>())) ?? 0
        guard count == 0 else { return }
        for config in defaultThingFigureRoleTypes {
            let type = ThingFigureRoleType(name: config.name, icon: config.icon, colorHex: config.colorHex)
            context.insert(type)
        }
        try? context.save()
    }

    package static func ensureThingPlaceRoleTypesExist(context: ModelContext) {
        let count = (try? context.fetchCount(FetchDescriptor<ThingPlaceRoleType>())) ?? 0
        guard count == 0 else { return }
        for config in defaultThingPlaceRoleTypes {
            let type = ThingPlaceRoleType(name: config.name, icon: config.icon, colorHex: config.colorHex)
            context.insert(type)
        }
        try? context.save()
    }

    package static func ensureThingEventRoleTypesExist(context: ModelContext) {
        let count = (try? context.fetchCount(FetchDescriptor<ThingEventRoleType>())) ?? 0
        guard count == 0 else { return }
        for config in defaultThingEventRoleTypes {
            let type = ThingEventRoleType(name: config.name, icon: config.icon, colorHex: config.colorHex)
            context.insert(type)
        }
        try? context.save()
    }

    // MARK: - Role Type Reverse Names

    /// Backfills `reverseName` for role types so associations read correctly from
    /// both sides (e.g. "Located Within" reads as "Contains" from the other
    /// place). Additive + idempotent — only writes where `reverseName == nil`,
    /// so user-entered reverse names always win.
    package static func ensureRoleReverseNames(context: ModelContext) {
        func backfill<T: RoleTypeDisplay>(_ type: T.Type, _ map: [String: String]) where T: PersistentModel {
            guard let items = try? context.fetch(FetchDescriptor<T>()) else { return }
            var changed = false
            for item in items {
                guard let reverse = map[item.name], reverse.isEmpty == false else { continue }
                if let settable = item as? RoleReverseNameSettable, settable.reverseName == nil {
                    settable.reverseName = reverse
                    changed = true
                }
            }
            if changed { try? context.save() }
        }

        backfill(PlacePlaceRoleType.self, [
            "Located Within": "Contains",
            "Near To": "Near To",
            "Part Of": "Contains",
            "Ruled From": "Ruled From",
            "Connected To": "Connected To",
            "Opposed To": "Opposed To",
        ])
        backfill(EventEventRoleType.self, [
            "Caused": "Caused By",
            "Motivated": "Motivated By",
            "Precedes": "Follows",
            "Follows": "Precedes",
            "Related To": "Related To",
            "Contradicts": "Contradicted By",
            "Parallels": "Parallels",
        ])
        backfill(EventPlaceRoleType.self, [
            "Occurred At": "Site Of",
            "Started At": "Start Site Of",
            "Ended At": "End Site Of",
            "Passed Through": "Passed Through",
        ])
        backfill(FigurePlaceRoleType.self, [
            "Patron Deity": "Patron Of",
            "Ruler": "Ruled By",
            "Builder": "Built By",
            "Founder": "Founded By",
            "Born At": "Birthplace Of",
            "Died At": "Deathplace Of",
            "Resident Of": "Home To",
            "Imprisoned At": "Prison Of",
            "Worshipped At": "Worshipped By",
            "Exiled To": "Exile Site Of",
        ])
        backfill(ThingFigureRoleType.self, [
            "Owned By": "Owns",
            "Used By": "Uses",
            "Created By": "Created",
            "Wielded By": "Wields",
            "Gifted To": "Received From",
            "Sacred To": "Sacred To",
            "Associated With": "Associated With",
        ])
        backfill(ThingPlaceRoleType.self, [
            "Located At": "Houses",
            "Housed At": "Houses",
            "Used At": "Place Of Use",
            "Created At": "Place Of Creation",
            "Associated With": "Associated With",
        ])
        backfill(ThingEventRoleType.self, [
            "Used In": "Used",
            "Created During": "Created",
            "Central To": "Central To",
            "Appears In": "Featured In",
            "Associated With": "Associated With",
        ])
    }

    /// Add Duttur (mother of Dumuzi & Geshtinanna) and parent relationships
    /// so sibling inference via shared parents works for Dumuzi <-> Geshtinanna.
    package static func ensureDumuziFamilyExists(context: ModelContext) {
        let existingNames = Set((try? context.fetch(FetchDescriptor<Figure>()))?.map { $0.name.lowercased() } ?? [])

        let fatherType = try? context.fetch(FetchDescriptor<RelationshipType>(predicate: #Predicate { $0.name == "Father" })).first
        let motherType = try? context.fetch(FetchDescriptor<RelationshipType>(predicate: #Predicate { $0.name == "Mother" })).first

        // Create Duttur if missing
        let dutturID: PersistentIdentifier?
        if existingNames.contains("duttur") {
            dutturID = (try? context.fetch(FetchDescriptor<Figure>(predicate: #Predicate { $0.name == "Duttur" })).first)?.persistentModelID
        } else {
            let figureType = try? context.fetch(FetchDescriptor<FigureType>(predicate: #Predicate { $0.name == "Deity" })).first
            let date = MythologicalDate(year: nil, era: "Age of the First Gods", isApproximate: true)
            let unknown = MythologicalDate(year: nil, era: "", isApproximate: true)
            let duttur = Figure(
                name: "Duttur",
                title: "Ewe Goddess, Mother of Dumuzi",
                figureType: figureType,
                gender: .female,
                domain: "Sheep, Motherhood",
                figureDescription: "Ewe goddess, mother of Dumuzi and Geshtinanna.",
                birthDate: date,
                deathDate: unknown,
                source: "Sumerian mythology"
            )
            context.insert(duttur)
            try? context.save()
            dutturID = duttur.persistentModelID
        }

        guard let dutturID else { return }

        let allFigures = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        guard let enki = allFigures.first(where: { $0.name.lowercased() == "enki" }),
              let dumuzi = allFigures.first(where: { $0.name.lowercased() == "dumuzi" }),
              let geshtinanna = allFigures.first(where: { $0.name.lowercased() == "geshtinanna" }),
              let duttur = allFigures.first(where: { $0.persistentModelID == dutturID }),
              let fatherType, let motherType else { return }

        let existingRels = context.fetchAll() as [Relationship]
        let hasRel: (Figure, Figure) -> Bool = { from, to in
            existingRels.contains(where: { $0.fromFigure?.persistentModelID == from.persistentModelID && $0.toFigure?.persistentModelID == to.persistentModelID })
        }

        if !hasRel(enki, dumuzi) {
            let rel = Relationship(fromFigure: enki, toFigure: dumuzi, relationshipType: fatherType, source: "Sumerian mythology")
            context.insert(rel)
        }
        if !hasRel(duttur, dumuzi) {
            let rel = Relationship(fromFigure: duttur, toFigure: dumuzi, relationshipType: motherType, source: "Sumerian mythology")
            context.insert(rel)
        }
        if !hasRel(enki, geshtinanna) {
            let rel = Relationship(fromFigure: enki, toFigure: geshtinanna, relationshipType: fatherType, source: "Sumerian mythology")
            context.insert(rel)
        }
        if !hasRel(duttur, geshtinanna) {
            let rel = Relationship(fromFigure: duttur, toFigure: geshtinanna, relationshipType: motherType, source: "Sumerian mythology")
            context.insert(rel)
        }

        try? context.save()
    }

    /// Import deities from deities_import.json that don't already exist in the database.
    package static func ensureDeitiesImportExist(context: ModelContext) {
        let existingNames = Set((try? context.fetch(FetchDescriptor<Figure>()))?.map { $0.name.lowercased() } ?? [])
        let targetNames: Set<String> = [
            "Ishkur", "Uraš", "Zababa", "Ninazu", "Ningishzida",
            "Gugalanna", "Birtu", "Kulla", "Mushdamma", "Hendursaga",
            "Isimud", "Papsukkal", "Lugal-Marada", "Numushda", "Shara",
            "Pabilsag", "Lulal", "Enkimdu", "Ninshubur",
        ]
        let targetNamesLower = Set(targetNames.map { $0.lowercased() })
        guard targetNamesLower.intersection(existingNames).count != targetNamesLower.count else { return }

        let url: URL? = {
            if let u = Bundle.module.url(forResource: "deities_import", withExtension: "json") { return u }
            return Bundle.main.url(forResource: "deities_import", withExtension: "json")
        }()
        guard let u = url,
              let data = try? Data(contentsOf: u),
               let root = try? JSONDecoder().decode(SeedDataRoot.self, from: data) else {
            return
        }

        let rootExistingNames = Set(root.figures.map { $0.name.lowercased() })
        guard rootExistingNames.isSubset(of: targetNamesLower) else {
            return
        }

        let toImport = root.figures.filter { !existingNames.contains($0.name.lowercased()) }
        guard !toImport.isEmpty else { return }

        let importedIds = Set(toImport.map(\.id))
        var filteredRoot = root
        filteredRoot.figures = toImport
        filteredRoot.alternateNames = root.alternateNames.filter { importedIds.contains($0.figureId ?? "") }
        filteredRoot.figurePlaceAssociations = root.figurePlaceAssociations?.filter { importedIds.contains($0.figureId) }

        SeedData.importFrom(root: filteredRoot, context: context)
    }

    /// Import deities from missing_deities_import.json.
    /// Uses figureName (not figureId) for alternate names — resolves at import time.
    /// Each imported figure gets a sticky note "FROM 26-08-2026 IMPORT".
    /// Additive + idempotent.
    package static func ensureMissingDeitiesImportExist(context: ModelContext) {
        let existingNames = Set((try? context.fetch(FetchDescriptor<Figure>()))?.map { $0.name.lowercased() } ?? [])

        let url: URL? = {
            if let u = Bundle.module.url(forResource: "missing_deities_import", withExtension: "json") { return u }
            return Bundle.main.url(forResource: "missing_deities_import", withExtension: "json")
        }()
        guard let url,
              let data = try? Data(contentsOf: url),
              let root = try? JSONDecoder().decode(SeedDataRoot.self, from: data) else {
            return
        }

        let toImport = root.figures.filter { !existingNames.contains($0.name.lowercased()) }
        guard !toImport.isEmpty else { return }

        // Import figures via SeedData.importFrom (filters alt names by figureId)
        let importedIds = Set(toImport.map(\.id))
        var filteredRoot = root
        filteredRoot.figures = toImport
        filteredRoot.alternateNames = root.alternateNames.filter { importedIds.contains($0.figureId ?? "") }
        SeedData.importFrom(root: filteredRoot, context: context)

        // Add sticky notes to all newly imported figures
        let stickyPrefix = "FROM 26-08-2026 IMPORT"
        let allFigures = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        let importedNames = Set(toImport.map { $0.name.lowercased() })
        for figure in allFigures where importedNames.contains(figure.name.lowercased()) {
            let alreadyHas = figure.stickies.contains { $0.text.hasPrefix(stickyPrefix) }
            guard !alreadyHas else { continue }
            context.insert(StickyNote(text: stickyPrefix, figure: figure))
        }
        try? context.save()
    }

    /// Update era orderIndex values to match current seed data ordering.
    /// Fixes the pre/post flood split that shifted when new eras were inserted.
    package static func fixEraOrderIndices(context: ModelContext) {
        let eras = (try? context.fetch(FetchDescriptor<Era>())) ?? []
        let newOrder: [String: Int] = [
            "Age of the First Gods": 0,
            "Creation": 1,
            "Creation of Mankind": 2,
            "Age of the Watchers": 3,
            "Antediluvian Period": 4,
            "Anunnaki on Earth": 5,
            "Antediluvian": 6,
            "SKL Antediluvian": 6,
            "The Great Flood": 7,
            "Post-Flood Kingdoms": 8,
            "Early Dynastic Period": 9,
            "First dynasty of Kish": 11,
            "First rulers of Uruk": 12,
            "First dynasty of Ur": 13,
            "Dynasty of Awan": 14,
            "Second dynasty of Kish": 15,
            "Dynasty of Hamazi": 16,
            "Second dynasty of Uruk": 17,
            "Second dynasty of Ur": 18,
            "Dynasty of Adab": 19,
            "Dynasty of Mari": 20,
            "Third dynasty of Kish": 21,
            "Dynasty of Akshak": 22,
            "Fourth dynasty of Kish": 23,
            "Third dynasty of Uruk": 24,
            "Dynasty of Akkad": 25,
            "Fourth dynasty of Uruk": 26,
            "Gutian rule": 27,
            "Fifth dynasty of Uruk": 28,
            "Third dynasty of Ur": 29,
            "Dynasty of Isin": 30,
            "Old Assyrian Period": 31,
            "Old Babylonian Period": 32,
            "Neo-Assyrian Period": 33,
        ]
        var changed = false
        for era in eras {
            if let newOI = newOrder[era.name] {
                if era.orderIndex != newOI {
                    era.orderIndex = newOI
                    changed = true
                }
            } else if era.orderIndex >= 9 {
                // Unlisted post-flood era — shift by +1 to account for the inserted eras
                era.orderIndex = era.orderIndex + 1
                changed = true
            }
        }
        if changed { try? context.save() }
    }

    /// Establish the canonical pre-flood chronology. The eight SKL antediluvian kings
    /// carry their (mythological but canonical) reign lengths, so we anchor the epoch
    /// at the flood (−28,000 BCE) and back-propagate each reign to give every king a
    /// concrete span: the eight reigns sum to 241,200 years, so the epoch runs
    /// −269,200 → −28,000 BCE. The older mythological eras are ordered around it
    /// (Age of the First Gods → Creation → Creation of Mankind → Age of the Watchers →
    /// Antediluvian Period) and given sequential placeholder spans so every band on the
    /// pre-flood timeline shows a date. User-approved figure moves place the primordial
    /// gods in Age of the First Gods, the great gods in Creation, the archangels in Age
    /// of the Watchers, and Alulim + Dumuzi the Shepherd into the Antediluvian Period.
    /// Additive + idempotent; see docs/PRE-FLOOD-TIMELINE.md for the full reasoning.
    package static func ensureAntediluvianChronology(context: ModelContext) {
        let eras = (try? context.fetch(FetchDescriptor<Era>())) ?? []
        let eraByName = Dictionary(eras.map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })
        let allFigures = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        let figureByName = Dictionary(allFigures.map { (Self.seedNameKey($0.name), $0) }, uniquingKeysWith: { first, _ in first })
        var changed = false

        // 1. Era date bands — only corrected while they still hold the legacy seed
        //    values (or are undated), so a user's later manual edit is never clobbered.
        func applyEraDates(_ name: String, targetStart: Int, targetEnd: Int, legacyStart: Int?, legacyEnd: Int?) -> Bool {
            guard let era = eraByName[name] else { return false }
            let curStart = era.startDate.startYear
            let curEnd = era.endDate.endYear
            let isLegacy = (curStart == nil && curEnd == nil)
                || (legacyStart != nil && curStart == legacyStart && curEnd == legacyEnd)
            guard isLegacy else { return false }
            let newStart = MythologicalDate(startYear: targetStart, endYear: targetStart, era: name)
            let newEnd = MythologicalDate(startYear: targetEnd, endYear: targetEnd, era: name)
            guard era.startDate != newStart || era.endDate != newEnd else { return false }
            era.startDate = newStart
            era.endDate = newEnd
            return true
        }
        changed = applyEraDates("Age of the First Gods", targetStart: -450000, targetEnd: -300000, legacyStart: -450000, legacyEnd: -300000) || changed
        changed = applyEraDates("Creation", targetStart: -300000, targetEnd: -280000, legacyStart: nil, legacyEnd: nil) || changed
        changed = applyEraDates("Creation of Mankind", targetStart: -280000, targetEnd: -275000, legacyStart: -200000, legacyEnd: -100000) || changed
        changed = applyEraDates("Age of the Watchers", targetStart: -275000, targetEnd: -269200, legacyStart: nil, legacyEnd: nil) || changed
        changed = applyEraDates("Antediluvian Period", targetStart: -269200, targetEnd: -28000, legacyStart: -241200, legacyEnd: -28000) || changed
        changed = applyEraDates("The Great Flood", targetStart: -28000, targetEnd: -27000, legacyStart: -28000, legacyEnd: -27000) || changed

        // 2. Antediluvian king dates — computed by back-propagating each SKL reign
        //    from the flood anchor. Only written where no date exists yet.
        let kingReigns: [(name: String, birth: Int, death: Int)] = [
            ("Alulim", -269200, -240400),
            ("Alalngar", -240400, -204400),
            ("En-men-lu-ana", -204400, -161200),
            ("En-men-gal-ana", -161200, -132400),
            ("Dumuzi the Shepherd", -132400, -96400),
            ("En-sipad-zid-ana", -96400, -67600),
            ("En-men-dur-ana", -67600, -46600),
            ("Ubara-Tutu", -46600, -28000),
        ]
        for reign in kingReigns {
            guard let figure = figureByName[Self.seedNameKey(reign.name)],
                  figure.birthDate.startYear == nil else { continue }
            figure.birthDate = MythologicalDate(startYear: reign.birth, endYear: reign.birth, era: "Antediluvian Period")
            figure.deathDate = MythologicalDate(startYear: reign.death, endYear: reign.death, era: "Antediluvian Period")
            figure.dateSource = Figure.DateSource.computed.rawValue
            changed = true
        }

        // 3. User-approved figure reassignments. Each move only fires while the figure
        //    sits in the legacy (wrong) era, so a later user move is never overridden.
        func moveToEra(_ name: String, _ targetEraName: String, from legacyEraName: String?) {
            guard let target = eraByName[targetEraName],
                  let figure = figureByName[Self.seedNameKey(name)],
                  (legacyEraName == nil ? figure.era == nil : figure.era?.name == legacyEraName),
                  figure.era?.persistentModelID != target.persistentModelID else { return }
            figure.era = target
            figure.birthDate.era = targetEraName
            figure.deathDate.era = targetEraName
            changed = true
        }
        let primordialGods = ["Kishar", "Tiamat", "Apsu", "Nammu", "Anshar", "Anunnaki", "Igigi"]
        for name in primordialGods { moveToEra(name, "Age of the First Gods", from: "Creation") }
        let greatGods = ["An", "Enlil", "Enki", "Ninhursag", "Nanna", "Utu", "Inanna", "Marduk", "Nabu", "Nergal", "Ereshkigal", "Ningal", "Sarpanit", "Sud", "Antu", "Haia", "Ningikuga", "Ninurta", "Ninsun"]
        for name in greatGods { moveToEra(name, "Creation", from: "Age of the First Gods") }
        let archangels = ["Michael", "Gabriel", "Uriel", "Raphael", "Raguel", "Saraqael", "Remiel"]
        for name in archangels { moveToEra(name, "Age of the Watchers", from: "Creation") }
        moveToEra("Alulim", "Antediluvian Period", from: nil)
        moveToEra("Dumuzi the Shepherd", "Antediluvian Period", from: "Age of the First Gods")

        // 4. Antediluvian succession order — the SKL sequence is the authority
        //    (Ziusudra, the flood survivor, comes last).
        let antediluvianOrder: [(name: String, index: Int)] = [
            ("Alulim", 0), ("Alalngar", 1), ("En-men-lu-ana", 2), ("En-men-gal-ana", 3),
            ("Dumuzi the Shepherd", 4), ("En-sipad-zid-ana", 5), ("En-men-dur-ana", 6),
            ("Ubara-Tutu", 7), ("Ziusudra", 8),
        ]
        for entry in antediluvianOrder {
            guard let figure = figureByName[Self.seedNameKey(entry.name)],
                  figure.era?.name == "Antediluvian Period",
                  figure.orderIndex != entry.index else { continue }
            figure.orderIndex = entry.index
            changed = true
        }

        if changed { try? context.save() }
    }

    /// Remove all auto-generated "Missing father/mother — look up on Wikipedia" stickies.
    package static func removeAutoGeneratedStickies(context: ModelContext) {
        let allStickies = (try? context.fetch(FetchDescriptor<StickyNote>())) ?? []
        let toDelete = allStickies.filter { $0.text.hasPrefix("Missing ") }
        guard !toDelete.isEmpty else { return }
        for sticky in toDelete {
            context.delete(sticky)
        }
        try? context.save()
    }

    /// Backfill BCE anchor dates for SKL figures that lack them.
    /// Reads from seed_data.json and adds `c. XXXX–XXXX BC` date ranges to
    /// one strategic figure per dynasty. The SKLDatePropagator then fills in
    /// dates for all other figures in the same dynasty via reign-length propagation.
    package static func ensureSKLAnchorDates(context: ModelContext) {
        let url: URL? = {
            if let u = Bundle.module.url(forResource: "seed_data", withExtension: "json") { return u }
            return Bundle.main.url(forResource: "seed_data", withExtension: "json")
        }()
        guard let u = url, let data = try? Data(contentsOf: u),
              let root = try? JSONDecoder().decode(SeedDataRoot.self, from: data) else { return }

        let bcRegex = try! NSRegularExpression(pattern: "c\\.\\s*\\d{3,4}[–-]\\d{3,4}\\s*BC")
        let centuryRegex = try! NSRegularExpression(pattern: "c\\.\\s*\\d{1,2}(st|nd|rd|th)\\s+century\\s+BC")

        let allFigures = (try? context.fetch(FetchDescriptor<Figure>())) ?? []

        for seedFig in root.figures {
            guard seedFig.source.contains("Sumerian King List") else { continue }
            let seedDesc = seedFig.figureDescription
            guard bcRegex.firstMatch(in: seedDesc, range: NSRange(seedDesc.startIndex..., in: seedDesc)) != nil else { continue }

            guard let dbFig = allFigures.first(where: { Self.seedNameKey($0.name) == Self.seedNameKey(seedFig.name) }) else { continue }
            let dbDesc = dbFig.figureDescription
            guard bcRegex.firstMatch(in: dbDesc, range: NSRange(dbDesc.startIndex..., in: dbDesc)) == nil else { continue }

            var updated = dbDesc
            if let centuryMatch = centuryRegex.firstMatch(in: updated, range: NSRange(updated.startIndex..., in: updated)) {
                guard let r = Range(centuryMatch.range, in: updated) else { continue }
                updated.removeSubrange(r)
                updated = updated.trimmingCharacters(in: .whitespaces)
            }

            guard let bcMatch = bcRegex.firstMatch(in: seedDesc, range: NSRange(seedDesc.startIndex..., in: seedDesc)),
                  let r = Range(bcMatch.range, in: seedDesc) else { continue }
            let bcStr = String(seedDesc[r])
            if bcStr.isEmpty { continue }

            if !updated.isEmpty && !updated.hasSuffix(".") && !updated.hasSuffix(" ") { updated += " " }
            updated += bcStr
            if !updated.hasSuffix(".") { updated += "." }

            dbFig.figureDescription = updated
        }
        try? context.save()
    }

    /// Backfill `Era.startDate`/`endDate` from seed_data.json for eras whose
    /// dates are still unknown. The seed has carried per-dynasty date ranges
    /// since the live DB was first seeded, so older stores have NULL era dates
    /// — which left undated dynasties (e.g. Second dynasty of Kish) floating in
    /// the timeline's estimation window instead of their proper chronological
    /// slot. Additive and idempotent: only fills eras with no known start year,
    /// never overwrites user-entered dates.
    package static func ensureEraDatesFromSeed(context: ModelContext) {
        let url: URL? = {
            if let u = Bundle.module.url(forResource: "seed_data", withExtension: "json") { return u }
            return Bundle.main.url(forResource: "seed_data", withExtension: "json")
        }()
        guard let u = url, let data = try? Data(contentsOf: u),
              let root = try? JSONDecoder().decode(SeedDataRoot.self, from: data) else { return }

        let allEras = (try? context.fetch(FetchDescriptor<Era>())) ?? []
        var changed = false
        for seedEra in root.eras {
            guard seedEra.startDate.startYear != nil else { continue }
            guard let era = allEras.first(where: { $0.name == seedEra.name }) else { continue }
            guard era.startDate.startYear == nil else { continue }
            era.startDate = seedEra.startDate.toMythologicalDate()
            era.endDate = seedEra.endDate.toMythologicalDate()
            changed = true
        }
        if changed { try? context.save() }
    }

    private static let listedReignRegex = try! NSRegularExpression(pattern: "\\(Listed reign:\\s*[\\d,]+\\s+years\\.\\)")

    package static func ensureSKLGutianReignLengths(context: ModelContext) {
        let url: URL? = {
            if let u = Bundle.module.url(forResource: "seed_data", withExtension: "json") { return u }
            return Bundle.main.url(forResource: "seed_data", withExtension: "json")
        }()
        guard let u = url, let data = try? Data(contentsOf: u),
              let root = try? JSONDecoder().decode(SeedDataRoot.self, from: data) else { return }

        let allFigures = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        var changed = false
        for seedFig in root.figures {
            guard seedFig.source.contains("Sumerian King List"),
                  seedFig.birthDate.era == "Gutian rule" else { continue }
            let seedDesc = seedFig.figureDescription
            guard listedReignRegex.firstMatch(in: seedDesc, range: NSRange(seedDesc.startIndex..., in: seedDesc)) != nil else { continue }
            guard let dbFig = allFigures.first(where: { Self.seedNameKey($0.name) == Self.seedNameKey(seedFig.name) && $0.birthDate.era == seedFig.birthDate.era }) else { continue }
            guard listedReignRegex.firstMatch(in: dbFig.figureDescription, range: NSRange(dbFig.figureDescription.startIndex..., in: dbFig.figureDescription)) == nil else { continue }
            if let suffixRange = seedDesc.range(of: "(Listed reign:") {
                let suffix = String(seedDesc[suffixRange.lowerBound...]).trimmingCharacters(in: .whitespaces)
                var updated = dbFig.figureDescription
                if !updated.hasSuffix(".") { updated += "." }
                updated += " " + suffix
                dbFig.figureDescription = updated
                changed = true
            }
        }
        if changed { try? context.save() }
    }

    /// Backfill citations for events that lack them.
    /// Matches event.source free-text to known Source entities by substring.
    package static func ensureEventCitations(context: ModelContext) {
        let allSources: [Source] = (try? context.fetch(FetchDescriptor<Source>())) ?? []
        let sourceByKeyword: [(keyword: String, source: Source)] = allSources.compactMap { s in
            let keywords: [String] = [
                "Sumerian King List", "Epic of Gilgamesh", "Enuma Elish",
                "Atra-Hasis", "Inanna's Descent", "Etana Myth",
                "Book of Enoch (1 Enoch)", "Book of Jubilees"
            ]
            guard let match = keywords.first(where: { s.name.contains($0) }) else { return nil }
            return (keyword: match, source: s)
        }

        let allEvents = (try? context.fetch(FetchDescriptor<Event>())) ?? []
        let allCits = (try? context.fetch(FetchDescriptor<Citation>())) ?? []
        let hasCit: (Event) -> Bool = { event in
            allCits.contains(where: { $0.safeEntityName == event.name && $0.safeEntityType == .event })
        }

        for event in allEvents where !hasCit(event) {
            let src = sourceByKeyword.first(where: { event.source.contains($0.keyword) })?.source
            ?? allSources.first(where: { $0.name == "ETCSL (Electronic Text Corpus of Sumerian Literature)" })

            let cit = Citation(
                source: src,
                location: event.source,
                note: event.eventDescription,
                entityType: .event,
                linkedEntityName: event.name
            )
            context.insert(cit)
        }
        try? context.save()
    }

    package static func ensureParentRelationshipsExist(context: ModelContext) {
        let fatherType = try? context.fetch(FetchDescriptor<RelationshipType>(predicate: #Predicate { $0.name == "Father" })).first
        let motherType = try? context.fetch(FetchDescriptor<RelationshipType>(predicate: #Predicate { $0.name == "Mother" })).first
        let creatorType = try? context.fetch(FetchDescriptor<RelationshipType>(predicate: #Predicate { $0.name == "Creator" })).first
        let deityType = try? context.fetch(FetchDescriptor<FigureType>(predicate: #Predicate { $0.name == "Deity" })).first
        let godDate = MythologicalDate(year: nil, era: "Age of the First Gods", isApproximate: true)
        let unknownDate = MythologicalDate(year: nil, era: "", isApproximate: true)

        let allFigures = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        let existingNames = Set(allFigures.map { $0.name.lowercased() })

        let figureById: [PersistentIdentifier: Figure] = allFigures.reduce(into: [:]) { $0[$1.persistentModelID] = $1 }
        let figureByName: [String: Figure] = allFigures.reduce(into: [:]) { $0[$1.name.lowercased()] = $1 }

        // Look up or create a figure by name
        func getOrCreateFigure(name: String, title: String, domain: String, description: String) -> Figure? {
            if let existing = figureByName[name.lowercased()] { return existing }
            let fig = Figure(
                name: name,
                title: title,
                figureType: deityType,
                gender: name == "Haia" ? .male : .female,
                domain: domain,
                figureDescription: description,
                birthDate: godDate,
                deathDate: unknownDate,
                source: "Sumerian mythology"
            )
            context.insert(fig)
            try? context.save()
            return fig
        }

        let existingRels = (try? context.fetch(FetchDescriptor<Relationship>())) ?? []
        let hasRel: (Figure, Figure) -> Bool = { from, to in
            existingRels.contains(where: {
                $0.fromFigure?.persistentModelID == from.persistentModelID &&
                $0.toFigure?.persistentModelID == to.persistentModelID
            })
        }

        // Create new figures if missing (Duttur and Geshtinanna may already exist via ensureDumuziFamilyExists)
        let _ = getOrCreateFigure(name: "Haia", title: "God of Stores, Father of Ninlil", domain: "Stores, Seals, Doorways", description: "God of stores and husband of Nisaba. Father of Ninlil (also known as Sud). Sometimes called Haya.")
        let _ = getOrCreateFigure(name: "Nisaba", title: "Goddess of Writing and Grain", domain: "Writing, Grain, Surveying, Accounting", description: "Goddess of writing, grain, and surveying. Mother of Ninlil (also called Sud). Also known as Nunbarshegunu.")
        let _ = getOrCreateFigure(name: "Ningikuga", title: "Lady of the Pure Reed", domain: "Reeds, Marshes, Purity", description: "Goddess of reeds and marshes, a consort of Enki. Mother of Ningal.")
        let _ = getOrCreateFigure(name: "Duttur", title: "Ewe Goddess, Mother of Dumuzi", domain: "Sheep, Motherhood, Mourning", description: "Ewe goddess, mother of Dumuzi and Geshtinanna. Also known as Sirtur.")
        let _ = getOrCreateFigure(name: "Geshtinanna", title: "Goddess of Agriculture and Dream Interpretation", domain: "Agriculture, Fertility, Dreams", description: "Sister of Dumuzi, goddess of agriculture and dream interpretation. Daughter of Enki and Duttur.")

        // Re-fetch figures after creating new ones
        let allFigures2 = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        let figureByName2: [String: Figure] = allFigures2.reduce(into: [:]) { $0[$1.name.lowercased()] = $1 }

        let relDefs: [(from: String, to: String, type: RelationshipType?, source: String)] = [
            // Mythological
            ("Haia", "Ninlil", fatherType, "Sumerian mythology"),
            ("Nisaba", "Ninlil", motherType, "Sumerian mythology"),
            ("Enki", "Ningikuga", fatherType, "Sumerian mythology"),
            ("Enki", "Ningal", fatherType, "Sumerian mythology"),
            ("Ningikuga", "Ningal", motherType, "Sumerian mythology"),
            ("Enlil", "Nergal", fatherType, "Enlil and Ninlil"),
            ("Ninlil", "Nergal", motherType, "Enlil and Ninlil"),
            ("Enki", "Dumuzi", fatherType, "Sumerian mythology"),
            ("Duttur", "Dumuzi", motherType, "Sumerian mythology"),
            ("Enki", "Geshtinanna", fatherType, "Sumerian mythology"),
            ("Duttur", "Geshtinanna", motherType, "Sumerian mythology"),
            ("Ubara-Tutu", "Ziusudra", fatherType, "Sumerian King List"),
            ("Ninhursag", "Enkidu", creatorType, "Epic of Gilgamesh"),

            // SKL filiations
            ("Atab", "Mashda", fatherType, "Sumerian King List"),
            ("Mashda", "Arwium", fatherType, "Sumerian King List"),
            ("Etana", "Balih", fatherType, "Sumerian King List"),
            ("En-me-nuna", "Melem-Kish", fatherType, "Sumerian King List"),
            ("En-me-nuna", "Barsal-nuna", fatherType, "Sumerian King List"),
            ("Barsal-nuna", "Zamug", fatherType, "Sumerian King List"),
            ("Zamug", "Tizqar", fatherType, "Sumerian King List"),
            ("Enmebaragesi", "Aga of Kish", fatherType, "Sumerian King List"),
            ("Mesh-ki-ang-gasher", "Enmerkar", fatherType, "Sumerian King List"),
            ("Gilgamesh", "Ur-Nungal", fatherType, "Sumerian King List"),
            ("Ur-Nungal", "Udul-kalama", fatherType, "Sumerian King List"),
            ("Ur-nigin", "Ur-gigir", fatherType, "Sumerian King List"),
            ("Ur-Namma", "Shulgi", fatherType, "Sumerian King List"),
            ("Shulgi", "Amar-Suena", fatherType, "Sumerian King List"),
            ("Amar-Suena", "Shu-Suen", fatherType, "Sumerian King List"),
            ("Shu-Suen", "Ibbi-Suen", fatherType, "Sumerian King List"),
            ("Ishbi-Erra", "Shu-Ilishu", fatherType, "Sumerian King List"),
            ("Shu-Ilishu", "Iddin-Dagan", fatherType, "Sumerian King List"),
            ("Iddin-Dagan", "Ishme-Dagan", fatherType, "Sumerian King List"),
            ("Ishme-Dagan", "Lipit-Eshtar", fatherType, "Sumerian King List"),
            ("Ur-Ninurta", "Bur-Suen", fatherType, "Sumerian King List"),
            ("Bur-Suen", "Lipit-Enlil", fatherType, "Sumerian King List"),
        ]

        for (fromName, toName, type, source) in relDefs {
            guard let type else { continue }
            guard let from = figureByName2[fromName.lowercased()],
                  let to = figureByName2[toName.lowercased()] else { continue }
            guard !hasRel(from, to) else { continue }
            let rel = Relationship(fromFigure: from, toFigure: to, relationshipType: type, source: source)
            context.insert(rel)
        }

        try? context.save()
    }

    package static func ensureCoverageExemptFlags(context: ModelContext) {
        let exemptTypeNames = ["Primordial", "Archangel", "Igigi", "Commander", "Deity", "Semi-Divine"]
        let figures = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        for fig in figures where fig.coverageExempt != true {
            guard let typeName = fig.figureType?.name else { continue }
            if exemptTypeNames.contains(typeName) {
                fig.coverageExempt = true
            }
        }
        try? context.save()
    }

    package static func ensureSKLDomain(context: ModelContext) {
        let domainByTitle: [String: String] = [
            "King of Sumerian King List": "Antediluvian Kingship",
            "King of First dynasty of Kish": "Kingship of Kish",
            "King of First dynasty of Ur": "Kingship of Ur",
            "King of First rulers of Uruk": "Kingship of Uruk",
            "King of Dynasty of Awan": "Kingship of Awan",
            "King of Second dynasty of Kish": "Kingship of Kish",
            "King of Dynasty of Hamazi": "Kingship of Hamazi",
            "King of Second dynasty of Uruk": "Kingship of Uruk",
            "King of Second dynasty of Ur": "Kingship of Ur",
            "King of Dynasty of Adab": "Kingship of Adab",
            "King of Dynasty of Mari": "Kingship of Mari",
            "King of Third dynasty of Kish": "Kingship of Kish",
            "King of Dynasty of Akshak": "Kingship of Akshak",
            "King of Fourth dynasty of Kish": "Kingship of Kish",
            "King of Third dynasty of Uruk": "Kingship of Uruk",
            "King of Dynasty of Akkad": "Kingship of Akkad",
            "King of Fourth dynasty of Uruk": "Kingship of Uruk",
            "King of Gutian rule": "Kingship of Gutium",
            "King of Fifth dynasty of Uruk": "Kingship of Uruk",
            "King of Third dynasty of Ur": "Kingship of Ur",
            "King of Dynasty of Isin": "Kingship of Isin",
        ]
        let figures = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        for fig in figures where fig.domain.isEmpty {
            guard let domain = domainByTitle[fig.title] else { continue }
            fig.domain = domain
        }
        try? context.save()
    }

    package static func enrichSKLData(context: ModelContext) {
        let allFigures = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        let allEras = (try? context.fetch(FetchDescriptor<Era>())) ?? []
        let eraByName = allEras.reduce(into: [:]) { $0[$1.name] = $1 }

        // 1. Propagate reign years via SKLDatePropagator
        let eraOrder = allEras.reduce(into: [:]) { $0[$1.name] = $1.orderIndex }
        let timelines = SKLDatePropagator.compute(figures: allFigures, eraOrder: eraOrder)
        for timeline in timelines {
            for reign in timeline.reigns {
                reign.figure.reignStartYear = reign.startBCE
                reign.figure.reignEndYear = reign.endBCE
            }
        }

        // 2. Link figures to eras by birthDate.era
        let eraMap: [String: String] = [
            "Before the Flood": "Age of the Watchers",
        ]
        for fig in allFigures where fig.era == nil {
            let eraName = fig.birthDate.era
            guard !eraName.isEmpty else { continue }
            let mappedName = eraMap[eraName] ?? eraName
            fig.era = eraByName[mappedName]
        }

        // 3. Fix citation entityIds for renamed figures
        let citationRenameMap: [String: String] = [
            "Shu-Suen (Dynasty of Akshak)": "Shu-Suen (Akshak)",
            "Puzur-Suen (Fourth dynasty of Kish)": "Puzur-Suen (Kish)",
        ]
        let allCitations = (try? context.fetch(FetchDescriptor<Citation>())) ?? []
        for cit in allCitations {
            if let newName = citationRenameMap[cit.linkedEntityName] {
                cit.linkedEntityName = newName
            }
        }

        // 4. Backfill SKL citations
        let sklSource = allEras.isEmpty ? nil : (try? context.fetch(FetchDescriptor<Source>(
            predicate: #Predicate { $0.name == "Sumerian King List" }
        ))).flatMap { $0.first }
        if let sklSource {
            let sklSourceID = sklSource.persistentModelID
            let allCits = (try? context.fetch(FetchDescriptor<Citation>())) ?? []
            let citedNames = Set(allCits.compactMap { $0.source?.persistentModelID == sklSourceID ? $0.linkedEntityName : nil })
            let humanType = try? context.fetch(FetchDescriptor<FigureType>(
                predicate: #Predicate { $0.name == "Human" }
            )).first
            let sklFigures = allFigures.filter { $0.figureType?.persistentModelID == humanType?.persistentModelID }
            for fig in sklFigures where !citedNames.contains(fig.name) {
                let citation = Citation(
                    source: sklSource,
                    location: "Sumerian King List entry",
                    note: fig.figureDescription,
                    entityType: .figure,
                    linkedEntityName: fig.name
                )
                context.insert(citation)
            }
        }

        try? context.save()
    }

    package static func ensureSKLEventTypesExist(context: ModelContext) {
        let foundationPredicate = #Predicate<EventType> { $0.name == "Foundation" }
        let foundationExists = (try? context.fetch(FetchDescriptor<EventType>(predicate: foundationPredicate)).first) != nil
        if !foundationExists {
            context.insert(EventType(name: "Foundation", icon: "building.columns.fill", colorHex: "F59E0B"))
        }
        let destructionPredicate = #Predicate<EventType> { $0.name == "Destruction" }
        let destructionExists = (try? context.fetch(FetchDescriptor<EventType>(predicate: destructionPredicate)).first) != nil
        if !destructionExists {
            context.insert(EventType(name: "Destruction", icon: "flame.fill", colorHex: "FF3B30"))
        }
        try? context.save()
    }

    package static func ensureMissingCitiesAndAssociations(context: ModelContext) {
        let url: URL? = {
            if let u = Bundle.module.url(forResource: "seed_data", withExtension: "json") { return u }
            return Bundle.main.url(forResource: "seed_data", withExtension: "json")
        }()
        guard let u = url, let data = try? Data(contentsOf: u),
              let root = try? JSONDecoder().decode(SeedDataRoot.self, from: data) else { return }

        let allFigures = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        let allPlaces = (try? context.fetch(FetchDescriptor<Place>())) ?? []
        let existingPlaceNames = Set(allPlaces.map { $0.name.lowercased() })
        let figureByName = allFigures.reduce(into: [:]) { $0[$1.name.lowercased()] = $1 }
        var placeByName = allPlaces.reduce(into: [:]) { $0[$1.name.lowercased()] = $1 }

        let seedFigureNameById = root.figures.reduce(into: [:]) { $0[$1.id] = $1.name }
        let seedPlaceNameById = root.places.reduce(into: [:]) { $0[$1.id] = $1.name }
        let allPlaceTypes: [PlaceType] = (try? context.fetch(FetchDescriptor<PlaceType>())) ?? []
        let placeTypeByName = allPlaceTypes.reduce(into: [:]) { $0[$1.name] = $1 }

        // 1. Create missing places
        for seedPlace in root.places {
            guard !existingPlaceNames.contains(seedPlace.name.lowercased()) else { continue }
            let placeType = placeTypeByName[seedPlace.placeType]
            let place = Place(
                name: seedPlace.name,
                placeType: placeType,
                modernLocation: seedPlace.modernLocation,
                placeDescription: seedPlace.placeDescription,
                source: seedPlace.source,
                latitude: seedPlace.latitude,
                longitude: seedPlace.longitude
            )
            context.insert(place)
            placeByName[seedPlace.name.lowercased()] = place
        }

        // 2. Create missing figure-place associations
        let allRoleTypes: [FigurePlaceRoleType] = (try? context.fetch(FetchDescriptor<FigurePlaceRoleType>())) ?? []
        let existingAssocs = (try? context.fetch(FetchDescriptor<FigurePlaceAssociation>())) ?? []

        for seedAssoc in root.figurePlaceAssociations ?? [] {
            guard let figName = seedFigureNameById[seedAssoc.figureId],
                  let placeName = seedPlaceNameById[seedAssoc.placeId],
                  let figure = figureByName[figName.lowercased()],
                  let place = placeByName[placeName.lowercased()] else { continue }

            let alreadyExists = existingAssocs.contains { assoc in
                assoc.figure?.persistentModelID == figure.persistentModelID &&
                assoc.place?.persistentModelID == place.persistentModelID &&
                assoc.roleType?.name == seedAssoc.role
            }
            guard !alreadyExists else { continue }

            let roleType = allRoleTypes.first(where: { $0.name == seedAssoc.role })
            let assoc = FigurePlaceAssociation(
                figure: figure,
                place: place,
                roleType: roleType,
                source: seedAssoc.source
            )
            context.insert(assoc)
        }

        // 3. Create missing place-place associations
        let placePlaceRoleTypes: [PlacePlaceRoleType] = (try? context.fetch(FetchDescriptor<PlacePlaceRoleType>())) ?? []
        let existingPlaceAssocs = (try? context.fetch(FetchDescriptor<PlacePlaceAssociation>())) ?? []

        for seedAssoc in root.placePlaceAssociations ?? [] {
            guard let fromPlace = placeByName[(seedPlaceNameById[seedAssoc.fromPlaceId] ?? "").lowercased()],
                  let toPlace = placeByName[(seedPlaceNameById[seedAssoc.toPlaceId] ?? "").lowercased()] else { continue }

            let alreadyExists = existingPlaceAssocs.contains { assoc in
                assoc.fromPlace?.persistentModelID == fromPlace.persistentModelID &&
                assoc.toPlace?.persistentModelID == toPlace.persistentModelID &&
                assoc.roleType?.name == seedAssoc.role
            }
            guard !alreadyExists else { continue }

            let roleType = placePlaceRoleTypes.first(where: { $0.name == seedAssoc.role })
            let assoc = PlacePlaceAssociation(
                fromPlace: fromPlace,
                toPlace: toPlace,
                roleType: roleType,
                source: seedAssoc.source
            )
            context.insert(assoc)
        }

        try? context.save()
    }

    /// Backfill SKL historical figures and events from seed_data.json.
    /// Creates figures (Eannatum, Entemena, Urukagina, Ukush, Mesilim),
    /// places (Girsu, Gu-Edin, Aratta, Dabrum), and 40 events.
    package static func ensureSKLEventsAndFigures(context: ModelContext) {
        let url: URL? = {
            if let u = Bundle.module.url(forResource: "seed_data", withExtension: "json") { return u }
            return Bundle.main.url(forResource: "seed_data", withExtension: "json")
        }()
        guard let u = url, let data = try? Data(contentsOf: u),
              let root = try? JSONDecoder().decode(SeedDataRoot.self, from: data) else { return }

        let allFigures = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        let allPlaces = (try? context.fetch(FetchDescriptor<Place>())) ?? []
        let allEventTypes = (try? context.fetch(FetchDescriptor<EventType>())) ?? []
        let allEventPlaceRoles = (try? context.fetch(FetchDescriptor<EventPlaceRoleType>())) ?? []

        var figureByName = allFigures.reduce(into: [:]) { $0[$1.name.lowercased()] = $1 }
        var placeByName = allPlaces.reduce(into: [:]) { $0[$1.name.lowercased()] = $1 }
        let eventTypeByName = allEventTypes.reduce(into: [:]) { $0[$1.name] = $1 }
        let occuredAtRole = allEventPlaceRoles.first(where: { $0.name == "Occurred At" })

        let existingEventNames = Set(allFigures.isEmpty ? [] : (try? context.fetch(FetchDescriptor<Event>()))?.map { $0.name.lowercased() } ?? [])

        let seedFigureNameById = root.figures.reduce(into: [:]) { $0[$1.id] = $1.name }
        let seedPlaceNameById = root.places.reduce(into: [:]) { $0[$1.id] = $1.name }

        // 1. Create missing figures
        for seedFig in root.figures {
            guard !figureByName.keys.contains(seedFig.name.lowercased()) else { continue }
            let sklFigures = Set(["Eannatum", "Entemena", "Urukagina", "Ukush", "Mesilim"])
            guard sklFigures.contains(seedFig.name) else { continue }
            let humanType = try? context.fetch(FetchDescriptor<FigureType>(predicate: #Predicate { $0.name == "Human" })).first
            let figure = Figure(
                name: seedFig.name,
                title: seedFig.title,
                figureType: humanType,
                gender: Figure.Gender(rawValue: seedFig.gender) ?? .male,
                domain: seedFig.domain,
                figureDescription: seedFig.figureDescription,
                birthDate: seedFig.birthDate.toMythologicalDate(),
                deathDate: seedFig.deathDate.toMythologicalDate(),
                source: seedFig.source
            )
            context.insert(figure)
            figureByName[seedFig.name.lowercased()] = figure
        }

        // 2. Create missing places
        let sklPlaceNames = Set(["Girsu", "Gu-Edin", "Aratta", "Dabrum"])
        for seedPlace in root.places {
            guard !placeByName.keys.contains(seedPlace.name.lowercased()) else { continue }
            guard sklPlaceNames.contains(seedPlace.name) else { continue }
            let placeType = try? context.fetch(FetchDescriptor<PlaceType>(predicate: #Predicate { $0.name == seedPlace.placeType })).first
            let place = Place(
                name: seedPlace.name,
                placeType: placeType,
                modernLocation: seedPlace.modernLocation,
                placeDescription: seedPlace.placeDescription,
                source: seedPlace.source,
                latitude: seedPlace.latitude,
                longitude: seedPlace.longitude
            )
            context.insert(place)
            placeByName[seedPlace.name.lowercased()] = place
        }

        try? context.save()

        // 3. Create missing events
        for seedEvent in root.events {
            guard !existingEventNames.contains(seedEvent.name.lowercased()) else { continue }

            let eventFigures = seedEvent.involvedFigureIds.compactMap { fid -> Figure? in
                guard let figName = seedFigureNameById[fid] else { return nil }
                return figureByName[figName.lowercased()]
            }

            let event = Event(
                name: seedEvent.name,
                eventType: eventTypeByName[seedEvent.eventType],
                eventDescription: seedEvent.eventDescription,
                date: seedEvent.date.toMythologicalDate(),
                era: seedEvent.era,
                source: seedEvent.source,
                involvedFigures: eventFigures
            )
            context.insert(event)

            // Create EventPlaceAssociation if placeId is specified
            if let pid = seedEvent.placeId, let placeName = seedPlaceNameById[pid], let place = placeByName[placeName.lowercased()] {
                let assoc = EventPlaceAssociation(
                    event: event,
                    place: place,
                    roleType: occuredAtRole,
                    source: seedEvent.source
                )
                context.insert(assoc)
            }
        }

        try? context.save()
    }

    /// Create default figure groups if none exist.
    package static func ensureDefaultFigureGroups(context: ModelContext) {
        let count = (try? context.fetchCount(FetchDescriptor<FigureGroup>())) ?? 0
        guard count == 0 else { return }

        let defaults: [(name: String, description: String, icon: String, colorHex: String, filter: GroupMemberFilter?, kind: GroupKind)] = [
            ("Divine Council", "Gods who sit in council, including the Anunnaki and Igigi", "person.3", "5856D6", nil, .standard),
            ("Sumerian Pantheon", "Major gods and goddesses of the Sumerian pantheon", "star", "FF9500",
             GroupMemberFilter(figureTypeNames: ["Deity"], domainKeywords: ["Sumerian"]), .standard),
            ("Akkadian/East Semitic", "Gods of the Akkadian, Assyrian, and Babylonian traditions", "star.circle", "FF3B30",
             GroupMemberFilter(domainKeywords: ["Akkadian", "Babylonian", "Assyrian"]), .standard),
            ("Book of Enoch", "Figures from the Book of Enoch tradition", "book", "FBBF24", nil, .enoch),
            ("Primordial Beings", "Primordial entities from before the gods", "sparkles", "8E8E93",
             GroupMemberFilter(figureTypeNames: ["Primordial"]), .standard),
            ("SKL Kings", "Kings of the Sumerian King List", "list.star", "007AFF",
             GroupMemberFilter(domainKeywords: ["Kingship"]), .skl),
        ]

        for (idx, config) in defaults.enumerated() {
            let filterJSON: String?
            if let filter = config.filter, let data = try? JSONEncoder().encode(filter) {
                filterJSON = String(data: data, encoding: .utf8)
            } else {
                filterJSON = nil
            }
            let group = FigureGroup(
                name: config.name,
                groupDescription: config.description,
                icon: config.icon,
                colorHex: config.colorHex,
                orderIndex: idx,
                memberFilter: filterJSON,
                isSmart: config.filter != nil,
                kind: config.kind
            )
            context.insert(group)
        }
        try? context.save()
    }

    package static func ensureFigureGroupKinds(context: ModelContext) {
        let allGroups = (try? context.fetch(FetchDescriptor<FigureGroup>())) ?? []

        let kindByName: [String: GroupKind] = [
            "Book of Enoch": .enoch,
            "SKL Kings": .skl,
            "Sumerian King List": .skl,
        ]

        let iconByName: [String: String] = [
            "Divine Council": "person.3",
            "Sumerian Pantheon": "star",
            "Akkadian/East Semitic": "star.circle",
            "Book of Enoch": "book",
            "SKL Kings": "list.star",
            "Sumerian King List": "list.star",
        ]

        for group in allGroups {
            if let kind = kindByName[group.name], group.kind != kind {
                group.kind = kind
            }
            if let icon = iconByName[group.name], group.icon != icon {
                group.icon = icon
            }
        }

        try? context.save()
    }

    /// Remove the legacy empty "The Flood" placeholder group if it is still empty
    /// (no members, subgroups, or text blocks). Deletes nothing that has content.
    package static func removeFloodPlaceholder(context: ModelContext) {
        let allGroups = (try? context.fetch(FetchDescriptor<FigureGroup>())) ?? []
        guard let group = allGroups.first(where: { $0.name == "The Flood" }) else { return }
        let hasContent = !group.figureAssociations.isEmpty
            || !((group.subgroups ?? []).isEmpty)
            || !((group.textBlocks ?? []).isEmpty)
        guard !hasContent else { return }
        try? context.transaction {
            group.figureAssociations = []
            group.subgroups = []
            group.textBlocks = []
            context.delete(group)
        }
    }

    /// Sweeps `FigureGroupAssociation` rows whose group was deleted. Group deletion empties the
    /// group-side association array (the crash-safe macOS 26 pattern), which nullifies each row's
    /// `group` but leaves the row itself linked from the entity-side arrays — so figures can show
    /// phantom group rows with a "?" description. Detach from every inverse side, then delete.
    package static func removeOrphanedGroupAssociations(context: ModelContext) {
        let orphans = (try? context.fetch(FetchDescriptor<FigureGroupAssociation>()))?.filter { $0.group == nil } ?? []
        guard !orphans.isEmpty else { return }
        try? context.transaction {
            for assoc in orphans {
                assoc.figure?.groupAssociations.removeAll { $0.persistentModelID == assoc.persistentModelID }
                assoc.place?.groupAssociations.removeAll { $0.persistentModelID == assoc.persistentModelID }
                assoc.event?.groupAssociations.removeAll { $0.persistentModelID == assoc.persistentModelID }
                assoc.thing?.groupAssociations.removeAll { $0.persistentModelID == assoc.persistentModelID }
                context.delete(assoc)
            }
        }
    }

    package static func ensureImportedDeityRelationships(context: ModelContext) {
        let relationships: [(from: String, to: String, type: String, source: String)] = [
            ("Gugalanna", "Ereshkigal", "Spouse", "Sumerian mythology"),
            ("Inanna", "Shara", "Mother", "Sumerian texts"),
            ("Isimud", "Enki", "Servant", "Sumerian texts"),
            ("Ninshubur", "Inanna", "Servant", "Sumerian texts"),
            ("Papsukkal", "Anu", "Servant", "Akkadian texts"),
            ("Ereshkigal", "Ninazu", "Mother", "Sumerian texts"),
            ("Gugalanna", "Ninazu", "Father", "Sumerian texts"),
            ("Enki", "Kulla", "Creator", "Sumerian texts"),
            ("Enki", "Mushdamma", "Creator", "Sumerian texts"),
            ("Anu", "Ishkur", "Father", "Akkadian texts"),
        ]

        let allFigures = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        let figureByName = allFigures.reduce(into: [:]) { $0[$1.name.lowercased()] = $1 }

        let allRelTypes = (try? context.fetch(FetchDescriptor<RelationshipType>())) ?? []
        let existingRelationships = (try? context.fetch(FetchDescriptor<Relationship>())) ?? []

        for rel in relationships {
            guard let fromFigure = figureByName[rel.from.lowercased()],
                  let toFigure = figureByName[rel.to.lowercased()],
                  let relType = allRelTypes.first(where: { $0.name == rel.type }) else { continue }

            let alreadyExists = existingRelationships.contains { existing in
                existing.fromFigure?.persistentModelID == fromFigure.persistentModelID &&
                existing.toFigure?.persistentModelID == toFigure.persistentModelID &&
                existing.relationshipType?.persistentModelID == relType.persistentModelID
            }
            guard !alreadyExists else { continue }

            let relationship = Relationship(
                fromFigure: fromFigure,
                toFigure: toFigure,
                relationshipType: relType,
                source: rel.source
            )
            context.insert(relationship)
        }
        try? context.save()
    }

    /// Auto-assign reign order for Sumerian King List groups. For any group whose kind (or an
    /// ancestor's kind) is `.skl`, order its figure members by their chronological key
    /// (era position then in-era sequence) and enable manual ordering. Only runs when no member
    /// has an explicit `orderIndex` yet, so user-arranged orders are never overwritten. Additive.
    package static func ensureSKLRegnalOrder(context: ModelContext) {
        let allGroups = (try? context.fetch(FetchDescriptor<FigureGroup>())) ?? []
        guard !allGroups.isEmpty else { return }

        func partOfSKLChain(_ group: FigureGroup) -> Bool {
            if group.kind == .skl { return true }
            if let parent = group.parentGroup { return partOfSKLChain(parent) }
            return false
        }

        var changed = false
        for group in allGroups where partOfSKLChain(group) {
            guard group.entityType == .figure,
                  !group.figureAssociations.isEmpty,
                  group.figureAssociations.allSatisfy({ $0.orderIndex == nil }) else { continue }
            group.applyRegnalOrder()
            group.sortMode = .ordered
            changed = true
        }
        if changed { try? context.save() }
    }

    /// Fix `Figure.orderIndex` for SKL figures whose seed order was wrong (Etana
    /// appeared before Jushur in an earlier seed_data.json). Reads the corrected
    /// seed, recomputes per-era orderIndex values, and re-runs `applyRegnalOrder`
    /// on every SKL-chain group so association display order matches the SKL.
    /// One-shot: only acts when at least one SKL figure's orderIndex doesn't match
    /// the seed (checked via a hash of expected values).
    package static func fixSKLFigureOrder(context: ModelContext) {
        guard let url = Bundle.module.url(forResource: "seed_data", withExtension: "json")
                ?? Bundle.main.url(forResource: "seed_data", withExtension: "json") else { return }
        guard let data = try? Data(contentsOf: url),
              let root = try? JSONDecoder().decode(SeedDataRoot.self, from: data) else { return }

        let allFigures = (try? context.fetch(FetchDescriptor<Figure>())) ?? []

        var expectedOrderIndex: [String: Int] = [:]
        var expectedOrderEra: [String: String] = [:]
        var sklEraIndex: [String: Int] = [:]
        for seedFig in root.figures {
            guard seedFig.source.contains("Sumerian King List") else { continue }
            let era = seedFig.birthDate.era.isEmpty ? "Antediluvian" : seedFig.birthDate.era
            let idx = sklEraIndex[era, default: 0]
            expectedOrderIndex[seedFig.name] = idx
            expectedOrderEra[seedFig.name] = era
            sklEraIndex[era] = idx + 1
        }

        var changed = false
        for (name, expectedIdx) in expectedOrderIndex {
            guard let figure = allFigures.first(where: { Self.seedNameKey($0.name) == Self.seedNameKey(name) && Self.seedNameKey($0.birthDate.era) == Self.seedNameKey(expectedOrderEra[name] ?? "") }),
                  figure.orderIndex != expectedIdx else { continue }
            figure.orderIndex = expectedIdx
            changed = true
        }
        guard changed else { return }
        try? context.save()

        func partOfSKLChain(_ group: FigureGroup) -> Bool {
            if group.kind == .skl { return true }
            if let parent = group.parentGroup { return partOfSKLChain(parent) }
            return false
        }
        let allGroups = (try? context.fetch(FetchDescriptor<FigureGroup>())) ?? []
        for group in allGroups where partOfSKLChain(group) && group.entityType == .figure && !group.figureAssociations.isEmpty {
            group.applyRegnalOrder()
            group.sortMode = .ordered
        }
        try? context.save()
    }

    /// Backfill `Figure.reignYears` from each figure's description ("Listed reign" /
    /// "Reigned X years" phrasing) when the field isn't set yet. Additive + idempotent —
    /// never overwrites a value the user typed. Runs after figure-creating migrations so
    /// newly seeded figures get populated on the same launch.
    package static func ensureReignYears(context: ModelContext) {
        let figures = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        var changed = false
        for figure in figures where figure.reignYears == nil {
            guard let reign = ReignLength.parse(from: figure.figureDescription) else { continue }
            figure.reignYears = reign.years
            changed = true
        }
        if changed { try? context.save() }
    }

    /// Backfills `Figure.epithet` from the `Epithet: ...` prose embedded in
    /// `figureDescription` (our seed writes e.g. `Epithet: ''"the boatman"''.` or
    /// `Epithet: 'the shepherd'`). Additive + idempotent — never overwrites a
    /// user-entered value.
    package static func ensureEpithets(context: ModelContext) {
        let figures = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        var changed = false
        for figure in figures where figure.epithet == nil {
            guard let epithet = Self.extractEpithet(from: figure.figureDescription) else { continue }
            figure.epithet = epithet
            changed = true
        }
        if changed { try? context.save() }
    }

    package static func ensureComputedSKLDates(context: ModelContext) {
        let allFigures = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        let allEras = (try? context.fetch(FetchDescriptor<Era>())) ?? []
        let eraOrder = allEras.reduce(into: [:]) { $0[$1.name] = $1.orderIndex }
        let timelines = SKLDatePropagator.compute(figures: allFigures, eraOrder: eraOrder)
        var changed = false
        for timeline in timelines {
            for reign in timeline.reigns {
                guard reign.figure.birthDate.startYear == nil,
                      let startBCE = reign.startBCE else { continue }
                let endBCE = reign.endBCE ?? startBCE
                reign.figure.birthDate = MythologicalDate(
                    startYear: startBCE,
                    endYear: endBCE,
                    era: reign.figure.birthDate.era,
                    isApproximate: true
                )
                if reign.figure.deathDate.endYear == nil {
                    reign.figure.deathDate = MythologicalDate(
                        startYear: nil,
                        endYear: endBCE,
                        era: reign.figure.deathDate.era,
                        isApproximate: true
                    )
                }
                reign.figure.dateSource = Figure.DateSource.computed.rawValue
                changed = true
            }
        }
        if changed { try? context.save() }
    }

    /// Reconciles `Figure.era` links so they always mirror the canonical era
    /// name (the `birthDate.era` string first, else the "Ruler from/in/of …"
    /// description prefix as a fallback). Runs every launch; idempotent and
    /// additive — `figure.era` is pure derived data, never hand-edited.
    package static func ensureFigureEraLinks(context: ModelContext) {
        let eras = (try? context.fetch(FetchDescriptor<Era>())) ?? []
        let eraByName = eras.reduce(into: [:]) { $0[$1.name] = $1 }
        let figures = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        var changed = false
        for figure in figures {
            if let name = Self.birthEraNameFromDescriptionIfEmpty(figure), figure.birthDate.era != name {
                figure.birthDate.era = name
                changed = true
            }
            let target = Self.resolveEraTarget(for: figure, eraByName: eraByName)
            if figure.era?.persistentModelID != target?.persistentModelID {
                figure.era = target
                changed = true
            }
        }
        if changed { try? context.save() }
    }

    private static let eraTypoMap: [String: String] = [
        "Guthian rule": "Gutian rule",
    ]

    package static func fixEraTypos(context: ModelContext) {
        let eras = (try? context.fetch(FetchDescriptor<Era>())) ?? []
        let eraByName = eras.reduce(into: [:]) { $0[$1.name] = $1 }
        let figures = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        var changed = false
        for figure in figures {
            if let corrected = Self.eraTypoMap[figure.birthDate.era] {
                figure.birthDate.era = corrected
                figure.deathDate.era = corrected
                changed = true
            }
            if let eraName = Self.eraTypoMap.values.first(where: { $0 == figure.birthDate.era }),
               let target = eraByName[eraName],
               figure.era?.persistentModelID != target.persistentModelID {
                figure.era = target
                changed = true
            }
        }
        if changed { try? context.save() }
    }

    /// If a figure's birth-era string is empty, derive the era name from the
    /// "Ruler from/in/of …" description prefix and write it into the string, so
    /// the string stays the complete source of truth (the description-derived
    /// era was historically only visible via a separate EraDetailView heuristic).
    private static func birthEraNameFromDescriptionIfEmpty(_ figure: Figure) -> String? {
        guard figure.birthDate.era.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return Self.eraName(fromDescription: figure.figureDescription)
    }

    private static func eraName(fromDescription desc: String) -> String? {
        let prefixes = ["Ruler from the ", "Ruler in the ", "Ruler of "]
        for prefix in prefixes where desc.hasPrefix(prefix) {
            let remainder = desc.dropFirst(prefix.count)
            let endChars: [Character] = [".", "(", "—", "\n"]
            let name = String(remainder.prefix { !endChars.contains($0) }).trimmingCharacters(in: .whitespaces)
            if !name.isEmpty {
                return name == "Sumerian King List" ? "Antediluvian Period" : name
            }
        }
        return nil
    }

    private static func resolveEraTarget(for figure: Figure, eraByName: [String: Era]) -> Era? {
        let raw = figure.birthDate.era.trimmingCharacters(in: .whitespacesAndNewlines)
        if !raw.isEmpty {
            let name = raw == "Before the Flood" ? "Age of the Watchers" : raw
            return eraByName[name]
        }
        return eraByName[Self.eraName(fromDescription: figure.figureDescription).map { $0 } ?? ""]
    }

    /// Resolves a single figure's era link from its birth-era string (alias-aware).
    /// Used by the figure form so an edit reflects immediately, not at next launch.
    package static func era(named text: String, context: ModelContext) -> Era? {
        let raw = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return nil }
        let name = raw == "Before the Flood" ? "Age of the Watchers" : raw
        return (try? context.fetch(FetchDescriptor<Era>(predicate: #Predicate { $0.name == name })))?.first
    }

    private static func extractEpithet(from text: String) -> String? {
        // Matches `Epithet: ''"the boatman"''` (seed JSON-escaped quotes) and
        // `Epithet: 'the shepherd'` (single-quoted prose).
        let patterns = [
            #"Epithet:\s*''"(.+?)"''"#,
            #"Epithet:\s*'(.+?)'"#,
        ]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            if let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               match.numberOfRanges > 1,
               let range = Range(match.range(at: 1), in: text) {
                let epithet = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !epithet.isEmpty { return epithet }
            }
        }
        return nil
    }

    /// Create the default "Mesopotamian" pantheon if missing, and add every figure
    /// that doesn't yet belong to any pantheon to it. Additive + idempotent — never
    /// removes or re-assigns an existing pantheon membership.
    package static func ensureMesopotamianPantheons(context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<Pantheon>(predicate: #Predicate { $0.name == "Mesopotamian" })))?.first
        let pantheon: Pantheon
        if let existing {
            pantheon = existing
        } else {
            let new = Pantheon(
                name: "Mesopotamian",
                pantheonDescription: "Deities of Sumerian, Akkadian, Babylonian, and Assyrian tradition",
                icon: "building.columns.circle.fill",
                colorHex: "8E5E3C"
            )
            context.insert(new)
            try? context.save()
            pantheon = new
        }

        let figures = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        var changed = false
        for figure in figures where figure.pantheons.isEmpty {
            figure.pantheons.append(pantheon)
            changed = true
        }
        if changed {
            try? context.save()
        }
    }

    /// Add the "Divine Collective" FigureType and the Anunnaki and Igigi figures that
    /// represent it. Collectives are groups of unnamed gods (the Anunnaki are the
    /// "those who came down" council of great gods; the Igigi are the labourer gods of
    /// the Atrahasis) that act as single entities in the myths — linkable, queryable,
    /// and relational — without being individual deities. Additive + idempotent.
    package static func ensureDivineCollectives(context: ModelContext) {
        let typePredicate = #Predicate<FigureType> { $0.name == "Divine Collective" }
        let collectiveType: FigureType
        if let existing = try? context.fetch(FetchDescriptor<FigureType>(predicate: typePredicate)).first {
            collectiveType = existing
        } else {
            let newType = FigureType(name: "Divine Collective", icon: "person.3.fill", colorHex: "8B5CF6")
            context.insert(newType)
            collectiveType = newType
        }

        let existingNames = Set((try? context.fetch(FetchDescriptor<Figure>()))?.map { $0.name.lowercased() } ?? [])

        let collectiveConfigs: [(name: String, title: String, domain: String, description: String)] = [
            ("Anunnaki", "The Great Gods of Heaven and Earth",
             "Sky, Earth, Underworld, Divine Council",
             "A collective of the great gods of Mesopotamian religion, the primary divine council. Their name is often explained as 'those who came down from heaven to earth'. In the oldest Sumerian tradition they were the chthonic deities of the underworld, numbering fifty; in the canonical lists of Akkadian religion they are usually the seven great gods (Anu, Enlil, Enki, Ninhursag, Nanna, Utu, Inanna). In Atrahasis the Anunnaki are the seven great gods who sit in council and decide the fate of the Igigi."),
            ("Igigi", "The Gods of Heaven / The Divine Workforce",
             "Heaven, Labor",
             "A collective of the gods who in Atrahasis serve as the heavenly workforce, digging the rivers Tigris and Euphrates under the oversight of the Anunnaki. When their labor becomes unbearable they rebel and march on the dwelling of Enlil, prompting the creation of mankind from the clay and the blood of the slain god to take over their work. Sometimes identified with the great gods of heaven, sometimes distinguished from them; the precise rank of the Igigi relative to the Anunnaki varies by tradition."),
        ]

        let mythicDate = MythologicalDate(year: nil, era: "Creation", isApproximate: true)

        for config in collectiveConfigs {
            guard !existingNames.contains(config.name.lowercased()) else { continue }
            let figure = Figure(
                name: config.name,
                title: config.title,
                figureType: collectiveType,
                gender: .unknown,
                domain: config.domain,
                figureDescription: config.description,
                birthDate: mythicDate,
                deathDate: MythologicalDate.unknown,
                source: "Atrahasis"
            )
            context.insert(figure)
        }
        try? context.save()
    }

    /// Imports deities found missing in the ORACC AMGG cross-check (2026-08-22).
    /// Skips any name already present as a figure or as an alternate name, so
    /// user-entered data always wins. Each import gets a sticky note
    /// "IMPORTED FROM ORACC". Additive + idempotent.
    package static func ensureOraccDeityImports(context: ModelContext) {
        let allFigures = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        let figureNames = Set(allFigures.map { $0.name.lowercased() })
        let altNames = Set((try? context.fetch(FetchDescriptor<AlternateName>()))?.map { $0.name.lowercased() } ?? [])
        func isKnown(_ n: String) -> Bool {
            figureNames.contains(n.lowercased()) || altNames.contains(n.lowercased())
        }

        let deityPredicate = #Predicate<FigureType> { $0.name == "Deity" }
        let deityType: FigureType
        if let existing = try? context.fetch(FetchDescriptor<FigureType>(predicate: deityPredicate)).first {
            deityType = existing
        } else {
            let created = FigureType(name: "Deity", icon: "star.fill", colorHex: "007AFF")
            context.insert(created)
            deityType = created
        }

        let undated = MythologicalDate(year: nil, era: "", isApproximate: true)

        let oraccDeities: [(
            name: String,
            gender: Figure.Gender,
            title: String,
            domain: String,
            description: String,
            alternates: [(name: String, tradition: AlternateName.Tradition, note: String)]
        )] = [
            ("Gula", .female, "Goddess of Healing", "Healing, Medicine, Physicians",
             "The great healing goddess, 'the great physician', patroness of doctors and exorcists; her sacred animal is the dog. Chief cult centre Isin, also prominent at Nippur and Uruk. Wife of Ninurta in the standard pantheon (of Pabilsag or Nergal in other traditions). Worshipped under many names, including Ninkarrak.",
             [("Ninkarrak", .akkadian, "Distinct healing goddess often identified with Gula (ORACC treats them in one article)")]),
            ("Dagan", .male, "Grain God of the Middle Euphrates", "Grain, Royal Legitimacy",
             "West Semitic grain god whose cult was centred on the middle Euphrates (Tuttul, Mari, Ebla) long before he appears in Mesopotamian sources. In Old Babylonian royal ideology he grants kingship and legitimacy; Sargonic kings styled themselves servants of Dagan. Known as Dagon in the Hebrew Bible.",
             [("Dagon", .hebrew, "Hebrew Bible form of the name")]),
            ("Damu", .male, "God of Healing and Renewal", "Healing, Lament, Renewal",
             "Sumerian god of healing of the dying-rising child-deity type; son of Nininisinna (in other traditions of Gula or Bau). His disappearance and return were lamented ritually during the summer months.",
             []),
            ("Girra", .male, "God of Fire", "Fire, Light, Purification",
             "God of fire and light, invoked in purification rituals against witchcraft; known to the Akkadians as Bilgi. Often paired with the fire god Gibil and placed in the circle of Erra in first-millennium theology.",
             [("Bilgi", .akkadian, "Akkadian form of the name")]),
            ("Ninsi'anna", .female, "Venus Deity", "Venus, Stars",
             "'Redoubtable star of heaven' — the planet Venus as a deity. Originally a Venus aspect of Inana, she developed into an independent goddess (at times understood as male) during the Old Babylonian period.",
             [("Ninsianna", .sumerian, "Spelling variant")]),
            ("Tašmetu", .female, "Consort of Nabu", "Love, Song, Intercession",
             "Akkadian goddess, consort of Nabu, celebrated as the ideal bride in Akkadian love songs. Intercessor for humans before her exalted husband; associated with love, desire, and song.",
             [("Tashmetu", .akkadian, "ASCII spelling variant")]),
            ("Lugalirra", .male, "Underworld God, Twin of Meslamtaea", "Underworld",
             "'Great king' — underworld god, twin brother of Meslamtaea; together the pair act as gatekeepers of the netherworld within the circle of Nergal (whose byname Meslamtaea also is). Worshipped especially at Kisiga.",
             [("Lugal-irra", .sumerian, "Hyphenated spelling variant")]),
        ]

        var created = 0
        for deity in oraccDeities where !isKnown(deity.name) {
            let figure = Figure(
                name: deity.name,
                title: deity.title,
                figureType: deityType,
                gender: deity.gender,
                domain: deity.domain,
                figureDescription: deity.description,
                birthDate: undated,
                deathDate: undated,
                source: "ORACC AMGG (oracc.museum.upenn.edu/amgg)"
            )
            context.insert(figure)
            for alt in deity.alternates where !isKnown(alt.name) {
                context.insert(AlternateName(
                    figure: figure,
                    name: alt.name,
                    tradition: alt.tradition,
                    nameType: .spelling,
                    note: alt.note
                ))
            }
            context.insert(StickyNote(text: "IMPORTED FROM ORACC", figure: figure))
            created += 1
        }
        if created > 0 { try? context.save() }
    }

    /// Imports ten well-attested everyday-life episodes (curation approved by the
    /// user; plan in docs/NEXT_SESSION_HANDOFF.md) as events with Human figures,
    /// place associations, and family/trade relationships — a counterweight to the
    /// mythological corpus. Skips any figure, event, or place whose normalized name
    /// already exists (user data wins; "Ea Nasir" matches an existing "Ea-nasir").
    /// Additive + idempotent.
    package static func ensureEverydayLifeEpisodes(context: ModelContext) {
        func key(_ s: String) -> String { NameDuplicateCheck.normalizedKey(s) }
        let stickyText = "Import daily life events"

        // MARK: types

        let dailyLifeType: EventType
        if let existing = try? context.fetch(FetchDescriptor<EventType>(predicate: #Predicate { $0.name == "Daily Life" })).first {
            dailyLifeType = existing
        } else {
            let created = EventType(name: "Daily Life", icon: "cup.and.saucer.fill", colorHex: "0D9488")
            context.insert(created)
            dailyLifeType = created
        }

        let humanType = try? context.fetch(FetchDescriptor<FigureType>(predicate: #Predicate { $0.name == "Human" })).first
        let cityType = try? context.fetch(FetchDescriptor<PlaceType>(predicate: #Predicate { $0.name == "City" })).first

        let eventPlaceRoles = (try? context.fetch(FetchDescriptor<EventPlaceRoleType>())) ?? []
        let occurredAt = eventPlaceRoles.first { $0.name == "Occurred At" }

        let figurePlaceRoles = (try? context.fetch(FetchDescriptor<FigurePlaceRoleType>())) ?? []
        let residentOf = figurePlaceRoles.first { $0.name == "Resident Of" }
        let rulerOf = figurePlaceRoles.first { $0.name == "Ruler" }

        let relationshipTypes = (try? context.fetch(FetchDescriptor<RelationshipType>())) ?? []
        let spouseType = relationshipTypes.first { $0.name == "Spouse" }
        let fatherType = relationshipTypes.first { $0.name == "Father" }
        let motherType = relationshipTypes.first { $0.name == "Mother" }

        // MARK: places

        var placeByKey: [String: Place] = [:]
        for place in (try? context.fetch(FetchDescriptor<Place>())) ?? [] {
            placeByKey[key(place.name)] = place
        }

        let placeConfigs: [(name: String, modernLocation: String, description: String, source: String, lat: Double?, lon: Double?)] = [
            ("Ur", "Tell el-Muqayyar, southern Iraq",
             "Great Sumerian city on the Euphrates, home of the moon god Nanna. In Old Babylonian times a hub of trade and private houses — among them that of the copper merchant Ea-nasir.",
             "Everyday-life episode curation", 30.9625, 46.1030),
            ("Nippur", "Nuffar, southern Iraq",
             "Sacred city of Enlil and scribal capital of Sumer. Thousands of school tablets come from its edubba, making it the natural stage for tales like Schooldays and the Poor Man of Nippur.",
             "Everyday-life episode curation", 32.1261, 45.2302),
            ("Babylon", "Near Hillah, Babil Governorate, Iraq",
             "City of Marduk on the Euphrates, capital of Old Babylonian and later empires; setting of literary works such as the Dialogue of Pessimism.",
             "Everyday-life episode curation", 32.5425, 44.4210),
            ("Assur", "Qal'at Sherqat, northern Iraq",
             "City on the Tigris and namesake capital of Assyria. The Old Assyrian merchant families whose letters survive from Kanesh lived here.",
             "Everyday-life episode curation", 35.4566, 43.2607),
            ("Kanesh", "Kültepe, near Kayseri, Turkey",
             "Anatolian city housing the karum, the walled trading colony of Assyrian merchants. Its excavated letter archives give us most of what we know about Old Assyrian family life.",
             "Everyday-life episode curation", 38.8522, 35.6339),
            ("Kalhu", "Nimrud, northern Iraq",
             "Assyrian royal city on the Tigris, refounded by Ashurnasirpal II, who celebrated its completion with a banquet for 69,574 guests.",
             "Everyday-life episode curation", 36.0983, 43.3317),
        ]
        for config in placeConfigs where placeByKey[key(config.name)] == nil {
            let place = Place(
                name: config.name,
                placeType: cityType,
                modernLocation: config.modernLocation,
                placeDescription: config.description,
                source: config.source,
                latitude: config.lat,
                longitude: config.lon
            )
            context.insert(place)
            context.insert(StickyNote(text: stickyText, place: place))
            placeByKey[key(config.name)] = place
        }

        // MARK: figures

        var figureByKey: [String: Figure] = [:]
        let altNames = (try? context.fetch(FetchDescriptor<AlternateName>())) ?? []
        for figure in (try? context.fetch(FetchDescriptor<Figure>())) ?? [] {
            figureByKey[key(figure.name)] = figure
        }
        let knownKeys = Set(figureByKey.keys).union(altNames.map { key($0.name) })
        func knownFigure(named name: String) -> Bool { knownKeys.contains(key(name)) }

        let unknownDate = MythologicalDate.unknown
        let figureConfigs: [(
            name: String, gender: Figure.Gender, title: String, domain: String,
            description: String, source: String
        )] = [
            ("Ea-nasir", .male, "Copper Merchant of Ur", "Trade, Copper",
             "Old Babylonian copper merchant of Ur (c. 1750 BCE) whose house contained an archive of angry customer letters, chief among them the complaint tablet of Nanni about substandard ingots — often called the world's oldest written customer complaint.",
             "Complaint tablet to Ea-nasir (UET V 81), British Museum"),
            ("Nanni", .male, "Customer of Ea-nasir", "Trade",
             "Old Babylonian customer who paid forward silver for copper ingots, received inferior metal, and had his messenger treated with contempt at Ea-nasir's door. His tablet is the most famous piece in the archive.",
             "Complaint tablet to Ea-nasir (UET V 81), British Museum"),
            ("Gimil-Ninurta", .male, "The Poor Man of Nippur", "Folk Tale",
             "Impoverished Nipputean cheated by the mayor when his one mina of gold buys only a broken chariot. He returns three times in disguise — bird-catcher, physician, and curser — beating the mayor each visit until he is repaid threefold.",
             "Poor Man of Nippur; most complete copy from Sultantepe (c. 701 BCE)"),
            ("Mayor of Nippur", .male, "Villain of the Poor Man of Nippur", "Civic Office",
             "The pompous mayor of the folk tale who refuses Gimil-Ninurta's greeting and cheats him over the chariot hire, then is thrice beaten by the disguised poor man without recognising him.",
             "Poor Man of Nippur"),
            ("Taram-Kubi", .female, "Merchant's Wife in Assur", "Trade, Family",
             "Wife of the merchant Innaya. Her letters from Assur beg her husband to come home before their beer-bread goes stale, scold him for debts, and report his death in Kanesh while under house arrest over tax-evasion charges.",
             "Old Assyrian letters from Kültepe; Cécile Michel, Women of Assur and Kanesh"),
            ("Innaya", .male, "Merchant in Kanesh", "Trade",
             "Old Assyrian trader operating between Assur and Kanesh. His correspondence with his wife Taram-Kubi shows a marriage run as a business partnership; he died in Kanesh under house arrest amid tax disputes with the local authorities.",
             "Old Assyrian letters from Kültepe; Cécile Michel, Women of Assur and Kanesh"),
            ("Lamassi", .female, "Weaver and Merchant's Wife in Assur", "Textiles, Trade",
             "Merchant's wife famed for her sharp pen. When her husband Pushu-ken criticized the quality of textiles she sent him, she fired back: 'Who is this man who lives in Kanesh and finds fault with the quality of my textiles?'",
             "Old Assyrian letter TCL 19 20; Cécile Michel, Women of Assur and Kanesh"),
            ("Pushu-ken", .male, "Assyrian Merchant in Kanesh", "Trade",
             "Old Assyrian merchant whose complaint about his wife Lamassi's textiles earned him a stinging rebuttal preserved in the Kültepe archives.",
             "Old Assyrian letter TCL 19 20; Cécile Michel, Women of Assur and Kanesh"),
            ("Zizizi", .female, "Young Trader in Kanesh", "Trade, Family",
             "Daughter of Imdi-ilum working in the Kanesh trade. When she failed to write home, her parents sent a letter of wounded pride — 'You do not treat me like a gentleman! We are not important in your eyes' — which she kept.",
             "Old Assyrian letter; Cécile Michel, Women of Assur and Kanesh"),
            ("Imdi-ilum", .male, "Family Patriarch in Assur", "Family",
             "Father of Zizizi, co-author of the guilt-laden letter rebuking their daughter for neglecting to write from Kanesh.",
             "Old Assyrian letter; Cécile Michel, Women of Assur and Kanesh"),
            ("Ishtar-bashti", .female, "Family Matriarch in Assur", "Family",
             "Mother of Zizizi, co-author with her husband Imdi-ilum of the angry letter about their daughter's silence.",
             "Old Assyrian letter; Cécile Michel, Women of Assur and Kanesh"),
            ("Ashurnasirpal II", .male, "King of Assyria (883–859 BCE)", "Kingship, Conquest",
             "Neo-Assyrian king who rebuilt Kalhu as his capital and inaugurated it in 879 BCE with a ten-day feast for 69,574 guests, recorded on his Banquet Stele: thousands of sheep, cattle, birds, and rivers of beer and wine.",
             "Banquet Stele of Ashurnasirpal II"),
        ]

        var createdFigures = 0
        for config in figureConfigs where !knownFigure(named: config.name) {
            let figure = Figure(
                name: config.name,
                title: config.title,
                figureType: humanType,
                gender: config.gender,
                domain: config.domain,
                figureDescription: config.description,
                birthDate: unknownDate,
                deathDate: unknownDate,
                source: config.source
            )
            context.insert(figure)
            context.insert(StickyNote(text: stickyText, figure: figure))
            figureByKey[key(config.name)] = figure
            createdFigures += 1
        }

        func figureNamed(_ name: String) -> Figure? { figureByKey[key(name)] }

        // MARK: events

        let existingEventKeys = Set(((try? context.fetch(FetchDescriptor<Event>())) ?? []).map { key($0.name) })

        struct Episode {
            let name: String
            let description: String
            let year: Int?
            let era: String
            let approximate: Bool
            let source: String
            let sortName: String?
            let figureNames: [String]
            let places: [(name: String, roleName: String?)]
        }

        let episodes: [Episode] = [
            Episode(
                name: "The Complaint Tablet to Ea-nasir",
                description: "Nanni, having paid silver up front for copper ingots, received metal of such poor quality that he refused delivery — and found his messenger dismissed with contempt. In a tablet recovered from Ea-nasir's own house in Ur he demands a refund and asks how the merchant could have wronged him alone. The archive holds further complaints from other customers, making Ea-nasir history's best-documented bad supplier.",
                year: -1750, era: "Old Babylonian Period", approximate: true,
                source: "UET V 81, British Museum",
                sortName: "Complaint Tablet to Ea-nasir",
                figureNames: ["Ea-nasir", "Nanni"],
                places: [("Ur", nil)]
            ),
            Episode(
                name: "Schooldays",
                description: "A Sumerian school satire: a young scribe, caned all day for sloppy recitation and untidy tablets, tells his father the teacher must be flattered into kindness. Father invites teacher to dinner, seats him front and centre, showers him with gifts — and the boy graduates unharmed. Samuel Noah Kramer, its first translator, called it 'the first case of apple-polishing in the history of man'.",
                year: -2000, era: "Old Babylonian Period", approximate: true,
                source: "Sumerian text 'Edubba A'; S. N. Kramer, JAOS 69 (1949); CDLI P268190",
                sortName: "Schooldays",
                figureNames: [],
                places: [("Nippur", nil)]
            ),
            Episode(
                name: "Poor Man of Nippur",
                description: "Gimil-Ninurta hires the mayor's chariot with a mina of gold and is sent a rusted wreck. Insulted twice, he plots triple revenge: returning as a bird-catcher, a physician, and finally a curser of demons, each time luring the mayor behind closed doors and thrashing him. The tale was a scribal-school favourite, its fullest copy unearthed at Sultantepe in 1952.",
                year: -1500, era: "Old Babylonian Period", approximate: true,
                source: "Poor Man of Nippur; copy from Sultantepe, Gurney, Anatolian Studies 5 (1955)",
                sortName: "Poor Man of Nippur",
                figureNames: ["Gimil-Ninurta", "Mayor of Nippur"],
                places: [("Nippur", nil)]
            ),
            Episode(
                name: "Taram-Kubi's Letters Home",
                description: "From Assur the merchant's wife Taram-Kubi wrote again and again to Innaya in distant Kanesh: come home before the beer bread I made goes stale, pay your debts, mind your agent. Years of letters trace their partnership — and end with news that Innaya died in Kanesh while under house arrest, caught in the tax net of the local authorities.",
                year: -1860, era: "Old Assyrian Period", approximate: true,
                source: "Old Assyrian letters from Kültepe; Cécile Michel, Women of Assur and Kanesh",
                sortName: "Taram-Kubi's Letters Home",
                figureNames: ["Taram-Kubi", "Innaya"],
                places: [("Assur", "Started At"), ("Kanesh", "Ended At")]
            ),
            Episode(
                name: "Lamassi's Textile Rebuttal",
                description: "Pushu-ken, an Assyrian merchant in Kanesh, complained home that the textiles shipped by his wife Lamassi were of poor quality. Her reply survives: 'Who is this man who lives in Kanesh and finds fault with the quality of my textiles?' — before dismantling his criticism line by line. One of the sharpest voices in the Kültepe correspondence.",
                year: -1860, era: "Old Assyrian Period", approximate: true,
                source: "Old Assyrian letter TCL 19 20; Cécile Michel, Women of Assur and Kanesh",
                sortName: "Lamassi's Textile Rebuttal",
                figureNames: ["Lamassi", "Pushu-ken"],
                places: [("Assur", nil)]
            ),
            Episode(
                name: "Zizizi's Angry Parents",
                description: "Imdi-ilum and Ishtar-bashti had set up their daughter Zizizi in the Kanesh trade, but she stopped writing home. Their reply is pure wounded pride across thirty-nine centuries: 'You do not treat me like a gentleman! We are not important in your eyes.' That she filed the letter away suggests it did not go unanswered.",
                year: -1860, era: "Old Assyrian Period", approximate: true,
                source: "Old Assyrian letter; Cécile Michel, Women of Assur and Kanesh",
                sortName: "Zizizi's Angry Parents",
                figureNames: ["Zizizi", "Imdi-ilum", "Ishtar-bashti"],
                places: [("Assur", "Started At"), ("Kanesh", "Ended At")]
            ),
            Episode(
                name: "Yale Culinary Tablets",
                description: "Three small Babylonian tablets in Yale's collection carry the world's oldest surviving recipes: around twenty-five broths and stews seasoned with leek, onion, garlic, beer, coriander, and cumin, including a beet stew called tuh'u and an 'Elamite broth'. Written around 1730 BCE, they read like kitchen aide-mémoires rather than cookbooks — ingredient lists for cooks who knew the method.",
                year: -1730, era: "Old Babylonian Period", approximate: true,
                source: "YBC 4644 et al.; Jean Bottéro, Textes culinaires mésopotamiens",
                sortName: "Yale Culinary Tablets",
                figureNames: [],
                places: []
            ),
            Episode(
                name: "Farmer's Instructions",
                description: "A Sumerian farmer's almanac cast as advice from father to son: flood the field, clear the weeds, mind the oxen, plough twice, pray to Ninkilim against vermin — through harvest and threshing. Preserved in Old Babylonian copies from Nippur, it compresses a full agricultural year into practical verse, the oldest farming manual we have.",
                year: -1800, era: "Old Babylonian Period", approximate: true,
                source: "The Instructions of Suruppak, ed. Bendt Alster",
                sortName: "Farmer's Instructions",
                figureNames: [],
                places: [("Nippur", nil)]
            ),
            Episode(
                name: "Dialogue of Pessimism",
                description: "A Babylonian master proposes fine schemes — a feast, public office, founding a family, even rebellion — and his slave demolishes each with flawless arguments, ending every rebuttal 'so let us not do it'. When the master finally proposes doing nothing, the slave agrees — then notes nothing lasts forever anyway. A masterpiece of irony from the first millennium BCE.",
                year: -1000, era: "Neo-Assyrian Period", approximate: true,
                source: "Dialogue of Pessimism, British Museum K.34113 et al.",
                sortName: "Dialogue of Pessimism",
                figureNames: [],
                places: [("Babylon", nil)]
            ),
            Episode(
                name: "Ashurnasirpal II's Banquet at Kalhu",
                description: "To inaugurate his refounded capital Kalhu in 879 BCE, Ashurnasirpal II threw a ten-day party for 69,574 guests from across the empire and abroad. The Banquet Stele itemises the menu: 25,000 sheep and calves, 16,000 lambs, 30,000 birds, 10,000 jars of beer, 100 vats of wine — and the king installed the god Ninurta in his new temple before the drinking began.",
                year: -879, era: "Neo-Assyrian Period", approximate: false,
                source: "Banquet Stele of Ashurnasirpal II",
                sortName: "Ashurnasirpal II's Banquet at Kalhu",
                figureNames: ["Ashurnasirpal II"],
                places: [("Kalhu", nil)]
            ),
        ]

        var createdEvents = 0
        for episode in episodes where !existingEventKeys.contains(key(episode.name)) {
            let involved = episode.figureNames.compactMap { figureNamed($0) }
            let associations = episode.places.compactMap { entry -> EventPlaceAssociation? in
                guard let place = placeByKey[key(entry.name)] else { return nil }
                let role = entry.roleName.flatMap { name in eventPlaceRoles.first { $0.name == name } } ?? occurredAt
                return EventPlaceAssociation(event: nil, place: place, roleType: role)
            }
            let event = Event(
                name: episode.name,
                eventType: dailyLifeType,
                eventDescription: episode.description,
                date: MythologicalDate(year: episode.year, era: episode.era, isApproximate: episode.approximate),
                era: episode.era,
                source: episode.source,
                sortName: episode.sortName,
                involvedFigures: involved,
                placeAssociations: associations
            )
            for assoc in event.placeAssociations { assoc.event = event }
            context.insert(event)
            context.insert(StickyNote(text: stickyText, event: event))
            createdEvents += 1
        }

        // MARK: relationships

        let existingRelationships = (try? context.fetch(FetchDescriptor<Relationship>())) ?? []
        func hasRelationship(from: Figure, type: RelationshipType?, to: Figure) -> Bool {
            guard let type else { return true }
            return existingRelationships.contains {
                $0.relationshipType?.persistentModelID == type.persistentModelID &&
                $0.fromFigure === from && $0.toFigure === to
            }
        }
        func link(_ fromName: String, _ type: RelationshipType?, _ toName: String, source: String) {
            guard let from = figureNamed(fromName), let to = figureNamed(toName), let type,
                  !hasRelationship(from: from, type: type, to: to) else { return }
            context.insert(Relationship(fromFigure: from, toFigure: to, relationshipType: type, source: source))
        }
        link("Taram-Kubi", spouseType, "Innaya", source: "Old Assyrian letters from Kültepe")
        link("Lamassi", spouseType, "Pushu-ken", source: "Old Assyrian letters from Kültepe")
        link("Imdi-ilum", fatherType, "Zizizi", source: "Old Assyrian letters from Kültepe")
        link("Ishtar-bashti", motherType, "Zizizi", source: "Old Assyrian letters from Kültepe")

        // MARK: figure-place associations

        let existingFigurePlaceAssocs = (try? context.fetch(FetchDescriptor<FigurePlaceAssociation>())) ?? []
        let residencePairs: [(figure: String, place: String, role: FigurePlaceRoleType?)] = [
            ("Ea-nasir", "Ur", residentOf), ("Nanni", "Ur", residentOf),
            ("Gimil-Ninurta", "Nippur", residentOf), ("Mayor of Nippur", "Nippur", residentOf),
            ("Taram-Kubi", "Assur", residentOf), ("Innaya", "Kanesh", residentOf),
            ("Lamassi", "Assur", residentOf), ("Pushu-ken", "Kanesh", residentOf),
            ("Zizizi", "Kanesh", residentOf), ("Imdi-ilum", "Assur", residentOf),
            ("Ishtar-bashti", "Assur", residentOf), ("Ashurnasirpal II", "Kalhu", rulerOf),
        ]
        for pair in residencePairs {
            guard let figure = figureNamed(pair.figure), let place = placeByKey[key(pair.place)] else { continue }
            let exists = existingFigurePlaceAssocs.contains {
                $0.figure === figure && $0.place === place && $0.roleType?.name == pair.role?.name
            }
            guard !exists else { continue }
            context.insert(FigurePlaceAssociation(figure: figure, place: place, roleType: pair.role))
        }

        if createdFigures > 0 || createdEvents > 0 { try? context.save() }
    }

    /// Repairs the four parent-role edges the consistency scan proved contradictory,
    /// scoped narrowly so nothing else can ever match:
    /// 1. "Mother of Ninsun/Ninisina" edges hang on the MALE Uras ("patron god of
    ///    Dilbat") — tradition gives both goddesses the FEMALE Uraš (earth, consort
    ///    of An) as mother, so the edges are re-pointed to her when she exists.
    /// 2. Rachujal (described as a matriarch) is listed as Father of Rashujal —
    ///    re-typed to Mother. The bogus self-referential "Rashujal mother of
    ///    Rashujal" edge is deliberately LEFT ALONE (deleting user rows is never
    ///    automatic); it keeps surfacing in Data Integrity until removed by hand.
    /// Additive/idempotent; fires only on these exact normalized-name + gender
    /// conditions.
    package static func ensureConsistentParentRoles(context: ModelContext) {
        func key(_ s: String) -> String { NameDuplicateCheck.normalizedKey(s) }
        let allFigures = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        let types = (try? context.fetch(FetchDescriptor<RelationshipType>())) ?? []
        let motherType = types.first { $0.name == "Mother" }
        let fatherType = types.first { $0.name == "Father" }
        var changed = false

        // 1. Uras: male Dilbat patron must not mother anyone.
        let maleUras = allFigures.first {
            key($0.name) == "uras" && $0.gender == .male && $0.title.localizedCaseInsensitiveContains("Dilbat")
        }
        let femaleUrasList = allFigures.filter { key($0.name) == "uras" && $0.gender == .female }
        if let maleUras, let goddess = femaleUrasList.first, femaleUrasList.count == 1,
           let motherType {
            let childrenKeys: Set<String> = ["ninsun", "ninisina"]
            let edges = (try? context.fetch(FetchDescriptor<Relationship>())) ?? []
            for edge in edges where edge.relationshipType === motherType &&
                edge.fromFigure === maleUras &&
                edge.toFigure.map({ childrenKeys.contains(key($0.name)) }) == true {
                edge.fromFigure = goddess
                changed = true
            }
        }

        // 2. Rachujal the matriarch was typed Father instead of Mother.
        if let motherType, let fatherType,
           let rachujal = allFigures.first(where: { key($0.name) == "rachujal" }),
           let rashujal = allFigures.first(where: { key($0.name) == "rashujal" }) {
            let edges = (try? context.fetch(FetchDescriptor<Relationship>())) ?? []
            for edge in edges where edge.relationshipType === fatherType &&
                edge.fromFigure === rachujal && edge.toFigure === rashujal {
                edge.relationshipType = motherType
                changed = true
            }
        }

        if changed { try? context.save() }
    }

    /// Creates the three historical period labels that events reference but which
    /// the seed never included as Era entities (Old Assyrian, Old Babylonian,
    /// Neo-Assyrian). Lanes are appended AFTER the seeded dynasty lanes (31–33);
    /// they are ALSO registered in `fixEraOrderIndices`'s name map, because its
    /// catch-all otherwise bumps unlisted post-flood eras by +1 on every launch.
    /// Check-by-name creation; existing eras are never modified.
    package static func ensureHistoricalPeriodEras(context: ModelContext) {
        let existingKeys = Set(((try? context.fetch(FetchDescriptor<Era>())) ?? [])
            .map { NameDuplicateCheck.normalizedKey($0.name) })
        let configs: [(name: String, order: Int, description: String, start: Int, end: Int)] = [
            ("Old Assyrian Period", 31,
             "Period of the Assyrian merchant colonies (kārum) in Anatolia, best known from the Kültepe letter archives.",
             -2000, -1750),
            ("Old Babylonian Period", 32,
             "Amorite-led era opening with Hammurabi's dynasty at Babylon; the language of its cuneiform records became the classical Babylonian of scribal training.",
             -1894, -1595),
            ("Neo-Assyrian Period", 33,
             "The last great Assyrian empire, from Ashurnasirpal II's refoundation of Kalhu to the fall of Nineveh.",
             -911, -609),
        ]
        var createdAny = false
        for config in configs where !existingKeys.contains(NameDuplicateCheck.normalizedKey(config.name)) {
            let era = Era(
                name: config.name,
                orderIndex: config.order,
                eraDescription: config.description,
                startDate: MythologicalDate(year: config.start, isApproximate: true),
                endDate: MythologicalDate(year: config.end, isApproximate: true)
            )
            context.insert(era)
            createdAny = true
        }
        if createdAny { try? context.save() }
    }

    /// Links every `Relationship.sourceRef` to the `Source` entity named by its
    /// free-text `source` string. Existing Source names match case-insensitively
    /// ("Adapa myth" → seeded "Adapa Myth"); multi-text strings such as
    /// "Enuma Elish, Babylonian texts" use the first text as the primary
    /// attribution; unknown names get a coarse new `Source` created. Additive +
    /// idempotent — never re-points an existing `sourceRef`.
    package static func ensureRelationshipSources(context: ModelContext) {
        var byName: [String: Source] = [:]
        for source in (try? context.fetch(FetchDescriptor<Source>())) ?? [] {
            byName[source.name.lowercased()] = source
        }

        let relationships = (try? context.fetch(FetchDescriptor<Relationship>())) ?? []
        var changed = false
        for relationship in relationships where relationship.sourceRef == nil {
            guard let name = Self.primarySourceName(from: relationship.source) else { continue }
            let key = name.lowercased()
            if let existing = byName[key] {
                existing.relationships.append(relationship)
            } else {
                let source = Source(
                    name: name,
                    sourceType: name.localizedCaseInsensitiveContains("king list") ? .kingList : .ancientText,
                    author: "",
                    language: "",
                    period: "",
                    sourceDescription: "",
                    publicationInfo: "",
                    url: ""
                )
                context.insert(source)
                source.relationships.append(relationship)
                byName[key] = source
            }
            changed = true
        }
        if changed { try? context.save() }
    }

    private static func primarySourceName(from raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count >= 3 else { return nil }
        let first = trimmed.split(separator: ",").first.map(String.init) ?? trimmed
        let name = first.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.count >= 3 ? name : nil
    }

    /// Back-links free-text `CellSource`s on comparison-table cells to matching
    /// `Source` rows using lenient matching (e.g. "An=Anum" -> "Lexical God
    /// List An = Anum (Tablet IV)"). Additive and idempotent; links are set via
    /// the annotated side (`Source.cellListSources`).
    package static func ensureCellSourceLinksExist(context: ModelContext) {
        let sources = (try? context.fetch(FetchDescriptor<Source>())) ?? []
        let cellSources = (try? context.fetch(FetchDescriptor<CellSource>())) ?? []
        var changed = false
        for cellSource in cellSources where cellSource.sourceRef == nil {
            guard let match = Source.bestMatch(forCandidate: cellSource.source, among: sources) else { continue }
            if match.cellListSources.contains(where: { $0 === cellSource }) { continue }
            match.cellListSources.append(cellSource)
            cellSource.sourceRef = match
            changed = true
        }
        if changed { try? context.save() }
    }

    /// Backfills the standard Mesopotamian god list "An = Anum" as a Source row
    /// so comparison-table cells can cite it as a verified work. Additive and
    /// check-by-name: never duplicates an existing source. No URL (the text is
    /// not freely available online), which keeps `sourceWithoutURL` from firing.
    package static func ensureAnAnumGodListSourceExists(context: ModelContext) {
        let name = "Lexical God List An = Anum (Tablet IV)"
        let existing = (try? context.fetch(FetchDescriptor<Source>())) ?? []
        guard !existing.contains(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) else { return }

        let source = Source(
            name: name,
            sourceType: .tablet,
            author: "",
            language: "Sumerian/Akkadian",
            period: "Old Babylonian",
            sourceDescription: "The An = Anum god list enumerates the chief Mesopotamian deities and their summus deus theology.",
            publicationInfo: "Tablet IV",
            url: ""
        )
        context.insert(source)
        try? context.save()
    }

    /// Cleans up debris produced by junk free-text source strings. A typo like
    /// `"d"` on a relationship's `source` field used to materialize a bare
    /// `Source` row via `ensureRelationshipSources`; deleting that row only
    /// nullified the link while the string survived, so every launch recreated
    /// it. Blank any sub-3-character source strings (detaching via the
    /// annotated side), then delete sources that are pure machine debris:
    /// sub-3-character name, all metadata empty, no citations/attachments/
    /// relationships. Anything with real metadata or references is never
    /// touched. Additive + idempotent.
    package static func ensureJunkSourceStringsCleaned(context: ModelContext) {
        let relationships = (try? context.fetch(FetchDescriptor<Relationship>())) ?? []
        var changed = false
        for relationship in relationships {
            let trimmed = relationship.source.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, trimmed.count < 3 else { continue }
            if let source = relationship.sourceRef {
                source.relationships.removeAll { $0 == relationship }
            }
            relationship.source = ""
            changed = true
        }

        let sources = (try? context.fetch(FetchDescriptor<Source>())) ?? []
        for source in sources where source.name.trimmingCharacters(in: .whitespacesAndNewlines).count < 3 {
            let isDebris = source.author.isEmpty
                && source.language.isEmpty
                && source.period.isEmpty
                && source.sourceDescription.isEmpty
                && source.publicationInfo.isEmpty
                && source.url.isEmpty
                && source.citations.isEmpty
                && source.attachments.isEmpty
                && source.relationships.isEmpty
            if isDebris {
                context.delete(source)
                changed = true
            }
        }

        if changed { try? context.save() }
    }

    /// Tag every entity that has no tags yet using `TagEngine`'s rule-based
    /// suggestions (derived from type, gender, domain, era, source, description).
    /// Additive + idempotent — entities that already have any tag are never touched,
    /// so user curation is never overridden and a deleted auto-tag stays gone.
    /// New `Tag` rows get a deterministic palette color from the tag name.
    package static func ensureAutoTags(context: ModelContext) {
        let existingTags = (try? context.fetch(FetchDescriptor<Tag>())) ?? []
        var tagByName = existingTags.reduce(into: [:]) { $0[$1.name.lowercased()] = $1 }

        func tag(named name: String) -> Tag {
            let key = name.lowercased()
            if let existing = tagByName[key] { return existing }
            let newTag = Tag(name: name, colorHex: TagEngine.colorHex(for: name))
            context.insert(newTag)
            tagByName[key] = newTag
            return newTag
        }

        var changed = false

        let figures = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        for figure in figures where figure.tags.isEmpty {
            let names = TagEngine.tags(for: figure).sorted()
            guard !names.isEmpty else { continue }
            for name in names {
                figure.tags.append(tag(named: name))
            }
            changed = true
        }

        let places = (try? context.fetch(FetchDescriptor<Place>())) ?? []
        for place in places where place.tags.isEmpty {
            let names = TagEngine.tags(for: place).sorted()
            guard !names.isEmpty else { continue }
            for name in names {
                place.tags.append(tag(named: name))
            }
            changed = true
        }

        let events = (try? context.fetch(FetchDescriptor<Event>())) ?? []
        for event in events where event.tags.isEmpty {
            let names = TagEngine.tags(for: event).sorted()
            guard !names.isEmpty else { continue }
            for name in names {
                event.tags.append(tag(named: name))
            }
            changed = true
        }

        let things = (try? context.fetch(FetchDescriptor<Thing>())) ?? []
        for thing in things where thing.tags.isEmpty {
            let names = TagEngine.tags(for: thing).sorted()
            guard !names.isEmpty else { continue }
            for name in names {
                thing.tags.append(tag(named: name))
            }
            changed = true
        }

        if changed { try? context.save() }
    }

    /// Follow-up to `ensureAutoTags`: the old `domainTags` kept each comma-separated
    /// domain phrase whole, producing fragment tags like `"and the underworld"` or
    /// `"steward and scribe"`. `TagEngine.domainTags` now emits single words with
    /// connectors stripped. This pass removes exactly those legacy fragment links
    /// and backfills the refined single-word facets. Idempotent and additive — only
    /// tags matching a legacy domain phrase that no longer survives the new engine
    /// are removed; curated/type/tradition tags are untouched and `Tag` entities
    /// (shared across entities) are never deleted.
    package static func ensureRefinedDomainTags(context: ModelContext) {
        let existingTags = (try? context.fetch(FetchDescriptor<Tag>())) ?? []
        var tagByName = existingTags.reduce(into: [:]) { $0[$1.name.lowercased()] = $1 }

        func tag(named name: String) -> Tag {
            let key = name.lowercased()
            if let existing = tagByName[key] { return existing }
            let newTag = Tag(name: name, colorHex: TagEngine.colorHex(for: name))
            context.insert(newTag)
            tagByName[key] = newTag
            return newTag
        }

        var changed = false
        let figures = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        for figure in figures where !figure.domain.isEmpty {
            let obsolete = Set(legacyDomainTagPhrases(figure.domain)).subtracting(TagEngine.domainTags(figure.domain))
            guard !obsolete.isEmpty else { continue }

            var hasChange = false
            let before = figure.tags.count
            figure.tags.removeAll { obsolete.contains($0.name.lowercased()) }
            hasChange = figure.tags.count != before

            for tagName in TagEngine.domainTags(figure.domain).sorted() {
                guard !figure.tags.contains(where: { $0.name.lowercased() == tagName }) else { continue }
                figure.tags.append(tag(named: tagName))
                hasChange = true
            }

            if hasChange { changed = true }
        }

        if changed { try? context.save() }
    }

    private static func legacyDomainTagPhrases(_ domain: String) -> [String] {
        let phrases = domain.split(whereSeparator: { $0 == "," || $0 == ";" })
        var result: [String] = []
        for phrase in phrases {
            let cleaned = TagEngine.cleanedToken(String(phrase))
            guard !cleaned.isEmpty, cleaned != "and", cleaned != "of", cleaned != "the" else { continue }
            result.append(cleaned)
        }
        return result
    }

    /// Creates a top-level "Dynasties" group (kind `.skl`) with one subgroup per SKL
    /// dynasty era from the `Era` table. Each subgroup auto-populates its kings (figures
    /// whose `era` points to that era) ordered by reign succession, plus any events whose
    /// era string matches the dynasty name — giving every dynasty a mixed-type page
    /// (figures + events, places added by hand) like the Enoch-style group pages.
    /// Additive + idempotent: only missing groups/members are created; existing groups,
    /// manual additions, and user-set ordering are never overwritten.
    package static func ensureDynastyGroups(context: ModelContext) {
        let allGroups = (try? context.fetch(FetchDescriptor<FigureGroup>())) ?? []
        let eras = (try? context.fetch(FetchDescriptor<Era>())) ?? []
        let dynastyEras = eras
            .filter { $0.name.localizedCaseInsensitiveContains("dynasty") }
            .sorted { $0.orderIndex < $1.orderIndex }
        guard !dynastyEras.isEmpty else { return }

        let figures = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        let events = (try? context.fetch(FetchDescriptor<Event>())) ?? []
        var changed = false

        var top = allGroups.first { $0.name == "Dynasties" }
        if top == nil {
            let group = FigureGroup(
                name: "Dynasties",
                groupDescription: "Sumerian King List dynasties with their kings, events, and places",
                icon: "building.columns",
                colorHex: "007AFF",
                orderIndex: 100,
                kind: .skl,
                entityType: .figure
            )
            context.insert(group)
            top = group
            changed = true
        }
        guard let top else { return }

        var subgroupIndex = (top.subgroups ?? []).compactMap { $0.orderIndex }.max().map { $0 + 1 } ?? (top.subgroups ?? []).count
        for era in dynastyEras {
            var sub: FigureGroup?
            let isNew: Bool
            if let existing = (top.subgroups ?? []).first(where: { $0.name == era.name }) {
                sub = existing
                isNew = false
            } else {
                let newSub = FigureGroup(
                    name: era.name,
                    groupDescription: "Kings, events, and places of \(era.name)",
                    icon: "crown",
                    colorHex: "007AFF",
                    orderIndex: subgroupIndex,
                    kind: .skl,
                    entityType: .figure,
                    sortMode: .ordered
                )
                context.insert(newSub)
                if top.subgroups == nil { top.subgroups = [] }
                top.subgroups?.append(newSub)
                subgroupIndex += 1
                changed = true
                sub = newSub
                isNew = true
            }
            guard let sub else { continue }
            if sub.era?.persistentModelID != era.persistentModelID {
                sub.era = era
                changed = true
            }

            for figure in figures where figure.era?.persistentModelID == era.persistentModelID {
                guard !sub.figureAssociations.contains(where: { $0.figure?.persistentModelID == figure.persistentModelID }) else { continue }
                let assoc = FigureGroupAssociation(figure: figure)
                context.insert(assoc)
                sub.figureAssociations.append(assoc)
                figure.groupAssociations.append(assoc)
                changed = true
            }

            let eraName = era.name.trimmingCharacters(in: .whitespaces).lowercased()
            for event in events where event.era.trimmingCharacters(in: .whitespaces).lowercased() == eraName {
                guard !sub.figureAssociations.contains(where: { $0.event?.persistentModelID == event.persistentModelID }) else { continue }
                let assoc = FigureGroupAssociation(event: event)
                context.insert(assoc)
                sub.figureAssociations.append(assoc)
                event.groupAssociations.append(assoc)
                changed = true
            }

            if isNew && !sub.figureAssociations.isEmpty {
                sub.applyRegnalOrder()
            }
        }

        // Link eras to dynasty subgroups in any other tree (e.g. a legacy hand-built
        // "Sumerian King List" group) by normalized name. Additive + idempotent —
        // existing era links and user-created groups are untouched.
        let eraByNormalized: [String: Era] = Dictionary(
            dynastyEras.map { (Self.normalizedGroupName($0.name), $0) },
            uniquingKeysWith: { first, _ in first }
        )
        for sub in allGroups where sub.parentGroup != nil && sub.era == nil {
            guard let era = eraByNormalized[Self.normalizedGroupName(sub.name)] else { continue }
            sub.era = era
            changed = true
        }

        if changed { try? context.save() }
    }

    private static func normalizedGroupName(_ name: String) -> String {
        var s = name.trimmingCharacters(in: .whitespaces).lowercased()
        while s.hasPrefix("the ") { s = String(s.dropFirst(4)) }
        return s
    }

    /// Seed-to-DB name key tolerant of the spelling variants users accumulate
    /// (e.g. seed "Apilkin" vs DB "Apil-kin"): lowercased, hyphens stripped.
    private static func seedNameKey(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespaces).lowercased().replacingOccurrences(of: "-", with: "")
    }

    /// Author-era territory polygons for the SKL dynasties (lon, lat), keyed by
    /// normalized era name. Open rings; closed at serialization. Drawn once when
    /// `era.boundaryGeoJSON` is empty so the user's own drawings always win.
    package static let dynastyBoundaryRings: [String: [[Double]]] = [
        "first dynasty of kish": [[44.05, 33.45], [44.75, 33.45], [45.05, 33.15], [45.15, 32.65], [45.35, 32.20], [45.20, 31.95], [44.95, 32.00], [44.55, 32.10], [44.30, 32.15], [44.10, 32.55], [44.00, 32.95]],
        "first rulers of uruk": [[45.35, 32.10], [45.75, 32.10], [46.15, 31.90], [46.30, 31.55], [46.15, 31.25], [45.80, 31.05], [45.45, 31.15], [45.30, 31.45], [45.25, 31.75]],
        "first dynasty of ur": [[45.55, 31.55], [46.00, 31.60], [46.35, 31.40], [46.40, 31.00], [46.20, 30.75], [45.90, 30.75], [45.70, 30.95], [45.45, 31.15]],
        "second dynasty of kish": [[44.10, 33.20], [44.70, 33.30], [45.00, 33.10], [45.10, 32.70], [45.00, 32.35], [44.70, 32.30], [44.35, 32.40], [44.15, 32.80]],
        "dynasty of hamazi": [[44.90, 33.60], [45.40, 33.70], [45.90, 34.00], [46.40, 34.10], [46.80, 33.90], [46.70, 33.40], [46.20, 33.20], [45.70, 33.30], [45.20, 33.40]],
        "second dynasty of uruk": [[45.40, 32.05], [45.80, 32.05], [46.10, 31.85], [46.25, 31.50], [46.10, 31.20], [45.75, 31.05], [45.45, 31.15], [45.30, 31.45], [45.40, 31.80]],
        "second dynasty of ur": [[45.60, 31.60], [46.05, 31.65], [46.40, 31.45], [46.50, 31.05], [46.25, 30.70], [45.95, 30.70], [45.65, 30.90], [45.45, 31.15]],
        "dynasty of adab": [[45.40, 32.30], [45.85, 32.30], [46.25, 32.10], [46.40, 31.80], [46.25, 31.50], [45.90, 31.50], [45.60, 31.70], [45.40, 32.00]],
        "dynasty of mari": [[40.30, 34.90], [40.90, 35.20], [41.60, 35.20], [42.20, 34.90], [42.30, 34.40], [41.70, 34.10], [41.00, 34.10], [40.40, 34.30], [40.10, 34.60]],
        "dynasty of awan": [[45.20, 33.60], [46.20, 33.80], [47.40, 33.60], [48.40, 33.20], [48.50, 32.20], [48.10, 31.70], [47.30, 31.90], [46.40, 32.10], [45.60, 32.40]],
        "third dynasty of kish": [[44.10, 33.25], [44.75, 33.30], [45.05, 33.05], [45.20, 32.60], [45.30, 32.15], [45.05, 31.95], [44.70, 32.10], [44.35, 32.20], [44.10, 32.60]],
        "dynasty of akshak": [[44.10, 33.45], [44.80, 33.50], [45.15, 33.30], [45.25, 32.90], [45.10, 32.50], [44.75, 32.35], [44.40, 32.45], [44.15, 32.85]],
        "fourth dynasty of kish": [[44.05, 33.40], [44.70, 33.45], [45.00, 33.15], [45.10, 32.65], [45.30, 32.20], [45.05, 32.00], [44.60, 32.10], [44.30, 32.20], [44.10, 32.60]],
        "third dynasty of uruk": [[45.25, 32.20], [45.65, 32.15], [46.05, 31.95], [46.20, 31.60], [46.05, 31.25], [45.70, 31.10], [45.40, 31.20], [45.25, 31.50]],
        "dynasty of akkad": [[40.60, 35.40], [42.30, 35.60], [45.30, 35.40], [46.60, 34.60], [47.20, 33.20], [46.60, 31.60], [46.00, 30.60], [45.30, 30.70], [44.70, 31.00], [43.90, 31.60], [43.20, 32.60], [42.60, 33.80], [41.60, 34.20], [40.60, 34.60]],
        "fourth dynasty of uruk": [[45.35, 32.00], [45.75, 32.00], [46.10, 31.80], [46.20, 31.45], [46.05, 31.20], [45.70, 31.05], [45.40, 31.15], [45.28, 31.45], [45.35, 31.80]],
        "fifth dynasty of uruk": [[45.40, 32.10], [45.85, 32.10], [46.15, 31.85], [46.25, 31.50], [46.10, 31.20], [45.75, 31.05], [45.42, 31.15], [45.30, 31.50], [45.40, 31.85]],
        "third dynasty of ur": [[43.60, 34.60], [45.20, 34.50], [46.80, 33.90], [48.40, 33.30], [48.60, 31.80], [47.80, 31.50], [46.60, 30.60], [45.60, 30.55], [44.80, 30.90], [43.90, 31.70], [43.20, 32.90], [43.20, 33.90]],
        "dynasty of isin": [[44.30, 32.80], [44.90, 32.80], [45.20, 32.60], [45.40, 32.20], [45.60, 31.90], [45.90, 31.70], [46.10, 31.40], [46.05, 31.10], [45.65, 30.95], [45.35, 31.10], [45.10, 31.45], [44.90, 31.85], [44.55, 32.10], [44.30, 32.50]],
        "gutian rule": [[44.60, 34.20], [45.40, 34.40], [46.40, 34.90], [47.20, 35.10], [47.80, 34.40], [47.30, 33.50], [46.40, 33.30], [45.60, 33.40], [44.90, 33.80]],
    ]

    /// Backfills `Era.boundaryGeoJSON` with the author-drawn territory polygon
    /// for every dynasty era, once. Additive + idempotent: closed, non-degenerate
    /// existing boundaries (user-drawn or edited) are never overwritten. Rings
    /// saved by the prototype draw tool were unclosed and could be degenerate
    /// (invisible slivers) — those are repaired back to the authored territory.
    /// The repair also covers *closed* slivers: a ring whose extent along either
    /// axis is below `sliverMinAxisDegrees` is a dot / thick line / test-draw,
    /// not a territory (the smallest authored ring spans 0.70 degrees), so it is
    /// restored to the authored polygon too.
    package static func ensureDynastyBoundaries(context: ModelContext) {
        guard !Self.dynastyBoundaryRings.isEmpty else { return }
        let eras = (try? context.fetch(FetchDescriptor<Era>())) ?? []
        let eraByNormalized: [String: Era] = Dictionary(
            eras.map { (Self.normalizedGroupName($0.name), $0) },
            uniquingKeysWith: { first, _ in first }
        )
        var changed = false
        for (normalizedName, ring) in Self.dynastyBoundaryRings {
            guard let era = eraByNormalized[normalizedName],
                  let authored = Self.polygonGeoJSON(ring: ring) else { continue }
            if let existing = era.boundaryGeoJSON,
               let stored = Self.decodedRing(from: existing),
               stored.count >= 4,
               stored.first == stored.last,
               Self.ringAreaSq(stored) > 0.001,
               Self.ringMinAxisDegrees(stored) >= Self.sliverMinAxisDegrees {
                continue
            }
            era.boundaryGeoJSON = authored
            changed = true
        }
        if changed { try? context.save() }
    }

    private static let sliverMinAxisDegrees = 0.4

    /// The smallest bounding-box extent (degrees) across both axes. A closed
    /// ring whose min-axis is tiny is a degenerate dot/line, not a polygon.
    private static func ringMinAxisDegrees(_ ring: [[Double]]) -> Double {
        var minLon = Double.infinity, maxLon = -Double.infinity
        var minLat = Double.infinity, maxLat = -Double.infinity
        for point in ring {
            minLon = Swift.min(minLon, point[0])
            maxLon = Swift.max(maxLon, point[0])
            minLat = Swift.min(minLat, point[1])
            maxLat = Swift.max(maxLat, point[1])
        }
        return Swift.min(maxLon - minLon, maxLat - minLat)
    }

    private static func decodedRing(from json: String) -> [[Double]]? {
        guard let data = json.data(using: .utf8),
              let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              object["type"] as? String == "Polygon",
              let coordinates = object["coordinates"] as? [[[Double]]],
              let ring = coordinates.first else { return nil }
        return ring
    }

    private static func ringAreaSq(_ ring: [[Double]]) -> Double {
        guard ring.count >= 3 else { return 0 }
        var area = 0.0
        for i in 0..<ring.count {
            let p = ring[i]
            let q = ring[(i + 1) % ring.count]
            area += p[0] * q[1] - q[0] * p[1]
        }
        return abs(area) / 2
    }

    package static func polygonGeoJSON(ring: [[Double]]) -> String? {
        guard ring.count >= 3 else { return nil }
        let closed = ring + [ring[0]]
        let object: [String: Any] = ["type": "Polygon", "coordinates": [closed]]
        guard let data = try? JSONSerialization.data(withJSONObject: object) else { return nil }
        return String(data: data, encoding: .utf8)
    }

}

extension Migration {
    /// Backfill ActivityLogEntry.user links for entries written before the
    /// key-based relation existed (they only carry the userName snapshot).
    /// Idempotent: only touches entries whose user is nil and whose snapshot
    /// name matches exactly one user (case-insensitive).
    package static func ensureActivityLogUserLinks(context: ModelContext) {
        let entries = (try? context.fetch(FetchDescriptor<ActivityLogEntry>())) ?? []
        let unlinked = entries.filter { $0.user == nil && !$0.userName.isEmpty }
        guard !unlinked.isEmpty else { return }

        let users = (try? context.fetch(FetchDescriptor<User>())) ?? []
        guard !users.isEmpty else { return }

        var changed = false
        for entry in unlinked {
            let matches = users.filter { $0.name.caseInsensitiveCompare(entry.userName) == .orderedSame }
            guard matches.count == 1, let user = matches.first else { continue }
            entry.user = user
            user.activityLogEntries?.append(entry)
            changed = true
        }
        if changed { try? context.save() }
    }
}

extension Migration {
    /// Promote the earliest-created user to administrator when no admin exists.
    /// Idempotent: fires only while the store has zero administrators, so a
    /// later admin demotion or role edit is never overridden.
    package static func ensureFirstUserIsAdmin(context: ModelContext) {
        let users = (try? context.fetch(FetchDescriptor<User>())) ?? []
        guard !users.isEmpty else { return }
        guard !users.contains(where: \.isAdministrator) else { return }

        let first = users.min { ($0.createdAt, $0.name) < ($1.createdAt, $1.name) }
        first?.isAdmin = true
        try? context.save()
    }

    /// Marks figures that already had syncretised deity names in the database
    /// before the 2026-08-26 missing-deities import. Each gets a sticky note
    /// so the user can review the relationship. Additive + idempotent.
    package static func markPreExistingSyncretisms(context: ModelContext) {
        let figures = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        let figureByName: [String: Figure] = Dictionary(uniqueKeysWithValues: figures.map { ($0.name.lowercased(), $0) })

        let syncretisms: [(existingName: String, altName: String)] = [
            ("Ninhursag", "Ki"),
            ("Nergal", "Erra"),
            ("Marduk", "Asarluhi"),
            ("Kug-Bau", "Bau"),
            ("Damkina", ""),
        ]

        let stickyPrefix = "FROM 26-08-2026 IMPORT"
        var changed = false
        for (existingName, altName) in syncretisms {
            guard let figure = figureByName[existingName.lowercased()] else { continue }
            let alreadyHas = figure.stickies.contains { $0.text.hasPrefix(stickyPrefix) }
            guard !alreadyHas else { continue }
            let note = altName.isEmpty
                ? stickyPrefix
                : "\(stickyPrefix) — \(altName) was already an alternate name"
            context.insert(StickyNote(text: note, figure: figure))
            changed = true
        }
        if changed { try? context.save() }
    }

    /// Ensures canonical spouse and family links for key deity couples.
    /// Dynamically detects all couples that share a child (via Mother/Father
    /// relationships) but have no Spouse relationship between them, and creates
    /// the missing link. Also fixes Asarluhi's mother from Ninhursag to Damkina
    /// where applicable. Additive + idempotent.
    package static func ensureCanonicalDeityFamilies(context: ModelContext) {
        func key(_ s: String) -> String { NameDuplicateCheck.normalizedKey(s) }
        let allFigures = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        let figureByName: [String: Figure] = Dictionary(
            allFigures.map { (key($0.name), $0) }, uniquingKeysWith: { first, _ in first })

        let types = (try? context.fetch(FetchDescriptor<RelationshipType>())) ?? []
        let motherType = types.first { $0.name == "Mother" }
        let fatherType = types.first { $0.name == "Father" }
        let spouseType = types.first { $0.name == "Spouse" }
        guard let motherType, let fatherType else { return }

        let edges = (try? context.fetch(FetchDescriptor<Relationship>())) ?? []
        var changed = false

        // Build spouse pair set (bidirectional)
        var spousePairs: Set<StaticIdentifier> = []
        if let spouseType {
            for edge in edges where edge.relationshipType === spouseType {
                if let from = edge.fromFigure, let to = edge.toFigure {
                    spousePairs.insert(StaticIdentifier(from.persistentModelID, to.persistentModelID))
                }
            }
        }

        // Build parent maps: child → {mothers, fathers}
        var childMothers: [PersistentIdentifier: Set<PersistentIdentifier>] = [:]
        var childFathers: [PersistentIdentifier: Set<PersistentIdentifier>] = [:]
        for edge in edges {
            guard let from = edge.fromFigure, let to = edge.toFigure else { continue }
            if edge.relationshipType === motherType {
                childMothers[to.persistentModelID, default: []].insert(from.persistentModelID)
            } else if edge.relationshipType === fatherType {
                childFathers[to.persistentModelID, default: []].insert(from.persistentModelID)
            }
        }

        // Find all couples with shared children but no Spouse link
        let idToFigure: [PersistentIdentifier: Figure] = Dictionary(
            allFigures.map { ($0.persistentModelID, $0) }, uniquingKeysWith: { first, _ in first })

        var fixedPairs: Set<StaticIdentifier> = []
        if let spouseType {
            for (childId, mothers) in childMothers {
                guard let fathers = childFathers[childId] else { continue }
                for motherId in mothers {
                    for fatherId in fathers {
                        let pair = StaticIdentifier(motherId, fatherId)
                        guard !fixedPairs.contains(pair) else { continue }
                        if !spousePairs.contains(pair),
                           let mother = idToFigure[motherId],
                           let father = idToFigure[fatherId] {
                            let rel = Relationship(fromFigure: father, toFigure: mother, relationshipType: spouseType, source: "Mythological tradition")
                            context.insert(rel)
                            fixedPairs.insert(pair)
                            changed = true
                        }
                    }
                }
            }
        }

        // Fix Asarluhi's mother: reassign from Ninhursag to Damkina
        if let damkina = figureByName["damkina"], let ninhursag = figureByName["ninhursag"] {
            for childName in ["asarluhi", "asalluhi"] {
                guard let child = figureByName[childName] else { continue }
                for edge in edges where edge.relationshipType === motherType &&
                    edge.fromFigure === ninhursag && edge.toFigure === child {
                    edge.fromFigure = damkina
                    changed = true
                }
            }
        }

        if changed { try? context.save() }
    }

    /// Ensures bidirectional consistency for relationship types that are
    /// inherently mutual (Spouse, Consort, Sibling, Ally, Enemy). If X→Y
    /// exists but Y→X does not, creates the reverse link preserving the
    /// original source. Additive + idempotent.
    package static func ensureBidirectionalRelationshipConsistency(context: ModelContext) {
        let bidirectionalTypes: Set<String> = ["Spouse", "Consort", "Sibling", "Ally", "Enemy"]

        let edges = (try? context.fetch(FetchDescriptor<Relationship>())) ?? []
        var changed = false

        // Build a set of existing directed edges
        struct EdgeKey: Hashable {
            let from: PersistentIdentifier
            let to: PersistentIdentifier
            let type: String
        }
        var existing = Set<EdgeKey>()
        for edge in edges {
            guard let from = edge.fromFigure, let to = edge.toFigure,
                  let typeName = edge.relationshipType?.name else { continue }
            existing.insert(EdgeKey(from: from.persistentModelID, to: to.persistentModelID, type: typeName))
        }

        // For each edge, check if the reverse exists; if not, create it
        for edge in edges {
            guard let from = edge.fromFigure, let to = edge.toFigure,
                  let typeName = edge.relationshipType?.name,
                  bidirectionalTypes.contains(typeName) else { continue }

            let reverse = EdgeKey(from: to.persistentModelID, to: from.persistentModelID, type: typeName)
            guard !existing.contains(reverse) else { continue }

            let rel = Relationship(
                fromFigure: to,
                toFigure: from,
                relationshipType: edge.relationshipType,
                source: edge.source,
                sourceRef: edge.sourceRef,
                isPreferred: edge.isPreferred ?? false,
                groupID: edge.groupID
            )
            context.insert(rel)
            existing.insert(reverse)
            changed = true
        }

        if changed { try? context.save() }
    }
}
