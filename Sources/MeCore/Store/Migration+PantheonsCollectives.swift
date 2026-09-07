import Foundation
import SwiftData

extension Migration {
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

    /// Add a "Collectives" sidebar group and seed the human collectives — the peoples and
    /// nations of Mesopotamia (Akkadians, Assyrians, Babylonians, …) — as figures with the
    /// "Human Collective" type, mirroring the existing "Divine Collective" pattern. The
    /// existing divine collectives (Anunnaki, Igigi) are folded into the same group so the
    /// sidebar has one entry for every collective. The "Human/Mixed Collective" types are
    /// created here if absent. Additive + idempotent.
    package static func ensureCollectives(context: ModelContext) {
        let types = (try? context.fetch(FetchDescriptor<FigureType>())) ?? []
        func typeNamed(_ name: String) -> FigureType {
            if let existing = types.first(where: { $0.name == name }) { return existing }
            let created: FigureType
            switch name {
            case "Human Collective": created = FigureType(name: name, icon: "person.3.fill", colorHex: "34C759")
            case "Mixed Collective": created = FigureType(name: name, icon: "person.3", colorHex: "FF9500")
            default: created = FigureType(name: name, icon: "person.3", colorHex: "8E8E93")
            }
            context.insert(created)
            return created
        }
        let humanType = typeNamed("Human Collective")
        let _ = typeNamed("Mixed Collective")

        var top = (try? context.fetch(FetchDescriptor<FigureGroup>()))?.first { $0.name == "Collectives" && $0.parentGroup == nil }
        if top == nil {
            let group = FigureGroup(
                name: "Collectives",
                groupDescription: "Divine, human, and mixed collectives — peoples, tribes, and councils — with their members, events, and places",
                icon: "person.3",
                colorHex: "007AFF",
                orderIndex: 200,
                kind: .standard,
                entityType: .figure,
                sortMode: .ordered
            )
            context.insert(group)
            top = group
        }
        guard let top else { return }

        let allFigures = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        let eras = (try? context.fetch(FetchDescriptor<Era>())) ?? []

        struct CollectiveSeed {
            let name: String
            let title: String
            let typeName: String
            let domain: String
            let eraName: String?
            let description: String
        }

        let seeds: [CollectiveSeed] = [
            CollectiveSeed(
                name: "Sumerians", title: "The People of Sumer", typeName: "Human Collective",
                domain: "Southern Mesopotamia (Sumer)", eraName: "Early Dynastic Period",
                description: "The people of the Sumerian city-states of southern Mesopotamia, speakers of the (isolated) Sumerian language and creators of the first urban civilization: the earliest writing (cuneiform), the first cities (Uruk, Ur, Kish, Lagash), and the earliest dynastic kingship. Active from the fourth millennium BCE through the early second millennium BCE."
            ),
            CollectiveSeed(
                name: "Akkadians", title: "The People of Akkad", typeName: "Human Collective",
                domain: "Central and northern Mesopotamia (Akkad)", eraName: "Dynasty of Akkad",
                description: "The Semitic-speaking people of northern Babylonia who, under Sargon of Akkad (c. 2334–2279 BCE), forged the first empire in history, uniting Sumer and Akkad. Their Akkadian language — with its cuneiform script — became the lingua franca of the ancient Near East for over a millennium."
            ),
            CollectiveSeed(
                name: "Gutians", title: "The Mountain People of the Zagros", typeName: "Human Collective",
                domain: "Zagros mountains (Gutium)", eraName: "Gutian rule",
                description: "Mountain people of the Zagros who, after years of raiding Sumer, ruled Mesopotamia during the 'Gutian rule' (c. 2193–2119 BCE). Mesopotamian tradition blamed them for widespread destruction until Utu-hengal of Uruk expelled them and restored native Sumerian rule."
            ),
            CollectiveSeed(
                name: "Amorites", title: "The Western Semitic Nomads", typeName: "Human Collective",
                domain: "Syrian steppe and Lower Mesopotamia", eraName: nil,
                description: "West Semitic nomadic people from the Syrian steppe who settled across Mesopotamia in the early second millennium BCE. Their dynasties came to dominate the region — the First Dynasty of Babylon, the dynasty of Mari, and the kingdoms of Larsa and Isin."
            ),
            CollectiveSeed(
                name: "Babylonians", title: "The People of Babylon", typeName: "Human Collective",
                domain: "Central Mesopotamia (Babylonia)", eraName: "Old Babylonian Period",
                description: "The people of Babylon, heirs of the Sumero-Akkadian tradition. Under the Old Babylonian dynasty and its most famous king, Hammurabi (c. 1792–1750 BCE), Babylon unified Mesopotamia and produced the celebrated law code that bears his name."
            ),
            CollectiveSeed(
                name: "Assyrians", title: "The People of Assur", typeName: "Human Collective",
                domain: "Northern Mesopotamia (Assyria)", eraName: "Old Assyrian Period",
                description: "The people of the northern Mesopotamian city-state of Assur. In the Old Assyrian period (early second millennium BCE) their merchants ran a wide trading network across Anatolia (the kārum of Kanesh); later their New Kingdom and Neo-Assyrian Empire dominated the entire Near East."
            ),
            CollectiveSeed(
                name: "Elamites", title: "The People of Elam", typeName: "Human Collective",
                domain: "Southwest Iran (Elam, capital Susa)", eraName: nil,
                description: "The people of Elam, the region of southwest Iran centered on Susa. A persistent rival and partner of the Mesopotamian states, they sacked Ur (c. 2004 BCE) and later interacted with Babylonia, Kassite rule, and Assyria."
            ),
            CollectiveSeed(
                name: "Hurrians", title: "The People of Mitanni", typeName: "Human Collective",
                domain: "Northern Mesopotamia and the Upper Tigris–Euphrates", eraName: nil,
                description: "The people of northern Mesopotamia and the foothills of the Taurus–Zagros arc who adopted cuneiform and the cultural forms of the south. Their kingdom of Mitanni was a great power of the mid-second millennium BCE, contending with Egypt and the Hittites."
            ),
            CollectiveSeed(
                name: "Kassites", title: "The Mountain People of Babylonia", typeName: "Human Collective",
                domain: "Zagros mountains and Babylonia", eraName: nil,
                description: "Mountain people from the Zagros who took Babylon (c. 1595 BCE) after the Hittite raid and ruled Babylonia for nearly four centuries. They restored stability, rebuilt the cities, and were thoroughly absorbed into Mesopotamian culture."
            ),
            CollectiveSeed(
                name: "Hittites", title: "The People of Hatti", typeName: "Human Collective",
                domain: "Central Anatolia (Hatti, capital Hattusa)", eraName: nil,
                description: "The Indo-European-speaking people of central Anatolia who, from their capital Hattusa, raided Babylon (c. 1595 BCE) and built a great empire that contended with Egypt (the Battle of Kadesh) and, later, Assyria."
            ),
        ]

        var orderCounter = 0
        for seed in seeds {
            let figure: Figure
            if let existing = allFigures.first(where: { $0.name.lowercased() == seed.name.lowercased() }) {
                figure = existing
            } else {
                let newFigure = Figure(
                    name: seed.name,
                    title: seed.title,
                    figureType: humanType,
                    gender: .unknown,
                    domain: seed.domain,
                    figureDescription: seed.description,
                    birthDate: MythologicalDate.unknown,
                    deathDate: MythologicalDate.unknown,
                    source: "Wikipedia"
                )
                context.insert(newFigure)
                figure = newFigure
            }
            if figure.figureType?.name != seed.typeName {
                figure.figureType = typeNamed(seed.typeName)
            }
            if let eraName = seed.eraName, figure.era == nil {
                figure.era = eras.first { $0.name == eraName }
            }
            if !figure.groupAssociations.contains(where: { $0.group?.persistentModelID == top.persistentModelID }) {
                let assoc = FigureGroupAssociation(figure: figure, orderIndex: orderCounter)
                context.insert(assoc)
                figure.groupAssociations.append(assoc)
                top.figureAssociations.append(assoc)
            }
            orderCounter += 1
        }

        // Fold the existing divine collectives into the group so one sidebar entry holds
        // every collective (divine, human, mixed).
        for divineName in ["Anunnaki", "Igigi"] {
            guard let figure = allFigures.first(where: { $0.name.lowercased() == divineName.lowercased() }) else { continue }
            if !figure.groupAssociations.contains(where: { $0.group?.persistentModelID == top.persistentModelID }) {
                let assoc = FigureGroupAssociation(figure: figure, orderIndex: orderCounter)
                context.insert(assoc)
                figure.groupAssociations.append(assoc)
                top.figureAssociations.append(assoc)
                orderCounter += 1
            }
        }

        try? context.save()
    }

