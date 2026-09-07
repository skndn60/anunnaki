import Foundation
import SwiftData

extension Migration {
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

    /// Seeds curated everyday-life Things (objects/artifacts that do not belong in
    /// the event timeline, e.g. the Yale culinary tablets). Additive and idempotent:
    /// each entry is created only if no Thing with the same normalized name exists.
    package static func ensureEverydayLifeThings(context: ModelContext) {
        func key(_ s: String) -> String { NameDuplicateCheck.normalizedKey(s) }

        let textType = (try? context.fetch(FetchDescriptor<ThingType>(predicate: #Predicate { $0.name == "Text" })))?.first
        let existingThings = (try? context.fetch(FetchDescriptor<Thing>())) ?? []
        var created = 0

        struct CuratedThing {
            let name: String
            let description: String
            let source: String
        }

        let thingConfigs: [CuratedThing] = [
            CuratedThing(
                name: "Yale Culinary Tablets",
                description: "Three small Babylonian tablets in Yale's collection carry the world's oldest surviving recipes: around twenty-five broths and stews seasoned with leek, onion, garlic, beer, coriander, and cumin, including a beet stew called tuh'u and an 'Elamite broth'. Written around 1730 BCE, they read like kitchen aide-mémoires rather than cookbooks — ingredient lists for cooks who knew the method.",
                source: "YBC 4644 et al.; Jean Bottéro, Textes culinaires mésopotamiens"
            )
        ]

        for config in thingConfigs where !existingThings.contains(where: { key($0.name) == key(config.name) }) {
            let thing = Thing(name: config.name, thingDescription: config.description, source: config.source)
            thing.thingType = textType
            context.insert(thing)
            created += 1
        }
        if created > 0 { try? context.save() }
    }

    /// Reclassifies the "Yale Culinary Tablets" everyday-life entry from an Event
    /// into a Thing ("Text" type): the tablets are physical objects, not a
    /// happening, so they belong in Things rather than the event timeline.
    /// Carries over name, description, and source, drops the now-dangling
    /// auto-generated citation, then removes the Event. Idempotent — does nothing
    /// if no such Event exists, and never overwrites a Thing the user may have
    /// created themselves.
    package static func convertYaleCulinaryTabletsEventToThing(context: ModelContext) {
        func key(_ s: String) -> String { NameDuplicateCheck.normalizedKey(s) }
        let yaleKey = key("Yale Culinary Tablets")

        let allEvents = (try? context.fetch(FetchDescriptor<Event>())) ?? []
        guard let event = allEvents.first(where: { key($0.name) == yaleKey }) else { return }

        let textType = (try? context.fetch(FetchDescriptor<ThingType>(predicate: #Predicate { $0.name == "Text" })))?.first
        let allThings = (try? context.fetch(FetchDescriptor<Thing>())) ?? []
        let existingThing = allThings.first(where: { key($0.name) == yaleKey })

        if existingThing == nil {
            let thing = Thing(name: event.name, thingDescription: event.eventDescription, source: event.source)
            thing.richDescription = event.richDescription
            thing.thingType = textType
            context.insert(thing)
        }

        let allCitations = (try? context.fetch(FetchDescriptor<Citation>())) ?? []
        let autoCitation = allCitations.first { $0.safeEntityName == event.name && $0.safeEntityType == .event }
        if let autoCitation { context.delete(autoCitation) }

        context.delete(event)
        try? context.save()
    }

    /// Backfills `Event.involvedFigures` (and `Figure.events`) for any
    /// `EventFigureAssociation` whose figure is not yet present in the event's
    /// array. The event popover used to link figures with
    /// `alsoLinkInvolvedFigures: false`, silently leaving the figure out of the
    /// involved-figures list — so the figure's Events section stayed empty and
    /// the "no figures linked" warning never cleared. Both the association row
    /// and the involved-figures list must agree. Additive and idempotent.
    package static func repairInvolvedFiguresFromAssociations(context: ModelContext) {
        let events = (try? context.fetch(FetchDescriptor<Event>())) ?? []
        var changed = false
        for event in events {
            for assoc in event.figureAssociations ?? [] {
                guard let figure = assoc.figure else { continue }
                if !event.involvedFigures.contains(where: { $0.persistentModelID == figure.persistentModelID }) {
                    event.involvedFigures.append(figure)
                    changed = true
                }
                if !figure.events.contains(where: { $0.persistentModelID == event.persistentModelID }) {
                    figure.events.append(event)
                    changed = true
                }
            }
        }
        if changed { try? context.save() }
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

}
