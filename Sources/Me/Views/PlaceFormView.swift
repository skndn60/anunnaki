import SwiftUI
import SwiftData

struct PlaceFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss

    let place: Place?
    @Query(sort: \PlaceType.name) private var placeTypes: [PlaceType]
    @Query(sort: \Source.name) private var sources: [Source]

    @State private var name = ""
    @State private var sortName = ""
    @State private var placeType: PlaceType? = nil
    @State private var modernLocation = ""
    @State private var placeDescription = ""
    @State private var richDescription: Data? = nil
    @State private var source = ""
    @State private var showCustomSourceField = false
    @State private var latitudeStr = ""
    @State private var longitudeStr = ""
    @State private var selectedTags: [Tag] = []
    @State private var foundedDate: MythologicalDate = .unknown

    @State private var currentStep = 0
    @State private var showSuccessAlert = false

    private let stepLabels = ["Identity", "Location", "Foundation", "Description & Tags"]

    private var isEditing: Bool { place != nil }
    private var totalSteps: Int { 4 }
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

    var body: some View {
        WizardContainer(
            title: isEditing ? "Edit Place" : "Add Place",
            step: currentStep,
            totalSteps: totalSteps,
            stepLabels: stepLabels,
            canGoBack: canGoBack,
            canGoNext: canGoNext,
            saveLabel: saveButtonLabel,
            iconName: placeType?.icon ?? "mappin.and.ellipse",
            iconColor: placeType?.color ?? .blue,
            onCancel: { dismiss() },
            onBack: { currentStep -= 1 },
            onNext: { currentStep += 1 },
            onSave: { save() }
        ) {
            switch currentStep {
            case 0: identityStep
            case 1: locationStep
            case 2: foundationStep
            case 3: descriptionTagsStep
            default: EmptyView()
            }
        }
        .frame(width: 660, height: 600)
        .onAppear { loadIfEditing() }
        .alert(isEditing ? "Place Updated" : "Place Created", isPresented: $showSuccessAlert) {
            Button("OK") { dismiss() }
        } message: {
            if isEditing {
                Text("\"\(name)\" was successfully updated in Places.")
            } else {
                Text("\"\(name)\" was successfully created in Places.")
            }
        }
    }

    private var identityStep: some View {
        Form {
            Section("Identity") {
                TextField("Name", text: $name, prompt: Text("e.g. Uruk, Eridu, Kur"))
                    .help("The primary name of this place")
                TextField("Sort Name", text: $sortName, prompt: Text("Leave blank to auto-derive from name"))
                Picker("Type", selection: $placeType) {
                    ForEach(placeTypes, id: \.persistentModelID) { type in
                        Text(type.name).tag(type as PlaceType?)
                    }
                }
                Picker("Source", selection: $source) {
                    Text("None").tag("")
                    ForEach(sources) { s in
                        Text(s.name).tag(s.name)
                    }
                    Divider()
                    Text("Custom\u{2026}").tag("__custom__")
                }
                .onChange(of: source) { _, newValue in
                    showCustomSourceField = newValue == "__custom__"
                    if showCustomSourceField { source = "" }
                }
                if showCustomSourceField {
                    TextField("Source name", text: $source, prompt: Text("e.g. Sumerian King List"))
                }
            }
        }
        .formStyle(.grouped)
    }

    private var locationStep: some View {
        Form {
            Section("Location") {
                TextField("Modern Location", text: $modernLocation, prompt: Text("e.g. Southern Iraq, Warka"))
            }

            Section("Coordinates") {
                HStack {
                    TextField("Latitude", text: $latitudeStr, prompt: Text("e.g. 31.322"))
                    TextField("Longitude", text: $longitudeStr, prompt: Text("e.g. 45.637"))
                }
            }
        }
        .formStyle(.grouped)
    }

    private var foundationStep: some View {
        Form {
            MythologicalDateEditor(label: "Founded", date: $foundedDate)
        }
        .formStyle(.grouped)
    }

    private var descriptionTagsStep: some View {
        Form {
            Section("Description") {
                RichTextEditorSection(richData: $richDescription, plainText: $placeDescription)
                    .frame(minHeight: 200)
            }

            Section("Tags") {
                TagEditorView(tags: $selectedTags)
            }
        }
        .formStyle(.grouped)
    }

    private func loadIfEditing() {
        guard let place else { return }
        name = place.name
        sortName = place.sortName ?? ""
        placeType = place.placeType
        modernLocation = place.modernLocation
        placeDescription = place.placeDescription
        richDescription = place.richDescription
        source = place.source
        latitudeStr = place.latitude.map { String($0) } ?? ""
        longitudeStr = place.longitude.map { String($0) } ?? ""
        selectedTags = place.tags
        foundedDate = place.foundedDate ?? .unknown
    }

    private func save() {
        if let place {
            place.name = name
            place.sortName = sortName.isEmpty ? nil : sortName
            place.placeType = placeType
            place.modernLocation = modernLocation
            place.placeDescription = placeDescription
            place.richDescription = richDescription
            place.source = source
            place.latitude = Double(latitudeStr)
            place.longitude = Double(longitudeStr)
            place.isConcept = false
            place.tags = selectedTags
            place.foundedDate = foundedDate
            RecentEditStore.trackEdit(entityType: "Place", entityName: place.name)
        } else {
            let newPlace = Place(
                name: name, placeType: placeType,
                modernLocation: modernLocation,
                placeDescription: placeDescription, source: source,
                latitude: Double(latitudeStr),
                longitude: Double(longitudeStr)
            )
            newPlace.sortName = sortName.isEmpty ? nil : sortName
            newPlace.richDescription = richDescription
            newPlace.tags = selectedTags
            newPlace.foundedDate = foundedDate
            modelContext.insert(newPlace)
            RecentEditStore.trackEdit(entityType: "Place", entityName: newPlace.name)
        }
        try? modelContext.save()
        showSuccessAlert = true
    }
}