    /// Seed a starter set of key figures for the non-SKL collectives (Babylonians,
    /// Assyrians, Hittites, Elamites, Kassites, Hurrians, Amorites), each linked to its
    /// collective via a "Member of" relationship. Creates the "Member of" relationship
    /// type if absent. Additive + idempotent.
    package static func ensureCollectiveMembers(context: ModelContext) {
        let allFigures = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        let figureByName = Dictionary(allFigures.map { ($0.name.lowercased(), $0) }, uniquingKeysWith: { first, _ in first })
        let types = (try? context.fetch(FetchDescriptor<FigureType>())) ?? []
        let humanType = types.first(where: { $0.name == "Human" })
        let eras = (try? context.fetch(FetchDescriptor<Era>())) ?? []
        let eraByName = Dictionary(eras.map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })

        let relTypes = (try? context.fetch(FetchDescriptor<RelationshipType>())) ?? []
        let memberOfType: RelationshipType
        if let existing = relTypes.first(where: { $0.name == "Member of" }) {
            memberOfType = existing
        } else {
            let created = RelationshipType(name: "Member of", icon: "person.3", colorHex: "007AFF", category: "membership", reverseName: "Contains")
            context.insert(created)
            memberOfType = created
        }

        struct MemberSeed {
            let collective: String
            let name: String
            let title: String
            let domain: String
            let eraName: String?
            let description: String
        }

