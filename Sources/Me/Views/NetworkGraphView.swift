import SwiftUI
import SwiftData

// MARK: - Graph Node

struct GraphNode: Identifiable, Equatable {
    let id: UUID
    let name: String
    let type: NodeType
    let color: Color
    let figureTypeName: String?
    let placeTypeName: String?
    let eventTypeName: String?
    let persistentModelID: PersistentIdentifier?
    var position: CGPoint
    var velocity: CGPoint
    var isPinned: Bool

    enum NodeType: String, CaseIterable {
        case figure = "Figures"
        case place = "Places"
        case event = "Events"

        var color: Color {
            switch self {
            case .figure: return .blue
            case .place: return .green
            case .event: return .orange
            }
        }

        var icon: String {
            switch self {
            case .figure: return "person.fill"
            case .place: return "building.columns.fill"
            case .event: return "bolt.fill"
            }
        }
    }
}

// MARK: - Graph Edge

struct GraphEdge: Identifiable {
    let id: UUID
    let sourceID: UUID
    let targetID: UUID
    let label: String
    let color: Color
}

// MARK: - Force Simulation Engine

struct ForceEngine {
    let repulsion: CGFloat = 80000
    let attraction: CGFloat = 0.005
    let centerGravity: CGFloat = 0.002
    let damping: CGFloat = 0.85
    let minDistance: CGFloat = 10
    let maxVelocity: CGFloat = 50
    let cellSize: CGFloat = 90
    var temperature: CGFloat = 1.0
    let coolingRate: CGFloat = 0.997
    let minTemperature: CGFloat = 0.01

    /// Advances the simulation one step. Returns the maximum node speed this
    /// step so the caller can stop once the layout has settled.
    @discardableResult
    mutating func tick(nodes: inout [GraphNode], edges: [GraphEdge], size: CGSize) -> CGFloat {
        let count = nodes.count
        guard count > 0 else { return 0 }

        var forces: [UUID: CGPoint] = [:]
        forces.reserveCapacity(count)
        for node in nodes { forces[node.id] = .zero }

        var indexOf: [UUID: Int] = [:]
        indexOf.reserveCapacity(count)
        for (i, node) in nodes.enumerated() { indexOf[node.id] = i }

        applyGridRepulsion(nodes: nodes, forces: &forces)

        for edge in edges {
            guard let si = indexOf[edge.sourceID], let ti = indexOf[edge.targetID] else { continue }
            let a = nodes[si], b = nodes[ti]
            var delta = CGPoint(x: b.position.x - a.position.x, y: b.position.y - a.position.y)
            let dist = max(sqrt(delta.x * delta.x + delta.y * delta.y), minDistance)
            let force = attraction * dist
            delta = CGPoint(x: delta.x / dist * force, y: delta.y / dist * force)
            forces[a.id] = CGPoint(x: forces[a.id]!.x + delta.x, y: forces[a.id]!.y + delta.y)
            forces[b.id] = CGPoint(x: forces[b.id]!.x - delta.x, y: forces[b.id]!.y - delta.y)
        }

        let cx = size.width / 2, cy = size.height / 2
        for i in 0..<count {
            let node = nodes[i]
            if node.isPinned { continue }
            let dx = cx - node.position.x, dy = cy - node.position.y
            forces[node.id] = CGPoint(
                x: forces[node.id]!.x + dx * centerGravity,
                y: forces[node.id]!.y + dy * centerGravity
            )
        }

        var maxSpeed: CGFloat = 0
        for i in 0..<count {
            guard !nodes[i].isPinned else { continue }
            let f = CGPoint(
                x: forces[nodes[i].id]!.x * temperature,
                y: forces[nodes[i].id]!.y * temperature
            )
            var vx = nodes[i].velocity.x + f.x
            var vy = nodes[i].velocity.y + f.y
            let speed = sqrt(vx * vx + vy * vy)
            if speed > maxVelocity {
                vx = vx / speed * maxVelocity
                vy = vy / speed * maxVelocity
            }
            vx *= damping
            vy *= damping
            nodes[i].velocity = CGPoint(x: vx, y: vy)
            nodes[i].position = CGPoint(
                x: nodes[i].position.x + vx,
                y: nodes[i].position.y + vy
            )
            let moved = sqrt(vx * vx + vy * vy)
            if moved > maxSpeed { maxSpeed = moved }
        }
        temperature = max(minTemperature, temperature * coolingRate)
        return maxSpeed
    }

