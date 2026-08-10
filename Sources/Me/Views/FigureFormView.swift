import SwiftUI
import SwiftData

struct FigureFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss

    let figure: Figure?
    @Query private var figureTypes: [FigureType]
    @Query(sort: \Source.name) private var sources: [Source]
    @Query(sort: \Pantheon.name) private var pantheons: [Pantheon]

    @State private var name = ""
    @State private var disambiguation = ""
    @State private var title = ""
    @State private var epithet = ""
    @State private var selectedFigureType: FigureType? = nil
    @State private var gender: Figure.Gender = .unknown
    @State private var domain = ""
    @State private var selectedPantheons: [Pantheon] = []
    @State private var figureDescription = ""
    @State private var richDescription: Data? = nil
    @State private var birthDate: MythologicalDate = .unknown
    @State private var deathDate: MythologicalDate = .unknown
    @State private var source = ""
    @State private var showCustomSourceField = false
    @State private var causeOfDeath = ""
    @State private var reignStartText = ""
    @State private var reignEndText = ""
    @State private var reignYearsText = ""
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
                    .textFieldStyle(.roundedBorder)
                    .help("The primary name of this figure")
                TextField("Disambiguation", text: $disambiguation, prompt: Text("e.g. Fourth dynasty of Kish"))
                    .textFieldStyle(.roundedBorder)
                    .help("Optional context to distinguish from other figures with the same name")
                TextField("Title", text: $title, prompt: Text("e.g. King of the Gods"))
                    .textFieldStyle(.roundedBorder)
                TextField("Epithet", text: $epithet, prompt: Text("e.g. the shepherd who ascended to heaven"))
                    .textFieldStyle(.roundedBorder)
                    .help("A title or praise-phrase, e.g. Etana's 'the shepherd who ascended to heaven'. Not an alternate name.")
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
                    .textFieldStyle(.roundedBorder)
                    .help("Comma-separated list of domains this figure governs")
                VStack(alignment: .leading, spacing: 4) {
                    Text("Pantheons")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if pantheons.isEmpty {
                        Text("No pantheons yet — create them in Type Settings")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    } else {
                        Menu {
                            ForEach(pantheons) { pantheon in
                                let isSelected = selectedPantheons.contains { $0.persistentModelID == pantheon.persistentModelID }
                                Button {
                                    if isSelected {
                                        selectedPantheons.removeAll { $0.persistentModelID == pantheon.persistentModelID }
                                    } else {
                                        selectedPantheons.append(pantheon)
                                    }
                                } label: {
                                    Label(pantheon.name, systemImage: isSelected ? "checkmark" : "")
                                }
                            }
                        } label: {
                            Label("\(selectedPantheons.count)", systemImage: "building.columns")
                                .labelStyle(.titleAndIcon)
                        }
                        .menuStyle(.borderlessButton)
                        .help("Assign pantheons to this figure")
                        .fixedSize()
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private var reignStep: some View {
        Form {
            Section("Reign") {
                HStack {
                    TextField("Start Year", text: $reignStartText, prompt: Text("e.g. -2047"))
                        .textFieldStyle(.roundedBorder)
                        .help("Negative = BCE, positive = CE")
                    TextField("End Year", text: $reignEndText, prompt: Text("e.g. -2030"))
                        .textFieldStyle(.roundedBorder)
                        .help("Negative = BCE, positive = CE")
                }
                TextField("Duration (years)", text: $reignYearsText, prompt: Text("e.g. 35"))
                    .textFieldStyle(.roundedBorder)
                    .help("Listed reign length in years (e.g. the SKL's own figure). Leave empty if unknown.")
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
                    .textFieldStyle(.roundedBorder)
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
                        .textFieldStyle(.roundedBorder)
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
        epithet = figure.epithet ?? ""
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
        reignYearsText = figure.reignYears.map(String.init) ?? ""
        selectedTags = figure.tags
        selectedPantheons = figure.pantheons
    }

    private func save() {
        if let figure {
            figure.name = name
            figure.disambiguation = disambiguation.isEmpty ? nil : disambiguation
            figure.title = title
            figure.epithet = epithet.isEmpty ? nil : epithet
            figure.figureType = selectedFigureType
            figure.gender = gender
            figure.domain = domain
            figure.figureDescription = figureDescription
            figure.richDescription = richDescription
            figure.birthDate = birthDate
            figure.deathDate = deathDate
            figure.era = Migration.era(named: birthDate.era, context: modelContext)
            figure.source = source
            figure.causeOfDeath = causeOfDeath.isEmpty ? nil : causeOfDeath
            figure.isConcept = false
            figure.reignStartYear = Int(reignStartText)
            figure.reignEndYear = Int(reignEndText)
            figure.reignYears = Int(reignYearsText)
            figure.tags = selectedTags
            figure.pantheons = selectedPantheons
            pruneOrphanedPantheonAssociations(figure)
            RecentEditStore.trackEdit(entityType: "Figure", entityName: figure.name)
        } else {
            let newFigure = Figure(
                name: name, disambiguation: disambiguation.isEmpty ? nil : disambiguation, title: title, figureType: selectedFigureType,
                gender: gender, domain: domain, figureDescription: figureDescription,
                birthDate: birthDate, deathDate: deathDate, source: source,
                causeOfDeath: causeOfDeath.isEmpty ? nil : causeOfDeath
            )
            newFigure.epithet = epithet.isEmpty ? nil : epithet
            newFigure.reignStartYear = Int(reignStartText)
            newFigure.reignEndYear = Int(reignEndText)
            newFigure.reignYears = Int(reignYearsText)
            newFigure.richDescription = richDescription
            newFigure.tags = selectedTags
            newFigure.pantheons = selectedPantheons
            newFigure.era = Migration.era(named: birthDate.era, context: modelContext)
            modelContext.insert(newFigure)
            RecentEditStore.trackEdit(entityType: "Figure", entityName: newFigure.name)
        }
        try? modelContext.save()
        showSuccessAlert = true
    }

    private func pruneOrphanedPantheonAssociations(_ figure: Figure) {
        let memberIDs = Set(figure.pantheons.map(\.persistentModelID))
        let orphans = (figure.pantheonAssociations ?? []).filter {
            guard let pantheon = $0.pantheon else { return true }
            return !memberIDs.contains(pantheon.persistentModelID)
        }
        for assoc in orphans {
            figure.pantheonAssociations?.removeAll { $0.persistentModelID == assoc.persistentModelID }
            modelContext.delete(assoc)
        }
    }
}