        let seeds: [MemberSeed] = [
            MemberSeed(collective: "Amorites", name: "Sumu-abum", title: "Founder of the First Dynasty of Babylon", domain: "Babylon", eraName: "Old Babylonian Period",
                description: "Founder of the First Dynasty of Babylon (c. 1894–1881 BCE), establishing the Amorite royal house that would rule Babylon for three centuries."),
            MemberSeed(collective: "Amorites", name: "Sumu-la-El", title: "Second King of the First Dynasty of Babylon", domain: "Babylon, Kish", eraName: "Old Babylonian Period",
                description: "Second king of Babylon (c. 1880–1845 BCE), who conquered Kish and expanded Babylon's territory into northern Babylonia."),
            MemberSeed(collective: "Amorites", name: "Sin-muballit", title: "King of Babylon, Father of Hammurabi", domain: "Babylon", eraName: "Old Babylonian Period",
                description: "King of Babylon (c. 1813–1793 BCE) and father of Hammurabi; extended Babylonian control over the surrounding region."),
            MemberSeed(collective: "Amorites", name: "Rim-Sin", title: "Last King of the Amorite Dynasty of Larsa", domain: "Larsa", eraName: nil,
                description: "Last king of the Amorite dynasty of Larsa (c. 1822–1763 BCE), whose long reign made Larsa dominant in the south until Hammurabi conquered it."),

            MemberSeed(collective: "Babylonians", name: "Samsu-iluna", title: "King of Babylon, Son of Hammurabi", domain: "Babylonia", eraName: "Old Babylonian Period",
                description: "King of Babylon (c. 1749–1712 BCE), son and successor of Hammurabi, who struggled to hold the empire together amid revolts in the south."),
            MemberSeed(collective: "Babylonians", name: "Abi-eshuh", title: "King of Babylon", domain: "Babylonia", eraName: "Old Babylonian Period",
                description: "King of Babylon (c. 1711–1684 BCE), grandson of Hammurabi, who warred with the Sealand dynasty and sought to dam the Tigris against it."),
            MemberSeed(collective: "Babylonians", name: "Ammi-ditana", title: "King of Babylon", domain: "Babylonia", eraName: "Old Babylonian Period",
                description: "King of Babylon (c. 1683–1647 BCE) of the First Dynasty, a period of rebuilding and consolidation before Babylon's eventual eclipse."),
            MemberSeed(collective: "Babylonians", name: "Nabopolassar", title: "Founder of the Neo-Babylonian Empire", domain: "Babylonia", eraName: nil,
                description: "Founder of the Neo-Babylonian (Chaldean) Empire (626–605 BCE), who destroyed the Assyrian capital Nineveh with the Medes in 612 BCE."),
            MemberSeed(collective: "Babylonians", name: "Nebuchadnezzar II", title: "Builder King of Babylon", domain: "Babylonia", eraName: nil,
                description: "Neo-Babylonian king (c. 605–562 BCE), conqueror of Jerusalem (587 BCE) and builder of Babylon's great walls, gates, and the famed Hanging Gardens."),

            MemberSeed(collective: "Assyrians", name: "Shamshi-Adad I", title: "Founder of the Old Assyrian Kingdom", domain: "Assur, Ekallatum, Upper Mesopotamia", eraName: "Old Assyrian Period",
                description: "Amorite conqueror who made Assur the capital of a large Upper Mesopotamian kingdom (c. 1808–1776 BCE), rivalling Babylon and Mari."),
            MemberSeed(collective: "Assyrians", name: "Shalmaneser III", title: "Neo-Assyrian King", domain: "Assyria", eraName: "Neo-Assyrian Period",
                description: "Neo-Assyrian king (859–824 BCE) who fought a coalition of western states at Qarqar (853 BCE) and repeatedly campaigned to the Mediterranean."),
            MemberSeed(collective: "Assyrians", name: "Tiglath-Pileser III", title: "Empire Builder of the Neo-Assyrian Period", domain: "Assyria", eraName: "Neo-Assyrian Period",
                description: "Neo-Assyrian king (745–727 BCE) who transformed the empire with efficient provincial administration and aggressive conquest across the Near East."),
            MemberSeed(collective: "Assyrians", name: "Sennacherib", title: "King of Assyria, Builder of Nineveh", domain: "Assyria, Nineveh", eraName: "Neo-Assyrian Period",
                description: "Neo-Assyrian king (705–681 BCE) who made Nineveh his capital, besieged Jerusalem in 701 BCE, and destroyed Babylon."),
            MemberSeed(collective: "Assyrians", name: "Esarhaddon", title: "King of Assyria", domain: "Assyria", eraName: "Neo-Assyrian Period",
                description: "Neo-Assyrian king (681–669 BCE) who rebuilt Babylon and conquered Egypt in 671 BCE, the empire's greatest territorial extent."),
            MemberSeed(collective: "Assyrians", name: "Ashurbanipal", title: "King of Assyria, Patron of the Library at Nineveh", domain: "Assyria, Nineveh", eraName: "Neo-Assyrian Period",
                description: "Last great king of Assyria (669–631 BCE), renowned for the great cuneiform library assembled at Nineveh."),

            MemberSeed(collective: "Hittites", name: "Hattusili I", title: "Founder of the Hittite Old Kingdom", domain: "Anatolia, Hattusa", eraName: nil,
                description: "Hittite king (c. 1650–1620 BCE) who consolidated the Old Kingdom and made Hattusa its capital."),
            MemberSeed(collective: "Hittites", name: "Mursili I", title: "Sacker of Babylon", domain: "Anatolia, Hattusa", eraName: nil,
                description: "Hittite king (c. 1620–1595 BCE) who raided deep into Mesopotamia and sacked Babylon in c. 1595 BCE, ending the First Dynasty of Babylon."),
            MemberSeed(collective: "Hittites", name: "Suppiluliuma I", title: "Founder of the Hittite New Kingdom", domain: "Anatolia, Syria", eraName: nil,
                description: "Great Hittite king (c. 1344–1322 BCE) who defeated Mitanni, extended Hittite power over Syria, and dealt with Egypt's pharaohs."),
            MemberSeed(collective: "Hittites", name: "Muwatalli II", title: "Hittite King at the Battle of Kadesh", domain: "Anatolia, Syria", eraName: nil,
                description: "Hittite king (c. 1295–1272 BCE) who fought Ramesses II at the Battle of Kadesh (c. 1274 BCE)."),
            MemberSeed(collective: "Hittites", name: "Hattusili III", title: "Signatory of the Kadesh Peace Treaty", domain: "Anatolia", eraName: nil,
                description: "Hittite king (c. 1267–1237 BCE) who concluded the first recorded peace treaty with Egypt after Kadesh."),

            MemberSeed(collective: "Elamites", name: "Puzur-Inshushinak", title: "Last King of the Awan Dynasty of Elam", domain: "Elam, Susa", eraName: nil,
                description: "Powerful Elamite king of Awan (c. 2100 BCE) who conquered much of Mesopotamia in the shadow of the weakening Ur III state."),
            MemberSeed(collective: "Elamites", name: "Kindattu", title: "Elamite King of Shimashki, Sacker of Ur", domain: "Elam", eraName: nil,
                description: "Elamite king of the Shimashki dynasty (c. 2004 BCE) whose forces sacked Ur, ending the Third Dynasty of Ur."),
            MemberSeed(collective: "Elamites", name: "Shutruk-Nahhunte", title: "Elamite King, Conqueror of Babylon", domain: "Elam, Susa", eraName: nil,
                description: "Elamite king (c. 1185–1155 BCE) who sacked Babylon and carried the Code of Hammurabi stele to Susa."),
            MemberSeed(collective: "Elamites", name: "Kutir-Nahhunte", title: "Elamite King, Destroyer of Babylon", domain: "Elam", eraName: nil,
                description: "Son of Shutruk-Nahhunte who completed the destruction of Babylon in c. 1155 BCE and took its statues to Elam."),
            MemberSeed(collective: "Elamites", name: "Untash-Napirisha", title: "Builder of Chogha Zanbil", domain: "Elam", eraName: nil,
                description: "Elamite king (c. 1340–1300 BCE) who founded the religious complex of Chogha Zanbil with its great ziggurat."),

            MemberSeed(collective: "Kassites", name: "Agum II", title: "Restorer of Marduk's Statue", domain: "Babylonia", eraName: nil,
                description: "Kassite king (c. 1595 BCE) who took Babylon and is credited with returning Marduk's statue from Hani after the Hittite raid."),
            MemberSeed(collective: "Kassites", name: "Karaindash", title: "Kassite King of Babylon", domain: "Babylonia", eraName: nil,
                description: "Kassite king (c. 1415 BCE) who established relations with Egypt and rebuilt temples, including at Uruk."),
            MemberSeed(collective: "Kassites", name: "Kurigalzu I", title: "Founder of Dur-Kurigalzu", domain: "Babylonia", eraName: nil,
                description: "Kassite king (c. 1400 BCE) who built the new capital Dur-Kurigalzu and corresponded with the Amarna pharaohs."),
            MemberSeed(collective: "Kassites", name: "Burnaburiash II", title: "Kassite King, Amarna Correspondent", domain: "Babylonia", eraName: nil,
                description: "Kassite king (c. 1359–1333 BCE) whose letters appear among the Amarna correspondence with Egypt."),
            MemberSeed(collective: "Kassites", name: "Meli-Shipak", title: "Late Kassite King", domain: "Babylonia", eraName: nil,
                description: "Kassite king (c. 1188–1174 BCE) whose land-grant kudurru stones document late Kassite administration."),

            MemberSeed(collective: "Hurrians", name: "Parattarna", title: "Early King of Mitanni", domain: "Mitanni", eraName: nil,
                description: "Early king of Mitanni (c. 1500 BCE) attested in the Alalakh tablets as a powerful over-lord of northern Syria."),
            MemberSeed(collective: "Hurrians", name: "Saushtatar", title: "Great King of Mitanni", domain: "Mitanni", eraName: nil,
                description: "King of Mitanni (c. 1450 BCE) who conquered Assur and made Mitanni the dominant power of the north."),
            MemberSeed(collective: "Hurrians", name: "Artatama I", title: "King of Mitanni", domain: "Mitanni", eraName: nil,
                description: "King of Mitanni (c. 1400 BCE) who corresponded with Egypt during the early Amarna period."),
            MemberSeed(collective: "Hurrians", name: "Tushratta", title: "King of Mitanni in the Amarna Letters", domain: "Mitanni", eraName: nil,
                description: "King of Mitanni (c. 1380–1340 BCE) whose vivid letters to Akhenaten survive among the Amarna correspondence."),
            MemberSeed(collective: "Hurrians", name: "Shattiwaza", title: "Last King of Mitanni", domain: "Mitanni", eraName: nil,
                description: "Last king of Mitanni, a vassal of Assyria after the kingdom's collapse under Shalmaneser I's campaigns."),
        ]

