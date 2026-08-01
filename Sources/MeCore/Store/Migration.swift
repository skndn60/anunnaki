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

    /// Add Duttur (mother of Dumuzi & Geshtinanna) and parent relationships
    /// so sibling inference via shared parents works for Dumuzi <-> Geshtinanna.
    package static func ensureDumuziFamilyExists(context: ModelContext) {
        let existingNames = Set((try? context.fetch(FetchDescriptor<Figure>()))?.map(\.name) ?? [])

        let fatherType = try? context.fetch(FetchDescriptor<RelationshipType>(predicate: #Predicate { $0.name == "Father" })).first
        let motherType = try? context.fetch(FetchDescriptor<RelationshipType>(predicate: #Predicate { $0.name == "Mother" })).first

        // Create Duttur if missing
        let dutturID: PersistentIdentifier?
        if existingNames.contains("Duttur") {
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
        guard let enki = allFigures.first(where: { $0.name == "Enki" }),
              let dumuzi = allFigures.first(where: { $0.name == "Dumuzi" }),
              let geshtinanna = allFigures.first(where: { $0.name == "Geshtinanna" }),
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
        let existingNames = Set((try? context.fetch(FetchDescriptor<Figure>()))?.map(\.name) ?? [])
        let targetNames: Set<String> = [
            "Ishkur", "Uraš", "Zababa", "Ninazu", "Ningishzida",
            "Gugalanna", "Birtu", "Kulla", "Mushdamma", "Hendursaga",
            "Isimud", "Papsukkal", "Lugal-Marada", "Numushda", "Shara",
            "Pabilsag", "Lulal", "Enkimdu", "Ninshubur",
        ]
        guard targetNames.intersection(existingNames).count != targetNames.count else { return }

        let url: URL? = {
            if let u = Bundle.module.url(forResource: "deities_import", withExtension: "json") { return u }
            return Bundle.main.url(forResource: "deities_import", withExtension: "json")
        }()
        guard let u = url,
              let data = try? Data(contentsOf: u),
               let root = try? JSONDecoder().decode(SeedDataRoot.self, from: data) else {
            return
        }

        let rootExistingNames = Set(root.figures.map(\.name))
        guard rootExistingNames.isSubset(of: targetNames) else {
            return
        }

        let toImport = root.figures.filter { !existingNames.contains($0.name) }
        guard !toImport.isEmpty else { return }

        let importedIds = Set(toImport.map(\.id))
        var filteredRoot = root
        filteredRoot.figures = toImport
        filteredRoot.alternateNames = root.alternateNames.filter { importedIds.contains($0.figureId ?? "") }
        filteredRoot.figurePlaceAssociations = root.figurePlaceAssociations?.filter { importedIds.contains($0.figureId) }

        SeedData.importFrom(root: filteredRoot, context: context)
    }

    /// Update era orderIndex values to match current seed data ordering.
    /// Fixes the pre/post flood split that shifted when new eras were inserted.
    package static func fixEraOrderIndices(context: ModelContext) {
        let eras = (try? context.fetch(FetchDescriptor<Era>())) ?? []
        let newOrder: [String: Int] = [
            "Creation": 0,
            "Age of the Watchers": 1,
            "Age of the First Gods": 2,
            "Anunnaki on Earth": 3,
            "Creation of Mankind": 4,
            "Antediluvian Period": 5,
            "Antediluvian": 6,
            "SKL Antediluvian": 6,
            "The Great Flood": 7,
            "Post-Flood Kingdoms": 8,
            "Early Dynastic Period": 9,
        ]
        var changed = false
        for era in eras {
            if let newOI = newOrder[era.name] {
                if era.orderIndex != newOI {
                    era.orderIndex = newOI
                    changed = true
                }
            } else if era.orderIndex >= 9 {
                // SKL dynasty eras — shift by +1 to account for the inserted eras
                era.orderIndex = era.orderIndex + 1
                changed = true
            }
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

            guard let dbFig = allFigures.first(where: { $0.name == seedFig.name }) else { continue }
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
        let existingNames = Set(allFigures.map(\.name))

        let figureById: [PersistentIdentifier: Figure] = allFigures.reduce(into: [:]) { $0[$1.persistentModelID] = $1 }
        let figureByName: [String: Figure] = allFigures.reduce(into: [:]) { $0[$1.name] = $1 }

        // Look up or create a figure by name
        func getOrCreateFigure(name: String, title: String, domain: String, description: String) -> Figure? {
            if let existing = figureByName[name] { return existing }
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
        let figureByName2: [String: Figure] = allFigures2.reduce(into: [:]) { $0[$1.name] = $1 }

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
            guard let from = figureByName2[fromName],
                  let to = figureByName2[toName] else { continue }
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
        let existingPlaceNames = Set(allPlaces.map(\.name))
        let figureByName = allFigures.reduce(into: [:]) { $0[$1.name] = $1 }
        var placeByName = allPlaces.reduce(into: [:]) { $0[$1.name] = $1 }

        let seedFigureNameById = root.figures.reduce(into: [:]) { $0[$1.id] = $1.name }
        let seedPlaceNameById = root.places.reduce(into: [:]) { $0[$1.id] = $1.name }
        let allPlaceTypes: [PlaceType] = (try? context.fetch(FetchDescriptor<PlaceType>())) ?? []
        let placeTypeByName = allPlaceTypes.reduce(into: [:]) { $0[$1.name] = $1 }

        // 1. Create missing places
        for seedPlace in root.places {
            guard !existingPlaceNames.contains(seedPlace.name) else { continue }
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
            placeByName[seedPlace.name] = place
        }

        // 2. Create missing figure-place associations
        let allRoleTypes: [FigurePlaceRoleType] = (try? context.fetch(FetchDescriptor<FigurePlaceRoleType>())) ?? []
        let existingAssocs = (try? context.fetch(FetchDescriptor<FigurePlaceAssociation>())) ?? []

        for seedAssoc in root.figurePlaceAssociations ?? [] {
            guard let figName = seedFigureNameById[seedAssoc.figureId],
                  let placeName = seedPlaceNameById[seedAssoc.placeId],
                  let figure = figureByName[figName],
                  let place = placeByName[placeName] else { continue }

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
            guard let fromPlace = placeByName[seedPlaceNameById[seedAssoc.fromPlaceId] ?? ""],
                  let toPlace = placeByName[seedPlaceNameById[seedAssoc.toPlaceId] ?? ""] else { continue }

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

        var figureByName = allFigures.reduce(into: [:]) { $0[$1.name] = $1 }
        var placeByName = allPlaces.reduce(into: [:]) { $0[$1.name] = $1 }
        let eventTypeByName = allEventTypes.reduce(into: [:]) { $0[$1.name] = $1 }
        let occuredAtRole = allEventPlaceRoles.first(where: { $0.name == "Occurred At" })

        let existingEventNames = Set(allFigures.isEmpty ? [] : (try? context.fetch(FetchDescriptor<Event>()))?.map(\.name) ?? [])

        let seedFigureNameById = root.figures.reduce(into: [:]) { $0[$1.id] = $1.name }
        let seedPlaceNameById = root.places.reduce(into: [:]) { $0[$1.id] = $1.name }

        // 1. Create missing figures
        for seedFig in root.figures {
            guard !figureByName.keys.contains(seedFig.name) else { continue }
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
            figureByName[seedFig.name] = figure
        }

        // 2. Create missing places
        let sklPlaceNames = Set(["Girsu", "Gu-Edin", "Aratta", "Dabrum"])
        for seedPlace in root.places {
            guard !placeByName.keys.contains(seedPlace.name) else { continue }
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
            placeByName[seedPlace.name] = place
        }

        try? context.save()

        // 3. Create missing events
        for seedEvent in root.events {
            guard !existingEventNames.contains(seedEvent.name) else { continue }

            let eventFigures = seedEvent.involvedFigureIds.compactMap { fid -> Figure? in
                guard let figName = seedFigureNameById[fid] else { return nil }
                return figureByName[figName]
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
            if let pid = seedEvent.placeId, let placeName = seedPlaceNameById[pid], let place = placeByName[placeName] {
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
            ("The Flood", "The Mesopotamian flood narrative (Atra-Hasis, Epic of Gilgamesh)", "drop", "34C759", nil, .flood),
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
            "The Flood": .flood,
        ]

        let iconByName: [String: String] = [
            "Divine Council": "person.3",
            "Sumerian Pantheon": "star",
            "Akkadian/East Semitic": "star.circle",
            "Book of Enoch": "book",
            "SKL Kings": "list.star",
            "Sumerian King List": "list.star",
            "The Flood": "drop",
        ]

        for group in allGroups {
            if let kind = kindByName[group.name], group.kind != kind {
                group.kind = kind
            }
            if let icon = iconByName[group.name], group.icon != icon {
                group.icon = icon
            }
        }

        if !allGroups.contains(where: { $0.name == "The Flood" }) {
            let maxOrder = allGroups.map(\.orderIndex).max() ?? 0
            let group = FigureGroup(
                name: "The Flood",
                groupDescription: "The Mesopotamian flood narrative (Atra-Hasis, Epic of Gilgamesh)",
                icon: "drop",
                colorHex: "34C759",
                orderIndex: maxOrder + 1,
                kind: .flood
            )
            context.insert(group)
        }
        try? context.save()
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
        let figureByName = allFigures.reduce(into: [:]) { $0[$1.name] = $1 }

        let allRelTypes = (try? context.fetch(FetchDescriptor<RelationshipType>())) ?? []
        let existingRelationships = (try? context.fetch(FetchDescriptor<Relationship>())) ?? []

        for rel in relationships {
            guard let fromFigure = figureByName[rel.from],
                  let toFigure = figureByName[rel.to],
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

}
