import SwiftUI
import SwiftData

struct CausalChainDiagramView: View {

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Event.name) private var events: [Event]
    @Query private var eventAssociations: [EventEventAssociation]

    @State private var layoutEvents: [CCEvent] = []
    @State private var layoutLinks: [CCLink] = []
    @State private var eraOrder: [String] = []
    @State private var loaded = false
    @State private var hiddenRoles: Set<String> = []
    @State private var selectedID: PersistentIdentifier?
    @State private var detailEventID: PersistentIdentifier?
    @State private var searchText = ""
    @State private var showUnlinked = true

    private static let nodeSize = CGSize(width: 214, height: 68)
    private static let palette: [Color] = [
        .red, .green, .blue, .orange, .purple, .teal,
        .pink, .indigo, .yellow, .brown, .mint, .cyan
    ]

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Divider()
            HStack(spacing: 0) {
                Group {
                    if loaded {
                        CausalCanvasView(
                            nodes: linkedEvents,
                            links: visibleLinks,
                            selectionID: selectedID,
                            onSelect: { selectedID = $0 }
                        )
                    } else {
                        ProgressView("Building causal chains…")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                Divider()
                sidePanel
                    .frame(width: 330)
            }
            Divider()
            footer
        }
        .task { rebuild() }
        .onChange(of: events.map(\.persistentModelID)) { _, _ in rebuild() }
        .onChange(of: eventAssociations.map(\.persistentModelID)) { _, _ in rebuild() }
        .sheet(isPresented: showDetailBinding) {
            if let id = detailEventID {
                CausalChainEventSheet(entityID: id)
            }
        }
    }

    // MARK: - Top bar / Footer

    private var topBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Label("Causal Chain", systemImage: "arrow.triangle.merge")
                    .font(.title3.bold())
                Spacer()
                Button {
                    selectedID = nil
                } label: {
                    Label("Deselect", systemImage: "xmark.circle")
                        .font(.callout)
                }
                .buttonStyle(.bordered)
                .disabled(selectedID == nil)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(roleInfos) { info in
                        roleChip(info)
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 2)
    }

    private var footer: some View {
        HStack(spacing: 16) {
            Text(linkedEvents.count > 0
                ? "\(linkedEvents.count) linked events · \(visibleLinks.count) causal links"
                : "No event-to-event associations yet — add EventEvent links from the Associations view.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(isolatedEvents.count) unlinked events")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
    }

    private func roleChip(_ info: RoleInfo) -> some View {
        let hidden = hiddenRoles.contains(info.name)
        return Button {
            if hidden {
                hiddenRoles.remove(info.name)
            } else {
                hiddenRoles.insert(info.name)
            }
        } label: {
            HStack(spacing: 5) {
                Circle()
                    .fill(info.color)
                    .frame(width: 8, height: 8)
                Text("\(info.name) (\(info.count))")
                    .font(.caption)
                    .strikethrough(hidden)
                    .foregroundStyle(hidden ? .secondary : .primary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                hidden ? AnyShapeStyle(.quaternary.opacity(0.5)) : AnyShapeStyle(info.color.opacity(0.15)),
                in: Capsule()
            )
        }
        .buttonStyle(.plain)
        .help(hidden ? "Show \(info.name) links" : "Hide \(info.name) links")
    }

    private var sidePanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                TextField("Search events", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .controlBackgroundColor)))

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if chainGroups.isEmpty && isolatedEvents.isEmpty {
                        Text(loaded ? "No events to show." : "")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(Array(chainGroups.enumerated()), id: \.offset) { index, chain in
                        chainSection(index: index, chain: chain)
                    }
                    if !isolatedEvents.isEmpty {
                        unlinkedSection
                    }
                }
                .padding(10)
            }

            if selectedEvent != nil {
                Divider()
                detailsSection
                    .padding(10)
            }
        }
        .padding(10)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func chainSection(index: Int, chain: [CCEvent]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Circle()
                    .fill(chainColor(index))
                    .frame(width: 10, height: 10)
                Text("Chain \(index + 1)")
                    .font(.subheadline.bold())
                Spacer()
                Text("\(chain.count) events")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ForEach(chain) { event in
                let matches = searchText.isEmpty || event.name.localizedCaseInsensitiveContains(searchText)
                if matches {
                    chainEventRow(event)
                }
            }
        }
    }

    private func chainEventRow(_ event: CCEvent) -> some View {
        let outgoing = connectedLinks(from: event.id).filter { $0.fromID == event.id }
        let incoming = connectedLinks(from: event.id).filter { $0.toID == event.id }
        return Button {
            selectedID = event.id
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(event.name)
                        .font(.caption.weight(.medium))
                        .lineLimit(1)
                        .foregroundStyle(selectedID == event.id ? Color.accentColor : .primary)
                    if !outgoing.isEmpty {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 8, weight: .black))
                            .foregroundStyle(outgoing.first?.roleColor ?? .secondary)
                    }
                }
                HStack(spacing: 6) {
                    Text(event.dateLabel)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    if !incoming.isEmpty {
                        Text("← \(incoming.first?.roleName ?? "")")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                selectedID == event.id ? Color.accentColor.opacity(0.15) : Color.clear,
                in: RoundedRectangle(cornerRadius: 6)
            )
        }
        .buttonStyle(.plain)
    }

    private var unlinkedSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button {
                withAnimation { showUnlinked.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: showUnlinked ? "chevron.down" : "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("Unlinked events (\(isolatedEvents.count))")
                        .font(.subheadline.bold())
                }
            }
            .buttonStyle(.plain)
            if showUnlinked {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(isolatedEvents) { event in
                        let matches = searchText.isEmpty || event.name.localizedCaseInsensitiveContains(searchText)
                        if matches {
                            Button {
                                selectedID = event.id
                            } label: {
                                Text(event.name)
                                    .font(.caption)
                                    .foregroundStyle(selectedID == event.id ? Color.accentColor : .primary)
                                    .lineLimit(1)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private var detailsSection: some View {
        Group {
            if let event = selectedEvent {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(event.eraColor)
                            .frame(width: 12, height: 12)
                        Text(event.name)
                            .font(.headline)
                            .lineLimit(2)
                    }
                    HStack(spacing: 8) {
                        Text(event.era)
                        Text("·")
                        Text(event.dateLabel)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    if !event.description.isEmpty {
                        Text(verbatim: event.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(6)
                    }
                    let outgoing = connectedLinks(from: event.id).filter { $0.fromID == event.id }
                    let incoming = connectedLinks(from: event.id).filter { $0.toID == event.id }
                    if !incoming.isEmpty {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Caused/preceded by")
                                .font(.caption.bold())
                            ForEach(incoming) { link in
                                roleLine(link, otherName: eventNames[link.fromID] ?? "?")
                            }
                        }
                    }
                    if !outgoing.isEmpty {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Leads to")
                                .font(.caption.bold())
                            ForEach(outgoing) { link in
                                roleLine(link, otherName: eventNames[link.toID] ?? "?")
                            }
                        }
                    }
                    HStack {
                        Button {
                            detailEventID = event.id
                        } label: {
                            Label("Open Detail", systemImage: "doc.text")
                        }
                        .buttonStyle(.borderedProminent)
                        Spacer()
                    }
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .controlBackgroundColor)))
            }
        }
    }

    private func roleLine(_ link: CCLink, otherName: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(link.roleColor)
                .frame(width: 8, height: 8)
            Text(otherName)
                .font(.caption)
                .lineLimit(1)
            Spacer()
            Text(link.roleName)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Derived data

    private var showDetailBinding: Binding<Bool> {
        Binding(
            get: { detailEventID != nil },
            set: { if !$0 { detailEventID = nil } }
        )
    }

    private struct RoleInfo: Identifiable {
        let id: String
        let name: String
        let color: Color
        let count: Int
    }

    private var roleInfos: [RoleInfo] {
        var order: [String] = []
        var colors: [String: Color] = [:]
        var counts: [String: Int] = [:]
        for link in layoutLinks {
            if colors[link.roleName] == nil {
                colors[link.roleName] = link.roleColor
                order.append(link.roleName)
            }
            counts[link.roleName, default: 0] += 1
        }
        return order.map { RoleInfo(id: $0, name: $0, color: colors[$0] ?? .gray, count: counts[$0] ?? 0) }
    }

    private var visibleLinks: [CCLink] {
        layoutLinks.filter { !hiddenRoles.contains($0.roleName) }
    }

    private var linkedIDs: Set<PersistentIdentifier> {
        var ids = Set<PersistentIdentifier>()
        for link in visibleLinks {
            ids.insert(link.fromID)
            ids.insert(link.toID)
        }
        return ids
    }

    private var linkedEvents: [CCEvent] {
        layoutEvents.filter { linkedIDs.contains($0.id) }
    }

    private var isolatedEvents: [CCEvent] {
        layoutEvents.filter { !linkedIDs.contains($0.id) }
    }

    private var eventNames: [PersistentIdentifier: String] {
        Dictionary(uniqueKeysWithValues: layoutEvents.map { ($0.id, $0.name) })
    }

    private var selectedEvent: CCEvent? {
        guard let id = selectedID else { return nil }
        return layoutEvents.first { $0.id == id }
    }

    private func connectedLinks(from id: PersistentIdentifier) -> [CCLink] {
        visibleLinks.filter { $0.fromID == id || $0.toID == id }
    }

    private var chainGroups: [[CCEvent]] {
        let nodesById = Dictionary(uniqueKeysWithValues: linkedEvents.map { ($0.id, $0) })
        var parent: [PersistentIdentifier: PersistentIdentifier] = [:]
        for id in linkedEvents.map(\.id) { parent[id] = id }

        func find(_ x: PersistentIdentifier) -> PersistentIdentifier {
            var root = x
            while parent[root] != root {
                root = parent[root]!
            }
            var cur = x
            while parent[cur] != root {
                let next = parent[cur]!
                parent[cur] = root
                cur = next
            }
            return root
        }
        func union(_ a: PersistentIdentifier, _ b: PersistentIdentifier) {
            let ra = find(a), rb = find(b)
            if ra != rb { parent[ra] = rb }
        }

        for link in visibleLinks {
            union(link.fromID, link.toID)
        }

        var groups: [PersistentIdentifier: [CCEvent]] = [:]
        for event in linkedEvents {
            groups[find(event.id), default: []].append(event)
        }
        return groups.values
            .map { Self.topologicalOrder($0, links: visibleLinks) }
            .sorted { a, b in (a.first?.sortKey ?? Int.max) < (b.first?.sortKey ?? Int.max) }
    }

    private func chainColor(_ index: Int) -> Color {
        Self.palette[index % Self.palette.count]
    }

    private func eraColor(_ era: String) -> Color {
        guard let idx = eraOrder.firstIndex(of: era) else { return .gray }
        return Self.palette[idx % Self.palette.count]
    }

    // MARK: - Rebuild (off render path)

    private func rebuild() {
        var eraCounts: [String: Int] = [:]
        for event in events {
            let era = event.era.isEmpty ? "Unassigned" : event.era
            eraCounts[era, default: 0] += 1
        }
        eraOrder = eraCounts.keys.sorted { (eraCounts[$0] ?? 0, $0) > (eraCounts[$1] ?? 0, $1) }

        var built: [CCEvent] = []
        for event in events {
            let type = event.eventType
            let eraName = event.era.isEmpty ? "Unassigned" : event.era
            built.append(CCEvent(
                id: event.persistentModelID,
                name: event.name,
                era: eraName,
                dateLabel: event.date.displayLabel,
                typeIcon: type?.icon ?? "bolt",
                typeColor: type?.color ?? .orange,
                eraColor: eraColor(eraName),
                description: event.eventDescription,
                sortMode: event.sortName ?? event.name,
                sortKey: event.date.sortValue
            ))
        }

        var links: [CCLink] = []
        for association in eventAssociations {
            guard let from = association.fromEvent,
                  let to = association.toEvent,
                  from.persistentModelID != to.persistentModelID else { continue }
            let role = association.roleType
            links.append(CCLink(
                id: UUID(),
                fromID: from.persistentModelID,
                toID: to.persistentModelID,
                roleName: role?.name ?? "Related To",
                roleColor: role?.color ?? .gray,
                source: association.source
            ))
        }

        layoutEvents = built
        layoutLinks = links
        loaded = true
    }

    private static func topologicalOrder(_ events: [CCEvent], links: [CCLink]) -> [CCEvent] {
        let ids = Set(events.map(\.id))
        var inDegree: [PersistentIdentifier: Int] = [:]
        var outgoing: [PersistentIdentifier: [PersistentIdentifier]] = [:]
        for event in events {
            inDegree[event.id] = 0
            outgoing[event.id] = []
        }
        for link in links {
            if ids.contains(link.fromID), ids.contains(link.toID) {
                inDegree[link.toID, default: 0] += 1
                outgoing[link.fromID, default: []].append(link.toID)
            }
        }
        var ready = events
            .filter { inDegree[$0.id, default: 0] == 0 }
            .sorted { $0.sortMode.localizedCaseInsensitiveCompare($1.sortMode) == .orderedAscending }
        var ordered: [CCEvent] = []
        let byID = Dictionary(uniqueKeysWithValues: events.map { ($0.id, $0) })
        while let next = ready.popLast() {
            ordered.append(next)
            for child in outgoing[next.id, default: []] {
                inDegree[child, default: 0] -= 1
                if inDegree[child, default: 0] == 0, let event = byID[child] {
                    ready.append(event)
                    ready.sort { $0.sortMode.localizedCaseInsensitiveCompare($1.sortMode) == .orderedAscending }
                }
            }
        }
        if ordered.count != events.count {
            let done = Set(ordered.map(\.id))
            let leftovers = events
                .filter { !done.contains($0.id) }
                .sorted { $0.sortMode.localizedCaseInsensitiveCompare($1.sortMode) == .orderedAscending }
            ordered.append(contentsOf: leftovers)
        }
        return ordered
    }
}

