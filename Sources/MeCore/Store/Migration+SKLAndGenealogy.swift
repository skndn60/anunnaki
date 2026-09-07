import Foundation
import SwiftData

extension Migration {
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

}
