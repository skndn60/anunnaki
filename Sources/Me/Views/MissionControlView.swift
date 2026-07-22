import SwiftUI
import SwiftData

struct MissionControlView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Agent.createdAt, order: .reverse) private var agents: [Agent]
    @Query private var blindSpots: [BlindSpot]
    @Query private var figures: [Figure]
    @Environment(\.openWindow) private var openWindow
    @State private var showingDispatchSheet = false
    @State private var selectedAgentID: PersistentIdentifier?
    @State private var showDeleteConfirm = false
    @State private var showScanning = false
    @State private var blindSpotFilter: BlindSpotCategory? = nil
    @State private var dispatchingSpot: BlindSpot?
    @State private var dispatchQuery: String = ""
    @AppStorage("missionControlDetailWidth") private var detailWidth: Double = 480

    @Query private var blockedSources: [BlockedSource]

    private let service = AgentService.shared

    private var blockedURLs: Set<String> {
        Set(blockedSources.map { $0.sourceURL })
    }

    private var unresolvedBlindSpots: [BlindSpot] {
        let base = blindSpots.filter { !$0.isResolved }
        guard let filter = blindSpotFilter else { return base }
        return base.filter { $0.categoryEnum == filter }
    }

    private var selectedAgent: Agent? {
        guard let id = selectedAgentID else { return nil }
        return agents.first { $0.persistentModelID == id }
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                header
                Divider()
                agentList
                Divider()
                blindSpotSection
                if !blockedSources.isEmpty {
                    Divider()
                    blockedSourcesSection
                }
            }
            .frame(minWidth: 400, maxWidth: .infinity)

            if let agent = selectedAgent {
                ResizableDivider(width: $detailWidth, range: 200...800)
                detailPanel(agent: agent)
                    .frame(width: detailWidth)
                    .background(.thinMaterial)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: selectedAgentID)
        .sheet(isPresented: $showingDispatchSheet) {
            dispatchSheet
        }
        .alert("Delete Agent?", isPresented: $showDeleteConfirm, presenting: selectedAgent) { agent in
            Button("Delete", role: .destructive) { deleteAgent(agent) }
            Button("Cancel", role: .cancel) {}
        } message: { agent in
            Text("Delete \"\(agent.name)\"? Collected data will also be removed.")
        }
    }

    private var header: some View {
        HStack {
            Text("Mission Control")
                .font(.title2.bold())
            Spacer()
            Button(action: { showingDispatchSheet = true }) {
                Label("New Agent", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private var agentList: some View {
        Group {
            if agents.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("No agents yet")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Text("Dispatch an agent to start collecting data")
                        .font(.callout)
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                List(selection: $selectedAgentID) {
                    ForEach(agents) { agent in
                        agentRow(agent: agent)
                            .tag(agent.persistentModelID)
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }
        }
    }

    private func agentRow(agent: Agent) -> some View {
        HStack(spacing: 10) {
            statusDot(agent.statusEnum)
            VStack(alignment: .leading, spacing: 2) {
                Text(agent.name.isEmpty ? agent.missionParameter : agent.name)
                    .fontWeight(.medium)
                Text(agent.missionParameter)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(agent.currentActivity)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .italic()
                    .frame(height: 14, alignment: .leading)
            }
            Spacer()
            Text("\(agent.collectedData.count)/\(agent.targetCount)")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .monospacedDigit()
            statusLabel(agent.statusEnum)
                .font(.caption)
            HStack(spacing: 2) {
                if agent.statusEnum == .running {
                    IconActionButton(icon: "pause.fill", color: .orange, help: "Pause") {
                        service.pauseAgent(agent, context: modelContext)
                    }
                }
                if agent.statusEnum == .paused || agent.statusEnum == .completed {
                    IconActionButton(icon: "play.fill", color: .green, help: "Resume") {
                        service.resumeAgent(agent, context: modelContext)
                    }
                }
                if agent.statusEnum == .running || agent.statusEnum == .paused {
                    IconActionButton(icon: "xmark", color: .red, help: "Recall") {
                        service.recallAgent(agent, context: modelContext)
                    }
                }
                if agent.statusEnum == .idle || agent.statusEnum == .completed || agent.statusEnum == .failed {
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.red)
                    .help("Delete agent and all collected data")
                }
            }
        }
        .padding(.vertical, 4)
        .onHover { hovering in
            if hovering { NSCursor.pointingHand.push() }
            else { NSCursor.pop() }
        }
    }

    private func statusDot(_ status: AgentStatus) -> some View {
        Circle()
            .fill(statusColor(status))
            .frame(width: 8, height: 8)
    }

    private func statusLabel(_ status: AgentStatus) -> some View {
        Text(status.rawValue)
            .foregroundStyle(statusColor(status))
    }

    private func statusColor(_ status: AgentStatus) -> Color {
        switch status {
        case .idle: return .gray
        case .running: return .green
        case .paused: return .orange
        case .completed: return .blue
        case .failed: return .red
        }
    }

    private func detailPanel(agent: Agent) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Button(action: { selectedAgentID = nil }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 22, height: 22)
                        .background(
                            RoundedRectangle(cornerRadius: 5)
                                .fill(Color.secondary.opacity(0.1))
                        )
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    if hovering { NSCursor.pointingHand.push() }
                    else { NSCursor.pop() }
                }
                Spacer()
                Text("\(agent.collectedData.count) items")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 8)

            if agent.collectedData.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "tray")
                        .font(.system(size: 32))
                        .foregroundStyle(.tertiary)
                    Text("No data collected yet")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            } else {
                List {
                    ForEach(agent.collectedData) { datum in
                        DatumRow(
                            datum: datum,
                            isBlocked: blockedURLs.contains(datum.sourceURL),
                            onZoom: { openWindow(id: "datum-zoom", value: datum.persistentModelID) },
                            onReview: { toggleReview(datum) },
                            onReject: { rejectDatum(datum) },
                            onRejectBlock: { rejectAndBlockDatum(datum) }
                        )
                    }
                }
                .listStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
    }

    private func toggleReview(_ datum: CollectedDatum) {
        datum.isReviewed = !(datum.isReviewed ?? false)
        try? modelContext.save()
    }

    private func rejectDatum(_ datum: CollectedDatum) {
        modelContext.delete(datum)
        try? modelContext.save()
    }

    private func rejectAndBlockDatum(_ datum: CollectedDatum) {
        let blocked = BlockedSource(
            sourceURL: datum.sourceURL,
            sourceTitle: datum.sourceTitle
        )
        modelContext.insert(blocked)
        modelContext.delete(datum)
        try? modelContext.save()
    }

    private var blindSpotSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .foregroundStyle(.secondary)
                Text("Blind Spots")
                    .font(.headline)
                Spacer()
                if showScanning {
                    Text("Scanning\u{2026}")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Button("Scan") {
                        scanBlindSpots()
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)

            if !blindSpots.isEmpty {
                HStack(spacing: 6) {
                    categoryFilterButton(label: "All", category: nil)
                    ForEach(BlindSpotCategory.allCases, id: \.rawValue) { cat in
                        categoryFilterButton(label: cat.rawValue, category: cat)
                    }
                }
                .padding(.horizontal)
                .font(.caption)
            }

            if blindSpots.isEmpty {
                Text("No blind spots detected")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
            } else {
                List {
                    ForEach(unresolvedBlindSpots) { spot in
                        BlindSpotRow(
                            spot: spot,
                            onToggleCategory: { toggleBlindSpotCategory(spot) },
                            onViewFigure: { openFigureQuicklook(name: spot.figureName) },
                            onDispatch: { _ in presentDispatch(spot) }
                        )
                    }
                }
                .listStyle(.plain)
                .frame(height: min(CGFloat(unresolvedBlindSpots.count) * 52, 260))
            }
        }
        .sheet(item: $dispatchingSpot) { spot in
            DispatchBlindSpotSheet(
                spot: spot,
                query: dispatchQuery,
                onUpdateQuery: { dispatchQuery = $0 },
                onDispatch: { dispatchBlindSpotAgent(spot, query: dispatchQuery) },
                onMarkKnownGap: { markBlindSpotAsKnownGap(spot) },
                onMarkPermanentGap: { markBlindSpotAsPermanentGap(spot) }
            )
        }
    }

    private func categoryFilterButton(label: String, category: BlindSpotCategory?) -> some View {
        CategoryFilterButton(
            label: label,
            category: category,
            isSelected: blindSpotFilter == category,
            onSelect: { blindSpotFilter = category }
        )
    }

    private var blockedSourcesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "hand.raised.fill")
                    .foregroundStyle(.secondary)
                Text("Blocked Sources")
                    .font(.headline)
                Text("(\(blockedSources.count))")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 8)

            List {
                ForEach(blockedSources) { source in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(source.sourceTitle)
                                .font(.caption)
                                .fontWeight(.medium)
                            Text(source.sourceURL)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                            Text("Blocked \(source.blockedAt.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        Spacer()
                        Button("Unblock") {
                            modelContext.delete(source)
                            try? modelContext.save()
                        }
                        .buttonStyle(.plain)
                        .font(.caption)
                        .foregroundColor(.accentColor)
                        .onHover { hovering in
                            if hovering { NSCursor.pointingHand.push() }
                            else { NSCursor.pop() }
                        }
                    }
                }
            }
            .listStyle(.plain)
            .frame(height: min(CGFloat(blockedSources.count) * 56, 140))
        }
    }

    private func scanBlindSpots() {
        let majorTypes: Set<String> = ["Deity", "Primordial", "Archangel", "Igigi"]
        showScanning = true
        Task { @MainActor in
            let existing = Set(blindSpots.map { "\($0.figureName)-\($0.blindSpotType)" })
            var newCount = 0
            for figure in figures {
                guard let typeName = figure.figureType?.name, majorTypes.contains(typeName) else { continue }

                let key = { (type: BlindSpotType) in "\(figure.name)-\(type.rawValue)" }

                let hasParent = figure.incomingRelationships.contains { $0.relationshipType?.name == "Father" || $0.relationshipType?.name == "Mother" }
                if !hasParent && !existing.contains(key(.missingParent)) {
                    let spot = BlindSpot(figureName: figure.name, blindSpotType: .missingParent, spotDescription: "\(figure.name) has no recorded parent", suggestedQuery: "Who are the parents of \(figure.name)?")
                    modelContext.insert(spot)
                    newCount += 1
                }

                let hasChild = figure.outgoingRelationships.contains { $0.relationshipType?.name == "Father" || $0.relationshipType?.name == "Mother" }
                if !hasChild && !existing.contains(key(.missingChild)) {
                    let spot = BlindSpot(figureName: figure.name, blindSpotType: .missingChild, spotDescription: "\(figure.name) has no recorded child", suggestedQuery: "Who are the children of \(figure.name)?")
                    modelContext.insert(spot)
                    newCount += 1
                }

                if figure.placeAssociations.isEmpty && !existing.contains(key(.missingPlace)) {
                    let spot = BlindSpot(figureName: figure.name, blindSpotType: .missingPlace, spotDescription: "\(figure.name) has no place associations", suggestedQuery: "What is the cult center or primary temple of \(figure.name)?")
                    modelContext.insert(spot)
                    newCount += 1
                }

                if figure.events.isEmpty && !existing.contains(key(.missingEvent)) {
                    let spot = BlindSpot(figureName: figure.name, blindSpotType: .missingEvent, spotDescription: "\(figure.name) has no associated events", suggestedQuery: "What mythological events is \(figure.name) involved in?")
                    modelContext.insert(spot)
                    newCount += 1
                }
            }
            try? modelContext.save()
            showScanning = false
        }
    }

    private func toggleBlindSpotCategory(_ spot: BlindSpot) {
        spot.categoryEnum = spot.categoryEnum == .unresearched ? .knownGap : .unresearched
        try? modelContext.save()
    }

    private func markBlindSpotAsKnownGap(_ spot: BlindSpot) {
        spot.categoryEnum = .knownGap
        try? modelContext.save()
    }

    private func openFigureQuicklook(name: String) {
        guard let figure = figures.first(where: { $0.name == name }) else { return }
        openWindow(id: "figure-quickview", value: figure.persistentModelID)
    }

    private func markBlindSpotAsPermanentGap(_ spot: BlindSpot) {
        spot.categoryEnum = .knownGap
        spot.isResolved = true
        try? modelContext.save()
    }

    private func presentDispatch(_ spot: BlindSpot) {
        dispatchQuery = spot.suggestedQuery ?? spot.figureName
        dispatchingSpot = spot
    }

    private func dispatchBlindSpotAgent(_ spot: BlindSpot, query: String) {
        let typeLabel = BlindSpotType(rawValue: spot.blindSpotType)?.rawValue ?? "Blind Spot"
        let agent = Agent(
            name: "\(typeLabel): \(spot.figureName)",
            missionParameter: query,
            phase: 2
        )
        modelContext.insert(agent)
        agent.blindSpots.append(spot)
        spot.isResolved = true
        try? modelContext.save()
        service.dispatchAgent(agent, context: modelContext)
    }

    private var dispatchSheet: some View {
        DispatchAgentSheet { agent in
            modelContext.insert(agent)
            try? modelContext.save()
            service.dispatchAgent(agent, context: modelContext)
        }
    }

    private func deleteAgent(_ agent: Agent) {
        if selectedAgentID == agent.persistentModelID {
            selectedAgentID = nil
        }
        service.deleteAgent(agent, context: modelContext)
    }
}