// MARK: - Canvas view

private struct CausalCanvasView: View {
    let nodes: [CCEvent]
    let links: [CCLink]
    let selectionID: PersistentIdentifier?
    let onSelect: (PersistentIdentifier) -> Void

    @State private var hoveredID: PersistentIdentifier?
    @State private var canvasSize: CGSize = .zero

    private static let nodeSize = CGSize(width: 214, height: 68)

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(nsColor: .textBackgroundColor)
                    .onAppear { canvasSize = geo.size }
                    .onChange(of: geo.size) { _, s in canvasSize = s }

                edgeLayer
                nodeLayer

                if nodes.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "arrow.triangle.merge")
                            .font(.system(size: 34))
                            .foregroundStyle(.tertiary)
                        Text("No causal chains yet")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        Text("Add Event → Event associations (caused, motivated, precedes…) to see chains build up here.")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 320)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .allowsHitTesting(false)
                }
            }
            .clipShape(Rectangle())
        }
    }

    private var positionsById: [PersistentIdentifier: CGPoint] {
        Self.computeLayout(nodes: nodes, links: links, canvasSize: canvasSize, nodeSize: Self.nodeSize)
    }

    private var positionedNodes: [PositionedNode] {
        let positions = positionsById
        guard let hovered = hoveredID else {
            return nodes.compactMap { event in
                guard let p = positions[event.id] else { return nil }
                return PositionedNode(
                    id: event.id, name: event.name, sub: subLine(event), eraLine: event.era,
                    eraColor: event.eraColor, typeIcon: event.typeIcon, typeColor: event.typeColor,
                    position: p, dimmed: false
                )
            }
        }
        let hoveredNeighbors = neighborIDs(of: hovered)
        return nodes.compactMap { event in
            guard let p = positions[event.id] else { return nil }
            let dimmed = event.id != hovered && !hoveredNeighbors.contains(event.id)
            return PositionedNode(
                id: event.id, name: event.name, sub: subLine(event), eraLine: event.era,
                eraColor: event.eraColor, typeIcon: event.typeIcon, typeColor: event.typeColor,
                position: p, dimmed: dimmed
            )
        }
    }

    private func subLine(_ event: CCEvent) -> String {
        let date = event.dateLabel
        if date.isEmpty || date == "Unknown" { return event.era }
        if event.era.isEmpty { return date }
        return "\(date) · \(event.era)"
    }

    private func neighborIDs(of id: PersistentIdentifier) -> Set<PersistentIdentifier> {
        var ids = Set<PersistentIdentifier>()
        for link in links {
            if link.fromID == id { ids.insert(link.toID) }
            if link.toID == id { ids.insert(link.fromID) }
        }
        return ids
    }

    private var edgeLayer: some View {
        Canvas { context, _ in
            guard !links.isEmpty else { return }
            let positions = positionsById
            var endpoints: [UUID: (from: CGPoint, to: CGPoint)] = [:]
            for link in links {
                guard let from = positions[link.fromID], let to = positions[link.toID] else { continue }
                let f = CGPoint(x: from.x + Self.nodeSize.width / 2, y: from.y)
                let t = CGPoint(x: to.x - Self.nodeSize.width / 2, y: to.y)
                endpoints[link.id] = (f, t)
            }
            var drawn: [String: Int] = [:]
            for link in links {
                guard let (f, t) = endpoints[link.id] else { continue }
                let key = "\(f.x),\(f.y)->\(t.x),\(t.y)"
                let dup = drawn[key, default: 0]
                drawn[key] = dup + 1
                let shift = CGFloat(dup) * 7.0
                let p1 = CGPoint(x: f.x, y: f.y - shift)
                let p2 = CGPoint(x: t.x, y: t.y - shift)
                drawEdge(link, from: p1, to: p2, in: context)
            }
        }
    }

    private func drawEdge(_ link: CCLink, from: CGPoint, to: CGPoint, in context: GraphicsContext) {
        let dx = max(0, to.x - from.x)
        let c1 = CGPoint(x: from.x + dx * 0.45, y: from.y)
        let c2 = CGPoint(x: to.x - dx * 0.45, y: to.y)
        let hovering = hoveredID == link.fromID || hoveredID == link.toID
        let connected = hoveredID == nil || hovering
        let baseOpacity: Double = connected ? (hovering ? 1.0 : 0.75) : 0.12

        var path = Path()
        path.move(to: from)
        path.addCurve(to: to, control1: c1, control2: c2)
        context.stroke(path, with: .color(link.roleColor.opacity(hovering ? 1 : baseOpacity)), style: StrokeStyle(lineWidth: hovering ? 3 : 2, lineCap: .round))

        let angle = atan2(to.y - c2.y, to.x - c2.x)
        drawArrowHead(at: to, angle: angle, color: link.roleColor.opacity(baseOpacity), in: context)

        if dx >= 130, connected {
            let mid = bezierMidpoint(from, c1, c2, to)
            let label = Text(link.roleName)
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.primary)
            let resolved = context.resolve(label)
            let size = resolved.measure(in: CGSize(width: 10000, height: 10000))
            let box = CGRect(
                x: mid.x - size.width / 2 - 5,
                y: mid.y - size.height / 2 - 8,
                width: size.width + 10,
                height: size.height + 4
            )
            context.fill(
                Path(roundedRect: box, cornerRadius: 4),
                with: .color(Color(nsColor: .textBackgroundColor).opacity(0.9))
            )
            context.draw(resolved, at: CGPoint(x: mid.x, y: mid.y - 6))
        }
    }

    private func drawArrowHead(at point: CGPoint, angle: Double, color: Color, in context: GraphicsContext) {
        let length: CGFloat = 9
        let halfWidth: CGFloat = 4.5
        let tip = point
        let base = CGPoint(x: point.x - length * CGFloat(cos(angle)), y: point.y - length * CGFloat(sin(angle)))
        let left = CGPoint(
            x: base.x + halfWidth * CGFloat(cos(angle + .pi / 2)),
            y: base.y + halfWidth * CGFloat(sin(angle + .pi / 2))
        )
        let right = CGPoint(
            x: base.x + halfWidth * CGFloat(cos(angle - .pi / 2)),
            y: base.y + halfWidth * CGFloat(sin(angle - .pi / 2))
        )
        var p = Path()
        p.move(to: tip)
        p.addLine(to: left)
        p.addLine(to: right)
        p.closeSubpath()
        context.fill(p, with: .color(color))
    }

    private func bezierMidpoint(_ p1: CGPoint, _ c1: CGPoint, _ c2: CGPoint, _ p2: CGPoint) -> CGPoint {
        let t = 0.5
        let u = 1 - t
        return CGPoint(
            x: u*u*u*p1.x + 3*u*u*t*c1.x + 3*u*t*t*c2.x + t*t*t*p2.x,
            y: u*u*u*p1.y + 3*u*u*t*c1.y + 3*u*t*t*c2.y + t*t*t*p2.y
        )
    }

    private var nodeLayer: some View {
        ForEach(positionedNodes) { pn in
            CausalNodeCard(
                name: pn.name,
                sub: pn.sub,
                eraLine: pn.eraLine,
                eraColor: pn.eraColor,
                typeIcon: pn.typeIcon,
                typeColor: pn.typeColor,
                hovered: hoveredID == pn.id,
                selected: selectionID == pn.id,
                dimmed: pn.dimmed
            )
            .onTapGesture { onSelect(pn.id) }
            .onHover { over in hoveredID = over ? pn.id : nil }
            .position(x: pn.position.x, y: pn.position.y)
        }
    }

    private static func computeLayout(
        nodes: [CCEvent],
        links: [CCLink],
        canvasSize: CGSize,
        nodeSize: CGSize
    ) -> [PersistentIdentifier: CGPoint] {
        guard !nodes.isEmpty, canvasSize.width > 0, canvasSize.height > 0 else { return [:] }

        let ids = Set(nodes.map(\.id))
        var rank: [PersistentIdentifier: Int] = [:]
        for node in nodes { rank[node.id] = 0 }

        let iterations = max(1, nodes.count)
        for _ in 0..<iterations {
            var changed = false
            for link in links where link.fromID != link.toID {
                guard ids.contains(link.fromID), ids.contains(link.toID) else { continue }
                let candidate = rank[link.fromID, default: 0] + 1
                if candidate > rank[link.toID, default: 0] {
                    rank[link.toID] = candidate
                    changed = true
                }
            }
            if !changed { break }
        }

        let columns = Dictionary(grouping: nodes, by: { rank[$0.id, default: 0] })
        let columnKeys = columns.keys.sorted()

        var orderByColumn: [Int: [PersistentIdentifier]] = [:]
        var previousRow: [PersistentIdentifier: Double] = [:]
        for column in columnKeys {
            var list = columns[column] ?? []
            if previousRow.isEmpty {
                list.sort { $0.sortMode.localizedCaseInsensitiveCompare($1.sortMode) == .orderedAscending }
            } else {
                list.sort { a, b in
                    let aKey = barycenter(of: a.id, links: links, previous: previousRow)
                    let bKey = barycenter(of: b.id, links: links, previous: previousRow)
                    switch (aKey, bKey) {
                    case let (av?, bv?): return av < bv
                    case (_?, nil): return true
                    case (nil, _?): return false
                    case (nil, nil): return a.sortMode.localizedCaseInsensitiveCompare(b.sortMode) == .orderedAscending
                    }
                }
            }
            let order = list.map(\.id)
            orderByColumn[column] = order
            for (i, id) in order.enumerated() {
                previousRow[id] = Double(i)
            }
        }

        var result: [PersistentIdentifier: CGPoint] = [:]
        let columnWidth = canvasSize.width / CGFloat(max(1, columnKeys.count))
        for (i, column) in columnKeys.enumerated() {
            let list = orderByColumn[column] ?? []
            let rowHeight = canvasSize.height / CGFloat(max(1, list.count))
            let x = columnWidth * (CGFloat(i) + 0.5)
            for (row, id) in list.enumerated() {
                result[id] = CGPoint(x: x, y: rowHeight * (CGFloat(row) + 0.5))
            }
        }

        for _ in 0..<6 {
            var next = result
            for (_, column) in columnKeys.enumerated() {
                let list = orderByColumn[column] ?? []
                guard !list.isEmpty else { continue }
                let slot = canvasSize.height / CGFloat(list.count)
                for (row, id) in list.enumerated() {
                    guard let p = result[id] else { continue }
                    var ys: [CGFloat] = [p.y]
                    for link in links {
                        if link.fromID == id, let q = result[link.toID] { ys.append(q.y) }
                        if link.toID == id, let q = result[link.fromID] { ys.append(q.y) }
                    }
                    let mean = ys.reduce(0, +) / CGFloat(ys.count)
                    let lo = CGFloat(row) * slot
                    let hi = CGFloat(row + 1) * slot
                    next[id] = CGPoint(x: p.x, y: min(hi, max(lo, mean)))
                }
            }
            result = next
        }
        return result
    }

    private static func barycenter(of id: PersistentIdentifier, links: [CCLink], previous: [PersistentIdentifier: Double]) -> Double? {
        var values: [Double] = []
        for link in links where link.toID == id {
            if let row = previous[link.fromID] { values.append(row) }
        }
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }
}

