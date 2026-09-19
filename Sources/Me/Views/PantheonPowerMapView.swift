import SwiftUI
import SwiftData

struct PantheonPowerMapView: View {

    enum PowerMetric: String, CaseIterable, Identifiable {
        case power = "Power"
        case relationships = "Relationships"
        case balanced = "Balanced"
        var id: String { rawValue }
        var help: String {
            switch self {
            case .power: return "Power = 1 + 2×relationships + events + places + aliases + images"
            case .relationships: return "Slice area = 1 + number of relationships"
            case .balanced: return "Every figure counts as exactly 1"
            }
        }
    }

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Pantheon.name) private var allPantheons: [Pantheon]
    @Query(sort: \Figure.name) private var allFigures: [Figure]
    @Query(sort: \FigureType.name) private var figureTypes: [FigureType]

    @State private var metric: PowerMetric = .power
    @State private var hovered: Slice?
    @State private var focusPantheonID: PersistentIdentifier?
    @State private var detailFigureID: PersistentIdentifier?
    @State private var canvasSize: CGSize = .zero

    private let radii = SunburstRadii(
        pantheonInner: 101, pantheonOuter: 191,
        domainInner: 194, domainOuter: 271,
        figureInner: 273, figureOuter: 351
    )

    var body: some View {
        let slices = layoutSlices
        VStack(spacing: 10) {
            header
            GeometryReader { geo in
                let side = max(280, min(geo.size.width - 300, geo.size.height))
                HStack(alignment: .top, spacing: 14) {
                    canvasView(slices: slices)
                        .frame(width: side, height: side)
                    sidePanel
                }
                .padding(.horizontal, 2)
            }
            footer
        }
        .padding()
        .sheet(isPresented: showDetailBinding) {
            if let id = detailFigureID {
                PantheonFigureSheet(entityID: id)
            }
        }
        .overlay(alignment: .bottom) {
            if let info = hoverInfo {
                tooltipView(info)
            }
        }
    }

    // MARK: - Header / Footer / Panel

    private var header: some View {
        HStack(spacing: 12) {
            Label("Pantheon Power Map", systemImage: "circle.hexagongrid.fill")
                .font(.title3.bold())
            Spacer()
            if let focusID = focusPantheonID {
                Button {
                    focusPantheonID = nil
                } label: {
                    Label(pantheonName(for: focusID), systemImage: "xmark.circle.fill")
                        .font(.callout)
                }
                .buttonStyle(.bordered)
            }
            Picker("Metric", selection: $metric) {
                ForEach(PowerMetric.allCases) { m in
                    Text(m.rawValue).tag(m)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 280)
            .help(metric.help)
        }
    }

    private var footer: some View {
        HStack(spacing: 16) {
            Text(metric.help)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(mappedFigureCount) figures · \(powerTree.count) pantheons · \(domainCount) domains · Σ \(Int(totalWeight.rounded())) power")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var sidePanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Pantheons")
                .font(.headline)
            ForEach(pantheonEntries) { entry in
                Button {
                    if let id = entry.id { toggleFocus(id) }
                } label: {
                    HStack(spacing: 8) {
                        Circle().fill(entry.color).frame(width: 12, height: 12)
                        Text(entry.name)
                            .font(.callout)
                            .lineLimit(1)
                        Spacer()
                        Text("\(entry.count)")
                            .font(.callout.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
            Divider()
            Text("Figure types")
                .font(.headline)
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(typeLegendRows) { row in
                        HStack(spacing: 8) {
                            Circle().fill(row.color).frame(width: 10, height: 10)
                            Image(systemName: row.icon).font(.caption2)
                            Text(row.name).font(.caption)
                            Spacer()
                            Text("\(row.count)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            Spacer(minLength: 0)
            Text("Tap a pantheon to focus it.\nTap a figure slice to open it.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .frame(width: 252, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(nsColor: .separatorColor).opacity(0.3), lineWidth: 1))
    }

    // MARK: - Canvas

    private func canvasView(slices: [Slice]) -> some View {
        Canvas { context, size in
            drawSlices(slices, in: context, size: size)
        }
        .contentShape(Rectangle())
        .background(
            GeometryReader { g in
                Color.clear
                    .onAppear { canvasSize = g.size }
                    .onChange(of: g.size) { _, newSize in canvasSize = newSize }
            }
        )
        .onContinuousHover { phase in
            switch phase {
            case .active(let location): hovered = slice(at: location)
            case .ended: hovered = nil
            }
        }
        .gesture(
            SpatialTapGesture().onEnded { value in
                handleTap(at: value.location)
            }
        )
    }

    private func drawSlices(_ slices: [Slice], in context: GraphicsContext, size: CGSize) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        for slice in slices {
            let isHover = hovered?.matches(slice) == true
            let path = sectorPath(slice, center: center)
            let fill = isHover ? slice.color : dimmed(slice.color, kind: slice.kind)
            context.fill(path, with: .color(fill))
            context.stroke(path, with: .color(Color(nsColor: .windowBackgroundColor)), lineWidth: isHover ? 2.5 : 1)
        }
        drawLabels(slices, in: context, center: center)
    }

    private func drawLabels(_ slices: [Slice], in context: GraphicsContext, center: CGPoint) {
        for slice in slices {
            switch slice.kind {
            case .pantheon:
                if slice.sweep > 22 {
                    let c = centroid(slice, center)
                    let midR = (slice.innerRadius + slice.outerRadius) / 2
                    let avail = slice.sweep * .pi / 180 * midR
                    let text = Text(slice.pantheonName)
                        .font(.system(size: 13, weight: .bold, design: .serif))
                        .foregroundColor(.white)
                    if width(of: text, in: context) + 8 < avail {
                        context.draw(text, at: c, anchor: .center)
                    }
                }
            case .domain:
                if slice.sweep > 6, let name = slice.domainName {
                    let c = centroid(slice, center)
                    let midR = (slice.innerRadius + slice.outerRadius) / 2
                    let avail = slice.sweep * .pi / 180 * midR
                    let text = Text(name)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.white)
                    if width(of: text, in: context) + 6 < avail {
                        var r = context
                        r.translateBy(x: c.x, y: c.y)
                        r.rotate(by: .degrees(radialRotation(for: (slice.startDeg + slice.endDeg) / 2)))
                        r.draw(text, at: .zero, anchor: .center)
                    }
                }
            case .figure:
                if slice.sweep > 2.6, let name = slice.figureName {
                    let c = centroid(slice, center)
                    let midR = (slice.innerRadius + slice.outerRadius) / 2
                    let avail = slice.sweep * .pi / 180 * midR
                    let text = Text(name)
                        .font(.system(size: 7.5, weight: .medium))
                        .foregroundColor(.white)
                    if width(of: text, in: context) + 4 < avail {
                        var r = context
                        r.translateBy(x: c.x, y: c.y)
                        r.rotate(by: .degrees(radialRotation(for: (slice.startDeg + slice.endDeg) / 2)))
                        r.draw(text, at: .zero, anchor: .center)
                    }
                }
            }
        }
    }

    private func width(of text: Text, in context: GraphicsContext) -> CGFloat {
        context.resolve(text)
            .measure(in: CGSize(width: 10000, height: 10000))
            .width
    }

    private func dimmed(_ c: Color, kind: Slice.Kind) -> Color {
        switch kind {
        case .pantheon: return c.opacity(0.95)
        case .domain: return c.opacity(0.45)
        case .figure: return c.opacity(0.8)
        }
    }

    private func radialRotation(for midDeg: Double) -> Double {
        var rot = midDeg
        if rot > 90 && rot < 270 { rot += 180 }
        return rot
    }

    private func centroid(_ slice: Slice, _ center: CGPoint) -> CGPoint {
        let mid = (slice.startDeg + slice.endDeg) / 2 * .pi / 180
        let r = (slice.innerRadius + slice.outerRadius) / 2
        return CGPoint(x: center.x + r * CGFloat(sin(mid)), y: center.y - r * CGFloat(cos(mid)))
    }

    private func sectorPath(_ slice: Slice, center: CGPoint) -> Path {
        let a0 = slice.startDeg * .pi / 180
        let a1 = slice.endDeg * .pi / 180
        let steps = max(4, Int(slice.sweep / 10) + 1)

        func pt(_ t: Double, _ r: CGFloat) -> CGPoint {
            CGPoint(x: center.x + r * CGFloat(sin(t)), y: center.y - r * CGFloat(cos(t)))
        }

        var p = Path()
        p.move(to: pt(a0, slice.innerRadius))
        for i in 1...steps {
            p.addLine(to: pt(a0 + (a1 - a0) * Double(i) / Double(steps), slice.innerRadius))
        }
        for i in (0...steps).reversed() {
            p.addLine(to: pt(a0 + (a1 - a0) * Double(i) / Double(steps), slice.outerRadius))
        }
        p.closeSubpath()
        return p
    }

    // MARK: - Hit testing & actions

    private func slice(at location: CGPoint) -> Slice? {
        let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
        let dx = location.x - center.x
        let dy = location.y - center.y
        let dist = hypot(dx, dy)
        guard dist >= radii.pantheonInner - 4, dist <= radii.figureOuter + 4 else { return nil }
        var deg = atan2(dx, -dy) * 180 / .pi
        if deg < 0 { deg += 360 }
        return layoutSlices.first { slice in
            slice.startDeg <= deg && deg < slice.endDeg && dist >= slice.innerRadius && dist <= slice.outerRadius
        }
    }

    private func handleTap(at location: CGPoint) {
        guard let s = slice(at: location) else { return }
        switch s.kind {
        case .figure: detailFigureID = s.figureID
        case .pantheon: toggleFocus(s.pantheonID)
        case .domain: break
        }
    }

    private func toggleFocus(_ id: PersistentIdentifier) {
        focusPantheonID = (focusPantheonID == id) ? nil : id
    }

    private var showDetailBinding: Binding<Bool> {
        Binding(
            get: { detailFigureID != nil },
            set: { if !$0 { detailFigureID = nil } }
        )
    }

    // MARK: - Value tree

    private var layoutSlices: [Slice] {
        let tree = focusPantheonID.flatMap { focusID in
            powerTree.first { $0.id == focusID }
        }.map { [$0] } ?? powerTree
        guard !tree.isEmpty else { return [] }
        let total = tree.reduce(0.0) { $0 + $1.weight(metric) }
        guard total > 0 else { return [] }

        var slices: [Slice] = []
        var cursor = 0.0
        for pantheon in tree {
            let sweep = pantheon.weight(metric) / total * 360
            appendPantheon(pantheon, start: cursor, sweep: sweep, into: &slices)
            cursor += sweep
        }
        return slices
    }

    private func appendPantheon(_ p: PowerPantheon, start: Double, sweep: Double, into slices: inout [Slice]) {
        let end = start + sweep
        slices.append(Slice(
            kind: .pantheon,
            pantheonID: p.id, pantheonName: p.name,
            domainName: nil, figureID: nil, figureName: nil,
            color: p.color,
            startDeg: start, endDeg: end,
            innerRadius: radii.pantheonInner, outerRadius: radii.pantheonOuter
        ))
        guard sweep > 0, !p.domains.isEmpty else { return }
        var cursor = start
        for domain in p.domains {
            let dSweep = domain.weight(metric) / p.weight(metric) * sweep
            appendDomain(domain, pantheon: p, start: cursor, sweep: dSweep, into: &slices)
            cursor += dSweep
        }
    }

    private func appendDomain(_ d: PowerDomain, pantheon: PowerPantheon, start: Double, sweep: Double, into slices: inout [Slice]) {
        let end = start + sweep
        slices.append(Slice(
            kind: .domain,
            pantheonID: pantheon.id, pantheonName: pantheon.name,
            domainName: d.name, figureID: nil, figureName: nil,
            color: pantheon.color.opacity(0.55),
            startDeg: start, endDeg: end,
            innerRadius: radii.domainInner, outerRadius: radii.domainOuter
        ))
        guard sweep > 0, !d.figures.isEmpty else { return }
        var cursor = start
        for figure in d.figures {
            let fSweep = figure.weight(metric) / d.weight(metric) * sweep
            slices.append(Slice(
                kind: .figure,
                pantheonID: pantheon.id, pantheonName: pantheon.name,
                domainName: d.name, figureID: figure.id, figureName: figure.name,
                color: figure.typeColor,
                startDeg: cursor, endDeg: cursor + fSweep,
                innerRadius: radii.figureInner, outerRadius: radii.figureOuter
            ))
            cursor += fSweep
        }
    }

    private var powerTree: [PowerPantheon] {
        var figureBuckets: [PersistentIdentifier: [PowerFigure]] = [:]
        for figure in allFigures {
            let pf = makePowerFigure(figure)
            for pantheon in figure.pantheons {
                figureBuckets[pantheon.persistentModelID, default: []].append(pf)
            }
        }
        var result: [PowerPantheon] = []
        for pantheon in allPantheons {
            guard let figures = figureBuckets[pantheon.persistentModelID], !figures.isEmpty else { continue }
            var domainBuckets: [String: [PowerFigure]] = [:]
            for pf in figures {
                let domains = pf.domain.components(separatedBy: ",")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
                for domain in domains {
                    domainBuckets[domain, default: []].append(pf)
                }
            }
            let sortedDomains = domainBuckets
                .map { PowerDomain(name: $0.key, figures: $0.value) }
                .sorted { $0.weight(metric) > $1.weight(metric) }
            result.append(PowerPantheon(
                id: pantheon.persistentModelID,
                name: pantheon.name,
                icon: pantheon.icon,
                color: pantheon.color,
                domains: sortedDomains
            ))
        }
        return result
    }

    private func makePowerFigure(_ figure: Figure) -> PowerFigure {
        let type = figure.figureType
        return PowerFigure(
            id: figure.persistentModelID,
            name: figure.name,
            domain: figure.domain,
            typeName: type?.name ?? "Unspecified",
            icon: type?.icon ?? "questionmark.circle",
            typeColor: type?.color ?? .gray,
            rel: figure.outgoingRelationships.count + figure.incomingRelationships.count,
            events: figure.events.count,
            places: figure.placeAssociations.count,
            alt: figure.alternateNames.count,
            images: figure.images.count
        )
    }

    private var mappedFigureCount: Int {
        var ids = Set<PersistentIdentifier>()
        for p in powerTree {
            for d in p.domains {
                for f in d.figures { ids.insert(f.id) }
            }
        }
        return ids.count
    }

    private var domainCount: Int {
        powerTree.reduce(0) { $0 + $1.domains.count }
    }

    private var totalWeight: Double {
        powerTree.reduce(0) { $0 + $1.weight(metric) }
    }

    private func pantheonName(for id: PersistentIdentifier) -> String {
        powerTree.first(where: { $0.id == id })?.name ?? "Pantheon"
    }

    // MARK: - Tooltip

    private var hoverInfo: HoverInfo? {
        guard let s = hovered else { return nil }
        switch s.kind {
        case .pantheon:
            guard let p = powerTree.first(where: { $0.id == s.pantheonID }) else { return nil }
            return HoverInfo(
                color: p.color,
                title: p.name,
                subtitle: "\(p.figureCount) figures · \(p.domains.count) domains",
                detail: "Σ \(Int(p.weight(metric).rounded())) \(metric.rawValue.lowercased())"
            )
        case .domain:
            guard let p = powerTree.first(where: { $0.id == s.pantheonID }),
                  let d = p.domains.first(where: { $0.name == s.domainName }) else { return nil }
            return HoverInfo(
                color: p.color.opacity(0.6),
                title: d.name,
                subtitle: "\(d.figures.count) figures · in \(p.name)",
                detail: "Σ \(Int(d.weight(metric).rounded())) \(metric.rawValue.lowercased())"
            )
        case .figure:
            guard let p = powerTree.first(where: { $0.id == s.pantheonID }),
                  let d = p.domains.first(where: { $0.name == s.domainName }),
                  let f = d.figures.first(where: { $0.id == s.figureID }) else { return nil }
            return HoverInfo(
                color: f.typeColor,
                title: f.name,
                subtitle: "\(f.typeName) · in \(p.name), \(d.name)",
                detail: f.breakdown
            )
        }
    }

    private func tooltipView(_ info: HoverInfo) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Circle().fill(info.color).frame(width: 10, height: 10)
                Text(info.title).font(.callout.bold())
            }
            Text(info.subtitle).font(.caption).foregroundStyle(.secondary)
            Text(info.detail).font(.caption).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 10).fill(.thickMaterial))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(nsColor: .separatorColor).opacity(0.4), lineWidth: 1))
        .padding(.bottom, 12)
    }

    // MARK: - Legend data

    private var pantheonEntries: [PantheonEntry] {
        powerTree.map { PantheonEntry(id: $0.id, name: $0.name, color: $0.color, count: $0.figureCount) }
    }

    private var typeLegendRows: [TypeLegendRow] {
        figureTypes
            .filter { $0.figures.count > 0 }
            .map { TypeLegendRow(id: "\($0.persistentModelID.hashValue)", name: $0.name, icon: $0.icon, color: $0.color, count: $0.figures.count) }
            .sorted { $0.count > $1.count }
    }
}

