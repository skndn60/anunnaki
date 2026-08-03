import Foundation
import SwiftData

/// One stored "Add from Text" operation. Everything the recognizer created or mutated,
/// so a later revert can undo exactly that without touching unrelated data.
package struct FromTextApplyRecord: Codable, Hashable, Identifiable {
    package var id: UUID
    package var date: Date
    package var subject: String
    package var createdFigureNames: [String]
    package var createdPlaceNames: [String]
    package var createdFigureTypeNames: [String]
    package var createdRelationshipTypeNames: [String]
    package var createdRoleTypeNames: [String]
    package var alternateNames: [String]
    package var relationships: [FromTextRecordedRelationship]
    package var placeLinks: [FromTextRecordedPlaceLink]
    package var figureMutations: [FromTextFigureMutation]
    package var revertedAt: Date?

    package init(
        id: UUID = UUID(),
        date: Date = Date(),
        subject: String,
        createdFigureNames: [String] = [],
        createdPlaceNames: [String] = [],
        createdFigureTypeNames: [String] = [],
        createdRelationshipTypeNames: [String] = [],
        createdRoleTypeNames: [String] = [],
        alternateNames: [String] = [],
        relationships: [FromTextRecordedRelationship] = [],
        placeLinks: [FromTextRecordedPlaceLink] = [],
        figureMutations: [FromTextFigureMutation] = [],
        revertedAt: Date? = nil
    ) {
        self.id = id
        self.date = date
        self.subject = subject
        self.createdFigureNames = createdFigureNames
        self.createdPlaceNames = createdPlaceNames
        self.createdFigureTypeNames = createdFigureTypeNames
        self.createdRelationshipTypeNames = createdRelationshipTypeNames
        self.createdRoleTypeNames = createdRoleTypeNames
        self.alternateNames = alternateNames
        self.relationships = relationships
        self.placeLinks = placeLinks
        self.figureMutations = figureMutations
        self.revertedAt = revertedAt
    }
}

package struct FromTextRecordedRelationship: Codable, Hashable {
    package var fromFigure: String
    package var toFigure: String
    package var relationshipType: String
    package var source: String

    package init(fromFigure: String, toFigure: String, relationshipType: String, source: String) {
        self.fromFigure = fromFigure
        self.toFigure = toFigure
        self.relationshipType = relationshipType
        self.source = source
    }
}

package struct FromTextRecordedPlaceLink: Codable, Hashable {
    package var figure: String
    package var place: String
    package var roleName: String
    package var source: String

    package init(figure: String, place: String, roleName: String, source: String) {
        self.figure = figure
        self.place = place
        self.roleName = roleName
        self.source = source
    }
}

/// Before/after state of a figure that already existed when an add mutated it.
package struct FromTextFigureMutation: Codable, Hashable {
    package var figureName: String
    package var before: FromTextFieldState
    package var after: FromTextFieldState

    package init(figureName: String, before: FromTextFieldState, after: FromTextFieldState) {
        self.figureName = figureName
        self.before = before
        self.after = after
    }
}

package struct FromTextFieldState: Codable, Hashable {
    package var figureTypeName: String?
    package var gender: Figure.Gender
    package var title: String
    package var domain: String
    package var figureDescription: String
    package var birthDate: MythologicalDate
    package var deathDate: MythologicalDate
    package var reignStart: Int?
    package var reignEnd: Int?

    package init(
        figureTypeName: String? = nil,
        gender: Figure.Gender = .unknown,
        title: String = "",
        domain: String = "",
        figureDescription: String = "",
        birthDate: MythologicalDate = .unknown,
        deathDate: MythologicalDate = .unknown,
        reignStart: Int? = nil,
        reignEnd: Int? = nil
    ) {
        self.figureTypeName = figureTypeName
        self.gender = gender
        self.title = title
        self.domain = domain
        self.figureDescription = figureDescription
        self.birthDate = birthDate
        self.deathDate = deathDate
        self.reignStart = reignStart
        self.reignEnd = reignEnd
    }
}

