import Foundation
import SwiftData

package struct VersionManager {

    package static var snapshotsDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("Me", isDirectory: true)
            .appendingPathComponent("Snapshots", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    package static func commit(name: String, branch: String = "main", parentId: String? = nil, context: ModelContext) -> DataVersion? {
        let root = exportToSeedDataRoot(context: context)

        guard let data = try? JSONEncoder().encode(root),
              let jsonString = String(data: data, encoding: .utf8) else {
            assertionFailure("Failed to encode snapshot")
            return nil
        }

        let versionId = UUID().uuidString
        let filename = "\(versionId).json"
        let fileURL = snapshotsDirectory.appendingPathComponent(filename)

        do {
            try jsonString.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            assertionFailure("Failed to write snapshot file: \(error)")
            return nil
        }

        let version = DataVersion(
            id: versionId,
            name: name,
            branch: branch,
            timestamp: Date(),
            filename: filename,
            parentId: parentId
        )
        context.insert(version)
        try? context.save()
        return version
    }

    package static func checkout(version: DataVersion, context: ModelContext) {
        let fileURL = snapshotsDirectory.appendingPathComponent(version.filename)
        guard let data = try? Data(contentsOf: fileURL),
              let root = try? JSONDecoder().decode(SeedDataRoot.self, from: data) else {
            assertionFailure("Failed to load snapshot file: \(fileURL.path)")
            return
        }

        let currentCount = (try? context.fetchCount(FetchDescriptor<Figure>())) ?? 0
        if currentCount > 0 {
            let autoName = "Auto-saved before restore of: \(version.name)"
            commit(name: autoName, branch: version.branch, parentId: version.id, context: context)
        }

        SeedData.clearAll(context: context)
        try? context.save()

        SeedData.importFrom(root: root, context: context)
    }

    package static func log(context: ModelContext) -> [DataVersion] {
        let descriptor = FetchDescriptor<DataVersion>(sortBy: [SortDescriptor(\.timestamp, order: .reverse)])
        return (try? context.fetch(descriptor)) ?? []
    }

    package static func branch(name: String, fromVersion: DataVersion, context: ModelContext) -> DataVersion? {
        let fileURL = snapshotsDirectory.appendingPathComponent(fromVersion.filename)
        guard let data = try? Data(contentsOf: fileURL),
              let root = try? JSONDecoder().decode(SeedDataRoot.self, from: data) else {
            assertionFailure("Failed to load snapshot for branching")
            return nil
        }

        let branchId = UUID().uuidString
        let filename = "\(branchId).json"

        guard let jsonData = try? JSONEncoder().encode(root),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            assertionFailure("Failed to encode branch snapshot")
            return nil
        }

        let destURL = snapshotsDirectory.appendingPathComponent(filename)
        do {
            try jsonString.write(to: destURL, atomically: true, encoding: .utf8)
        } catch {
            assertionFailure("Failed to write branch snapshot: \(error)")
            return nil
        }

        let version = DataVersion(
            id: branchId,
            name: "Branch: \(name)",
            branch: name,
            timestamp: Date(),
            filename: filename,
            parentId: fromVersion.id
        )
        context.insert(version)
        try? context.save()
        return version
    }

    package static func delete(version: DataVersion, context: ModelContext) {
        let fileURL = snapshotsDirectory.appendingPathComponent(version.filename)
        try? FileManager.default.removeItem(at: fileURL)
        context.delete(version)
        try? context.save()
    }

    // MARK: - Export

    private static func exportToSeedDataRoot(context: ModelContext) -> SeedDataRoot {
        var root = SeedDataRoot()

        // Figure Types
        let figureTypes = (try? context.fetch(FetchDescriptor<FigureType>())) ?? []
        for ft in figureTypes {
            let id = ft.persistentModelID.hashValue.description
            root.figureTypes = (root.figureTypes ?? []) + [
                SeedFigureType(id: id, name: ft.name, icon: ft.icon, colorHex: ft.colorHex)
            ]
        }

        // Place Types
        let placeTypes = (try? context.fetch(FetchDescriptor<PlaceType>())) ?? []
        for pt in placeTypes {
            let id = pt.persistentModelID.hashValue.description
            root.placeTypes = (root.placeTypes ?? []) + [
                SeedPlaceType(id: id, name: pt.name, icon: pt.icon, colorHex: pt.colorHex)
            ]
        }

        // Event Types
        let eventTypes = (try? context.fetch(FetchDescriptor<EventType>())) ?? []
        for et in eventTypes {
            let id = et.persistentModelID.hashValue.description
            root.eventTypes = (root.eventTypes ?? []) + [
                SeedEventType(id: id, name: et.name, icon: et.icon, colorHex: et.colorHex)
            ]
        }

        // Eras
        let eras = (try? context.fetch(FetchDescriptor<Era>(sortBy: [SortDescriptor(\.orderIndex)]))) ?? []
        var eraIds: [String: String] = [:]
        for era in eras {
            let id = UUID().uuidString
            eraIds[era.persistentModelID.hashValue.description] = id
            root.eras.append(SeedEra(
                id: id,
                name: era.name,
                orderIndex: era.orderIndex,
                eraDescription: era.eraDescription,
                startDate: SeedDate(startYear: era.startDate.startYear, endYear: era.startDate.endYear, era: era.startDate.era, isApproximate: era.startDate.isApproximate),
                endDate: SeedDate(startYear: era.endDate.startYear, endYear: era.endDate.endYear, era: era.endDate.era, isApproximate: era.endDate.isApproximate)
            ))
        }

        // Figures
        let figures = (try? context.fetch(FetchDescriptor<Figure>(sortBy: [SortDescriptor(\.name)]))) ?? []
        var figureIds: [String: String] = [:]
        for figure in figures {
            let id = UUID().uuidString
            figureIds[figure.persistentModelID.hashValue.description] = id
            root.figures.append(SeedFigure(
                id: id,
                name: figure.name,
                disambiguation: figure.disambiguation ?? "",
                title: figure.title,
                figureType: figure.figureType?.name ?? "",
                gender: figure.gender.rawValue,
                domain: figure.domain,
                figureDescription: figure.figureDescription,
                birthDate: SeedDate(startYear: figure.birthDate.startYear, endYear: figure.birthDate.endYear, era: figure.birthDate.era, isApproximate: figure.birthDate.isApproximate),
                deathDate: SeedDate(startYear: figure.deathDate.startYear, endYear: figure.deathDate.endYear, era: figure.deathDate.era, isApproximate: figure.deathDate.isApproximate),
                source: figure.source
            ))
        }

        // Relationships
        let relationships = (try? context.fetch(FetchDescriptor<Relationship>())) ?? []
        for rel in relationships {
            guard let fromFigure = rel.fromFigure,
                  let toFigure = rel.toFigure,
                  let fromId = figureIds[fromFigure.persistentModelID.hashValue.description],
                  let toId = figureIds[toFigure.persistentModelID.hashValue.description] else { continue }
            root.relationships.append(SeedRelationship(
                fromFigureId: fromId,
                toFigureId: toId,
                relationshipType: rel.relationshipType?.name ?? "",
                source: rel.source
            ))
        }

        // Places
        let places = (try? context.fetch(FetchDescriptor<Place>(sortBy: [SortDescriptor(\.name)]))) ?? []
        var placeIds: [String: String] = [:]
        for place in places {
            let id = UUID().uuidString
            placeIds[place.persistentModelID.hashValue.description] = id
            root.places.append(SeedPlace(
                id: id,
                name: place.name,
                placeType: place.placeType?.name ?? "",
                modernLocation: place.modernLocation,
                placeDescription: place.placeDescription,
                source: place.source,
                latitude: place.latitude,
                longitude: place.longitude
            ))
        }

        // Events
        let events = (try? context.fetch(FetchDescriptor<Event>(sortBy: [SortDescriptor(\.name)]))) ?? []
        var eventIds: [String: String] = [:]
        for event in events {
            let id = UUID().uuidString
            eventIds[event.persistentModelID.hashValue.description] = id
            let involvedFigureIds = event.involvedFigures.compactMap { figureIds[$0.persistentModelID.hashValue.description] }
            root.events.append(SeedEvent(
                id: id,
                name: event.name,
                eventType: event.eventType?.name ?? "",
                eventDescription: event.eventDescription,
                date: SeedDate(startYear: event.date.startYear, endYear: event.date.endYear, era: event.date.era, isApproximate: event.date.isApproximate),
                era: event.era,
                source: event.source,
                involvedFigureIds: involvedFigureIds
            ))
        }

        // Sources
        let sources = (try? context.fetch(FetchDescriptor<Source>(sortBy: [SortDescriptor(\.name)]))) ?? []
        var sourceIds: [String: String] = [:]
        for source in sources {
            let id = UUID().uuidString
            sourceIds[source.persistentModelID.hashValue.description] = id
            root.sources.append(SeedSource(
                id: id,
                name: source.name,
                sourceType: source.sourceType.rawValue,
                author: source.author,
                language: source.language,
                period: source.period,
                sourceDescription: source.sourceDescription,
                publicationInfo: source.publicationInfo,
                url: source.url
            ))
        }

        // Attachments
        let attachments = (try? context.fetch(FetchDescriptor<Attachment>())) ?? []
        for attachment in attachments {
            guard let src = attachment.source,
                  let srcId = sourceIds[src.persistentModelID.hashValue.description] else { continue }
            root.attachments.append(SeedAttachment(
                sourceId: srcId,
                title: attachment.title,
                url: attachment.url,
                attachmentType: attachment.attachmentType.rawValue,
                note: attachment.note
            ))
        }

        // Citations
        let citations = (try? context.fetch(FetchDescriptor<Citation>())) ?? []
        for citation in citations {
            guard let src = citation.source,
                  let srcId = sourceIds[src.persistentModelID.hashValue.description] else { continue }
            root.citations.append(SeedCitation(
                sourceId: srcId,
                location: citation.location,
                entityType: citation.entityType?.rawValue ?? "",
                entityId: citation.linkedEntityName,
                note: citation.note
            ))
        }

        // Alternate Names
        let alternateNames = (try? context.fetch(FetchDescriptor<AlternateName>())) ?? []
        for altName in alternateNames {
            let figId = altName.figure.flatMap { figureIds[$0.persistentModelID.hashValue.description] }
            guard figId != nil || altName.place != nil else { continue }
            root.alternateNames.append(SeedAlternateName(
                figureId: figId,
                placeId: altName.place.flatMap { placeIds[$0.persistentModelID.hashValue.description] },
                name: altName.name,
                tradition: altName.tradition.rawValue,
                nameType: altName.nameType.rawValue,
                note: altName.note
            ))
        }

        // Figure-Place Associations
        let fpa = (try? context.fetch(FetchDescriptor<FigurePlaceAssociation>())) ?? []
        for assoc in fpa {
            guard let figure = assoc.figure, let place = assoc.place,
                  let figId = figureIds[figure.persistentModelID.hashValue.description],
                  let plcId = placeIds[place.persistentModelID.hashValue.description] else { continue }
            root.figurePlaceAssociations = (root.figurePlaceAssociations ?? []) + [
                SeedFigurePlaceAssociation(figureId: figId, placeId: plcId, role: assoc.roleType?.name ?? "", source: assoc.source)
            ]
        }

        // Place-Place Associations
        let ppa = (try? context.fetch(FetchDescriptor<PlacePlaceAssociation>())) ?? []
        for assoc in ppa {
            guard let from = assoc.fromPlace, let to = assoc.toPlace,
                  let fromId = placeIds[from.persistentModelID.hashValue.description],
                  let toId = placeIds[to.persistentModelID.hashValue.description] else { continue }
            root.placePlaceAssociations = (root.placePlaceAssociations ?? []) + [
                SeedPlacePlaceAssociation(fromPlaceId: fromId, toPlaceId: toId, role: assoc.roleType?.name ?? "", source: assoc.source)
            ]
        }

        // Event-Place Associations
        let epa = (try? context.fetch(FetchDescriptor<EventPlaceAssociation>())) ?? []
        for assoc in epa {
            guard let event = assoc.event, let place = assoc.place,
                  let evtId = eventIds[event.persistentModelID.hashValue.description],
                  let plcId = placeIds[place.persistentModelID.hashValue.description] else { continue }
            root.eventPlaceAssociations = (root.eventPlaceAssociations ?? []) + [
                SeedEventPlaceAssociation(eventId: evtId, placeId: plcId, role: assoc.roleType?.name ?? "", source: assoc.source)
            ]
        }

        // Event-Event Associations
        let eea = (try? context.fetch(FetchDescriptor<EventEventAssociation>())) ?? []
        for assoc in eea {
            guard let from = assoc.fromEvent, let to = assoc.toEvent,
                  let fromId = eventIds[from.persistentModelID.hashValue.description],
                  let toId = eventIds[to.persistentModelID.hashValue.description] else { continue }
            root.eventEventAssociations = (root.eventEventAssociations ?? []) + [
                SeedEventEventAssociation(fromEventId: fromId, toEventId: toId, role: assoc.roleType?.name ?? "", source: assoc.source)
            ]
        }

        // Things
        let things = (try? context.fetch(FetchDescriptor<Thing>(sortBy: [SortDescriptor(\.name)]))) ?? []
        var thingIds: [String: String] = [:]
        for thing in things {
            let id = UUID().uuidString
            thingIds[thing.persistentModelID.hashValue.description] = id
            root.things.append(SeedThing(
                id: id,
                name: thing.name,
                thingDescription: thing.thingDescription,
                source: thing.source
            ))
        }

        // Thing-Figure Associations
        let tfa = (try? context.fetch(FetchDescriptor<ThingFigureAssociation>())) ?? []
        for assoc in tfa {
            guard let thing = assoc.thing, let figure = assoc.figure,
                  let thgId = thingIds[thing.persistentModelID.hashValue.description],
                  let figId = figureIds[figure.persistentModelID.hashValue.description] else { continue }
            root.thingFigureAssociations = (root.thingFigureAssociations ?? []) + [
                SeedThingFigureAssociation(thingId: thgId, figureId: figId, role: assoc.roleType?.name ?? "", source: assoc.source)
            ]
        }

        // Thing-Place Associations
        let tpa = (try? context.fetch(FetchDescriptor<ThingPlaceAssociation>())) ?? []
        for assoc in tpa {
            guard let thing = assoc.thing, let place = assoc.place,
                  let thgId = thingIds[thing.persistentModelID.hashValue.description],
                  let plcId = placeIds[place.persistentModelID.hashValue.description] else { continue }
            root.thingPlaceAssociations = (root.thingPlaceAssociations ?? []) + [
                SeedThingPlaceAssociation(thingId: thgId, placeId: plcId, role: assoc.roleType?.name ?? "", source: assoc.source)
            ]
        }

        // Thing-Event Associations
        let tea = (try? context.fetch(FetchDescriptor<ThingEventAssociation>())) ?? []
        for assoc in tea {
            guard let thing = assoc.thing, let event = assoc.event,
                  let thgId = thingIds[thing.persistentModelID.hashValue.description],
                  let evtId = eventIds[event.persistentModelID.hashValue.description] else { continue }
            root.thingEventAssociations = (root.thingEventAssociations ?? []) + [
                SeedThingEventAssociation(thingId: thgId, eventId: evtId, role: assoc.roleType?.name ?? "", source: assoc.source)
            ]
        }

        // Image Assets
        let images = (try? context.fetch(FetchDescriptor<ImageAsset>())) ?? []
        var imageIds: [String: String] = [:]
        for image in images {
            let id = UUID().uuidString
            imageIds[image.persistentModelID.hashValue.description] = id
            let figIds = image.figures.compactMap { figureIds[$0.persistentModelID.hashValue.description] }
            let plcIds = image.places.compactMap { placeIds[$0.persistentModelID.hashValue.description] }
            let evtIds = image.events.compactMap { eventIds[$0.persistentModelID.hashValue.description] }
            let thgIds = image.things.compactMap { thingIds[$0.persistentModelID.hashValue.description] }
            root.imageAssets = (root.imageAssets ?? []) + [
                SeedImageAsset(id: id, filename: image.filename, caption: image.caption, source: image.source, figureIds: figIds, placeIds: plcIds, eventIds: evtIds, thingIds: thgIds)
            ]
        }

        // Tags
        let tags = (try? context.fetch(FetchDescriptor<Tag>())) ?? []
        for tag in tags {
            let figIds = tag.figures.compactMap { figureIds[$0.persistentModelID.hashValue.description] }
            let plcIds = tag.places.compactMap { placeIds[$0.persistentModelID.hashValue.description] }
            let evtIds = tag.events.compactMap { eventIds[$0.persistentModelID.hashValue.description] }
            let imgIds = tag.images.compactMap { imageIds[$0.persistentModelID.hashValue.description] }
            let thgIds = tag.things.compactMap { thingIds[$0.persistentModelID.hashValue.description] }
            root.tags = (root.tags ?? []) + [
                SeedTag(id: UUID().uuidString, name: tag.name, colorHex: tag.colorHex, figureIds: figIds, placeIds: plcIds, eventIds: evtIds, imageIds: imgIds, thingIds: thgIds)
            ]
        }

        return root
    }
}
