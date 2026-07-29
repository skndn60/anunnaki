import SwiftUI
import SwiftData

struct FigureFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss

    let figure: Figure?
    @Query private var figureTypes: [FigureType]
    @Query(sort: \Source.name) private var sources: [Source]

    @State private var name = ""
    @State private var disambiguation = ""
    @State private var title = ""
    @State private var selectedFigureType: FigureType? = nil
    @State private var gender: Figure.Gender = .unknown
    @State private var domain = ""
    @State private var figureDescription = ""
    @State private var richDescription: Data? = nil
    @State private var birthDate: MythologicalDate = .unknown
    @State private var deathDate: MythologicalDate = .unknown
    @State private var source = ""
    @State private var showCustomSourceField = false
    @State private var causeOfDeath = ""
    @State private var reignStartText = ""
    @State private var reignEndText = ""
    @State private var selectedTags: [Tag] = []

    @State private var currentStep = 0
    @State private var showSuccessAlert = false

    private let stepLabels = ["Identity", "Reign", "Birth", "Death", "Description", "Source & Tags"]

    private var isEditing: Bool { figure != nil }
    private var totalSteps: Int { 6 }
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
            title: isEditing ? "Edit Figure" : "Add Figure",
            step: currentStep,
            totalSteps: totalSteps,
            stepLabels: stepLabels,
            canGoBack: canGoBack,
            canGoNext: canGoNext,
            saveLabel: saveButtonLabel,
            iconName: selectedFigureType?.icon ?? "person.fill",
            iconColor: selectedFigureType?.color ?? .gray,
            onCancel: { dismiss() },
            onBack: { currentStep -= 1 },
            onNext: { currentStep += 1 },
            onSave: { save() }
        ) {
            switch currentStep {
            case 0: identityStep
            case 1: reignStep
            case 2: birthStep
            case 3: deathStep
            case 4: descriptionStep
            case 5: sourceTagsStep
            default: EmptyView()
            }
        }
        .frame(width: 660, height: 600)
        .onAppear { loadIfEditing() }
        .alert(isEditing ? "Figure Updated" : "Figure Created", isPresented: $showSuccessAlert) {
            Button("OK") { dismiss() }
        } message: {
            if isEditing {
                Text("\"\(name)\" was successfully updated in Figures.")
            } else {
                Text("\"\(name)\" was successfully created in Figures.")
            }
        }
    }

    private var identityStep: some View {
        Form {
            Section("Identity") {
                TextField("Name", text: $name)
                    .help("The primary name of this figure")
                TextField("Disambiguation", text: $disambiguation, prompt: Text("e.g. Fourth dynasty of Kish"))
                    .help("Optional context to distinguish from other figures with the same name")
                TextField("Title", text: $title, prompt: Text("e.g. King of the Gods"))
                Picker("Type", selection: $selectedFigureType) {
                    Text("None").tag(nil as FigureType?)
                    ForEach(figureTypes) { type in
                        Text(type.name).tag(type as FigureType?)
                    }
                }
                Picker("Gender", selection: $gender) {
                    ForEach(Figure.Gender.allCases, id: \.self) { g in
                        Text("\(g.symbol) \(g.rawValue)").tag(g)
                    }
                }
                TextField("Domain", text: $domain, prompt: Text("e.g. Sky, Wisdom, War"))
                    .help("Comma-separated list of domains this figure governs")
            }
        }
        .formStyle(.grouped)
    }

    private var reignStep: some View {
        Form {
            Section("Reign") {
                HStack {
                    TextField("Start Year", text: $reignStartText, prompt: Text("e.g. -2047"))
                        .help("Negative = BCE, positive = CE")
                    TextField("End Year", text: $reignEndText, prompt: Text("e.g. -2030"))
                        .help("Negative = BCE, positive = CE")
                }
            }
        }
        .formStyle(.grouped)
    }

    private var birthStep: some View {
        Form {
            MythologicalDateEditor(label: "Birth / Origin", date: $birthDate)
        }
        .formStyle(.grouped)
    }

    private var deathStep: some View {
        Form {
            MythologicalDateEditor(label: "Death / End", date: $deathDate)

            Section("Cause of Death") {
                TextField("Cause of Death", text: $causeOfDeath, prompt: Text("e.g. Slain in battle"))
            }
        }
        .formStyle(.grouped)
    }

    private var descriptionStep: some View {
        Form {
            Section("Description") {
                RichTextEditorSection(richData: $richDescription, plainText: $figureDescription)
                    .frame(minHeight: 200)
            }
        }
        .formStyle(.grouped)
    }

    private var sourceTagsStep: some View {
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
                }
            }

            Section("Tags") {
                TagEditorView(tags: $selectedTags)
            }
        }
        .formStyle(.grouped)
    }

    private func loadIfEditing() {
        guard let figure else { return }
        name = figure.name
        disambiguation = figure.disambiguation ?? ""
        title = figure.title
        selectedFigureType = figure.figureType
        gender = figure.gender
        domain = figure.domain
        figureDescription = figure.figureDescription
        richDescription = figure.richDescription
        birthDate = figure.birthDate
        deathDate = figure.deathDate
        source = figure.source
        causeOfDeath = figure.causeOfDeath ?? ""
        reignStartText = figure.reignStartYear.map(String.init) ?? ""
        reignEndText = figure.reignEndYear.map(String.init) ?? ""
        selectedTags = figure.tags
    }

    private func save() {
        if let figure {
            figure.name = name
            figure.disambiguation = disambiguation.isEmpty ? nil : disambiguation
            figure.title = title
            figure.figureType = selectedFigureType
            figure.gender = gender
            figure.domain = domain
            figure.figureDescription = figureDescription
            figure.richDescription = richDescription
            figure.birthDate = birthDate
            figure.deathDate = deathDate
            figure.source = source
            figure.causeOfDeath = causeOfDeath.isEmpty ? nil : causeOfDeath
            figure.isConcept = false
            figure.reignStartYear = Int(reignStartText)
            figure.reignEndYear = Int(reignEndText)
            figure.tags = selectedTags
            RecentEditStore.trackEdit(entityType: "Figure", entityName: figure.name)
        } else {
            let newFigure = Figure(
                name: name, disambiguation: disambiguation.isEmpty ? nil : disambiguation, title: title, figureType: selectedFigureType,
                gender: gender, domain: domain, figureDescription: figureDescription,
                birthDate: birthDate, deathDate: deathDate, source: source,
                causeOfDeath: causeOfDeath.isEmpty ? nil : causeOfDeath
            )
            newFigure.reignStartYear = Int(reignStartText)
            newFigure.reignEndYear = Int(reignEndText)
            newFigure.richDescription = richDescription
            newFigure.tags = selectedTags
            modelContext.insert(newFigure)
            RecentEditStore.trackEdit(entityType: "Figure", entityName: newFigure.name)
        }
        try? modelContext.save()
        showSuccessAlert = true
    }
}