/// Outcome of a revert; used for the confirmation-free result display after reverting.
package struct FromTextRevertReport: Equatable {
    package var deletedFigures: [String] = []
    package var keptFigures: [String] = []
    package var deletedPlaces: [String] = []
    package var keptPlaces: [String] = []
    package var deletedAlternateNames: Int = 0
    package var deletedRelationships: Int = 0
    package var deletedPlaceLinks: Int = 0
    package var restoredMutations: [String] = []
    package var skippedMutations: [String] = []
    package var deletedTypes: [String] = []
    package var keptTypes: [String] = []

    package var summary: String {
        var parts: [String] = []
        if !deletedFigures.isEmpty { parts.append("\(deletedFigures.count) figure(s) removed") }
        if !deletedPlaces.isEmpty { parts.append("\(deletedPlaces.count) place(s) removed") }
        if deletedRelationships > 0 { parts.append("\(deletedRelationships) relationship(s) removed") }
        if deletedPlaceLinks > 0 { parts.append("\(deletedPlaceLinks) place link(s) removed") }
        if deletedAlternateNames > 0 { parts.append("\(deletedAlternateNames) alternate name(s) removed") }
        if !restoredMutations.isEmpty { parts.append("restored \(restoredMutations.count) existing figure(s)") }
        if !keptFigures.isEmpty { parts.append("kept \(keptFigures.count) figure(s) that have other data") }
        if !keptPlaces.isEmpty { parts.append("kept \(keptPlaces.count) place(s) that have other data") }
        if !skippedMutations.isEmpty { parts.append("left \(skippedMutations.count) figure(s) you edited after adding") }
        return parts.isEmpty ? "Nothing was reverted." : parts.joined(separator: "; ")
    }

    package init(
        deletedFigures: [String] = [],
        keptFigures: [String] = [],
        deletedPlaces: [String] = [],
        keptPlaces: [String] = [],
        deletedAlternateNames: Int = 0,
        deletedRelationships: Int = 0,
        deletedPlaceLinks: Int = 0,
        restoredMutations: [String] = [],
        skippedMutations: [String] = [],
        deletedTypes: [String] = [],
        keptTypes: [String] = []
    ) {
        self.deletedFigures = deletedFigures
        self.keptFigures = keptFigures
        self.deletedPlaces = deletedPlaces
        self.keptPlaces = keptPlaces
        self.deletedAlternateNames = deletedAlternateNames
        self.deletedRelationships = deletedRelationships
        self.deletedPlaceLinks = deletedPlaceLinks
        self.restoredMutations = restoredMutations
        self.skippedMutations = skippedMutations
        self.deletedTypes = deletedTypes
        self.keptTypes = keptTypes
    }
}