        for seed in seeds {
            let figure: Figure
            if let existing = figureByName[seed.name.lowercased()] {
                figure = existing
            } else {
                let newFigure = Figure(
                    name: seed.name,
                    title: seed.title,
                    figureType: humanType,
                    gender: .unknown,
                    domain: seed.domain,
                    figureDescription: seed.description,
                    birthDate: MythologicalDate.unknown,
                    deathDate: MythologicalDate.unknown,
                    source: "Wikipedia"
                )
                context.insert(newFigure)
                figure = newFigure
            }
            if let eraName = seed.eraName, figure.era == nil {
                figure.era = eraByName[eraName]
            }
            guard let collective = figureByName[seed.collective.lowercased()] else { continue }
            let alreadyLinked = figure.outgoingRelationships.contains {
                $0.toFigure?.persistentModelID == collective.persistentModelID &&
                $0.relationshipType?.persistentModelID == memberOfType.persistentModelID
            }
            if !alreadyLinked {
                context.insert(Relationship(fromFigure: figure, toFigure: collective, relationshipType: memberOfType, source: "Wikipedia"))
            }
        }

        // Link existing figures (SKL kings, Ur III and Isin rulers, Lagash and Uruk
        // city-state rulers, Old Assyrian merchants) to their collectives so the rich
        // existing data connects to the new collectives.
        let existingLinks: [String: [String]] = [
            "Sumerians": ["Ur-Namma", "Shulgi", "Amar-Suena", "Shu-Suen", "Ibbi-Suen", "Gilgamesh", "Enmerkar", "Lugalbanda", "Mesh-ki-ang-gasher", "Eannatum", "Entemena", "Urukagina", "Lugal-zage-si", "Utu-hengal"],
            "Akkadians": ["Sargon of Akkad", "Rimush", "Manishtushu", "Naram-Sin of Akkad", "Shar-Kali-Sharri", "Dudu of Akkad", "Shu-Durul", "Enheduanna"],
            "Gutians": ["Tirigan", "Inkishush", "Elulmesh", "Hadanish", "Sarlagab", "Yarla", "Yarlagab", "Yarlaganda", "Inimabakesh", "Igeshaush"],
            "Amorites": ["Ishbi-Erra", "Shu-Ilishu", "Iddin-Dagan", "Lipit-Ishtar", "Ur-Ninurta", "Enlil-bani", "Zambiya", "Iter-pisha", "Ur-du-kuga", "Suen-magir", "Gimil-Ninurta", "Bazi"],
            "Babylonians": ["Hammurabi", "Nabonidus"],
            "Assyrians": ["Ashurnasirpal II", "Taram-Kubi", "Innaya", "Pushu-ken", "Lamassi", "Imdi-ilum", "Zizizi"],
        ]
        for (collectiveName, memberNames) in existingLinks {
            guard let collective = figureByName[collectiveName.lowercased()] else { continue }
            for memberName in memberNames {
                guard let member = figureByName[memberName.lowercased()] else { continue }
                let alreadyLinked = member.outgoingRelationships.contains {
                    $0.toFigure?.persistentModelID == collective.persistentModelID &&
                    $0.relationshipType?.persistentModelID == memberOfType.persistentModelID
                }
                if !alreadyLinked {
                    context.insert(Relationship(fromFigure: member, toFigure: collective, relationshipType: memberOfType, source: "Wikipedia"))
                }
            }
        }