    /// Grid-accelerated repulsion: exact all-pairs inside a cell, a coarse
    /// monopole for far cells — O(n · cells) instead of O(n²) per tick.
    private func applyGridRepulsion(nodes: [GraphNode], forces: inout [UUID: CGPoint]) {
        struct CellKey: Hashable {
            let x: Int
            let y: Int
        }
        struct Cell {
            var indices: [Int] = []
            var centroid = CGPoint.zero
        }

        var cells: [CellKey: Cell] = [:]
        cells.reserveCapacity(nodes.count / 4 + 1)
        for (i, node) in nodes.enumerated() {
            let key = CellKey(
                x: Int(floor(node.position.x / cellSize)),
                y: Int(floor(node.position.y / cellSize))
            )
            var cell = cells[key] ?? Cell()
            cell.indices.append(i)
            cell.centroid.x += node.position.x
            cell.centroid.y += node.position.y
            cells[key] = cell
        }
        for key in Array(cells.keys) {
            guard let cell = cells[key] else { continue }
            let count = CGFloat(cell.indices.count)
            cells[key] = Cell(
                indices: cell.indices,
                centroid: CGPoint(x: cell.centroid.x / count, y: cell.centroid.y / count)
            )
        }

        for (_, cell) in cells {
            for aIdx in 0..<cell.indices.count {
                let a = nodes[cell.indices[aIdx]]
                for bIdx in (aIdx + 1)..<cell.indices.count {
                    let b = nodes[cell.indices[bIdx]]
                    var delta = CGPoint(x: a.position.x - b.position.x, y: a.position.y - b.position.y)
                    let dist = max(sqrt(delta.x * delta.x + delta.y * delta.y), minDistance)
                    let force = repulsion / (dist * dist)
                    delta = CGPoint(x: delta.x / dist * force, y: delta.y / dist * force)
                    forces[a.id] = CGPoint(x: forces[a.id]!.x + delta.x, y: forces[a.id]!.y + delta.y)
                    forces[b.id] = CGPoint(x: forces[b.id]!.x - delta.x, y: forces[b.id]!.y - delta.y)
                }
            }
        }

        for node in nodes {
            let ownKey = CellKey(
                x: Int(floor(node.position.x / cellSize)),
                y: Int(floor(node.position.y / cellSize))
            )
            for (key, cell) in cells where key != ownKey {
                var delta = CGPoint(x: node.position.x - cell.centroid.x, y: node.position.y - cell.centroid.y)
                let dist = max(sqrt(delta.x * delta.x + delta.y * delta.y), minDistance)
                let force = repulsion * CGFloat(cell.indices.count) / (dist * dist)
                delta = CGPoint(x: delta.x / dist * force, y: delta.y / dist * force)
                forces[node.id] = CGPoint(x: forces[node.id]!.x + delta.x, y: forces[node.id]!.y + delta.y)
            }
        }
    }
}

// MARK: - Object Graph View

struct NetworkGraphView: View {
    var coordinator: NavigationCoordinator?

    @Environment(\.modelContext) private var modelContext

    @Query private var figures: [Figure]
    @Query private var places: [Place]
    @Query private var events: [Event]
    @Query private var relationships: [Relationship]
    @Query private var figurePlaceAssociations: [FigurePlaceAssociation]
    @Query private var eventPlaceAssociations: [EventPlaceAssociation]
    @Query private var eventEventAssociations: [EventEventAssociation]
    @Query private var figureTypes: [FigureType]
    @Query private var placeTypes: [PlaceType]
    @Query private var eventTypes: [EventType]

    @State private var nodes: [GraphNode] = []
    @State private var edges: [GraphEdge] = []
    @State private var engine = ForceEngine()
    @State private var showTypes: Set<GraphNode.NodeType> = [.figure, .place, .event]
    @State private var hiddenFigureTypes: Set<String> = []
    @State private var hiddenPlaceTypes: Set<String> = []
    @State private var hiddenEventTypes: Set<String> = []
    @State private var hideVeryBusy = false
    @State private var hideBusy = false
    @State private var searchText = ""
    @State private var selectedNode: GraphNode?
    @State private var hoveredNode: GraphNode?
    @State private var scale: CGFloat = 1.0
    @State private var offset = CGSize.zero
    @State private var draggingNodeID: UUID?
    @State private var dragStartLocation: CGPoint?
    @State private var isDragging: Bool = false
    @State private var preDragOffset: CGSize = .zero
    @State private var isSimulationRunning = true
    @State private var canvasSize: CGSize = .zero
    @State private var canvasGlobalFrame: CGRect = .zero
    @State private var scrollMonitor: Any?
    @State private var connectionDegrees: [UUID: Int] = [:]
    @State private var staticTicks = 0
    @State private var pinchStartScale: CGFloat?

    private enum PanelContent {
        case dossier
        case detailFigure(Figure)
        case detailPlace(Place)
        case detailEvent(Event)
    }
    @State private var panelContent: PanelContent = .dossier