private struct DispatchAgentSheet: View {
    @Environment(\.dismiss) var dismiss
    let onDispatch: (Agent) -> Void

    @State private var name = ""
    @State private var missionParameter = ""
    @State private var targetCount = 10

    var body: some View {
        VStack(spacing: 0) {
            Text("Dispatch New Agent")
                .font(.title3.bold())
                .padding()

            Form {
                TextField("Agent Name", text: $name, prompt: Text("Optional — defaults to search query"))
                TextField("Search Query", text: $missionParameter, prompt: Text("e.g. Enki, Sumerian deities"))
                    .help("The search term the agent will use to collect data")
                Stepper("Target: \(targetCount) results", value: $targetCount, in: 1...50)
            }
            .formStyle(.grouped)

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Dispatch") {
                    let agent = Agent(
                        name: name.isEmpty ? missionParameter : name,
                        missionParameter: missionParameter,
                        phase: 1,
                        targetCount: targetCount
                    )
                    onDispatch(agent)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(missionParameter.isEmpty)
            }
            .padding()
        }
        .frame(width: 420, height: 280)
    }
}

private struct BlindSpotRow: View {
    let spot: BlindSpot
    let onToggleCategory: () -> Void
    let onViewFigure: () -> Void
    let onDispatch: (BlindSpot) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Circle()
                    .fill(typeColor)
                    .frame(width: 6, height: 6)
                Button(action: onViewFigure) {
                    Text(spot.figureName)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)
                .help("View figure details")
                .onHover { hovering in
                    if hovering { NSCursor.pointingHand.push() }
                    else { NSCursor.pop() }
                }
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                categoryBadge
                Button("Agent") {
                    onDispatch(spot)
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundColor(.accentColor)
                .onHover { hovering in
                    if hovering { NSCursor.pointingHand.push() }
                    else { NSCursor.pop() }
                }
            }
            if let query = spot.suggestedQuery {
                Text(query)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .padding(.leading, 18)
            }
        }
    }

    private var categoryBadge: some View {
        Button(action: onToggleCategory) {
            HStack(spacing: 2) {
                Image(systemName: spot.categoryEnum == .unresearched ? "questionmark.circle" : "eye.slash")
                    .font(.caption2)
                Text(spot.categoryEnum.rawValue)
                    .font(.caption2)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(categoryColor.opacity(0.12))
            .cornerRadius(4)
        }
        .buttonStyle(.plain)
        .help("Toggle between Unresearched / Known Gap")
        .onHover { hovering in
            if hovering { NSCursor.pointingHand.push() }
            else { NSCursor.pop() }
        }
    }

    private var type: BlindSpotType {
        BlindSpotType(rawValue: spot.blindSpotType) ?? .missingParent
    }

    private var label: String {
        type.rawValue
    }

    private var typeColor: Color {
        switch type {
        case .missingParent: return .red
        case .missingChild: return .orange
        case .missingPlace: return .teal
        case .missingEvent: return .purple
        }
    }

    private var categoryColor: Color {
        spot.categoryEnum == .unresearched ? .orange : .secondary
    }
}