// MARK: - Value types

private struct SunburstRadii {
    let pantheonInner: CGFloat
    let pantheonOuter: CGFloat
    let domainInner: CGFloat
    let domainOuter: CGFloat
    let figureInner: CGFloat
    let figureOuter: CGFloat
}

private struct PowerFigure {
    let id: PersistentIdentifier
    let name: String
    let domain: String
    let typeName: String
    let icon: String
    let typeColor: Color
    let rel: Int
    let events: Int
    let places: Int
    let alt: Int
    let images: Int

    var score: Int { rel * 2 + events + places + alt + images }
    var breakdown: String { "\(rel) relationships · \(events) events · \(places) places · \(alt) aliases · \(images) images" }

    func weight(_ metric: PantheonPowerMapView.PowerMetric) -> Double {
        switch metric {
        case .power: return Double(1 + score)
        case .relationships: return Double(1 + rel)
        case .balanced: return 1
        }
    }
}

private struct PowerDomain {
    let name: String
    let figures: [PowerFigure]
    func weight(_ metric: PantheonPowerMapView.PowerMetric) -> Double {
        figures.reduce(0) { $0 + $1.weight(metric) }
    }
}

private struct PowerPantheon {
    let id: PersistentIdentifier
    let name: String
    let icon: String
    let color: Color
    let domains: [PowerDomain]