/// Applies a parsed `FromTextResult` to the store and returns a record of everything it did,
/// so the action can be reverted precisely later.
package enum FromTextRecognizer {

    private static let addSource = "From text"

    @discardableResult
    package static func apply(_ result: FromTextResult, in context: ModelContext) -> FromTextApplyRecord? {
        guard !result.subject.isEmpty else { return nil }

        var record = FromTextApplyRecord(subject: result.subject)
        var createdFigures = Set<String>()
        var createdPlaces = Set<String>()
        var createdFigureTypes = Set<String>()
        var createdRelationshipTypes = Set<String>()
        var createdRoleTypes = Set<String>()

        let (subjectFigure, subjectCreated) = figure(named: result.subject, in: context)
        if subjectCreated { createdFigures.insert(result.subject) }

        if subjectCreated {
            populate(subjectFigure, result, in: context, createdFigureTypes: &createdFigureTypes)
        } else {
            let before = snapshot(subjectFigure)
            populate(subjectFigure, result, in: context, createdFigureTypes: &createdFigureTypes)
            let after = snapshot(subjectFigure)
            if before != after {
                record.figureMutations.append(FromTextFigureMutation(figureName: result.subject, before: before, after: after))
            }
        }

        for link in result.placeLinks {
            let (place, placeCreated) = place(named: link.place, in: context)
            if placeCreated { createdPlaces.insert(link.place) }
            let (role, roleCreated) = roleType(named: link.roleName, in: context)
            if roleCreated { createdRoleTypes.insert(link.roleName) }
            let assoc = FigurePlaceAssociation(figure: subjectFigure, place: place, roleType: role, source: addSource)
            context.insert(assoc)
            subjectFigure.placeAssociations.append(assoc)
            place.figureAssociations.append(assoc)
            record.placeLinks.append(FromTextRecordedPlaceLink(figure: result.subject, place: link.place, roleName: link.roleName, source: addSource))
        }

        let allRels = result.parents + result.otherRelationships
        for rel in allRels {
            let (from, fromCreated) = figure(named: rel.fromFigure, in: context)
            let (to, toCreated) = figure(named: rel.toFigure, in: context)
            if fromCreated { createdFigures.insert(rel.fromFigure) }
            if toCreated { createdFigures.insert(rel.toFigure) }
            let (type, typeCreated) = relationType(named: rel.relationshipType, in: context)
            if typeCreated { createdRelationshipTypes.insert(rel.relationshipType) }
            let relationship = Relationship(fromFigure: from, toFigure: to, relationshipType: type, source: addSource, isPreferred: rel.isPreferred)
            context.insert(relationship)
            from.outgoingRelationships.append(relationship)
            record.relationships.append(FromTextRecordedRelationship(fromFigure: rel.fromFigure, toFigure: rel.toFigure, relationshipType: rel.relationshipType, source: addSource))
        }

        for name in result.alternateNames where !name.isEmpty {
            let alt = AlternateName(figure: subjectFigure, name: name, tradition: .other, nameType: .spelling, note: "")
            context.insert(alt)
            subjectFigure.alternateNames.append(alt)
            record.alternateNames.append(name)
        }

        record.createdFigureNames = createdFigures.sorted()
        record.createdPlaceNames = createdPlaces.sorted()
        record.createdFigureTypeNames = createdFigureTypes.sorted()
        record.createdRelationshipTypeNames = createdRelationshipTypes.sorted()
        record.createdRoleTypeNames = createdRoleTypes.sorted()
        return record
    }

    /// Undo a previously applied add. Only objects created by that add are removed;
    /// created figures/places that have since acquired other data are kept (and reported),
    /// and mutations to pre-existing figures are restored only if the user has not edited
    /// the field since the add.
    package static func revert(_ record: FromTextApplyRecord, in context: ModelContext) -> FromTextRevertReport {
        var report = FromTextRevertReport()

        for rel in record.relationships {
            let matching = allRelationships(in: context).first {
                $0.source == rel.source
                    && $0.fromFigure?.name.caseInsensitiveCompare(rel.fromFigure) == .orderedSame
                    && $0.toFigure?.name.caseInsensitiveCompare(rel.toFigure) == .orderedSame
                    && $0.relationshipType?.name == rel.relationshipType
            }
            if let matching {
                context.delete(matching)
                report.deletedRelationships += 1
            }
        }

        for link in record.placeLinks {
            let matching = allPlaceLinks(in: context).first {
                $0.source == link.source
                    && $0.figure?.name.caseInsensitiveCompare(link.figure) == .orderedSame
                    && $0.place?.name.caseInsensitiveCompare(link.place) == .orderedSame
                    && $0.roleType?.name == link.roleName
            }
            if let matching {
                context.delete(matching)
                report.deletedPlaceLinks += 1
            }
        }

        if let subject = existingFigure(named: record.subject, in: context) {
            for name in record.alternateNames {
                if let alt = subject.alternateNames.first(where: { $0.name == name && $0.note.isEmpty }) {
                    context.delete(alt)
                    report.deletedAlternateNames += 1
                }
            }
        }

        for mutation in record.figureMutations {
            restore(mutation, in: context, report: &report)
        }

        // The orphan checks below must not see objects we just deleted, so flush first.
        try? context.save()

        for name in record.createdFigureNames {
            guard let fig = existingFigure(named: name, in: context) else { continue }
            if isOrphaned(fig) {
                context.delete(fig)
                report.deletedFigures.append(name)
            } else {
                report.keptFigures.append(name)
            }
        }

        for name in record.createdPlaceNames {
            guard let place = existingPlace(named: name, in: context) else { continue }
            if isOrphaned(place) {
                context.delete(place)
                report.deletedPlaces.append(name)
            } else {
                report.keptPlaces.append(name)
            }
        }

        for name in record.createdFigureTypeNames {
            guard let type = existingFigureType(named: name, in: context) else { continue }
            if type.figures.isEmpty {
                context.delete(type)
                report.deletedTypes.append(name)
            } else {
                report.keptTypes.append(name)
            }
        }

        for name in record.createdRelationshipTypeNames {
            guard let type = existingRelationshipType(named: name, in: context) else { continue }
            if type.relationships.isEmpty {
                context.delete(type)
                report.deletedTypes.append(name)
            } else {
                report.keptTypes.append(name)
            }
        }

        for name in record.createdRoleTypeNames {
            guard let type = existingRoleType(named: name, in: context) else { continue }
            if type.associations.isEmpty {
                context.delete(type)
                report.deletedTypes.append(name)
            } else {
                report.keptTypes.append(name)
            }
        }

        return report
    }

    // MARK: - Mutation restore

    private static func restore(_ mutation: FromTextFigureMutation, in context: ModelContext, report: inout FromTextRevertReport) {
        guard let fig = existingFigure(named: mutation.figureName, in: context) else { return }
        var skipped = false

        if fig.gender == mutation.after.gender, fig.gender != mutation.before.gender {
            fig.gender = mutation.before.gender
        } else if fig.gender != mutation.before.gender, fig.gender != mutation.after.gender {
            skipped = true
        }

        if fig.figureType?.name == mutation.after.figureTypeName, fig.figureType?.name != mutation.before.figureTypeName {
            fig.figureType = mutation.before.figureTypeName.flatMap { existingFigureType(named: $0, in: context) }
        } else if fig.figureType?.name != mutation.before.figureTypeName, fig.figureType?.name != mutation.after.figureTypeName {
            skipped = true
        }

        restoreField(fig.title, to: mutation.before.title, on: { fig.title = $0 }) {
            fig.title != mutation.after.title && fig.title != mutation.before.title
        } andIfChanged: { skipped = true }

        restoreField(fig.domain, to: mutation.before.domain, on: { fig.domain = $0 }) {
            fig.domain != mutation.after.domain && fig.domain != mutation.before.domain
        } andIfChanged: { skipped = true }

        restoreField(fig.figureDescription, to: mutation.before.figureDescription, on: { fig.figureDescription = $0 }) {
            fig.figureDescription != mutation.after.figureDescription && fig.figureDescription != mutation.before.figureDescription
        } andIfChanged: { skipped = true }

        restoreField(fig.birthDate, to: mutation.before.birthDate, on: { fig.birthDate = $0 }) {
            fig.birthDate != mutation.after.birthDate && fig.birthDate != mutation.before.birthDate
        } andIfChanged: { skipped = true }

        restoreField(fig.deathDate, to: mutation.before.deathDate, on: { fig.deathDate = $0 }) {
            fig.deathDate != mutation.after.deathDate && fig.deathDate != mutation.before.deathDate
        } andIfChanged: { skipped = true }

        restoreField(fig.reignStartYear, to: mutation.before.reignStart, on: { fig.reignStartYear = $0 }) {
            fig.reignStartYear != mutation.after.reignStart && fig.reignStartYear != mutation.before.reignStart
        } andIfChanged: { skipped = true }

        restoreField(fig.reignEndYear, to: mutation.before.reignEnd, on: { fig.reignEndYear = $0 }) {
            fig.reignEndYear != mutation.after.reignEnd && fig.reignEndYear != mutation.before.reignEnd
        } andIfChanged: { skipped = true }

        if skipped { report.skippedMutations.append(mutation.figureName) }
        else { report.restoredMutations.append(mutation.figureName) }
    }

    private static func restoreField<Value: Equatable>(_ current: Value, to before: Value, on apply: (Value) -> Void, changed: () -> Bool, andIfChanged markSkipped: () -> Void) {
        if changed() {
            markSkipped()
        } else if current != before {
            apply(before)
        }
    }

    // MARK: - Orphan checks

    private static func isOrphaned(_ fig: Figure) -> Bool {
        fig.outgoingRelationships.isEmpty
            && fig.incomingRelationships.isEmpty
            && fig.placeAssociations.isEmpty
            && fig.alternateNames.isEmpty
            && fig.thingAssociations.isEmpty
            && fig.stickies.isEmpty
            && fig.groupAssociations.isEmpty
            && fig.images.isEmpty
            && fig.tags.isEmpty
            && fig.events.isEmpty
            && (fig.contentAttributions?.isEmpty ?? true)
    }

    private static func isOrphaned(_ place: Place) -> Bool {
        place.figureAssociations.isEmpty
            && place.eventAssociations.isEmpty
            && place.thingAssociations.isEmpty
            && place.groupAssociations.isEmpty
            && place.alternateNames.isEmpty
            && place.stickies.isEmpty
            && place.images.isEmpty
            && place.tags.isEmpty
            && (place.contentAttributions?.isEmpty ?? true)
    }

    // MARK: - Field snapshot

    private static func snapshot(_ figure: Figure) -> FromTextFieldState {
        FromTextFieldState(
            figureTypeName: figure.figureType?.name,
            gender: figure.gender,
            title: figure.title,
            domain: figure.domain,
            figureDescription: figure.figureDescription,
            birthDate: figure.birthDate,
            deathDate: figure.deathDate,
            reignStart: figure.reignStartYear,
            reignEnd: figure.reignEndYear
        )
    }

    // MARK: - Create-or-resolve

    private static func figure(named name: String, in context: ModelContext) -> (Figure, created: Bool) {
        guard !name.isEmpty else { return (Figure(name: name), true) }
        let all: [Figure] = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        if let existing = all.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) { return (existing, false) }
        let figure = Figure(name: name)
        context.insert(figure)
        return (figure, true)
    }

    private static func place(named name: String, in context: ModelContext) -> (Place, created: Bool) {
        guard !name.isEmpty else { return (Place(name: name), true) }
        let all: [Place] = (try? context.fetch(FetchDescriptor<Place>())) ?? []
        if let existing = all.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) { return (existing, false) }
        let place = Place(name: name)
        context.insert(place)
        return (place, true)
    }

    private static func figureType(named name: String, in context: ModelContext) -> (FigureType, created: Bool) {
        let all: [FigureType] = (try? context.fetch(FetchDescriptor<FigureType>())) ?? []
        if let existing = all.first(where: { $0.name == name }) { return (existing, false) }
        let type = FigureType(name: name, icon: "person.fill", colorHex: "007AFF")
        context.insert(type)
        return (type, true)
    }

    private static func relationType(named name: String, in context: ModelContext) -> (RelationshipType, created: Bool) {
        let all: [RelationshipType] = (try? context.fetch(FetchDescriptor<RelationshipType>())) ?? []
        if let existing = all.first(where: { $0.name == name }) { return (existing, false) }
        let type = RelationshipType(name: name, icon: "link", colorHex: "007AFF", category: "family")
        context.insert(type)
        return (type, true)
    }

    private static func roleType(named name: String, in context: ModelContext) -> (FigurePlaceRoleType, created: Bool) {
        let all: [FigurePlaceRoleType] = (try? context.fetch(FetchDescriptor<FigurePlaceRoleType>())) ?? []
        if let existing = all.first(where: { $0.name == name }) { return (existing, false) }
        let type = FigurePlaceRoleType(name: name, icon: "star.fill", colorHex: "FF9500")
        context.insert(type)
        return (type, true)
    }

    // MARK: - Lookup-only (for revert)

    private static func existingFigure(named name: String, in context: ModelContext) -> Figure? {
        let all: [Figure] = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        return all.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame })
    }

    private static func existingPlace(named name: String, in context: ModelContext) -> Place? {
        let all: [Place] = (try? context.fetch(FetchDescriptor<Place>())) ?? []
        return all.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame })
    }

    private static func existingFigureType(named name: String, in context: ModelContext) -> FigureType? {
        let all: [FigureType] = (try? context.fetch(FetchDescriptor<FigureType>())) ?? []
        return all.first(where: { $0.name == name })
    }

    private static func existingRelationshipType(named name: String, in context: ModelContext) -> RelationshipType? {
        let all: [RelationshipType] = (try? context.fetch(FetchDescriptor<RelationshipType>())) ?? []
        return all.first(where: { $0.name == name })
    }

    private static func existingRoleType(named name: String, in context: ModelContext) -> FigurePlaceRoleType? {
        let all: [FigurePlaceRoleType] = (try? context.fetch(FetchDescriptor<FigurePlaceRoleType>())) ?? []
        return all.first(where: { $0.name == name })
    }

    private static func allRelationships(in context: ModelContext) -> [Relationship] {
        (try? context.fetch(FetchDescriptor<Relationship>())) ?? []
    }

    private static func allPlaceLinks(in context: ModelContext) -> [FigurePlaceAssociation] {
        (try? context.fetch(FetchDescriptor<FigurePlaceAssociation>())) ?? []
    }

    private static func populate(_ figure: Figure, _ result: FromTextResult, in context: ModelContext, createdFigureTypes: inout Set<String>) {
        if result.figureKind != .unknown, let name = result.figureKind.figureTypeName {
            let (type, created) = figureType(named: name, in: context)
            if created { createdFigureTypes.insert(name) }
            figure.figureType = type
        }
        switch result.gender {
        case .male: figure.gender = .male
        case .female: figure.gender = .female
        case .unknown: break
        }
        if let title = result.title { figure.title = title.capitalized }
        if let domain = result.domain { figure.domain = domain }
        if !result.description.isEmpty, figure.figureDescription.isEmpty {
            figure.figureDescription = result.description
        }
        if let by = result.birthYear {
            figure.birthDate = MythologicalDate(year: by, isApproximate: true)
        }
        if let dy = result.deathYear {
            figure.deathDate = MythologicalDate(year: dy, isApproximate: true)
        }
        if let rs = result.reignStart { figure.reignStartYear = rs }
        if let re = result.reignEnd { figure.reignEndYear = re }
    }
}
