import SwiftUI
import SwiftData

/// Overview of all associations defined in the system, with add/delete.
struct AssociationsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var figurePlaceAssocs: [FigurePlaceAssociation]
    @Query private var placePlaceAssocs: [PlacePlaceAssociation]
    @Query private var eventEventAssocs: [EventEventAssociation]
    @Query private var eventPlaceAssocs: [EventPlaceAssociation]
    @Query private var relationships: [Relationship]

    @State private var selectedTab = 0
    @State private var showingAddFigurePlace = false
    @State private var showingAddPlacePlace = false
    @State private var showingAddEventEvent = false
    @State private var showingAddEventPlace = false
    @State private var showingAddRelationship = false
    @State private var editingFigurePlaceAssoc: FigurePlaceAssociation?
    @State private var editingPlacePlaceAssoc: PlacePlaceAssociation?
    @State private var editingEventEventAssoc: EventEventAssociation?
    @State private var editingEventPlaceAssoc: EventPlaceAssociation?
    @State private var editingRelationship: Relationship?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Associations")
                    .font(.title2.bold())
                Spacer()
                HStack(spacing: 16) {
                    countBadge("Figure↔Figure", relationships.count, .blue)
                    countBadge("Figure↔Place", figurePlaceAssocs.count, .teal)
                    countBadge("Place↔Place", placePlaceAssocs.count, .green)
                    countBadge("Event↔Place", eventPlaceAssocs.count, .indigo)
                    countBadge("Event↔Event", eventEventAssocs.count, .orange)
                }
            }
            .padding()

            HStack {
                Picker("", selection: $selectedTab) {
                    Text("Figure ↔ Figure (\(relationships.count))").tag(0)
                    Text("Figure ↔ Place (\(figurePlaceAssocs.count))").tag(1)
                    Text("Place ↔ Place (\(placePlaceAssocs.count))").tag(2)
                    Text("Event ↔ Place (\(eventPlaceAssocs.count))").tag(3)
                    Text("Event ↔ Event (\(eventEventAssocs.count))").tag(4)
                }
                .pickerStyle(.segmented)

                Button(action: { addForCurrentTab() }) {
                    Label("Add", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)

            Divider()

            switch selectedTab {
            case 0: figureRelationshipsList
            case 1: figurePlaceList
            case 2: placePlaceList
            case 3: eventPlaceList
            case 4: eventEventList
            default: EmptyView()
            }
        }
        .sheet(isPresented: $showingAddFigurePlace) {
            AddFigurePlaceAssociationForm()
        }
        .sheet(isPresented: $showingAddPlacePlace) {
            AddPlacePlaceAssociationForm()
        }
        .sheet(isPresented: $showingAddEventPlace) {
            AddEventPlaceAssociationForm()
        }
        .sheet(isPresented: $showingAddEventEvent) {
            AddEventEventAssociationForm()
        }
        .sheet(isPresented: $showingAddRelationship) {
            RelationshipFormView()
        }
        .sheet(item: $editingFigurePlaceAssoc) { assoc in
            EditFigurePlaceAssociationForm(assoc: assoc)
        }
        .sheet(item: $editingPlacePlaceAssoc) { assoc in
            EditPlacePlaceAssociationForm(assoc: assoc)
        }
        .sheet(item: $editingEventEventAssoc) { assoc in
            EditEventEventAssociationForm(assoc: assoc)
        }
        .sheet(item: $editingEventPlaceAssoc) { assoc in
            EditEventPlaceAssociationForm(assoc: assoc)
        }
        .sheet(item: $editingRelationship) { rel in
            EditRelationshipForm(relationship: rel)
        }
    }

    private func addForCurrentTab() {
        switch selectedTab {
        case 0: showingAddRelationship = true
        case 1: showingAddFigurePlace = true
        case 2: showingAddPlacePlace = true
        case 3: showingAddEventPlace = true
        case 4: showingAddEventEvent = true
        default: break
        }
    }

    // MARK: - Figure ↔ Figure

    private var figureRelationshipsList: some View {
        Group {
            if relationships.isEmpty {
                emptyState("No figure relationships", "Add family connections between figures.")
            } else {
                List(relationships) { rel in
                    HStack(spacing: 10) {
                        Text(rel.fromFigure?.name ?? "?").fontWeight(.medium)
                        Image(systemName: rel.relationshipType.icon).font(.caption).foregroundStyle(rel.relationshipType.color)
                        Text(rel.relationshipType.rawValue).font(.caption).padding(.horizontal, 5).padding(.vertical, 2)
                            .background(RoundedRectangle(cornerRadius: 3).fill(rel.relationshipType.color.opacity(0.12)))
                        Image(systemName: "arrow.right").font(.caption2).foregroundStyle(.tertiary)
                        Text(rel.toFigure?.name ?? "?").fontWeight(.medium)
                        Spacer()
                        Text(rel.source).font(.caption2).foregroundStyle(.tertiary).lineLimit(1)
                        Button(action: { editingRelationship = rel }) {
                            Image(systemName: "pencil.circle.fill").font(.body).foregroundStyle(Color.accentColor)
                        }.buttonStyle(.plain)
                        Button(action: { modelContext.delete(rel) }) {
                            Image(systemName: "trash.circle.fill").font(.body).foregroundStyle(.red.opacity(0.7))
                        }.buttonStyle(.plain)
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }
        }
    }

    // MARK: - Figure ↔ Place

    private var figurePlaceList: some View {
        Group {
            if figurePlaceAssocs.isEmpty {
                emptyState("No figure-place associations", "Add patron deity, ruler, or other connections.")
            } else {
                List(figurePlaceAssocs) { assoc in
                    HStack(spacing: 10) {
                        Circle().fill(assoc.figure?.figureType?.color ?? .gray).frame(width: 8, height: 8)
                        Text(assoc.figure?.name ?? "?").fontWeight(.medium)
                        Text(assoc.role.rawValue).font(.caption).padding(.horizontal, 5).padding(.vertical, 2)
                            .background(RoundedRectangle(cornerRadius: 3).fill(Color.teal.opacity(0.12)))
                        Image(systemName: "arrow.right").font(.caption2).foregroundStyle(.tertiary)
                        Image(systemName: assoc.place?.placeType?.icon ?? "mappin").font(.caption).foregroundStyle(.teal)
                        Text(assoc.place?.name ?? "?").fontWeight(.medium)
                        Spacer()
                        Text(assoc.source).font(.caption2).foregroundStyle(.tertiary).lineLimit(1)
                        Button(action: { editingFigurePlaceAssoc = assoc }) {
                            Image(systemName: "pencil.circle.fill").font(.body).foregroundStyle(Color.accentColor)
                        }.buttonStyle(.plain)
                        Button(action: { modelContext.delete(assoc) }) {
                            Image(systemName: "trash.circle.fill").font(.body).foregroundStyle(.red.opacity(0.7))
                        }.buttonStyle(.plain)
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }
        }
    }

    // MARK: - Place ↔ Place

    private var placePlaceList: some View {
        Group {
            if placePlaceAssocs.isEmpty {
                emptyState("No place-place associations", "Add containment or proximity relationships.")
            } else {
                List(placePlaceAssocs) { assoc in
                    HStack(spacing: 10) {
                        Image(systemName: assoc.fromPlace?.placeType?.icon ?? "mappin").font(.caption).foregroundStyle(.teal)
                        Text(assoc.fromPlace?.name ?? "?").fontWeight(.medium)
                        Text(assoc.role.rawValue).font(.caption).padding(.horizontal, 5).padding(.vertical, 2)
                            .background(RoundedRectangle(cornerRadius: 3).fill(Color.green.opacity(0.12)))
                        Image(systemName: "arrow.right").font(.caption2).foregroundStyle(.tertiary)
                        Image(systemName: assoc.toPlace?.placeType?.icon ?? "mappin").font(.caption).foregroundStyle(.teal)
                        Text(assoc.toPlace?.name ?? "?").fontWeight(.medium)
                        Spacer()
                        Text(assoc.source).font(.caption2).foregroundStyle(.tertiary).lineLimit(1)
                        Button(action: { editingPlacePlaceAssoc = assoc }) {
                            Image(systemName: "pencil.circle.fill").font(.body).foregroundStyle(Color.accentColor)
                        }.buttonStyle(.plain)
                        Button(action: { modelContext.delete(assoc) }) {
                            Image(systemName: "trash.circle.fill").font(.body).foregroundStyle(.red.opacity(0.7))
                        }.buttonStyle(.plain)
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }
        }
    }

    // MARK: - Event ↔ Place

    private var eventPlaceList: some View {
        Group {
            if eventPlaceAssocs.isEmpty {
                emptyState("No event-place associations", "Add location associations to events.")
            } else {
                List(eventPlaceAssocs) { assoc in
                    HStack(spacing: 10) {
                        Image(systemName: assoc.event?.eventType?.icon ?? "bolt").font(.caption).foregroundStyle(assoc.event?.eventType?.color ?? .gray)
                        Text(assoc.event?.name ?? "?").fontWeight(.medium)
                        Text(assoc.role.rawValue).font(.caption).padding(.horizontal, 5).padding(.vertical, 2)
                            .background(RoundedRectangle(cornerRadius: 3).fill(Color.indigo.opacity(0.12)))
                        Image(systemName: "arrow.right").font(.caption2).foregroundStyle(.tertiary)
                        Image(systemName: assoc.place?.placeType?.icon ?? "mappin").font(.caption).foregroundStyle(.teal)
                        Text(assoc.place?.name ?? "?").fontWeight(.medium)
                        Spacer()
                        Text(assoc.source).font(.caption2).foregroundStyle(.tertiary).lineLimit(1)
                        Button(action: { editingEventPlaceAssoc = assoc }) {
                            Image(systemName: "pencil.circle.fill").font(.body).foregroundStyle(Color.accentColor)
                        }.buttonStyle(.plain)
                        Button(action: { modelContext.delete(assoc) }) {
                            Image(systemName: "trash.circle.fill").font(.body).foregroundStyle(.red.opacity(0.7))
                        }.buttonStyle(.plain)
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }
        }
    }

    // MARK: - Event ↔ Event

    private var eventEventList: some View {
        Group {
            if eventEventAssocs.isEmpty {
                emptyState("No event-event associations", "Add causal or sequential links between events.")
            } else {
                List(eventEventAssocs) { assoc in
                    HStack(spacing: 10) {
                        Image(systemName: assoc.fromEvent?.eventType?.icon ?? "bolt").font(.caption).foregroundStyle(assoc.fromEvent?.eventType?.color ?? .gray)
                        Text(assoc.fromEvent?.name ?? "?").fontWeight(.medium)
                        Text(assoc.role.rawValue).font(.caption).padding(.horizontal, 5).padding(.vertical, 2)
                            .background(RoundedRectangle(cornerRadius: 3).fill(Color.orange.opacity(0.12)))
                        Image(systemName: "arrow.right").font(.caption2).foregroundStyle(.tertiary)
                        Image(systemName: assoc.toEvent?.eventType?.icon ?? "bolt").font(.caption).foregroundStyle(assoc.toEvent?.eventType?.color ?? .gray)
                        Text(assoc.toEvent?.name ?? "?").fontWeight(.medium)
                        Spacer()
                        Text(assoc.source).font(.caption2).foregroundStyle(.tertiary).lineLimit(1)
                        Button(action: { editingEventEventAssoc = assoc }) {
                            Image(systemName: "pencil.circle.fill").font(.body).foregroundStyle(Color.accentColor)
                        }.buttonStyle(.plain)
                        Button(action: { modelContext.delete(assoc) }) {
                            Image(systemName: "trash.circle.fill").font(.body).foregroundStyle(.red.opacity(0.7))
                        }.buttonStyle(.plain)
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }
        }
    }

    // MARK: - Helpers

    private func countBadge(_ label: String, _ count: Int, _ color: Color) -> some View {
        HStack(spacing: 4) {
            Text("\(count)").font(.caption).fontWeight(.semibold).foregroundStyle(color)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
    }

    private func emptyState(_ title: String, _ subtitle: String) -> some View {
        VStack(spacing: 8) {
            Spacer()
            Text(title).font(.callout).foregroundStyle(.secondary)
            Text(subtitle).font(.caption).foregroundStyle(.tertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Add Forms

struct AddFigurePlaceAssociationForm: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss
    @Query private var figures: [Figure]
    @Query private var places: [Place]

    @State private var selectedFigure: Figure?
    @State private var selectedPlace: Place?
    @State private var role: FigurePlaceAssociation.Role = .patronDeity
    @State private var source = ""

    var body: some View {
        VStack(spacing: 0) {
            Text("Add Figure ↔ Place Association")
                .font(.title3.bold())
                .padding()
            Form {
                Picker("Figure", selection: $selectedFigure) {
                    Text("Select").tag(nil as Figure?)
                    ForEach(figures) { f in Text("\(f.gender.symbol) \(f.name)").tag(f as Figure?) }
                }
                Picker("Role", selection: $role) {
                    ForEach(FigurePlaceAssociation.Role.allCases, id: \.self) { r in Text(r.rawValue).tag(r) }
                }
                Picker("Place", selection: $selectedPlace) {
                    Text("Select").tag(nil as Place?)
                    ForEach(places) { p in Text(p.name).tag(p as Place?) }
                }
                TextField("Source", text: $source)
            }
            .formStyle(.grouped)
            .padding(.horizontal)
            HStack {
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("Add") { save() }.keyboardShortcut(.defaultAction).disabled(selectedFigure == nil || selectedPlace == nil)
            }.padding()
        }
        .frame(width: 450, height: 340)
    }

    private func save() {
        let assoc = FigurePlaceAssociation(figure: selectedFigure, place: selectedPlace, role: role, source: source)
        modelContext.insert(assoc)
        dismiss()
    }
}

struct AddPlacePlaceAssociationForm: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss
    @Query private var places: [Place]

    @State private var fromPlace: Place?
    @State private var toPlace: Place?
    @State private var role: PlacePlaceAssociation.Role = .locatedWithin
    @State private var source = ""

    var body: some View {
        VStack(spacing: 0) {
            Text("Add Place ↔ Place Association")
                .font(.title3.bold())
                .padding()
            Form {
                Picker("From Place", selection: $fromPlace) {
                    Text("Select").tag(nil as Place?)
                    ForEach(places) { p in Text(p.name).tag(p as Place?) }
                }
                Picker("Role", selection: $role) {
                    ForEach(PlacePlaceAssociation.Role.allCases, id: \.self) { r in Text(r.rawValue).tag(r) }
                }
                Picker("To Place", selection: $toPlace) {
                    Text("Select").tag(nil as Place?)
                    ForEach(places) { p in Text(p.name).tag(p as Place?) }
                }
                TextField("Source", text: $source)
            }
            .formStyle(.grouped)
            .padding(.horizontal)
            HStack {
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("Add") { save() }.keyboardShortcut(.defaultAction).disabled(fromPlace == nil || toPlace == nil)
            }.padding()
        }
        .frame(width: 450, height: 340)
    }

    private func save() {
        let assoc = PlacePlaceAssociation(fromPlace: fromPlace, toPlace: toPlace, role: role, source: source)
        modelContext.insert(assoc)
        dismiss()
    }
}

struct AddEventEventAssociationForm: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss
    @Query private var events: [Event]

    @State private var fromEvent: Event?
    @State private var toEvent: Event?
    @State private var role: EventEventAssociation.Role = .caused
    @State private var source = ""

    var body: some View {
        VStack(spacing: 0) {
            Text("Add Event ↔ Event Association")
                .font(.title3.bold())
                .padding()
            Form {
                Picker("From Event", selection: $fromEvent) {
                    Text("Select").tag(nil as Event?)
                    ForEach(events) { e in Text(e.name).tag(e as Event?) }
                }
                Picker("Role", selection: $role) {
                    ForEach(EventEventAssociation.Role.allCases, id: \.self) { r in Text(r.rawValue).tag(r) }
                }
                Picker("To Event", selection: $toEvent) {
                    Text("Select").tag(nil as Event?)
                    ForEach(events) { e in Text(e.name).tag(e as Event?) }
                }
                TextField("Source", text: $source)
            }
            .formStyle(.grouped)
            .padding(.horizontal)
            HStack {
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("Add") { save() }.keyboardShortcut(.defaultAction).disabled(fromEvent == nil || toEvent == nil)
            }.padding()
        }
        .frame(width: 450, height: 340)
    }

    private func save() {
        let assoc = EventEventAssociation(fromEvent: fromEvent, toEvent: toEvent, role: role, source: source)
        modelContext.insert(assoc)
        dismiss()
    }
}


// MARK: - Edit Forms

struct EditFigurePlaceAssociationForm: View {
    @Environment(\.dismiss) var dismiss
    @Query private var figures: [Figure]
    @Query private var places: [Place]
    let assoc: FigurePlaceAssociation

    @State private var selectedFigure: Figure?
    @State private var selectedPlace: Place?
    @State private var role: FigurePlaceAssociation.Role = .patronDeity
    @State private var source = ""

    var body: some View {
        VStack(spacing: 0) {
            Text("Edit Figure ↔ Place Association")
                .font(.title3.bold())
                .padding()
            Form {
                Picker("Figure", selection: $selectedFigure) {
                    Text("Select").tag(nil as Figure?)
                    ForEach(figures) { f in Text("\(f.gender.symbol) \(f.name)").tag(f as Figure?) }
                }
                Picker("Role", selection: $role) {
                    ForEach(FigurePlaceAssociation.Role.allCases, id: \.self) { r in Text(r.rawValue).tag(r) }
                }
                Picker("Place", selection: $selectedPlace) {
                    Text("Select").tag(nil as Place?)
                    ForEach(places) { p in Text(p.name).tag(p as Place?) }
                }
                TextField("Source", text: $source)
            }
            .formStyle(.grouped)
            .padding(.horizontal)
            HStack {
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("Save") { save() }.keyboardShortcut(.defaultAction)
            }.padding()
        }
        .frame(width: 450, height: 340)
        .onAppear {
            selectedFigure = assoc.figure
            selectedPlace = assoc.place
            role = assoc.role
            source = assoc.source
        }
    }

    private func save() {
        assoc.figure = selectedFigure
        assoc.place = selectedPlace
        assoc.role = role
        assoc.source = source
        dismiss()
    }
}

struct EditPlacePlaceAssociationForm: View {
    @Environment(\.dismiss) var dismiss
    @Query private var places: [Place]
    let assoc: PlacePlaceAssociation

    @State private var fromPlace: Place?
    @State private var toPlace: Place?
    @State private var role: PlacePlaceAssociation.Role = .locatedWithin
    @State private var source = ""

    var body: some View {
        VStack(spacing: 0) {
            Text("Edit Place ↔ Place Association")
                .font(.title3.bold())
                .padding()
            Form {
                Picker("From Place", selection: $fromPlace) {
                    Text("Select").tag(nil as Place?)
                    ForEach(places) { p in Text(p.name).tag(p as Place?) }
                }
                Picker("Role", selection: $role) {
                    ForEach(PlacePlaceAssociation.Role.allCases, id: \.self) { r in Text(r.rawValue).tag(r) }
                }
                Picker("To Place", selection: $toPlace) {
                    Text("Select").tag(nil as Place?)
                    ForEach(places) { p in Text(p.name).tag(p as Place?) }
                }
                TextField("Source", text: $source)
            }
            .formStyle(.grouped)
            .padding(.horizontal)
            HStack {
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("Save") { save() }.keyboardShortcut(.defaultAction)
            }.padding()
        }
        .frame(width: 450, height: 340)
        .onAppear {
            fromPlace = assoc.fromPlace
            toPlace = assoc.toPlace
            role = assoc.role
            source = assoc.source
        }
    }

    private func save() {
        assoc.fromPlace = fromPlace
        assoc.toPlace = toPlace
        assoc.role = role
        assoc.source = source
        dismiss()
    }
}

struct EditEventEventAssociationForm: View {
    @Environment(\.dismiss) var dismiss
    @Query private var events: [Event]
    let assoc: EventEventAssociation

    @State private var fromEvent: Event?
    @State private var toEvent: Event?
    @State private var role: EventEventAssociation.Role = .caused
    @State private var source = ""

    var body: some View {
        VStack(spacing: 0) {
            Text("Edit Event ↔ Event Association")
                .font(.title3.bold())
                .padding()
            Form {
                Picker("From Event", selection: $fromEvent) {
                    Text("Select").tag(nil as Event?)
                    ForEach(events) { e in Text(e.name).tag(e as Event?) }
                }
                Picker("Role", selection: $role) {
                    ForEach(EventEventAssociation.Role.allCases, id: \.self) { r in Text(r.rawValue).tag(r) }
                }
                Picker("To Event", selection: $toEvent) {
                    Text("Select").tag(nil as Event?)
                    ForEach(events) { e in Text(e.name).tag(e as Event?) }
                }
                TextField("Source", text: $source)
            }
            .formStyle(.grouped)
            .padding(.horizontal)
            HStack {
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("Save") { save() }.keyboardShortcut(.defaultAction)
            }.padding()
        }
        .frame(width: 450, height: 340)
        .onAppear {
            fromEvent = assoc.fromEvent
            toEvent = assoc.toEvent
            role = assoc.role
            source = assoc.source
        }
    }

    private func save() {
        assoc.fromEvent = fromEvent
        assoc.toEvent = toEvent
        assoc.role = role
        assoc.source = source
        dismiss()
    }
}


struct EditRelationshipForm: View {
    @Environment(\.dismiss) var dismiss
    @Query private var figures: [Figure]
    let relationship: Relationship

    @State private var fromFigure: Figure?
    @State private var toFigure: Figure?
    @State private var fromSearchText = ""
    @State private var toSearchText = ""
    @State private var relationshipType: Relationship.RelationshipType = .father
    @State private var source = ""

    private var filteredFromFigures: [Figure] {
        guard !fromSearchText.isEmpty else { return [] }
        return figures.filter { fig in
            (fromFigure == nil || fig.persistentModelID != fromFigure!.persistentModelID) &&
            fig.name.localizedCaseInsensitiveContains(fromSearchText)
        }
    }

    private var filteredToFigures: [Figure] {
        guard !toSearchText.isEmpty else { return [] }
        return figures.filter { fig in
            (toFigure == nil || fig.persistentModelID != toFigure!.persistentModelID) &&
            fig.name.localizedCaseInsensitiveContains(toSearchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Text("Edit Relationship")
                .font(.title3.bold())
                .padding()
            Form {
                Section("From") {
                    FigureSearchSelector(
                        selection: $fromFigure,
                        searchText: $fromSearchText,
                        figures: figures,
                        filteredFigures: filteredFromFigures,
                        placeholder: "Search from figure\u{2026}"
                    )
                }
                Section("Type") {
                    Picker("Type", selection: $relationshipType) {
                        ForEach(Relationship.RelationshipType.allCases, id: \.self) { t in Text(t.rawValue).tag(t) }
                    }
                }
                Section("To") {
                    FigureSearchSelector(
                        selection: $toFigure,
                        searchText: $toSearchText,
                        figures: figures,
                        filteredFigures: filteredToFigures,
                        placeholder: "Search to figure\u{2026}"
                    )
                }
                TextField("Source", text: $source)
            }
            .formStyle(.grouped)
            .padding(.horizontal)
            HStack {
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("Save") { save() }.keyboardShortcut(.defaultAction)
            }.padding()
        }
        .frame(width: 450, height: 520)
        .onAppear {
            fromFigure = relationship.fromFigure
            toFigure = relationship.toFigure
            relationshipType = relationship.relationshipType
            source = relationship.source
        }
        .onChange(of: fromFigure) { _, _ in inferType() }
    }

    private func save() {
        relationship.fromFigure = fromFigure
        relationship.toFigure = toFigure
        relationship.relationshipType = relationshipType
        relationship.source = source
        dismiss()
    }

    private func inferType() {
        switch fromFigure?.gender {
        case .female: relationshipType = .mother
        case .male: relationshipType = .father
        default: break
        }
    }
}

// MARK: - Event ↔ Place Forms

struct AddEventPlaceAssociationForm: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss
    @Query private var events: [Event]
    @Query private var places: [Place]

    @State private var selectedEvent: Event?
    @State private var selectedPlace: Place?
    @State private var role: EventPlaceAssociation.Role = .occurredAt
    @State private var source = ""

    var body: some View {
        VStack(spacing: 0) {
            Text("Add Event ↔ Place Association")
                .font(.title3.bold())
                .padding()
            Form {
                Picker("Event", selection: $selectedEvent) {
                    Text("Select").tag(nil as Event?)
                    ForEach(events) { e in Text(e.name).tag(e as Event?) }
                }
                Picker("Role", selection: $role) {
                    ForEach(EventPlaceAssociation.Role.allCases, id: \.self) { r in Text(r.rawValue).tag(r) }
                }
                Picker("Place", selection: $selectedPlace) {
                    Text("Select").tag(nil as Place?)
                    ForEach(places) { p in Text(p.name).tag(p as Place?) }
                }
                TextField("Source", text: $source)
            }
            .formStyle(.grouped)
            .padding(.horizontal)
            HStack {
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("Add") { save() }.keyboardShortcut(.defaultAction).disabled(selectedEvent == nil || selectedPlace == nil)
            }.padding()
        }
        .frame(width: 450, height: 340)
    }

    private func save() {
        let assoc = EventPlaceAssociation(event: selectedEvent, place: selectedPlace, role: role, source: source)
        modelContext.insert(assoc)
        dismiss()
    }
}

struct EditEventPlaceAssociationForm: View {
    @Environment(\.dismiss) var dismiss
    @Query private var events: [Event]
    @Query private var places: [Place]
    let assoc: EventPlaceAssociation

    @State private var selectedEvent: Event?
    @State private var selectedPlace: Place?
    @State private var role: EventPlaceAssociation.Role = .occurredAt
    @State private var source = ""

    var body: some View {
        VStack(spacing: 0) {
            Text("Edit Event ↔ Place Association")
                .font(.title3.bold())
                .padding()
            Form {
                Picker("Event", selection: $selectedEvent) {
                    Text("Select").tag(nil as Event?)
                    ForEach(events) { e in Text(e.name).tag(e as Event?) }
                }
                Picker("Role", selection: $role) {
                    ForEach(EventPlaceAssociation.Role.allCases, id: \.self) { r in Text(r.rawValue).tag(r) }
                }
                Picker("Place", selection: $selectedPlace) {
                    Text("Select").tag(nil as Place?)
                    ForEach(places) { p in Text(p.name).tag(p as Place?) }
                }
                TextField("Source", text: $source)
            }
            .formStyle(.grouped)
            .padding(.horizontal)
            HStack {
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("Save") { save() }.keyboardShortcut(.defaultAction)
            }.padding()
        }
        .frame(width: 450, height: 340)
        .onAppear {
            selectedEvent = assoc.event
            selectedPlace = assoc.place
            role = assoc.role
            source = assoc.source
        }
    }

    private func save() {
        assoc.event = selectedEvent
        assoc.place = selectedPlace
        assoc.role = role
        assoc.source = source
        dismiss()
    }
}
