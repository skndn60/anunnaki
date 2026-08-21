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
    @State private var sidebarTarget: GroupSidebarTarget = .auto
    @State private var customSidebarTargetName = ""
    @State private var parentGroupID: PersistentIdentifier?
    @State private var searchText = ""
    @State private var selectedMemberAliases: [PersistentIdentifier: String] = [:]

    @State private var currentStep = 0
    @State private var showSuccessAlert = false
    @State private var parentSearchText = ""
    @State private var aggregationEnabled = false
    @State private var aggregationOperation: GroupAggregationOperation = .sum
    @State private var aggregationTarget: GroupAggregationTarget = .reignYears
    @State private var aggregationLabel = ""
    @State private var memberSingular = ""
    @State private var memberPlural = ""
    @State private var isSmart = false
    @State private var ruleTypeNames: Set<String> = []
    @State private var rulePantheonNames: Set<String> = []
    @State private var ruleDomainText = ""
    @State private var ruleNameMatch = ""

    @Query(sort: \FigureType.name) private var figureTypes: [FigureType]
    @Query(sort: \PlaceType.name) private var placeTypes: [PlaceType]
    @Query(sort: \EventType.name) private var eventTypes: [EventType]
    @Query(sort: \ThingType.name) private var thingTypes: [ThingType]
    @Query(sort: \Pantheon.name) private var pantheons: [Pantheon]

    private let stepLabels = ["Identity", "Members"]

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

    /// The sidebar target to persist: `.custom` resolves to the typed section name.
    private var resolvedSidebarTarget: GroupSidebarTarget {
        switch sidebarTarget {
        case .custom:
            let trimmed = customSidebarTargetName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return .auto }
            return .custom(trimmed)
        default:
            return sidebarTarget
        }
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
        (allFigures.map { GroupMemberItem.figure($0, nil) }
            + allPlaces.map { GroupMemberItem.place($0, nil) }
            + allEvents.map { GroupMemberItem.event($0, nil) }
            + allThings.map { GroupMemberItem.thing($0, nil) })
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var filteredCandidates: [GroupMemberItem] {
        searchText.isEmpty ? allCandidates : allCandidates.filter { $0.matches(searchText) }
    }

    private var memberCountLabel: String {
        "\(selectedMemberAliases.count) selected"
    }

    private var availableAggregationTargets: [GroupAggregationTarget] {
        GroupAggregationTarget.allCases.filter { $0.supportedEntityTypes.contains(entityType) }
    }

    private var typePills: [RuleTypePill] {
        switch entityType {
        case .figure: return figureTypes.map { RuleTypePill(name: $0.name, icon: $0.icon, color: $0.color) }
        case .place: return placeTypes.map { RuleTypePill(name: $0.name, icon: $0.icon, color: $0.color) }
        case .event: return eventTypes.map { RuleTypePill(name: $0.name, icon: $0.icon, color: $0.color) }
        case .thing: return thingTypes.map { RuleTypePill(name: $0.name, icon: $0.icon, color: $0.color) }
        }
    }

    private var ruleDomainKeywords: [String] {
        ruleDomainText.split(separator: ",").map(String.init).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    private var hasSmartRule: Bool {
        !ruleTypeNames.isEmpty || !rulePantheonNames.isEmpty || !ruleDomainKeywords.isEmpty || !ruleNameMatch.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// Live preview of how many entities currently match the smart rule.
    private var smartMatchingItems: [GroupMemberItem] {
        guard let rule = buildSmartRule() else { return [] }
        switch entityType {
        case .figure: return allFigures.filter { rule.matches($0) }.map { GroupMemberItem.figure($0, nil) }
        case .place: return allPlaces.filter { rule.matchesPlace($0) }.map { GroupMemberItem.place($0, nil) }
        case .event: return allEvents.filter { rule.matchesEvent($0) }.map { GroupMemberItem.event($0, nil) }
        case .thing: return allThings.filter { rule.matchesThing($0) }.map { GroupMemberItem.thing($0, nil) }
        }
    }

    /// Build the `GroupMemberFilter` from the rule builder fields, or nil when empty.
    private func buildSmartRule() -> GroupMemberFilter? {
        guard hasSmartRule else { return nil }
        switch entityType {
        case .figure:
            return GroupMemberFilter(
                figureTypeNames: ruleTypeNames.isEmpty ? nil : Array(ruleTypeNames),
                domainKeywords: ruleDomainKeywords.isEmpty ? nil : ruleDomainKeywords,
                pantheonNames: rulePantheonNames.isEmpty ? nil : Array(rulePantheonNames),
                nameMatch: ruleNameMatch.trimmingCharacters(in: .whitespaces).isEmpty ? nil : ruleNameMatch.trimmingCharacters(in: .whitespaces)
            )
        case .place:
            return GroupMemberFilter(
                placeTypeNames: ruleTypeNames.isEmpty ? nil : Array(ruleTypeNames),
                nameMatch: ruleNameMatch.trimmingCharacters(in: .whitespaces).isEmpty ? nil : ruleNameMatch.trimmingCharacters(in: .whitespaces)
            )
        case .event:
            return GroupMemberFilter(
                eventTypeNames: ruleTypeNames.isEmpty ? nil : Array(ruleTypeNames),
                nameMatch: ruleNameMatch.trimmingCharacters(in: .whitespaces).isEmpty ? nil : ruleNameMatch.trimmingCharacters(in: .whitespaces)
            )
        case .thing:
            return GroupMemberFilter(
                thingTypeNames: ruleTypeNames.isEmpty ? nil : Array(ruleTypeNames),
                nameMatch: ruleNameMatch.trimmingCharacters(in: .whitespaces).isEmpty ? nil : ruleNameMatch.trimmingCharacters(in: .whitespaces)
            )
        }
    }

    /// Load a stored filter into the rule builder fields (entity-type aware).
    private func loadRule(from filter: GroupMemberFilter?) {
        guard let filter else {
            ruleTypeNames = []
            rulePantheonNames = []
            ruleDomainText = ""
            ruleNameMatch = ""
            return
        }
        switch entityType {
        case .figure:
            ruleTypeNames = Set(filter.figureTypeNames ?? [])
            rulePantheonNames = Set(filter.pantheonNames ?? [])
            ruleDomainText = (filter.domainKeywords ?? []).joined(separator: ", ")
        case .place: ruleTypeNames = Set(filter.placeTypeNames ?? [])
        case .event: ruleTypeNames = Set(filter.eventTypeNames ?? [])
        case .thing: ruleTypeNames = Set(filter.thingTypeNames ?? [])
        }
        ruleNameMatch = filter.nameMatch ?? ""
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
            entityName: name,
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

                Picker("Group Type", selection: $entityType) {
                    ForEach(GroupEntityType.allCases, id: \.self) { type in
                        Text(type.pluralName).tag(type)
                    }
                }
                .help("The group's primary type — used for sidebar placement, smart rules, and summaries. Members of any kind can be added to any group.")

                Section("Member Labels") {
                    TextField("Singular", text: $memberSingular, prompt: Text("ruler"))
                        .textFieldStyle(.roundedBorder)
                        .help("What to call one member of this group. Leave empty to use \"member\".")
                    TextField("Plural", text: $memberPlural, prompt: Text("rulers"))
                        .textFieldStyle(.roundedBorder)
                        .help("What to call multiple members of this group. Leave empty to use \"members\".")
                    if !memberSingular.isEmpty || !memberPlural.isEmpty {
                        Text("\(memberSingular.isEmpty ? "1 member" : "1 \(memberSingular)") / \(memberPlural.isEmpty ? "7 members" : "7 \(memberPlural)")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

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
                    set: { colorHex = $0.hex }
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

                Section("Summary") {
                    Toggle("Show aggregated summary", isOn: $aggregationEnabled)
                        .help("Compute a sum or average over member values and display it in the group header.")
                    if aggregationEnabled {
                        if availableAggregationTargets.isEmpty {
                            Text("No aggregateable fields for \(entityType.pluralName.lowercased()).")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Picker("Operation", selection: $aggregationOperation) {
                                ForEach(GroupAggregationOperation.allCases, id: \.self) { operation in
                                    Text(operation.displayName).tag(operation)
                                }
                            }
                            Picker("Target", selection: $aggregationTarget) {
                                ForEach(availableAggregationTargets, id: \.self) { target in
                                    Text(target.displayName).tag(target)
                                }
                            }
                            TextField("Label (optional)", text: $aggregationLabel, prompt: Text("e.g. Total dynasty reign"))
                                .textFieldStyle(.roundedBorder)
                                .help("Custom text shown before the value; leave empty for an auto-generated label.")
                        }
                    }
                }

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

                Picker("Sidebar section", selection: Binding(
                    get: { sidebarTarget },
                    set: { newValue in
                        sidebarTarget = newValue
                        if case .custom = newValue, customSidebarTargetName.isEmpty {
                            customSidebarTargetName = name.isEmpty ? "Custom" : name
                        }
                    }
                )) {
                    Text("Automatic (by type)").tag(GroupSidebarTarget.auto)
                    Text("History").tag(GroupSidebarTarget.history)
                    Text("Data").tag(GroupSidebarTarget.data)
                    Text("Custom section…").tag(GroupSidebarTarget.custom(""))
                }
                .help("Where this group appears in the sidebar. Automatic places figures in History and other types in their own \"X Groups\" section.")

                if case .custom = sidebarTarget {
                    TextField("Section name", text: $customSidebarTargetName)
                        .textFieldStyle(.roundedBorder)
                        .help("Name of the custom sidebar section this group appears in.")
                }
            }
        }
        .formStyle(.grouped)
        .onChange(of: entityType) { _, newType in
            if newType != .figure { kind = .standard }
            ruleTypeNames.removeAll()
            if availableAggregationTargets.isEmpty {
                aggregationEnabled = false
            }
        }
    }

    private var membersStep: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: isSmart ? "bolt.fill" : "magnifyingglass")
                    .foregroundStyle(isSmart ? Color.teal : .secondary)
                    .font(.caption)
                Toggle("Smart group — members come from a rule", isOn: $isSmart)
                    .font(.callout)
                    .toggleStyle(.checkbox)
                Spacer()
            }
            .padding(.horizontal)

            if isSmart {
                smartRuleStep
            } else {
                manualPickerStep
            }
        }
        .padding(.vertical)
    }

    private var manualPickerStep: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                TextField("Search members...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
            }
            .padding(.horizontal)

            Text(selectedMemberAliases.isEmpty ? "No members selected" : memberCountLabel)
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
                    Task { @MainActor in
                        toggleMember(candidate)
                    }
                }
            }
            .listStyle(.plain)
        }
    }

    private var smartRuleStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Every \(entityType.displayName.lowercased()) that matches the rule below is a member — re-evaluated live whenever the group is shown. New ones appear automatically; no manual picking.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 6) {
                    Text("By \(entityType.displayName) Type")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    let columns = [GridItem(.adaptive(minimum: 140))]
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 6) {
                        ForEach(typePills) { pill in
                            ruleTypeFilterButton(pill)
                        }
                    }
                }

                if entityType == .figure {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("By Domain Keyword")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("e.g. Sumerian, Akkadian, Kingship", text: $ruleDomainText)
                            .textFieldStyle(.roundedBorder)
                    }
                }

                if entityType == .figure && !pantheons.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("By Pantheon")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        let columns = [GridItem(.adaptive(minimum: 140))]
                        LazyVGrid(columns: columns, alignment: .leading, spacing: 6) {
                            ForEach(pantheons) { pantheon in
                                let isSelected = rulePantheonNames.contains(pantheon.name)
                                Button {
                                    if isSelected { rulePantheonNames.remove(pantheon.name) }
                                    else { rulePantheonNames.insert(pantheon.name) }
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: pantheon.icon)
                                            .font(.caption)
                                            .foregroundStyle(pantheon.color)
                                        Text(pantheon.name)
                                            .font(.caption)
                                            .lineLimit(1)
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(isSelected ? pantheon.color.opacity(0.15) : Color(.textBackgroundColor))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(isSelected ? pantheon.color : Color.gray.opacity(0.3), lineWidth: isSelected ? 1.5 : 0.5)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("By Name")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("e.g. Enki, Gilgamesh", text: $ruleNameMatch)
                        .textFieldStyle(.roundedBorder)
                }

                Divider()

                if let rule = buildSmartRule() {
                    HStack(spacing: 8) {
                        Text("\(smartMatchingItems.count) \(entityType.pluralName.lowercased()) currently match")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        Spacer()
                        if smartMatchingItems.count > 0 {
                            Text(rule.summary)
                                .font(.caption2)
                                .foregroundStyle(.teal)
                        }
                    }
                    if !smartMatchingItems.isEmpty {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            ForEach(smartMatchingItems.prefix(15), id: \.id) { item in
                                HStack(spacing: 10) {
                                    Image(systemName: item.icon)
                                        .font(.caption)
                                        .foregroundStyle(item.color)
                                        .frame(width: 16)
                                    Text(item.name)
                                        .font(.callout)
                                }
                            }
                            if smartMatchingItems.count > 15 {
                                Text("... and \(smartMatchingItems.count - 15) more")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.system(size: 20))
                            .foregroundStyle(.secondary)
                        Text("Define at least one criterion — the group starts empty until you do.")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 8)
                }
            }
            .padding(.horizontal)
        }
    }

    private func ruleTypeFilterButton(_ pill: RuleTypePill) -> some View {
        let isSelected = ruleTypeNames.contains(pill.name)
        return Button(action: {
            if isSelected { ruleTypeNames.remove(pill.name) }
            else { ruleTypeNames.insert(pill.name) }
        }) {
            HStack(spacing: 6) {
                Image(systemName: pill.icon)
                    .font(.caption)
                    .foregroundStyle(pill.color)
                Text(pill.name)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? pill.color.opacity(0.15) : Color(.textBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? pill.color : Color.gray.opacity(0.3), lineWidth: isSelected ? 1.5 : 0.5)
            )
        }
        .buttonStyle(.plain)
        .pointingHand()
    }

    private func toggleMember(_ candidate: GroupMemberItem) {
        if selectedMemberAliases[candidate.id] != nil {
            selectedMemberAliases.removeValue(forKey: candidate.id)
        } else {
            selectedMemberAliases[candidate.id] = candidate.matchedAlternateName(for: searchText) ?? ""
        }
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
        sidebarTarget = group.sidebarTarget
        if case .custom(let sectionName) = group.sidebarTarget {
            customSidebarTargetName = sectionName
        }
        isSmart = group.isSmart
        parentGroupID = group.parentGroup?.persistentModelID
        memberSingular = group.memberSingular ?? ""
        memberPlural = group.memberPlural ?? ""
        loadRule(from: group.decodedFilter)
        selectedMemberAliases = Dictionary(uniqueKeysWithValues: group.figureAssociations.compactMap { assoc in
            guard let id = memberID(assoc) else { return nil }
            return (id, assoc.displayName ?? "")
        })
        if let agg = group.decodedAggregation {
            aggregationEnabled = true
            aggregationOperation = agg.operation
            aggregationTarget = agg.target
            aggregationLabel = agg.label ?? ""
        }
    }

    private func save() {
        let newMemberAliases = selectedMemberAliases
        let newParent = allGroups.first { $0.persistentModelID == parentGroupID }
        let effectiveKind: GroupKind = entityType == .figure ? kind : .standard
        let newAggregation = buildAggregation()
        let rule = buildSmartRule()

        if let group {
            group.name = name
            group.groupDescription = groupDescription
            group.richDescription = richDescription
            group.icon = icon
            group.colorHex = colorHex
            group.kind = effectiveKind
            group.entityType = entityType
            group.isPublished = isPublished
            group.isSmart = isSmart
            group.sidebarTarget = resolvedSidebarTarget
            if isSmart {
                group.decodedFilter = rule
            }
            group.memberSingular = memberSingular.isEmpty ? nil : memberSingular
            group.memberPlural = memberPlural.isEmpty ? nil : memberPlural
            group.decodedAggregation = newAggregation
            setParent(group, parent: newParent)
            if !isSmart {
                syncMembers(group: group, newAliases: newMemberAliases)
            }
        } else {
            let newGroup = FigureGroup(
                name: name, groupDescription: groupDescription, icon: icon, colorHex: colorHex,
                isSmart: isSmart, kind: effectiveKind, entityType: entityType
            )
            newGroup.richDescription = richDescription
            newGroup.isPublished = isPublished
            newGroup.sidebarTarget = resolvedSidebarTarget
            if isSmart {
                newGroup.decodedFilter = rule
            }
            newGroup.memberSingular = memberSingular.isEmpty ? nil : memberSingular
            newGroup.memberPlural = memberPlural.isEmpty ? nil : memberPlural
            newGroup.decodedAggregation = newAggregation
            modelContext.insert(newGroup)
            setParent(newGroup, parent: newParent)
            if !isSmart {
                syncMembers(group: newGroup, newAliases: newMemberAliases)
            }
        }
        try? modelContext.save()
        showSuccessAlert = true
    }

    private func buildAggregation() -> GroupAggregation? {
        guard aggregationEnabled, availableAggregationTargets.contains(aggregationTarget) else { return nil }
        return GroupAggregation(
            operation: aggregationOperation,
            target: aggregationTarget,
            label: aggregationLabel.isEmpty ? nil : aggregationLabel
        )
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

    private func memberID(_ assoc: FigureGroupAssociation) -> PersistentIdentifier? {
        assoc.figure?.persistentModelID
            ?? assoc.place?.persistentModelID
            ?? assoc.event?.persistentModelID
            ?? assoc.thing?.persistentModelID
    }

    private func candidate(for id: PersistentIdentifier) -> GroupMemberItem? {
        allCandidates.first { $0.id == id }
    }

    private func syncMembers(group: FigureGroup, newAliases: [PersistentIdentifier: String]) {
        let existing = group.figureAssociations
        let existingIDs = Set(existing.compactMap { memberID($0) })
        let newIDs = Set(newAliases.keys)

        let toRemove = existing.filter { assoc in
            guard let id = memberID(assoc) else { return false }
            return !newIDs.contains(id)
        }
        for assoc in toRemove {
            if let event = assoc.event {
                group.removeEventWithDepropagation(event: event, in: modelContext)
            } else {
                modelContext.delete(assoc)
            }
        }

        for assoc in existing {
            guard let id = memberID(assoc), newIDs.contains(id) else { continue }
            assoc.displayName = newAliases[id].flatMap { $0.isEmpty ? nil : $0 }
        }

        let toAdd = newIDs.subtracting(existingIDs)
        for id in toAdd {
            guard let candidate = candidate(for: id) else { continue }
            if case .event(let event, _) = candidate {
                group.addEventWithPropagation(event: event, in: modelContext)
            } else {
                let assoc = makeAssociation(for: candidate)
                assoc.displayName = newAliases[id].flatMap { $0.isEmpty ? nil : $0 }
                modelContext.insert(assoc)
                group.figureAssociations.append(assoc)
            }
        }
    }

    private func makeAssociation(for candidate: GroupMemberItem) -> FigureGroupAssociation {
        candidate.makeAssociation()
    }
}

private struct RuleTypePill: Identifiable {
    let name: String
    let icon: String
    let color: Color

    var id: String { name }
}