// MARK: - Value types

private struct CCEvent: Identifiable {
    let id: PersistentIdentifier
    let name: String
    let era: String
    let dateLabel: String
    let typeIcon: String
    let typeColor: Color
    let eraColor: Color
    let description: String
    let sortMode: String
    let sortKey: Int
}

private struct CCLink: Identifiable {
    let id: UUID
    let fromID: PersistentIdentifier
    let toID: PersistentIdentifier
    let roleName: String
    let roleColor: Color
    let source: String
}

private struct PositionedNode: Identifiable {
    let id: PersistentIdentifier
    let name: String
    let sub: String
    let eraLine: String
    let eraColor: Color
    let typeIcon: String
    let typeColor: Color
    let position: CGPoint
    let dimmed: Bool
}

// MARK: - Node card

private struct CausalNodeCard: View {
    let name: String
    let sub: String
    let eraLine: String
    let eraColor: Color
    let typeIcon: String
    let typeColor: Color
    let hovered: Bool
    let selected: Bool
    let dimmed: Bool

    private static let size = CGSize(width: 214, height: 68)

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(
                    (selected ? Color.accentColor.opacity(0.18) : eraColor.opacity(0.16))
                        .opacity(dimmed ? 0.35 : 1)
                )
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(eraColor)
                    .frame(width: 4)
                ZStack {
                    Circle()
                        .fill(typeColor.opacity(0.9))
                        .frame(width: 26, height: 26)
                    Image(systemName: typeIcon)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.system(size: 11, weight: .semibold))
                        .lineLimit(2)
                    Text(sub)
                        .font(.system(size: 8.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Text(eraLine)
                        .font(.system(size: 8))
                        .foregroundStyle(eraColor)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(.leading, 0)
            .padding(.trailing, 8)
            .padding(.vertical, 6)
            .padding(.leading, 4)
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(
                    selected ? Color.accentColor : (hovered ? eraColor : eraColor.opacity(0.45)),
                    lineWidth: selected ? 2 : (hovered ? 1.5 : 1)
                )
        )
        .shadow(color: .black.opacity(hovered ? 0.18 : 0.08), radius: hovered ? 7 : 3, y: hovered ? 3 : 1)
        .opacity(dimmed ? 0.4 : 1)
        .scaleEffect(hovered ? 1.03 : 1.0)
        .animation(.easeOut(duration: 0.12), value: hovered)
    }
}

// MARK: - Event detail sheet

private struct CausalChainEventSheet: View {
    let entityID: PersistentIdentifier
    @State private var event: Event?
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if let event {
                    EventDetailView(event: event)
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 200)
                }
            }
            .frame(width: 840, height: 680)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .task {
            let fetch = FetchDescriptor<Event>(predicate: #Predicate { $0.persistentModelID == entityID })
            event = try? modelContext.fetch(fetch).first
        }
    }
}