private struct DatumRow: View {
    let datum: CollectedDatum
    let isBlocked: Bool
    let onZoom: () -> Void
    let onReview: () -> Void
    let onReject: () -> Void
    let onRejectBlock: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                if datum.isReviewed ?? false {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                        .help("Reviewed")
                }
                Text(datum.sourceTitle)
                    .fontWeight(.medium)
                    .lineLimit(1)
                Spacer()
                if isBlocked {
                    Image(systemName: "hand.raised.fill")
                        .font(.caption2)
                        .foregroundStyle(.red)
                        .help("Source is blocked")
                }
            }
            Text(datum.sourceURL)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
            Text(datum.acquiredAt.formatted(date: .abbreviated, time: .shortened))
                .font(.caption2)
                .foregroundStyle(.tertiary)
            HStack(spacing: 4) {
                Button(action: onZoom) {
                    Label("Zoom", systemImage: "magnifyingglass")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .help("View full data")
                .onHover { hovering in
                    if hovering { NSCursor.pointingHand.push() }
                    else { NSCursor.pop() }
                }
                Button(action: onReview) {
                    Label(datum.isReviewed ?? false ? "Reviewed" : "Mark Reviewed", systemImage: datum.isReviewed ?? false ? "checkmark.circle.fill" : "circle")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .foregroundColor(datum.isReviewed ?? false ? .green : .secondary)
                .help(datum.isReviewed ?? false ? "Mark as unreviewed" : "Mark as reviewed")
                .onHover { hovering in
                    if hovering { NSCursor.pointingHand.push() }
                    else { NSCursor.pop() }
                }
                Button(action: onReject) {
                    Label("Reject", systemImage: "trash")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .foregroundColor(.red)
                .help("Remove this datum")
                .onHover { hovering in
                    if hovering { NSCursor.pointingHand.push() }
                    else { NSCursor.pop() }
                }
                Button(action: onRejectBlock) {
                    Label("Reject & Block", systemImage: "hand.raised")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .foregroundColor(.red)
                .help("Remove and block this source")
                .onHover { hovering in
                    if hovering { NSCursor.pointingHand.push() }
                    else { NSCursor.pop() }
                }
            }
            .padding(.top, 2)
        }
        .padding(.vertical, 4)
    }
}

struct DatumZoomWindow: View {
    let datumID: PersistentIdentifier?
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var datum: CollectedDatum?
    @State private var isFormatted = true

    var body: some View {
        Group {
            if let datum {
                content(datum: datum)
            } else {
                Text("Collected data not found")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            guard let datumID else { return }
            let fetch = FetchDescriptor<CollectedDatum>(predicate: #Predicate { $0.persistentModelID == datumID })
            datum = try? modelContext.fetch(fetch).first
        }
    }

    private func content(datum: CollectedDatum) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(datum.sourceTitle)
                    .font(.headline)
                Spacer()
                Toggle("Formatted", isOn: $isFormatted)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                Toggle(isOn: reviewedBinding(datum)) {
                    Label("Reviewed", systemImage: "checkmark.circle")
                }
                .toggleStyle(.switch)
                .controlSize(.small)
            }
            .padding()

            Divider()

            ScrollView(.vertical) {
                Text(displayText(datum))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider()

            HStack {
                Text(datum.sourceURL)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .textSelection(.enabled)
                Spacer()
                Text(datum.acquiredAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding()
        }
    }

    private func reviewedBinding(_ datum: CollectedDatum) -> Binding<Bool> {
        Binding(
            get: { datum.isReviewed ?? false },
            set: { newValue in
                datum.isReviewed = newValue
                try? modelContext.save()
            }
        )
    }

    private func displayText(_ datum: CollectedDatum) -> String {
        if isFormatted {
            guard let data = datum.content.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data),
                  let pretty = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]),
                  let text = String(data: pretty, encoding: .utf8)
            else { return datum.content }
            return text
        }
        return datum.content
    }
}

