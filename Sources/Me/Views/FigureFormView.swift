import SwiftUI
import SwiftData

struct FigureFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.userSession) private var userSession
    @Environment(\.dismiss) var dismiss

    let figure: Figure?
    @Query private var figureTypes: [FigureType]
    @Query(sort: \Source.name) private var sources: [Source]
    @Query(sort: \Pantheon.name) private var pantheons: [Pantheon]
    @Query private var allFigures: [Figure]

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
    @State private var selectedSource: Source?
    @State private var causeOfDeath = ""
    @State private var reignStartText = ""
    @State private var reignEndText = ""
    @State private var reignYearsText = ""
    @State private var selectedTags: [Tag] = []

    @State private var variantDrafts: [ReignVariantDraft] = []

    @State private var currentStep = 0
    @State private var showSuccessAlert = false
    @State private var createdFigureID: PersistentIdentifier?

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

    private var duplicateNameWarning: String? {
        let others = allFigures
            .filter { $0.persistentModelID != figure?.persistentModelID && $0.persistentModelID != createdFigureID }
            .map(\.name)
        return NameDuplicateCheck.warning(candidate: name, existingNames: others)
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
            entityName: name,
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
                    .foregroundStyle(duplicateNameWarning == nil ? Color.primary : Color.orange)
                    .help("The primary name of this figure")
                if let duplicate = duplicateNameWarning {
                    Label("A figure named \"\(duplicate)\" already exists — continuing will create another one.", systemImage: "exclamationmark.triangle.fill")
                        .font(.callout.bold())
                        .foregroundStyle(.orange)
                }
                TextField("Disambiguation", text: $disambiguation, prompt: Text("Fourth dynasty of Kish"))
                    .textFieldStyle(.roundedBorder)
                    .help("Optional context to distinguish from other figures with the same name")
                TextField("Title", text: $title, prompt: Text("King of the Gods"))
                    .textFieldStyle(.roundedBorder)
                TextField("Epithet", text: $epithet, prompt: Text("the shepherd who ascended to heaven"))
                    .textFieldStyle(.roundedBorder)
                    .help("A title or praise phrase, such as Etana\u{2019}s \u{201C}the shepherd who ascended to heaven\u{201D}. Not an alternate name.")
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
                TextField("Domain", text: $domain, prompt: Text("Sky, Wisdom, War"))
                    .textFieldStyle(.roundedBorder)
                    .help("Comma-separated list of domains this figure governs")
                VStack(alignment: .leading, spacing: 4) {
                    Text("Pantheons")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if pantheons.isEmpty {
                        Text("No pantheons yet. Create them in Type Settings.")
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
                    TextField("Start Year", text: $reignStartText, prompt: Text("-2047"))
                        .textFieldStyle(.roundedBorder)
                        .help("Negative = BCE, positive = CE")
                    TextField("End Year", text: $reignEndText, prompt: Text("-2030"))
                        .textFieldStyle(.roundedBorder)
                        .help("Negative = BCE, positive = CE")
                }
                TextField("Duration (years)", text: $reignYearsText, prompt: Text("35"))
                    .textFieldStyle(.roundedBorder)
                    .help("Listed reign length in years (such as the SKL\u{2019}s own figure). Leave empty if unknown.")
            }

            Section("Variant Reigns") {
                if variantDrafts.isEmpty {
                    Text("No variant reigns recorded. Add alternatives such as \u{201C}or 900 in some copies\u{201D} or \u{201C}3 years per the Ur-Isin kinglist\u{201D}.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                ForEach($variantDrafts) { $draft in
                    ReignVariantRow(
                        draft: $draft,
                        index: (variantDrafts.firstIndex { $0.id == draft.id } ?? 0),
                        isLast: draft.id == variantDrafts.last?.id,
                        onRemove: { variantDrafts.removeAll { $0.id == draft.id } }
                    )
                }
                Button {
                    variantDrafts.append(ReignVariantDraft())
                } label: {
                    Label("Add Variant", systemImage: "plus.circle")
                }
            }
        }
        .formStyle(.grouped)
    }

    private var birthStep: some View {
        Form {
            Section("Period") {
                Picker("Period", selection: $birthDate.era) {
                    Text("None").tag("")
                    ForEach(eraNames, id: \.self) { name in
                        Text(name).tag(name)
                    }
                    if !birthDate.era.isEmpty && !eraNames.contains(birthDate.era) {
                        Text("\(birthDate.era) (not in era list)").tag(birthDate.era)
                    }
                }
                Text("Which timeline era the figure belongs to — independent of any dates.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            MythologicalDateEditor(label: "Birth / Origin", date: $birthDate, showsPeriodField: false)
        }
        .formStyle(.grouped)
        .task {
            loadEraNames()
            loadMentionIndex()
        }
    }

    private var deathStep: some View {
        Form {
            MythologicalDateEditor(label: "Death / End", date: $deathDate)

            Section("Cause of Death") {
                TextField("Cause of Death", text: $causeOfDeath, prompt: Text("Slain in battle"))
                    .textFieldStyle(.roundedBorder)
            }
        }
        .formStyle(.grouped)
    }

    @State private var eraNames: [String] = []
    @State private var mentionIndex: [String: Figure.Gender] = [:]

    private func loadEraNames() {
        let descriptor = FetchDescriptor<Era>(sortBy: [SortDescriptor(\Era.orderIndex)])
        eraNames = ((try? modelContext.fetch(descriptor)) ?? []).map(\.name)
    }

    private func loadMentionIndex() {
        mentionIndex = ConsistencyEngine.mentionGenderIndex(figures: allFigures)
    }

    private var genderWordingHint: String? {
        ConsistencyEngine.genderConflict(
            gender: gender,
            title: title,
            figureDescription: figureDescription,
            mentionIndex: mentionIndex,
            ownKeys: [NameDuplicateCheck.normalizedKey(name)]
        )?.message
    }

    private var descriptionStep: some View {
        Form {
            Section("Description") {
                RichTextEditorSection(richData: $richDescription, plainText: $figureDescription)
                    .frame(minHeight: 200)
                if let hint = genderWordingHint {
                    Label(hint, systemImage: "exclamationmark.triangle.fill")
                        .font(.callout.bold())
                        .foregroundStyle(.orange)
                }
            }
        }
        .formStyle(.grouped)
    }

    private var sourceTagsStep: some View {
        Form {
            Section("Source") {
                SourcePickerView(selection: $selectedSource, sources: sources)
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
        selectedSource = sources.first(where: { $0.name == figure.source })
        causeOfDeath = figure.causeOfDeath ?? ""
        reignStartText = figure.reignStartYear.map(String.init) ?? ""
        reignEndText = figure.reignEndYear.map(String.init) ?? ""
        reignYearsText = figure.reignYears.map(String.init) ?? ""
        variantDrafts = figure.sortedReignVersions.map { version in
            ReignVariantDraft(
                original: version,
                yearsText: version.years.map(String.init) ?? "",
                startYearText: version.startYear.map(String.init) ?? "",
                endYearText: version.endYear.map(String.init) ?? "",
                tradition: version.tradition,
                note: version.note
            )
        }
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
            figure.source = selectedSource?.name ?? ""
            figure.causeOfDeath = causeOfDeath.isEmpty ? nil : causeOfDeath
            figure.isConcept = false
            figure.updateKingship(
                reignStartYear: Int(reignStartText),
                reignEndYear: Int(reignEndText),
                reignYears: Int(reignYearsText)
            )
            syncReignVariants(for: figure)
            figure.tags = selectedTags
            figure.pantheons = selectedPantheons
            pruneOrphanedPantheonAssociations(figure)
            RecentEditStore.trackEdit(entityType: "Figure", entityName: figure.name)
            ActivityLogger.record(action: .updated, entityType: "Figure", entityName: figure.name, context: modelContext, session: userSession)
        } else {
            let newFigure = Figure(
                name: name, disambiguation: disambiguation.isEmpty ? nil : disambiguation, title: title, figureType: selectedFigureType,
                gender: gender, domain: domain, figureDescription: figureDescription,
                birthDate: birthDate, deathDate: deathDate, source: selectedSource?.name ?? "",
                causeOfDeath: causeOfDeath.isEmpty ? nil : causeOfDeath
            )
            newFigure.epithet = epithet.isEmpty ? nil : epithet
            newFigure.updateKingship(
                reignStartYear: Int(reignStartText),
                reignEndYear: Int(reignEndText),
                reignYears: Int(reignYearsText)
            )
            newFigure.richDescription = richDescription
            newFigure.tags = selectedTags
            newFigure.pantheons = selectedPantheons
            newFigure.era = Migration.era(named: birthDate.era, context: modelContext)
            modelContext.insert(newFigure)
            syncReignVariants(for: newFigure)
            createdFigureID = newFigure.persistentModelID
            RecentEditStore.trackEdit(entityType: "Figure", entityName: newFigure.name)
            ActivityLogger.record(action: .created, entityType: "Figure", entityName: newFigure.name, context: modelContext, session: userSession)
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

    private func syncReignVariants(for figure: Figure) {
        let originals = figure.sortedReignVersions
        let draftsByOriginal = Dictionary(
            uniqueKeysWithValues: variantDrafts.compactMap { draft in
                draft.original.map { ($0.persistentModelID, draft) }
            }
        )
        for version in originals {
            guard let draft = draftsByOriginal[version.persistentModelID] else { continue }
            version.years = Int(draft.yearsText)
            version.startYear = Int(draft.startYearText)
            version.endYear = Int(draft.endYearText)
            version.tradition = draft.tradition
            version.note = draft.note
        }
        let retainedIDs = Set(draftsByOriginal.keys)
        for version in originals where !retainedIDs.contains(version.persistentModelID) {
            figure.reignVersions.removeAll { $0.persistentModelID == version.persistentModelID }
            modelContext.delete(version)
        }
        for draft in variantDrafts where draft.original == nil {
            let version = ReignVersion(
                years: Int(draft.yearsText),
                startYear: Int(draft.startYearText),
                endYear: Int(draft.endYearText),
                tradition: draft.tradition,
                note: draft.note
            )
            figure.reignVersions.append(version)
            modelContext.insert(version)
        }
    }
}

private struct ReignVariantDraft: Identifiable {
    let id = UUID()
    var original: ReignVersion?
    var yearsText = ""
    var startYearText = ""
    var endYearText = ""
    var tradition = ""
    var note = ""
}

private struct ReignVariantRow: View {
    @Binding var draft: ReignVariantDraft
    let index: Int
    let isLast: Bool
    let onRemove: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Variant \(index + 1)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    Spacer()
                    Button(action: onRemove) {
                        Image(systemName: "trash")
                            .font(.system(size: 10))
                            .foregroundStyle(.red.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                    .help("Remove this variant")
                }
                LabeledContent("Duration") {
                    TextField("", text: $draft.yearsText, prompt: Text("900"))
                        .textFieldStyle(.roundedBorder)
                        .help("Variant reign length in years. Leave empty for a span-only variant.")
                }
                LabeledContent("Start Year") {
                    TextField("", text: $draft.startYearText, prompt: Text("-1700"))
                        .textFieldStyle(.roundedBorder)
                        .help("Negative = BCE, positive = CE")
                }
                LabeledContent("End Year") {
                    TextField("", text: $draft.endYearText, prompt: Text("-1600"))
                        .textFieldStyle(.roundedBorder)
                        .help("Negative = BCE, positive = CE")
                }
                LabeledContent("Tradition") {
                    TextField("", text: $draft.tradition, prompt: Text("Some copies of the SKL, Ur-Isin king list\u{2026}"))
                        .textFieldStyle(.roundedBorder)
                        .help("Which source records this variant")
                }
                LabeledContent("Note") {
                    TextField("", text: $draft.note, prompt: Text("Optional detail, e.g. where the figure is attested"))
                        .textFieldStyle(.roundedBorder)
                }
            }
            if !isLast {
                Divider()
                    .padding(.vertical, 8)
            }
        }
        .padding(.vertical, 2)
    }
}