        try? context.save()
    }

    /// Correctively repair figures that were wrongly typed "Human Collective".
    /// The collective group figures (Sumerians, Assyrians, Babylonians, \u{2026}) should
    /// keep the "Human Collective" type, but individual members of those collectives
    /// (kings like Ashurbanipal, Sennacherib, Hammurabi, \u{2026}) were seeded with that
    /// same type by an earlier version of `ensureCollectiveMembers`. This clears the
    /// type on any "Human Collective" figure that is itself a member of a collective
    /// (i.e. has an outgoing "Member of" relationship), leaving the groups untouched.
    /// Additive + idempotent.
    package static func fixHumanCollectiveMemberTypes(context: ModelContext) {
        let allFigures = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        let humanCollectiveType = allFigures.compactMap { $0.figureType }.first { $0.name == "Human Collective" }
        guard let humanCollectiveType else { return }

        let relTypes = (try? context.fetch(FetchDescriptor<RelationshipType>())) ?? []
        guard let memberOfType = relTypes.first(where: { $0.name == "Member of" }) else { return }

        for figure in allFigures {
            guard figure.figureType?.persistentModelID == humanCollectiveType.persistentModelID else { continue }
            let isMember = figure.outgoingRelationships.contains {
                $0.relationshipType?.persistentModelID == memberOfType.persistentModelID
            }
            if isMember {
                figure.figureType = nil
            }
        }
        try? context.save()
    }

    /// Add cross-cultural alternate names to the collectives (e.g. Akkadians/Akkadeans,
    /// Amorites/Amurru/Martu, Hittites/Hatti/Nesites) so they are findable by any alias.
    /// Additive + idempotent.
    package static func ensureCollectiveAlternateNames(context: ModelContext) {
        let allFigures = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        let figureByName = Dictionary(allFigures.map { ($0.name.lowercased(), $0) }, uniquingKeysWith: { first, _ in first })

        struct AltSeed {
            let figure: String
            let name: String
            let tradition: AlternateName.Tradition
            let nameType: AlternateName.NameType
            let note: String
        }

        let seeds: [AltSeed] = [
            AltSeed(figure: "Sumerians", name: "Black-headed people", tradition: .sumerian, nameType: .translation,
                note: "The Sumerians' own self-designation (sag-giga, 'black-headed people')."),
            AltSeed(figure: "Akkadians", name: "Akkadeans", tradition: .akkadian, nameType: .spelling,
                note: "Variant referring to the city of Akkade (Agade)."),
            AltSeed(figure: "Akkadians", name: "Agadeans", tradition: .akkadian, nameType: .spelling,
                note: "From the city Akkade (Agade)."),
            AltSeed(figure: "Gutians", name: "Guti", tradition: .sumerian, nameType: .spelling,
                note: "Sumerian name for the mountain people."),
            AltSeed(figure: "Gutians", name: "Qutium", tradition: .akkadian, nameType: .spelling,
                note: "Akkadian name for the Gutian land and people."),
            AltSeed(figure: "Amorites", name: "Amurru", tradition: .akkadian, nameType: .spelling,
                note: "Akkadian name; also used of the western region."),
            AltSeed(figure: "Amorites", name: "Martu", tradition: .sumerian, nameType: .spelling,
                note: "Sumerian name for the Amorites."),
            AltSeed(figure: "Amorites", name: "Westerners", tradition: .akkadian, nameType: .translation,
                note: "Literary epithet for the Amorites as a western people."),
            AltSeed(figure: "Babylonians", name: "Chaldeans", tradition: .babylonian, nameType: .translation,
                note: "Late (Neo-Babylonian) name for the Babylonians."),
            AltSeed(figure: "Babylonians", name: "People of Karduniaš", tradition: .babylonian, nameType: .translation,
                note: "Kassite-period name for Babylonia and its people."),
            AltSeed(figure: "Assyrians", name: "Ashurites", tradition: .assyrian, nameType: .spelling,
                note: "From the god and city Ashur."),
            AltSeed(figure: "Assyrians", name: "People of Assur", tradition: .assyrian, nameType: .translation,
                note: "The Assyrians' name for themselves as the city-people of Assur."),
            AltSeed(figure: "Elamites", name: "Elamtu", tradition: .akkadian, nameType: .spelling,
                note: "Akkadian name for the country and its people."),
            AltSeed(figure: "Elamites", name: "Susians", tradition: .greek, nameType: .translation,
                note: "Greek name derived from Susa, the Elamite capital."),
            AltSeed(figure: "Kassites", name: "Kaššû", tradition: .akkadian, nameType: .spelling,
                note: "Akkadian name (Kaššû) for the Kassites."),
            AltSeed(figure: "Kassites", name: "People of Karanduniash", tradition: .babylonian, nameType: .translation,
                note: "From Karanduniash, the Kassite-period name of Babylonia."),
            AltSeed(figure: "Hurrians", name: "Mitannians", tradition: .hurrian, nameType: .spelling,
                note: "People of the Mitanni kingdom."),
            AltSeed(figure: "Hurrians", name: "Hurri", tradition: .hurrian, nameType: .spelling,
                note: "Endonym; the source of 'Hurrian'."),
            AltSeed(figure: "Hurrians", name: "Subarians", tradition: .akkadian, nameType: .translation,
                note: "Old Akkadian term for the northern peoples."),
            AltSeed(figure: "Hittites", name: "Hatti", tradition: .hittite, nameType: .spelling,
                note: "The Hittites called their land Hatti."),
            AltSeed(figure: "Hittites", name: "Nesites", tradition: .hittite, nameType: .spelling,
                note: "From Nesite/Neshili, the name of the Hittite language."),
            AltSeed(figure: "Anunnaki", name: "Anunnaku", tradition: .akkadian, nameType: .spelling,
                note: "Akkadian form of the name."),
            AltSeed(figure: "Igigi", name: "Igigu", tradition: .akkadian, nameType: .spelling,
                note: "Akkadian form of the name."),
        ]

        for seed in seeds {
            guard let figure = figureByName[seed.figure.lowercased()] else { continue }
            if figure.alternateNames.contains(where: { $0.name.lowercased() == seed.name.lowercased() }) { continue }
            context.insert(AlternateName(figure: figure, name: seed.name, tradition: seed.tradition, nameType: seed.nameType, note: seed.note))
        }

        try? context.save()
    }

    /// Link each collective to its homeland, capital, and territory places via new
    /// "Homeland"/"Capital"/"Territory" FigurePlaceRoleTypes. Creates the role types and
    /// any missing key places (Hattusa, Washukanni, Dur-Kurigalzu). Additive + idempotent.
    package static func ensureCollectiveTerritory(context: ModelContext) {
        let roles = (try? context.fetch(FetchDescriptor<FigurePlaceRoleType>())) ?? []
        func roleNamed(_ name: String, _ icon: String, _ colorHex: String, reverseName: String) -> FigurePlaceRoleType {
            if let existing = roles.first(where: { $0.name == name }) { return existing }
            let created = FigurePlaceRoleType(name: name, icon: icon, colorHex: colorHex, reverseName: reverseName)
            context.insert(created)
            return created
        }
        let homeland = roleNamed("Homeland", "house.fill", "AF52DE", reverseName: "Homeland Of")
        let capital = roleNamed("Capital", "crown.fill", "FFCC00", reverseName: "Capital Of")
        let territory = roleNamed("Territory", "map.fill", "34C759", reverseName: "Territory Of")

        let allPlaces = (try? context.fetch(FetchDescriptor<Place>())) ?? []
        var placeByName = Dictionary(allPlaces.map { ($0.name.lowercased(), $0) }, uniquingKeysWith: { first, _ in first })
        let placeTypes = (try? context.fetch(FetchDescriptor<PlaceType>())) ?? []
        let cityType: PlaceType
        if let existing = placeTypes.first(where: { $0.name == "City" }) {
            cityType = existing
        } else {
            let created = PlaceType(name: "City", icon: "building.columns", colorHex: "007AFF")
            context.insert(created)
            cityType = created
        }

        func placeNamed(_ name: String, modernLocation: String, latitude: Double?, longitude: Double?) -> Place {
            if let existing = placeByName[name.lowercased()] { return existing }
            let created = Place(name: name, placeType: cityType, modernLocation: modernLocation, latitude: latitude, longitude: longitude)
            context.insert(created)
            placeByName[name.lowercased()] = created
            return created
        }
        _ = placeNamed("Hattusa", modernLocation: "Boğazkale, central Turkey", latitude: 40.02, longitude: 34.62)
        _ = placeNamed("Washukanni", modernLocation: "Tell Fekheriye (uncertain), northern Syria", latitude: 36.83, longitude: 40.04)
        _ = placeNamed("Dur-Kurigalzu", modernLocation: "Aqar Quf, near Baghdad, Iraq", latitude: 33.28, longitude: 44.19)

        let allFigures = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        let figureByName = Dictionary(allFigures.map { ($0.name.lowercased(), $0) }, uniquingKeysWith: { first, _ in first })

        struct TerritorySeed {
            let collective: String
            let place: String
            let role: FigurePlaceRoleType
        }
        let seeds: [TerritorySeed] = [
            TerritorySeed(collective: "Sumerians", place: "Ur", role: homeland),
            TerritorySeed(collective: "Sumerians", place: "Uruk", role: homeland),
            TerritorySeed(collective: "Sumerians", place: "Eridu", role: homeland),
            TerritorySeed(collective: "Sumerians", place: "Nippur", role: homeland),
            TerritorySeed(collective: "Akkadians", place: "Akkad", role: homeland),
            TerritorySeed(collective: "Akkadians", place: "Akkad", role: capital),
            TerritorySeed(collective: "Gutians", place: "Gutium", role: homeland),
            TerritorySeed(collective: "Amorites", place: "Mari", role: homeland),
            TerritorySeed(collective: "Babylonians", place: "Babylon", role: homeland),
            TerritorySeed(collective: "Babylonians", place: "Babylon", role: capital),
            TerritorySeed(collective: "Assyrians", place: "Assur", role: homeland),
            TerritorySeed(collective: "Assyrians", place: "Assur", role: capital),
            TerritorySeed(collective: "Assyrians", place: "Nineveh", role: capital),
            TerritorySeed(collective: "Elamites", place: "Susa", role: homeland),
            TerritorySeed(collective: "Elamites", place: "Susa", role: capital),
            TerritorySeed(collective: "Kassites", place: "Babylon", role: capital),
            TerritorySeed(collective: "Kassites", place: "Dur-Kurigalzu", role: homeland),
            TerritorySeed(collective: "Kassites", place: "Dur-Kurigalzu", role: capital),
            TerritorySeed(collective: "Hurrians", place: "Washukanni", role: homeland),
            TerritorySeed(collective: "Hurrians", place: "Washukanni", role: capital),
            TerritorySeed(collective: "Hittites", place: "Hattusa", role: homeland),
            TerritorySeed(collective: "Hittites", place: "Hattusa", role: capital),
        ]

        for seed in seeds {
            guard let figure = figureByName[seed.collective.lowercased()],
                  let place = placeByName[seed.place.lowercased()] else { continue }
            let already = figure.placeAssociations.contains {
                $0.place?.persistentModelID == place.persistentModelID &&
                $0.roleType?.persistentModelID == seed.role.persistentModelID
            }
            if !already {
                context.insert(FigurePlaceAssociation(figure: figure, place: place, roleType: seed.role, source: "Wikipedia"))
            }
        }

        try? context.save()
    }

}
