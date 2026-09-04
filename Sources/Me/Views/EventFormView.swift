import SwiftUI
import SwiftData

struct EventFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.userSession) private var userSession
    @Environment(\.dismiss) var dismiss

    let event: Event?
    @Query private var figures: [Figure]
    @Query private var places: [Place]
    @Query private var allEvents: [Event]
    @Query(sort: \EventType.name) private var eventTypes: [EventType]
    @Query(sort: \Era.orderIndex) private var eras: [Era]
    @Query(sort: \EventPlaceRoleType.name) private var eventPlaceRoleTypes: [EventPlaceRoleType]
    @Query(sort: \Source.name) private var sources: [Source]

    @State private var name = ""
    @State private var eventType: EventType? = nil
    @State private var eventDescription = ""
    @State private var richDescription: Data? = nil
    @State private var date: MythologicalDate = .unknown
    @State private var era = ""
    @State private var selectedSource: Source?
    @State private var sortName = ""
    @State private var selectedFigureIDs: Set<PersistentIdentifier> = []
    @State private var figureSearchText = ""
    @State private var placeSelections: [PlaceSelection] = []
    @State private var placeSearchText = ""
    @State private var selectedTags: [Tag] = []

    @State private var currentStep = 0
    @State private var showSuccessAlert = false

    private struct PlaceSelection: Identifiable {
        let id = UUID()
        var place: Place
        var roleType: EventPlaceRoleType?
    }

    private let stepLabels = ["Identity", "Date", "Figures", "Locations", "Description & Tags"]

    private var isEditing: Bool { event != nil }
    private var totalSteps: Int { 5 }
    private var canGoBack: Bool { currentStep > 0 }
    private var canGoNext: Bool {
        switch currentStep {
        case 0: return !name.isEmpty
        default: return true
        }
    }

    private var saveButtonLabel: String {
        if isEditing { return "Finish and Save" }
        return "Finish and Create"
    }

    private var duplicateNameWarning: String? {
        let others = allEvents
            .filter { $0.persistentModelID != event?.persistentModelID }
            .map(\.name)
        return NameDuplicateCheck.warning(candidate: name, existingNames: others)
    }

    private var selectedFigures: [Figure] {
        figures.filter { selectedFigureIDs.contains($0.persistentModelID) }
    }

    private var filteredFigures: [FigureSearchResult] {
        guard !figureSearchText.isEmpty else { return [] }
        let figs = figures.filter { !selectedFigureIDs.contains($0.persistentModelID) }
        return searchFigures(figs, query: figureSearchText)
    }

    private var filteredPlaces: [Place] {
        guard !placeSearchText.isEmpty else { return [] }
        let selectedIDs = Set(placeSelections.map(\.place.persistentModelID))
        return places.filter {
            !selectedIDs.contains($0.persistentModelID) &&
            $0.name.localizedCaseInsensitiveContains(placeSearchText)
        }
    }

    var body: some View {
        WizardContainer(
            title: isEditing ? "Edit Event" : "Add Event",
            step: currentStep,
            totalSteps: totalSteps,
            stepLabels: stepLabels,
            canGoBack: canGoBack,
            canGoNext: canGoNext,
            saveLabel: saveButtonLabel,
            iconName: eventType?.icon ?? "calendar.badge.clock",
            iconColor: eventType?.color ?? .orange,
            entityName: name,
            onCancel: { dismiss() },
            onBack: { currentStep -= 1 },
            onNext: { currentStep += 1 },
            onSave: { save() }
        ) {
            switch currentStep {
            case 0: identityStep
            case 1: dateStep
            case 2: figuresStep
            case 3: locationsStep
            case 4: descriptionAndTagsStep
            default: EmptyView()
            }
        }
        .frame(width: 660, height: 600)
        .onAppear { loadIfEditing() }
        .alert(isEditing ? "Event Updated" : "Event Created", isPresented: $showSuccessAlert) {
            Button("OK") { dismiss() }
        } message: {
            if isEditing {
                Text("\"\(name)\" was successfully updated in Events.")
            } else {
                Text("\"\(name)\" was successfully created in Events.")
            }
        }
    }

    private var identityStep: some View {
        Form {
            Section("Event Details") {
                TextField("Name", text: $name, prompt: Text("Slaying of Tiamat"))
                    .textFieldStyle(.roundedBorder)
                    .foregroundStyle(duplicateNameWarning == nil ? Color.primary : Color.orange)
                if let duplicate = duplicateNameWarning {
                    Label("An event named \"\(duplicate)\" already exists — continuing will create another one.", systemImage: "exclamationmark.triangle.fill")
                        .font(.callout.bold())
                        .foregroundStyle(.orange)
                }
                Picker("Type", selection: $eventType) {
                    ForEach(eventTypes, id: \.persistentModelID) { type in
                        Text(type.name).tag(type as EventType?)
                    }
                }
                Picker("Era", selection: $era) {
                    Text("None").tag("")
                    ForEach(eras) { eraItem in
                        Text(eraItem.name).tag(eraItem.name)
                    }
                }
                SourcePickerView(selection: $selectedSource, sources: sources)
                TextField("Sort key (overrides alphabetical sorting)", text: $sortName, prompt: Text("Flood for \"The Great Flood\""))
                    .textFieldStyle(.roundedBorder)
            }
        }
        .formStyle(.grouped)
    }

    private var dateStep: some View {
        Form {
            MythologicalDateEditor(label: "Date", date: $date)
        }
        .formStyle(.grouped)
    }

    private var figuresStep: some View {
        Form {
            Section("Involved Figures") {
                if !selectedFigureIDs.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(selectedFigures) { figure in
                                HStack(spacing: 2) {
                                    Text(figure.name)
                                        .font(.caption)
                                    if figure.isConcept {
                                        Text("C")
                                            .font(.system(size: 8, weight: .bold))
                                            .foregroundStyle(.orange)
                                            .padding(.horizontal, 2)
                                    }
                                    Button {
                                        selectedFigureIDs.remove(figure.persistentModelID)
                                    } label: {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundStyle(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                    .help("Remove figure")
                                }
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(.quaternary.opacity(0.3))
                                .cornerRadius(4)
                            }
                        }
                    }
                }

                TextField("Search figures\u{2026}", text: $figureSearchText)
                    .textFieldStyle(.roundedBorder)

                if !figureSearchText.isEmpty {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 2) {
                            if filteredFigures.isEmpty {
                                Button {
                                    let fig = Figure(name: figureSearchText, isConcept: true)
                                    modelContext.insert(fig)
                                    selectedFigureIDs.insert(fig.persistentModelID)
                                    figureSearchText = ""
                                } label: {
                                    Label("Create \"\(figureSearchText)\" as new figure", systemImage: "plus")
                                        .font(.caption)
                                        .foregroundStyle(.orange)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 6)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            } else {
                                ForEach(filteredFigures) { result in
                                    Button {
                                        selectedFigureIDs.insert(result.figure.persistentModelID)
                                        figureSearchText = ""
                                    } label: {
                                        HStack(spacing: 6) {
                                            Text(result.figure.gender.symbol)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                            Text(result.displayName)
                                        }
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 2)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .background(Color.primary.opacity(0.05))
                                    .cornerRadius(4)
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 160)
                }
            }
        }
        .formStyle(.grouped)
    }

    private var locationsStep: some View {
        Form {
            Section("Locations") {
                if !placeSelections.isEmpty {
                    VStack(spacing: 4) {
                        ForEach(Array(placeSelections.enumerated()), id: \.element.id) { index, _ in
                            HStack(spacing: 4) {
                                Text(placeSelections[index].place.name)
                                    .font(.caption)
                                Picker("", selection: Binding(
                                    get: { placeSelections[index].roleType },
                                    set: { placeSelections[index].roleType = $0 }
                                )) {
                                    Text("Select").tag(nil as EventPlaceRoleType?)
                                    ForEach(eventPlaceRoleTypes) { rt in
                                        Text(rt.name).tag(rt as EventPlaceRoleType?)
                                    }
                                }
                                .pickerStyle(.menu)
                                .labelsHidden()
                                .frame(width: 120)
                                Button {
                                    placeSelections.remove(at: index)
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                                .help("Remove place")
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(.quaternary.opacity(0.3))
                            .cornerRadius(4)
                        }
                    }
                }

                TextField("Search locations\u{2026}", text: $placeSearchText)
                    .textFieldStyle(.roundedBorder)

                if !placeSearchText.isEmpty {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 2) {
                            if filteredPlaces.isEmpty {
                                Button {
                                    let place = Place(name: placeSearchText, isConcept: true)
                                    modelContext.insert(place)
                                    placeSelections.append(PlaceSelection(place: place, roleType: nil))
                                    placeSearchText = ""
                                } label: {
                                    Label("Create \"\(placeSearchText)\" as new place", systemImage: "plus")
                                        .font(.caption)
                                        .foregroundStyle(.orange)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 6)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            } else {
                                ForEach(filteredPlaces) { place in
                                    Button {
                                        placeSelections.append(PlaceSelection(place: place, roleType: nil))
                                        placeSearchText = ""
                                    } label: {
                                        Text(place.name)
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 2)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .background(Color.primary.opacity(0.05))
                                    .cornerRadius(4)
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 160)
                }
            }
        }
        .formStyle(.grouped)
    }

    private var descriptionAndTagsStep: some View {
        Form {
            Section("Description") {
                RichTextEditorSection(richData: $richDescription, plainText: $eventDescription)
                    .frame(minHeight: 200)
            }

            Section("Tags") {
                TagEditorView(tags: $selectedTags)
            }
        }
        .formStyle(.grouped)
    }

    private func loadIfEditing() {
        guard let event else { return }
        name = event.name
        eventType = event.eventType
        eventDescription = event.eventDescription
        richDescription = event.richDescription
        date = event.date
        era = event.era
        selectedSource = sources.first(where: { $0.name == event.source })
        sortName = event.sortName ?? ""
        selectedFigureIDs = Set(event.involvedFigures.map(\.persistentModelID))
        placeSelections = event.placeAssociations.compactMap { assoc in
            guard let place = assoc.place else { return nil }
            return PlaceSelection(place: place, roleType: assoc.roleType)
        }
        selectedTags = event.tags
    }

    private func save() {
        let selectedFigs = figures.filter { selectedFigureIDs.contains($0.persistentModelID) }
        if let event {
            event.name = name
            event.eventType = eventType
            event.eventDescription = eventDescription
            event.richDescription = richDescription
            event.date = date
            event.era = era
            event.source = selectedSource?.name ?? ""
            event.sortName = sortName.isEmpty ? nil : sortName
            event.isConcept = false
            event.involvedFigures = selectedFigs
            for assoc in event.placeAssociations { modelContext.delete(assoc) }
            let manager = RelationshipManager(context: modelContext)
            var newPlaceAssocs: [EventPlaceAssociation] = []
            for sel in placeSelections {
                newPlaceAssocs.append(manager.addEventPlaceAssociation(event: event, place: sel.place, roleType: sel.roleType, sourceRef: selectedSource, dedupe: false))
            }
            event.placeAssociations = newPlaceAssocs
            event.tags = selectedTags
            RecentEditStore.trackEdit(entityType: "Event", entityName: event.name)
            ActivityLogger.record(action: .updated, entityType: "Event", entityName: event.name, context: modelContext, session: userSession)
        } else {
            let newEvent = Event(
                name: name, eventType: eventType,
                eventDescription: eventDescription,
                date: date, era: era, source: selectedSource?.name ?? "",
                sortName: sortName.isEmpty ? nil : sortName,
                involvedFigures: selectedFigs
            )
            newEvent.tags = selectedTags
            newEvent.richDescription = richDescription
            modelContext.insert(newEvent)
            let manager = RelationshipManager(context: modelContext)
            for sel in placeSelections {
                manager.addEventPlaceAssociation(event: newEvent, place: sel.place, roleType: sel.roleType, sourceRef: selectedSource, dedupe: false)
            }
            RecentEditStore.trackEdit(entityType: "Event", entityName: newEvent.name)
            ActivityLogger.record(action: .created, entityType: "Event", entityName: newEvent.name, context: modelContext, session: userSession)
        }
        try? modelContext.save()
        showSuccessAlert = true
    }
}