    func weight(_ metric: PantheonPowerMapView.PowerMetric) -> Double {
        domains.reduce(0) { $0 + $1.weight(metric) }
    }

    var figureCount: Int {
        domains.reduce(0) { $0 + $1.figures.count }
    }
}

private struct Slice {
    enum Kind {
        case pantheon, domain, figure
    }
    let kind: Kind
    let pantheonID: PersistentIdentifier
    let pantheonName: String
    let domainName: String?
    let figureID: PersistentIdentifier?
    let figureName: String?
    let color: Color
    let startDeg: Double
    let endDeg: Double
    let innerRadius: CGFloat
    let outerRadius: CGFloat

    var sweep: Double { endDeg - startDeg }

    func matches(_ o: Slice) -> Bool {
        kind == o.kind
            && pantheonID == o.pantheonID
            && domainName == o.domainName
            && figureID == o.figureID
    }
}

private struct HoverInfo {
    let color: Color
    let title: String
    let subtitle: String
    let detail: String
}

private struct PantheonEntry: Identifiable {
    let id: PersistentIdentifier?
    let name: String
    let color: Color
    let count: Int
}

private struct TypeLegendRow: Identifiable {
    let id: String
    let name: String
    let icon: String
    let color: Color
    let count: Int
}

// MARK: - Sheet detail

private struct PantheonFigureSheet: View {
    let entityID: PersistentIdentifier
    @State private var figure: Figure?
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if let figure {
                    FigureDetailView(figure: figure)
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
            let fetch = FetchDescriptor<Figure>(predicate: #Predicate { $0.persistentModelID == entityID })
            figure = try? modelContext.fetch(fetch).first
        }
    }
}