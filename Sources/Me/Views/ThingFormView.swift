import SwiftUI
import SwiftData

struct ThingFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.userSession) private var userSession
    @Environment(\.dismiss) var dismiss

    let thing: Thing?
    @Query private var thingTypes: [ThingType]
    @Query(sort: \Source.name) private var sources: [Source]
    @Query private var allThings: [Thing]

    @State private var name = ""
    @State private var thingDescription = ""
    @State private var richDescription: Data? = nil
    @State private var source = ""
    @State private var showCustomSourceField = false
    @State private var selectedThingType: ThingType? = nil
    @State private var selectedTags: [Tag] = []

    @State private var currentStep = 0
    @State private var showSuccessAlert = false

    private let stepLabels = ["Identity", "Description & Tags", "Source"]

    private var isEditing: Bool { thing != nil }
    private var totalSteps: Int { 3 }
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
        let others = allThings
            .filter { $0.persistentModelID != thing?.persistentModelID }
            .map(\.name)
        return NameDuplicateCheck.warning(candidate: name, existingNames: others)
    }

    var body: some View {
        WizardContainer(
            title: isEditing ? "Edit Thing" : "Add Thing",
            step: currentStep,
            totalSteps: totalSteps,
            stepLabels: stepLabels,
            canGoBack: canGoBack,
            canGoNext: canGoNext,
            saveLabel: saveButtonLabel,
            iconName: selectedThingType?.icon ?? "shippingbox",
            iconColor: selectedThingType?.color ?? .brown,
            entityName: name,
            onCancel: { dismiss() },
            onBack: { currentStep -= 1 },
            onNext: { currentStep += 1 },
            onSave: { save() }
        ) {
            switch currentStep {
            case 0: identityStep
            case 1: descriptionStep
            case 2: sourceStep
            default: EmptyView()
            }
        }
        .frame(width: 660, height: 600)
        .onAppear { loadIfEditing() }
        .alert(isEditing ? "Thing Updated" : "Thing Created", isPresented: $showSuccessAlert) {
            Button("OK") { dismiss() }
        } message: {
            if isEditing {
                Text("\"\(name)\" was successfully updated in Things.")
            } else {
                Text("\"\(name)\" was successfully created in Things.")
            }
        }
    }

    private var identityStep: some View {
        Form {
            Section("Identity") {
                TextField("Name", text: $name, prompt: Text("e.g. Tablet of Destinies"))
                    .textFieldStyle(.roundedBorder)
                    .foregroundStyle(duplicateNameWarning == nil ? Color.primary : Color.orange)
                    .help("The name of this artifact, object, or item")
                if let duplicate = duplicateNameWarning {
                    Label("A thing named \"\(duplicate)\" already exists — continuing will create another one.", systemImage: "exclamationmark.triangle.fill")
                        .font(.callout.bold())
                        .foregroundStyle(.orange)
                }

                if !thingTypes.isEmpty {
                    Picker("Type", selection: $selectedThingType) {
                        Text("None").tag(nil as ThingType?)
                        ForEach(thingTypes) { type in
                            HStack {
                                Image(systemName: type.icon)
                                Text(type.name)
                            }.tag(type as ThingType?)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private var descriptionStep: some View {
        Form {
            Section("Description") {
                RichTextEditorSection(richData: $richDescription, plainText: $thingDescription)
                    .frame(minHeight: 200)
            }

            Section("Tags") {
                TagEditorView(tags: $selectedTags)
            }
        }
        .formStyle(.grouped)
    }

    private var sourceStep: some View {
        Form {
            Section("Source") {
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
                    TextField("Source name", text: $source, prompt: Text("e.g. Enuma Elish"))
                        .textFieldStyle(.roundedBorder)
                }
            }
        }
        .formStyle(.grouped)
    }

    private func loadIfEditing() {
        guard let thing else { return }
        name = thing.name
        thingDescription = thing.thingDescription
        richDescription = thing.richDescription
        source = thing.source
        selectedThingType = thing.thingType
        selectedTags = thing.tags
    }

    private func save() {
        if let thing {
            thing.name = name
            thing.thingDescription = thingDescription
            thing.richDescription = richDescription
            thing.source = source
            thing.thingType = selectedThingType
            thing.tags = selectedTags
            RecentEditStore.trackEdit(entityType: "Thing", entityName: thing.name)
            ActivityLogger.record(action: .updated, entityType: "Thing", entityName: thing.name, context: modelContext, session: userSession)
        } else {
            let newThing = Thing(name: name, thingDescription: thingDescription, source: source)
            newThing.richDescription = richDescription
            newThing.thingType = selectedThingType
            newThing.tags = selectedTags
            modelContext.insert(newThing)
            RecentEditStore.trackEdit(entityType: "Thing", entityName: newThing.name)
            ActivityLogger.record(action: .created, entityType: "Thing", entityName: newThing.name, context: modelContext, session: userSession)
        }
        try? modelContext.save()
        showSuccessAlert = true
    }
}