private struct DispatchBlindSpotSheet: View {
    @Environment(\.dismiss) var dismiss
    let spot: BlindSpot
    let query: String
    let onUpdateQuery: (String) -> Void
    let onDispatch: () -> Void
    let onMarkKnownGap: () -> Void
    let onMarkPermanentGap: () -> Void

    @State private var editableQuery: String = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Dispatch Agent")
                    .font(.title3.bold())
                Spacer()
            }
            .padding()

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(typeColor)
                        .frame(width: 8, height: 8)
                    Text(spot.figureName)
                        .font(.headline)
                    Text(typeLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(spot.spotDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.bottom, 12)

            Form {
                TextField("Search Query", text: $editableQuery)
                    .textFieldStyle(.roundedBorder)
                    .help("The search term the agent will use. Edit to refine.")
            }
            .formStyle(.grouped)
            .onAppear {
                editableQuery = query
            }

            HStack {
                Button("Known Gap") {
                    onMarkKnownGap()
                    dismiss()
                }
                .buttonStyle(.plain)
                .foregroundColor(.orange)
                .help("Known gap — maybe new info emerges later")
                Button("Never Known") {
                    onMarkPermanentGap()
                    dismiss()
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                .help("This will never be known — dismiss permanently")
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Dispatch") {
                    onUpdateQuery(editableQuery)
                    onDispatch()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(editableQuery.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()
        }
        .frame(width: 480, height: 340)
    }

    private var type: BlindSpotType {
        BlindSpotType(rawValue: spot.blindSpotType) ?? .missingParent
    }

    private var typeLabel: String {
        type.rawValue
    }

    private var typeColor: Color {
        switch type {
        case .missingParent: return .red
        case .missingChild: return .orange
        case .missingPlace: return .teal
        case .missingEvent: return .purple
        }
    }
}

private struct CategoryFilterButton: View {
    let label: String
    let category: BlindSpotCategory?
    let isSelected: Bool
    let onSelect: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            Text(label)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    isSelected ? Color.accentColor.opacity(0.15) :
                    isHovered ? Color.accentColor.opacity(0.08) : Color.clear
                )
                .cornerRadius(4)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
            if hovering { NSCursor.pointingHand.push() }
            else { NSCursor.pop() }
        }
    }
}
