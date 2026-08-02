import SwiftUI
import SwiftData

struct FigureGroupFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss

    let group: FigureGroup?
    @State private var name = ""
    @State private var groupDescription = ""
    @State private var richDescription: Data? = nil
    @State private var icon = "rectangle.3.group"
    @State private var colorHex = "8E8E93"
    @State private var kind: GroupKind = .standard
    @State private var entityType: GroupEntityType = .figure
    @State private var isPublished = true
    @State private var parentGroupID: PersistentIdentifier?
    @State private var searchText = ""
    @State private var selectedMemberAliases: [PersistentIdentifier: String] = [:]

    @State private var currentStep = 0
    @State private var showSuccessAlert = false
    @State private var parentSearchText = ""

    private let stepLabels = ["Identity", "Members"]

    private var isEditing: Bool { group != nil }
    private var totalSteps: Int { 2 }
    private var loadedEntityType: GroupEntityType { group?.entityType ?? .figure }
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

    private var allPlaces: [Place] {
        (try? modelContext.fetch(FetchDescriptor<Place>(sortBy: [SortDescriptor(\.name)]))) ?? []
    }

    private var allEvents: [Event] {
        (try? modelContext.fetch(FetchDescriptor<Event>(sortBy: [SortDescriptor(\.name)]))) ?? []
    }

    private var allThings: [Thing] {
        (try? modelContext.fetch(FetchDescriptor<Thing>(sortBy: [SortDescriptor(\.name)]))) ?? []
    }

    private var allCandidates: [GroupMemberItem] {
        switch entityType {
        case .figure: return allFigures.map { GroupMemberItem.figure($0, nil) }
        case .place: return allPlaces.map { GroupMemberItem.place($0, nil) }
        case .event: return allEvents.map { GroupMemberItem.event($0, nil) }
        case .thing: return allThings.map { GroupMemberItem.thing($0, nil) }
        }
    }

    private var filteredCandidates: [GroupMemberItem] {
        searchText.isEmpty ? allCandidates : allCandidates.filter { $0.matches(searchText) }
    }

    private var memberCountLabel: String {
        "\(selectedMemberAliases.count) \(entityType.pluralName.lowercased()) selected"
    }

    @Query(sort: \FigureGroup.orderIndex) private var allGroups: [FigureGroup]

    private var candidateParents: [FigureGroup] {
        allGroups.filter { group in
            guard let editingGroup = self.group else { return true }
            return !descendantGroups(of: editingGroup).contains(group.persistentModelID)
                && group.persistentModelID != editingGroup.persistentModelID
        }
    }

    private func descendantGroups(of group: FigureGroup) -> Set<PersistentIdentifier> {
        var result: Set<PersistentIdentifier> = []
        var stack: [FigureGroup] = (group.subgroups ?? [])
        while let current = stack.popLast() {
            result.insert(current.persistentModelID)
            stack.append(contentsOf: current.subgroups ?? [])
        }
        return result
    }

    var body: some View {
        WizardContainer(
            title: isEditing ? "Edit Group" : "Add Group",
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
            case 1: membersStep
            default: EmptyView()
            }
        }
        .frame(width: 600, height: 560)
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
                    .textFieldStyle(.roundedBorder)
                    .help("The name of this group")

                Picker("Members Are", selection: $entityType) {
                    ForEach(GroupEntityType.allCases, id: \.self) { type in
                        Text(type.pluralName).tag(type)
                    }
                }
                .help("What kind of entity this group holds.")

                Section("Description") {
                    RichTextEditorSection(richData: $richDescription, plainText: $groupDescription)
                        .frame(minHeight: 120)
                }

                HStack {
                    TextField("Icon (SF Symbol)", text: $icon, prompt: Text("rectangle.3.group"))
                        .textFieldStyle(.roundedBorder)
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

                Picker("Kind", selection: $kind) {
                    ForEach(GroupKind.allCases, id: \.self) { kind in
                        Text(kind.displayName).tag(kind)
                    }
                }
                .disabled(entityType != .figure)
                .help(entityType == .figure
                    ? "Standard groups render their members; Book of Enoch, Sumerian King List, and The Flood use dedicated views."
                    : "Dedicated views are only available for figure groups.")

                VStack(alignment: .leading, spacing: 6) {
                    Text("Parent Group")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Toggle("Top-level group (no parent)", isOn: Binding(
                        get: { parentGroupID == nil },
                        set: { if $0 { parentGroupID = nil } }
                    ))
                    .toggleStyle(.checkbox)
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                        TextField("Search groups...", text: $parentSearchText)
                            .textFieldStyle(.roundedBorder)
                    }
                    let filtered = candidateParents.filter {
                        parentSearchText.isEmpty || $0.name.localizedCaseInsensitiveContains(parentSearchText)
                    }
                    if filtered.isEmpty {
                        Text("No matching groups")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    } else {
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 2) {
                                ForEach(filtered) { parent in
                                    Button {
                                        parentGroupID = parent.persistentModelID
                                    } label: {
                                        HStack(spacing: 8) {
                                            Image(systemName: parent.icon)
                                                .font(.caption)
                                                .foregroundStyle(Color(hex: parent.colorHex))
                                                .frame(width: 16)
                                            Text(parent.name)
                                                .font(.callout)
                                                .lineLimit(1)
                                            Spacer()
                                            if parentGroupID == parent.persistentModelID {
                                                Image(systemName: "checkmark")
                                                    .foregroundStyle(Color.accentColor)
                                            }
                                        }
                                        .padding(.vertical, 3)
                                        .padding(.horizontal, 6)
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .pointingHand()
                                }
                            }
                        }
                        .frame(maxHeight: 120)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(.textBackgroundColor))
                        )
                    }
                }
                .help("Make this group a subgroup of another group. Subgroups appear under their parent in the collection view.")

                Toggle("Show in sidebar", isOn: $isPublished)
                    .help("Unpublish to hide this group from the sidebar while keeping its data.")
            }
        }
        .formStyle(.grouped)
        .onChange(of: entityType) { _, newType in
            if newType != .figure { kind = .standard }
            if newType != loadedEntityType {
                selectedMemberAliases.removeAll()
            }
        }
    }

    private var membersStep: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                TextField("Search \(entityType.pluralName.lowercased())...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
            }
            .padding(.horizontal)

            Text(selectedMemberAliases.isEmpty ? "No \(entityType.pluralName.lowercased()) selected" : memberCountLabel)
                .font(.caption)
                .foregroundStyle(.secondary)

            List(filteredCandidates) { candidate in
                HStack(spacing: 10) {
                    Image(systemName: candidate.icon)
                        .font(.caption)
                        .foregroundStyle(candidate.color)
                        .frame(width: 16)
                    Text(candidate.displayName(matching: searchText))
                        .font(.body)
                    if !candidate.subtitle.isEmpty {
                        Text(candidate.subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if selectedMemberAliases[candidate.id] != nil {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.accentColor)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    if selectedMemberAliases[candidate.id] != nil {
                        selectedMemberAliases.removeValue(forKey: candidate.id)
                    } else {
                        selectedMemberAliases[candidate.id] = candidate.matchedAlternateName(for: searchText) ?? ""
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
        richDescription = group.richDescription
        icon = group.icon
        colorHex = group.colorHex
        kind = group.kind
        entityType = group.entityType
        isPublished = group.isPublished
        parentGroupID = group.parentGroup?.persistentModelID
        selectedMemberAliases = Dictionary(uniqueKeysWithValues: group.figureAssociations.compactMap { assoc in
            guard let id = memberID(assoc, of: entityType) else { return nil }
            return (id, assoc.displayName ?? "")
        })
    }

    private func save() {
        let newMemberAliases = selectedMemberAliases
        let newParent = allGroups.first { $0.persistentModelID == parentGroupID }
        let effectiveKind: GroupKind = entityType == .figure ? kind : .standard

        if let group {
            group.name = name
            group.groupDescription = groupDescription
            group.richDescription = richDescription
            group.icon = icon
            group.colorHex = colorHex
            group.kind = effectiveKind
            group.entityType = entityType
            group.isPublished = isPublished
            setParent(group, parent: newParent)
            syncMembers(group: group, newAliases: newMemberAliases)
        } else {
            let newGroup = FigureGroup(name: name, groupDescription: groupDescription, icon: icon, colorHex: colorHex, kind: effectiveKind, entityType: entityType)
            newGroup.richDescription = richDescription
            newGroup.isPublished = isPublished
            modelContext.insert(newGroup)
            setParent(newGroup, parent: newParent)
            syncMembers(group: newGroup, newAliases: newMemberAliases)
        }
        try? modelContext.save()
        showSuccessAlert = true
    }

    private func setParent(_ group: FigureGroup, parent: FigureGroup?) {
        if let current = group.parentGroup {
            current.subgroups?.removeAll { $0.persistentModelID == group.persistentModelID }
        }
        if let parent {
            guard parent.persistentModelID != group.persistentModelID else { return }
            if !(parent.subgroups ?? []).contains(where: { $0.persistentModelID == group.persistentModelID }) {
                parent.subgroups?.append(group)
            }
        }
    }

    private func memberID(_ assoc: FigureGroupAssociation, of type: GroupEntityType) -> PersistentIdentifier? {
        switch type {
        case .figure: return assoc.figure?.persistentModelID
        case .place: return assoc.place?.persistentModelID
        case .event: return assoc.event?.persistentModelID
        case .thing: return assoc.thing?.persistentModelID
        }
    }

    private func candidate(for id: PersistentIdentifier) -> GroupMemberItem? {
        allCandidates.first { $0.id == id }
    }

    private func syncMembers(group: FigureGroup, newAliases: [PersistentIdentifier: String]) {
        let existing = group.figureAssociations
        let existingIDs = Set(existing.compactMap { memberID($0, of: entityType) })
        let newIDs = Set(newAliases.keys)

        let toRemove = existing.filter { assoc in
            guard let id = memberID(assoc, of: entityType) else { return false }
            return !newIDs.contains(id)
        }
        for assoc in toRemove {
            modelContext.delete(assoc)
        }

        let toAdd = newIDs.subtracting(existingIDs)
        for id in toAdd {
            guard let candidate = candidate(for: id) else { continue }
            let assoc = makeAssociation(for: candidate)
            assoc.displayName = newAliases[id].flatMap { $0.isEmpty ? nil : $0 }
            modelContext.insert(assoc)
            group.figureAssociations.append(assoc)
        }
    }

    private func makeAssociation(for candidate: GroupMemberItem) -> FigureGroupAssociation {
        candidate.makeAssociation()
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