    private let nodeRadius: CGFloat = 20
    private let timer = Timer.publish(every: 1/60, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            HStack(spacing: 0) {
                figureTypeFilterColumn
                Divider()
                canvasArea
                    .layoutPriority(1)
                if selectedNode != nil {
                    Divider()
                    sidePanel
                        .frame(width: 320)
                }
            }
            Divider()
            legend
        }
        .onAppear {
            rebuildGraph()
            scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { event in
                guard cursorIsOverCanvas(event) else { return event }
                let dy = event.scrollingDeltaY
                guard dy != 0 else { return event }
                let pixels = event.hasPreciseScrollingDeltas ? dy : dy * 10
                applyZoom(CGFloat(exp(Double(pixels) * 0.015)), at: event)
                return nil
            }
        }
        .onChange(of: figures.map(\.persistentModelID)) { _, _ in rebuildGraph() }
        .onChange(of: places.map(\.persistentModelID)) { _, _ in rebuildGraph() }
        .onChange(of: events.map(\.persistentModelID)) { _, _ in rebuildGraph() }
        .onChange(of: relationships.map(\.persistentModelID)) { _, _ in rebuildGraph() }
        .onChange(of: figurePlaceAssociations.map(\.persistentModelID)) { _, _ in rebuildGraph() }
        .onChange(of: eventPlaceAssociations.map(\.persistentModelID)) { _, _ in rebuildGraph() }
        .onChange(of: eventEventAssociations.map(\.persistentModelID)) { _, _ in rebuildGraph() }
        .onReceive(timer) { _ in if isSimulationRunning { tick() } }
        .onDisappear {
            timer.upstream.connect().cancel()
            if let monitor = scrollMonitor {
                NSEvent.removeMonitor(monitor)
            }
        }

    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 12) {
            Text("Object Graph")
                .font(.title2.bold())

            Divider().frame(height: 20)

            HStack(spacing: 4) {
                ForEach(GraphNode.NodeType.allCases, id: \.self) { type in
                    Button(action: { toggleType(type) }) {
                        HStack(spacing: 4) {
                            Image(systemName: type.icon)
                                .font(.caption)
                            Text(type.rawValue)
                                .font(.caption)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(showTypes.contains(type) ? type.color.opacity(0.15) : Color(.textBackgroundColor))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(showTypes.contains(type) ? type.color.opacity(0.3) : .gray.opacity(0.2))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer()

            TextField("Search", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .frame(width: 180)

            HStack(spacing: 2) {
                Button(action: { scale = max(0.2, scale / 1.3) }) {
                    Image(systemName: "minus.magnifyingglass")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .help("Zoom out")

                Text("\(Int(scale * 100))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 40)

                Button(action: { scale = min(5.0, scale * 1.3) }) {
                    Image(systemName: "plus.magnifyingglass")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .help("Zoom in")

                Button(action: { scale = 1.0; offset = .zero }) {
                    Image(systemName: "1.magnifyingglass")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .help("Reset zoom")
            }

            Button(action: { isSimulationRunning.toggle() }) {
                Image(systemName: isSimulationRunning ? "pause.fill" : "play.fill")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .help(isSimulationRunning ? "Pause simulation" : "Resume simulation")

            Button(action: resetLayout) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .help("Reset layout")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - Canvas

    private var figureTypeFilterColumn: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                filterTypeSection(title: "Figure Types", items: figureTypeItems, hiddenSet: $hiddenFigureTypes)
                Divider()
                filterTypeSection(title: "Place Types", items: placeTypeItems, hiddenSet: $hiddenPlaceTypes)
                Divider()
                filterTypeSection(title: "Event Types", items: eventTypeItems, hiddenSet: $hiddenEventTypes)
                Divider()
                connectionsSection
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .frame(width: 150)
    }

    private struct TypeFilterItem: Identifiable {
        let id: String
        let name: String
        let color: Color
    }

    private var figureTypeItems: [TypeFilterItem] {
        figureTypes.sorted { $0.name < $1.name }.map { TypeFilterItem(id: $0.name, name: $0.name, color: $0.color) }
    }

    private var placeTypeItems: [TypeFilterItem] {
        placeTypes.sorted { $0.name < $1.name }.map { TypeFilterItem(id: $0.name, name: $0.name, color: $0.color) }
    }

    private var eventTypeItems: [TypeFilterItem] {
        eventTypes.sorted { $0.name < $1.name }.map { TypeFilterItem(id: $0.name, name: $0.name, color: $0.color) }
    }

    private func filterTypeSection(title: String, items: [TypeFilterItem], hiddenSet: Binding<Set<String>>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Toggle(isOn: selectAllBinding(items, hiddenSet: hiddenSet)) {
                    Text(title)
                        .font(.subheadline.bold())
                }
                .toggleStyle(.checkbox)
                .disabled(items.isEmpty)
                .help(items.isEmpty ? "No types" : "Select/deselect all \(title.lowercased())")
            }
            if items.isEmpty {
                Text("No types")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                ForEach(items) { item in
                    Toggle(isOn: typeVisibilityBinding(hiddenSet, for: item.id)) {
                        HStack(spacing: 5) {
                            Circle()
                                .fill(item.color)
                                .frame(width: 8, height: 8)
                            Text(item.name)
                                .font(.caption)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                    }
                    .toggleStyle(.checkbox)
                    .help("Show/hide \(item.name)")
                }
            }
        }
    }

    private func selectAllBinding(_ items: [TypeFilterItem], hiddenSet: Binding<Set<String>>) -> Binding<Bool> {
        Binding(
            get: { hiddenSet.wrappedValue.isEmpty },
            set: { isOn in
                if isOn {
                    hiddenSet.wrappedValue = []
                } else {
                    hiddenSet.wrappedValue = Set(items.map(\.id))
                }
            }
        )
    }

    private var connectionsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Connections")
                .font(.subheadline.bold())
            Toggle(isOn: $hideVeryBusy) {
                Text("Hide very busy (6+)")
                    .font(.caption)
            }
            .toggleStyle(.checkbox)
            .help("Hide nodes with more than 5 connections")
            Toggle(isOn: $hideBusy) {
                Text("Hide busy (2\u{2013}5)")
                    .font(.caption)
            }
            .toggleStyle(.checkbox)
            .help("Hide nodes with 2 to 5 connections")
        }
    }

    private func typeVisibilityBinding(_ set: Binding<Set<String>>, for value: String) -> Binding<Bool> {
        Binding(
            get: { !set.wrappedValue.contains(value) },
            set: { isOn in
                if isOn {
                    set.wrappedValue.remove(value)
                } else {
                    set.wrappedValue.insert(value)
                }
            }
        )
    }

    private var canvasArea: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack {
                Canvas { context, canvasSize in
                    let activeNodes = filteredNodes
                    let activeNodeIDs = Set(activeNodes.map(\.id))
                    let activeEdges = edges.filter { activeNodeIDs.contains($0.sourceID) && activeNodeIDs.contains($0.targetID) }
                    var nodeByID: [UUID: GraphNode] = [:]
                    nodeByID.reserveCapacity(activeNodes.count)
                    for node in activeNodes { nodeByID[node.id] = node }

                    context.translateBy(x: offset.width + canvasSize.width / 2, y: offset.height + canvasSize.height / 2)
                    context.scaleBy(x: scale, y: scale)

                    for edge in activeEdges {
                        guard let source = nodeByID[edge.sourceID],
                              let target = nodeByID[edge.targetID] else { continue }
                        var path = Path()
                        path.move(to: source.position)
                        path.addLine(to: target.position)
                        context.stroke(path, with: .color(edge.color.opacity(0.4)), lineWidth: 1)
                    }

                    for node in activeNodes {
                        let isSelected = node.id == selectedNode?.id
                        let isHovered = node.id == hoveredNode?.id
                        let isSearched = !searchText.isEmpty && node.name.localizedCaseInsensitiveContains(searchText)
                        let baseRadius = radius(for: node)
                        let r = baseRadius * (isSelected || isSearched ? 1.3 : 1.0)
                        let rect = CGRect(
                            x: node.position.x - r,
                            y: node.position.y - r,
                            width: r * 2,
                            height: r * 2
                        )

                        if isSelected || isHovered || isSearched {
                            let glowColor: Color = isSelected ? .accentColor : (isSearched ? .yellow : .gray)
                            context.fill(Path(ellipseIn: rect.insetBy(dx: -3, dy: -3)), with: .color(glowColor.opacity(0.3)))
                        }

                        context.fill(Path(ellipseIn: rect), with: .color(node.color))
                        context.stroke(Path(ellipseIn: rect), with: .color(.white.opacity(0.5)), lineWidth: isSelected ? 2 : 1)

                        if isHovered {
                            let label = Text(node.name)
                                .font(.system(size: 12 / scale, weight: .semibold))
                                .foregroundColor(.primary)
                            let resolved = context.resolve(label)
                            let labelSize = resolved.measure(in: CGSize(width: 10000, height: 10000))
                            let labelCenter = CGPoint(
                                x: node.position.x,
                                y: node.position.y + r + max(12, 12 / scale)
                            )
                            let backdrop = CGRect(
                                x: labelCenter.x - labelSize.width / 2 - 4,
                                y: labelCenter.y - labelSize.height / 2 - 2,
                                width: labelSize.width + 8,
                                height: labelSize.height + 4
                            )
                            context.fill(
                                Path(roundedRect: backdrop, cornerRadius: 4),
                                with: .color(Color(nsColor: .textBackgroundColor).opacity(0.85))
                            )
                            context.draw(resolved, at: labelCenter)
                        } else if scale > 0.5 || isSelected || isSearched {
                            context.draw(
                                Text(node.name)
                                    .font(.system(size: 9))
                                    .foregroundColor(.primary),
                                at: CGPoint(x: node.position.x, y: node.position.y + r + 12)
                            )
                        }
                    }
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in handleDragChanged(value, canvasSize: size) }
                        .onEnded { value in handleDragEnded(value, canvasSize: size) }
                )
                .simultaneousGesture(
                    MagnificationGesture()
                        .onChanged { value in
                            if pinchStartScale == nil {
                                pinchStartScale = scale
                                isSimulationRunning = false
                            }
                            if let start = pinchStartScale {
                                scale = max(0.2, min(5.0, start * value))
                            }
                        }
                        .onEnded { _ in
                            pinchStartScale = nil
                            if engine.temperature > engine.minTemperature {
                                isSimulationRunning = true
                            }
                        }
                )

                if filteredNodes.isEmpty {
                    Text("No data to display")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                if selectedNode == nil && !filteredNodes.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "hand.point.up")
                            .font(.title2)
                            .foregroundStyle(.tertiary)
                        Text("Click a node to inspect")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        Text("Drag to rearrange \u{00B7} Scroll to zoom")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .allowsHitTesting(false)
                }
            }
            .onAppear { canvasSize = size; canvasGlobalFrame = geo.frame(in: .global); initializePositions(size: size) }
            .onChange(of: size) { _, newSize in canvasSize = newSize; canvasGlobalFrame = geo.frame(in: .global) }
            .onContinuousHover { phase in
                switch phase {
                case .active(let location):
                    let loc = canvasLocation(from: location, canvasSize: size)
                    hoveredNode = filteredNodes.min(by: { a, b in
                        dist(a.position, loc) < dist(b.position, loc)
                    }).flatMap { node in
                        let hitRadius = radius(for: node) + 5
                        return dist(node.position, loc) < hitRadius ? node : nil
                    }
                case .ended:
                    hoveredNode = nil
                }
            }
        }
    }

    // MARK: - Legend

    private var legend: some View {
        HStack(spacing: 16) {
            legendItem(color: figureTypeColor("Deity") ?? .blue, label: "Deity")
            legendItem(color: figureTypeColor("Human") ?? .green, label: "Human")
            legendItem(color: figureTypeColor("Igigi") ?? .purple, label: "Igigi/Watchers")
            legendItem(color: GraphNode.NodeType.place.color, label: "Places")
            legendItem(color: GraphNode.NodeType.event.color, label: "Events")
            Spacer()
            Text("\(filteredNodes.count) nodes \u{00B7} \(filteredEdgesCount) edges")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func figureTypeColor(_ name: String) -> Color? {
        figureTypes.first { $0.name == name }?.color
    }

    // MARK: - Side Panel

    private var sidePanel: some View {
        VStack(spacing: 0) {
            switch panelContent {
            case .dossier:
                dossierPanel
            case .detailFigure(let figure):
                detailViewHeader(title: "Figure Detail") {
                    panelContent = .dossier
                }
                FigureDetailView(figure: figure, onSelectPlace: { place in
                    panelContent = .detailPlace(place)
                }, onSelectEvent: { event in
                    panelContent = .detailEvent(event)
                })
            case .detailPlace(let place):
                detailViewHeader(title: "Place Detail") {
                    panelContent = .dossier
                }
                PlaceDetailView(place: place, onSelectFigure: { figure in
                    panelContent = .detailFigure(figure)
                }, onSelectEvent: { event in
                    panelContent = .detailEvent(event)
                })
            case .detailEvent(let event):
                detailViewHeader(title: "Event Detail") {
                    panelContent = .dossier
                }
                EventDetailView(event: event, onSelectFigure: { figure in
                    panelContent = .detailFigure(figure)
                }, onSelectPlace: { place in
                    panelContent = .detailPlace(place)
                })
            }
        }
    }

    private func detailViewHeader(title: String, onBack: @escaping () -> Void) -> some View {
        HStack(spacing: 4) {
            Button(action: onBack) {
                HStack(spacing: 2) {
                    Image(systemName: "chevron.left")
                    Text("Back")
                }
                .font(.caption)
            }
            .buttonStyle(.plain)
            Spacer()
            Button { selectedNode = nil } label: {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
            .help("Close panel")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    // MARK: - Dossier Panel

    private var dossierPanel: some View {
        VStack(spacing: 0) {
            if let node = selectedNode {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(node.color)
                                .frame(width: 28, height: 28)
                                .overlay(
                                    Image(systemName: node.type.icon)
                                        .font(.caption)
                                        .foregroundStyle(.white)
                                )
                            VStack(alignment: .leading, spacing: 2) {
                                Text(node.name)
                                    .font(.headline)
                                Text(node.type.rawValue)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Divider()

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Connections (\(connectedEdges.count))")
                                .font(.subheadline.bold())
                            if connectedEdges.isEmpty {
                                Text("None")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            } else {
                                ForEach(connectedEdges) { edge in
                                    HStack(spacing: 4) {
                                        Circle()
                                            .fill(edge.color)
                                            .frame(width: 6, height: 6)
                                        Text(connectedNodeName(for: edge, excluding: node.id))
                                            .font(.caption)
                                        Spacer()
                                        Text(edge.label)
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                            }
                        }

                        Spacer()

                        VStack(spacing: 8) {
                            Button("Open Detail") {
                                guard let id = node.persistentModelID else { return }
                                switch node.type {
                                case .figure:
                                    if let figure = figures.first(where: { $0.persistentModelID == id }) {
                                        panelContent = .detailFigure(figure)
                                    }
                                case .place:
                                    if let place = places.first(where: { $0.persistentModelID == id }) {
                                        panelContent = .detailPlace(place)
                                    }
                                case .event:
                                    if let event = events.first(where: { $0.persistentModelID == id }) {
                                        panelContent = .detailEvent(event)
                                    }
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .frame(maxWidth: .infinity)

                            Button("Deselect") { selectedNode = nil }
                                .buttonStyle(.plain)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(12)
                }
            }
        }
    }

    private var connectedEdges: [GraphEdge] {
        guard let node = selectedNode else { return [] }
        return edges.filter { $0.sourceID == node.id || $0.targetID == node.id }
    }

    private func connectedNodeName(for edge: GraphEdge, excluding nodeID: UUID) -> String {
        let otherID = edge.sourceID == nodeID ? edge.targetID : edge.sourceID
        return nodes.first(where: { $0.id == otherID })?.name ?? "?"
    }

    // MARK: - Computed

    private var filteredNodes: [GraphNode] {
        var result = nodes.filter { showTypes.contains($0.type) }
        result = applyTypeFilter(result, nodeType: .figure, hidden: hiddenFigureTypes) { $0.figureTypeName }
        result = applyTypeFilter(result, nodeType: .place, hidden: hiddenPlaceTypes) { $0.placeTypeName }
        result = applyTypeFilter(result, nodeType: .event, hidden: hiddenEventTypes) { $0.eventTypeName }
        if hideVeryBusy {
            result = result.filter { connectionDegrees[$0.id, default: 0] <= 5 }
        }
        if hideBusy {
            result = result.filter { node in
                let degree = connectionDegrees[node.id, default: 0]
                return degree < 2 || degree > 5
            }
        }
        if !searchText.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        return result
    }

    private func applyTypeFilter(_ nodes: [GraphNode], nodeType: GraphNode.NodeType, hidden: Set<String>, typeName: (GraphNode) -> String?) -> [GraphNode] {
        guard !hidden.isEmpty else { return nodes }
        return nodes.filter { node in
            guard node.type == nodeType else { return true }
            guard let name = typeName(node) else { return false }
            return !hidden.contains(name)
        }
    }

    private var filteredEdgesCount: Int {
        let activeIDs = Set(filteredNodes.map(\.id))
        return edges.filter { activeIDs.contains($0.sourceID) && activeIDs.contains($0.targetID) }.count
    }

    private func dist(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = a.x - b.x, dy = a.y - b.y
        return sqrt(dx * dx + dy * dy)
    }

    private func radius(for node: GraphNode) -> CGFloat {
        let degree = connectionDegrees[node.id, default: 0]
        return 14 + sqrt(CGFloat(degree)) * 8
    }

    // MARK: - Actions

    private func toggleType(_ type: GraphNode.NodeType) {
        if showTypes.contains(type) {
            if showTypes.count > 1 { showTypes.remove(type) }
        } else {
            showTypes.insert(type)
        }
    }

    private func resetLayout() {
        for i in 0..<nodes.count {
            nodes[i].position = .zero
            nodes[i].velocity = .zero
            nodes[i].isPinned = false
        }
        engine.temperature = 1.0
        isSimulationRunning = true
        staticTicks = 0
        initializePositions(size: canvasSize)
    }

    private func navigateToEntity(_ node: GraphNode) {
        guard let id = node.persistentModelID else { return }
        switch node.type {
        case .figure: coordinator?.navigateToFigure(id, name: node.name)
        case .place: coordinator?.navigateToPlace(id, name: node.name)
        case .event: coordinator?.navigateToEvent(id, name: node.name)
        }
    }

    // MARK: - Coordinate Helpers

    private func canvasLocation(from viewLocation: CGPoint, canvasSize: CGSize) -> CGPoint {
        CGPoint(
            x: (viewLocation.x - offset.width - canvasSize.width / 2) / scale,
            y: (viewLocation.y - offset.height - canvasSize.height / 2) / scale
        )
    }

    private func cursorIsOverCanvas(_ event: NSEvent) -> Bool {
        guard let window = event.window, !canvasGlobalFrame.isEmpty else { return false }
        let height = window.contentView?.bounds.height ?? 0
        let point = CGPoint(x: event.locationInWindow.x, y: height - event.locationInWindow.y)
        return canvasGlobalFrame.contains(point)
    }

    private func applyZoom(_ factor: CGFloat, at event: NSEvent) {
        guard let window = event.window, !canvasGlobalFrame.isEmpty else { return }
        let height = window.contentView?.bounds.height ?? 0
        let anchor = CGPoint(
            x: event.locationInWindow.x - canvasGlobalFrame.minX,
            y: height - event.locationInWindow.y - canvasGlobalFrame.minY
        )
        let newScale = max(0.2, min(5.0, scale * factor))
        let applied = newScale / scale
        let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
        offset = CGSize(
            width: offset.width * applied + (anchor.x - center.x) * (1 - applied),
            height: offset.height * applied + (anchor.y - center.y) * (1 - applied)
        )
        scale = newScale
    }

    private func nodeAt(_ location: CGPoint) -> GraphNode? {
        filteredNodes.first { dist($0.position, location) < radius(for: $0) + 5 }
    }

    // MARK: - Gesture Handlers

    private let dragThreshold: CGFloat = 5

    private func handleDragChanged(_ value: DragGesture.Value, canvasSize: CGSize) {
        let movement = hypot(value.translation.width, value.translation.height)

        if dragStartLocation == nil && !isDragging {
            dragStartLocation = value.startLocation
            preDragOffset = offset
            isSimulationRunning = false
            let startLoc = canvasLocation(from: value.startLocation, canvasSize: canvasSize)
            if let node = nodeAt(startLoc) {
                draggingNodeID = node.id
                if let idx = nodes.firstIndex(where: { $0.id == node.id }) {
                    nodes[idx].isPinned = true
                }
            }
        }

        if !isDragging && movement > dragThreshold {
            isDragging = true
        }

        if isDragging {
            if let nodeID = draggingNodeID {
                let loc = canvasLocation(from: value.location, canvasSize: canvasSize)
                if let idx = nodes.firstIndex(where: { $0.id == nodeID }) {
                    nodes[idx].position = loc
                    nodes[idx].isPinned = true
                }
            } else {
                offset = CGSize(
                    width: preDragOffset.width + value.translation.width,
                    height: preDragOffset.height + value.translation.height
                )
            }
        }
    }

    private func handleDragEnded(_ value: DragGesture.Value, canvasSize: CGSize) {
        defer {
            draggingNodeID = nil
            dragStartLocation = nil
            isDragging = false
            if engine.temperature > engine.minTemperature {
                isSimulationRunning = true
            }
        }

        if !isDragging {
            let loc = canvasLocation(from: value.location, canvasSize: canvasSize)
            if let node = nodeAt(loc) {
                selectedNode = node
                panelContent = .dossier
            } else {
                selectedNode = nil
            }
            return
        }

        if let nodeID = draggingNodeID {
            if let idx = nodes.firstIndex(where: { $0.id == nodeID }) {
                nodes[idx].isPinned = false
            }
        }
    }

    // MARK: - Simulation

    private func tick() {
        let activeIDs = Set(filteredNodes.map(\.id))
        let activeEdges = edges.filter { activeIDs.contains($0.sourceID) && activeIDs.contains($0.targetID) }
        let maxSpeed = engine.tick(nodes: &nodes, edges: activeEdges, size: canvasSize)
        if maxSpeed < 0.5 {
            staticTicks += 1
        } else {
            staticTicks = 0
        }
        if staticTicks >= 40 || engine.temperature <= engine.minTemperature {
            isSimulationRunning = false
        }
    }

    // MARK: - Graph Building

    private func rebuildGraph() {
        var newNodes: [GraphNode] = []
        var newEdges: [GraphEdge] = []

        var oldPositions: [PersistentIdentifier: CGPoint] = [:]
        for node in nodes {
            if let id = node.persistentModelID {
                oldPositions[id] = node.position
            }
        }
        let oldSelectedID = selectedNode?.persistentModelID

        func addNode(name: String, type: GraphNode.NodeType, color: Color, figureTypeName: String? = nil, placeTypeName: String? = nil, eventTypeName: String? = nil, persistentModelID: PersistentIdentifier?) -> UUID {
            let id = UUID()
            newNodes.append(GraphNode(
                id: id, name: name, type: type, color: color,
                figureTypeName: figureTypeName,
                placeTypeName: placeTypeName,
                eventTypeName: eventTypeName,
                persistentModelID: persistentModelID,
                position: persistentModelID.flatMap { oldPositions[$0] } ?? .zero,
                velocity: .zero, isPinned: false
            ))
            return id
        }

        var figureNodeMap: [String: UUID] = [:]
        var placeNodeMap: [String: UUID] = [:]
        var eventNodeMap: [String: UUID] = [:]

        for figure in figures {
            let id = addNode(name: figure.name, type: .figure, color: figure.figureType?.color ?? .blue, figureTypeName: figure.figureType?.name, persistentModelID: figure.persistentModelID)
            figureNodeMap[figure.name] = id
        }

        for place in places {
            let id = addNode(name: place.name, type: .place, color: .green, placeTypeName: place.placeType?.name, persistentModelID: place.persistentModelID)
            placeNodeMap[place.name] = id
        }

        for event in events {
            let id = addNode(name: event.name, type: .event, color: .orange, eventTypeName: event.eventType?.name, persistentModelID: event.persistentModelID)
            eventNodeMap[event.name] = id
        }

        for rel in relationships {
            guard let fromName = rel.fromFigure?.name, let toName = rel.toFigure?.name,
                  let fromID = figureNodeMap[fromName], let toID = figureNodeMap[toName] else { continue }
            newEdges.append(GraphEdge(
                id: UUID(), sourceID: fromID, targetID: toID,
                label: rel.relationshipType?.name ?? "",
                color: rel.relationshipType?.color ?? .gray
            ))
        }

        for assoc in figurePlaceAssociations {
            guard let fName = assoc.figure?.name, let pName = assoc.place?.name,
                  let fID = figureNodeMap[fName], let pID = placeNodeMap[pName] else { continue }
            newEdges.append(GraphEdge(
                id: UUID(), sourceID: fID, targetID: pID,
                label: assoc.roleType?.name ?? "—",
                color: .teal
            ))
        }

        for assoc in eventPlaceAssociations {
            guard let eName = assoc.event?.name, let pName = assoc.place?.name,
                  let eID = eventNodeMap[eName], let pID = placeNodeMap[pName] else { continue }
            newEdges.append(GraphEdge(
                id: UUID(), sourceID: eID, targetID: pID,
                label: assoc.roleType?.name ?? "—",
                color: .mint
            ))
        }

        for assoc in eventEventAssociations {
            guard let fromName = assoc.fromEvent?.name, let toName = assoc.toEvent?.name,
                  let fromID = eventNodeMap[fromName], let toID = eventNodeMap[toName] else { continue }
            newEdges.append(GraphEdge(
                id: UUID(), sourceID: fromID, targetID: toID,
                label: assoc.roleType?.name ?? "—",
                color: .purple
            ))
        }

        nodes = newNodes
        edges = newEdges

        var degrees: [UUID: Int] = [:]
        for edge in newEdges {
            degrees[edge.sourceID, default: 0] += 1
            degrees[edge.targetID, default: 0] += 1
        }
        connectionDegrees = degrees

        initializePositions(size: canvasSize)

        if let oldSelectedID {
            selectedNode = nodes.first { $0.persistentModelID == oldSelectedID }
        }
        engine.temperature = 1.0
        isSimulationRunning = true
        staticTicks = 0
    }

    private func initializePositions(size: CGSize) {
        guard size.width > 0, size.height > 0, !nodes.isEmpty else { return }

        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let radius = min(size.width, size.height) * 0.35

        let unpositioned = nodes.filter { $0.position == .zero }.count
        guard unpositioned > 0 else { return }

        var index = 0
        for i in 0..<nodes.count where nodes[i].position == .zero {
            let angle = 2 * .pi * CGFloat(index) / CGFloat(unpositioned)
            nodes[i].position = CGPoint(
                x: center.x + radius * cos(angle),
                y: center.y + radius * sin(angle)
            )
            nodes[i].velocity = .zero
            index += 1
        }
    }
}
