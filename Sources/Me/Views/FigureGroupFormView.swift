import SwiftUI
import SwiftData

struct FigureGroupFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss

    let group: FigureGroup?
    @State private var name = ""
    @State private var groupDescription = ""
    @State private var icon = "rectangle.3.group"
    @State private var colorHex = "8E8E93"
    @State private var searchText = ""
    @State private var selectedFigures: Set<PersistentIdentifier> = []

    @State private var currentStep = 0
    @State private var showSuccessAlert = false

    private let stepLabels = ["Identity", "Figures"]

    private var isEditing: Bool { group != nil }
    private var totalSteps: Int { 2 }
    private var canGoBack: Bool { currentStep > 0 }
    private var canGoNext: Bool {
        switch currentStep {
        case 0: return !name.isEmpty
        default: return true
        }
    }

    private var saveButtonLabel: String {
        isEditing ? "Finish and Save" : "Finish and Create"
    }

    private var allFigures: [Figure] {
        (try? modelContext.fetch(FetchDescriptor<Figure>(sortBy: [SortDescriptor(\.name)]))) ?? []
    }

    private var filteredFigures: [Figure] {
        searchText.isEmpty ? allFigures : allFigures.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        WizardContainer(
            title: isEditing ? "Edit Group" : "Add Figure Group",
            step: currentStep,
            totalSteps: totalSteps,
            stepLabels: stepLabels,
            canGoBack: canGoBack,
            canGoNext: canGoNext,
            saveLabel: saveButtonLabel,
            iconName: icon,
            iconColor: Color(hex: colorHex),
            onCancel: { dismiss() },
            onBack: { currentStep -= 1 },
            onNext: { currentStep += 1 },
            onSave: { save() }
        ) {
            switch currentStep {
            case 0: identityStep
            case 1: figuresStep
            default: EmptyView()
            }
        }
        .frame(width: 600, height: 480)
        .onAppear { loadIfEditing() }
        .alert(isEditing ? "Group Updated" : "Group Created", isPresented: $showSuccessAlert) {
            Button("OK") { dismiss() }
        } message: {
            if isEditing {
                Text("\"\(name)\" was updated.")
            } else {
                Text("\"\(name)\" was created.")
            }
        }
    }

    private var identityStep: some View {
        Form {
            Section("Identity") {
                TextField("Name", text: $name, prompt: Text("e.g. Divine Council, Anunnaki Council"))
                    .help("The name of this figure group")

                TextField("Description", text: $groupDescription, prompt: Text("Optional description"), axis: .vertical)
                    .lineLimit(3...6)

                HStack {
                    TextField("Icon (SF Symbol)", text: $icon, prompt: Text("rectangle.3.group"))
                        .autocorrectionDisabled()
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundStyle(Color(hex: colorHex))
                        .frame(width: 28)
                }

                ColorPicker("Color", selection: Binding(
                    get: { Color(hex: colorHex) },
                    set: { colorHex = $0.toHex ?? "8E8E93" }
                ))
            }
        }
        .formStyle(.grouped)
    }

    private var figuresStep: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                TextField("Search figures...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
            }
            .padding(.horizontal)

            Text(selectedFigures.isEmpty ? "No figures selected" : "\(selectedFigures.count) figure(s) selected")
                .font(.caption)
                .foregroundStyle(.secondary)

            List(filteredFigures, id: \.persistentModelID) { figure in
                HStack(spacing: 10) {
                    Image(systemName: figure.figureType?.icon ?? "person.fill")
                        .font(.caption)
                        .foregroundStyle(figure.figureType?.color ?? .gray)
                        .frame(width: 16)
                    Text(figure.name)
                        .font(.body)
                    Spacer()
                    if selectedFigures.contains(figure.persistentModelID) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.accentColor)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    if selectedFigures.contains(figure.persistentModelID) {
                        selectedFigures.remove(figure.persistentModelID)
                    } else {
                        selectedFigures.insert(figure.persistentModelID)
                    }
                }
            }
            .listStyle(.plain)
        }
        .padding(.vertical)
    }

    private func loadIfEditing() {
        guard let group else { return }
        name = group.name
        groupDescription = group.groupDescription
        icon = group.icon
        colorHex = group.colorHex
        selectedFigures = Set(group.figureAssociations.compactMap { $0.figure?.persistentModelID })
    }

    private func save() {
        let figureById = allFigures.reduce(into: [:]) { $0[$1.persistentModelID] = $1 }
        let newFigureIDs = selectedFigures

        if let group {
            group.name = name
            group.groupDescription = groupDescription
            group.icon = icon
            group.colorHex = colorHex
            syncFigures(group: group, newIDs: newFigureIDs, figureById: figureById)
        } else {
            let newGroup = FigureGroup(name: name, groupDescription: groupDescription, icon: icon, colorHex: colorHex)
            modelContext.insert(newGroup)
            syncFigures(group: newGroup, newIDs: newFigureIDs, figureById: figureById)
        }
        try? modelContext.save()
        showSuccessAlert = true
    }

    private func syncFigures(group: FigureGroup, newIDs: Set<PersistentIdentifier>, figureById: [PersistentIdentifier: Figure]) {
        let existing = group.figureAssociations
        let existingFigureIDs = Set(existing.compactMap { $0.figure?.persistentModelID })

        let toRemove = existing.filter { $0.figure.map { !newIDs.contains($0.persistentModelID) } ?? false }
        for assoc in toRemove {
            modelContext.delete(assoc)
        }

        let toAdd = newIDs.subtracting(existingFigureIDs)
        for figID in toAdd {
            guard let figure = figureById[figID] else { continue }
            let assoc = FigureGroupAssociation(figure: figure, group: group)
            modelContext.insert(assoc)
        }
    }
}

private extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: Double
        switch hex.count {
        case 6:
            r = Double((int >> 16) & 0xFF) / 255
            g = Double((int >> 8) & 0xFF) / 255
            b = Double(int & 0xFF) / 255
        default:
            r = 0.5; g = 0.5; b = 0.5
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }

    var toHex: String? {
        guard let components = cgColor?.components, components.count >= 3 else { return nil }
        let r = Int(components[0] * 255)
        let g = Int(components[1] * 255)
        let b = Int(components[2] * 255)
        return String(format: "%02X%02X%02X", r, g, b)
    }
}
