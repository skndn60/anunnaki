import SwiftUI
import SwiftData

// MARK: - Lineage Tree View

struct LineageTreeView: View {
    var coordinator: NavigationCoordinator?

    @Query private var figures: [Figure]
    @Query private var figureTypes: [FigureType]
    @Query private var relationships: [Relationship]

    @State private var centerFigure: Figure?
    @State private var generationsAbove = 1
    @State private var generationsBelow = 1
    @State private var collapsedIDs: Set<String> = []
    @State private var detailFigure: Figure?
    @State private var altForFigure: Figure?
    @State private var rightClickFigureID: PersistentIdentifier?
    @State private var centerHistory: [Figure] = []
    @State private var sourceFilter = ""

    private var availableSources: [String] {
        let sources = relationships.map(\.sourceDisplayName).filter { !$0.isEmpty }
        return Array(Set(sources)).sorted()
    }

    private var filteredRelationships: [Relationship] {
        guard !sourceFilter.isEmpty else { return relationships }
        return relationships.filter { $0.sourceDisplayName == sourceFilter }
    }

    private let metrics = LineageTreeLayout.Metrics.standard

    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()
            if figures.isEmpty {
                emptyState
            } else if let center = centerFigure {
                treeCanvas(center)
            } else {
                emptyState
            }
        }
        .sheet(item: $altForFigure) { fig in
            AlternativePartnersSheet(
                figure: fig,
                partners: alternativePartners(of: fig),
                onClose: { altForFigure = nil },
                onRecenter: { altForFigure = nil; recenterTree(to: $0) }
            )
        }
        .sheet(item: $detailFigure) { fig in
            FigureDetailSheet(
                figure: fig,
                onClose: { detailFigure = nil },
                onRecenter: { detailFigure = nil; recenterTree(to: $0) }
            )
        }
        .onAppear {
            if let pendingID = coordinator?.consumePendingLineageFigureID(),
               let fig = figures.first(where: { $0.persistentModelID == pendingID }) {
                centerFigure = fig
            } else if centerFigure == nil {
                centerFigure = figures.first(where: { $0.name == "Anu" }) ?? figures.first
            }
        }
        .onChange(of: coordinator?.pendingLineageFigureID) { _, _ in
            if let pendingID = coordinator?.consumePendingLineageFigureID(),
               let fig = figures.first(where: { $0.persistentModelID == pendingID }) {
                centerFigure = fig
                collapsedIDs.removeAll()
            }
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: 8) {
            Text("Lineage Tree")
                .font(.title2.bold())
            if !centerHistory.isEmpty {
                Button(action: goBack) {
                    HStack(spacing: 2) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .font(.caption)
                    .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
                .help("Go back to previous figure")
            }
            Spacer()
            FigureTypeLegend(types: figureTypes)

            if availableSources.count > 1 {
                sourceFilterMenu
            }

            stepperButton(direction: .up, value: $generationsAbove, maximum: 4)
            stepperButton(direction: .down, value: $generationsBelow, maximum: 4)
        }
        .padding()
    }

    // MARK: - Stepper

    private var sourceFilterMenu: some View {
        Menu {
            Button("All sources") { sourceFilter = "" }
            Divider()
            ForEach(availableSources, id: \.self) { source in
                Button(source) { sourceFilter = source }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "book.closed")
                    .font(.system(size: 9))
                Text(sourceFilter.isEmpty ? "All sources" : sourceFilter)
                    .font(.caption)
                    .lineLimit(1)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 7))
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule().fill(Color.secondary.opacity(0.1)))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help("Filter lineage by source")
    }

    private enum StepperDirection {
        case up, down
        var label: String { self == .up ? "↑" : "↓" }
    }

    private func stepperButton(direction: StepperDirection, value: Binding<Int>, maximum: Int) -> some View {
        HStack(spacing: 4) {
            Button(action: { value.wrappedValue = max(0, value.wrappedValue - 1) }) {
                Image(systemName: "minus")
                    .font(.title3.weight(.semibold))
                    .frame(width: 32, height: 28)
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)

            Text("\(direction.label) \(value.wrappedValue)")
                .font(.body.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(minWidth: 32)

            Button(action: { value.wrappedValue = min(maximum, value.wrappedValue + 1) }) {
                Image(systemName: "plus")
                    .font(.title3.weight(.semibold))
                    .frame(width: 32, height: 28)
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
        }
        .help(direction == .up ? "Generations above" : "Generations below")
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "tree").font(.system(size: 48)).foregroundStyle(.secondary)
            Text("No figures yet").font(.title3).foregroundStyle(.secondary)
            Text("Add figures and relationships using the input screens to build the lineage tree.")
                .font(.body).foregroundStyle(.tertiary).multilineTextAlignment(.center)
                .frame(maxWidth: 300)
            Spacer()
        }
    }

    // MARK: - Tree Canvas

    private var treeData: LineageTreeData? {
        guard let center = centerFigure else { return nil }
        return LineageTreeLayout.buildTreeData(
            center: center,
            relationships: filteredRelationships,
            generationsAbove: generationsAbove,
            generationsBelow: generationsBelow,
            collapsedNames: collapsedIDs
        )
    }

    private func treeCanvas(_ center: Figure) -> some View {
        let data = LineageTreeLayout.buildTreeData(
            center: center,
            relationships: filteredRelationships,
            generationsAbove: generationsAbove,
            generationsBelow: generationsBelow,
            collapsedNames: collapsedIDs
        )
        let layout = LineageTreeLayout.computeLayout(data: data, metrics: metrics)

        return ScrollView([.horizontal, .vertical], showsIndicators: true) {
            ZStack(alignment: .topLeading) {
                Canvas { context, _ in
                    drawGenerationBackground(context: &context, data: data, layout: layout)
                }
                .allowsHitTesting(false)
                .frame(width: layout.canvasWidth, height: layout.canvasHeight)

                Canvas { context, _ in
                    drawBrackets(context: &context, data: data, layout: layout)
                }
                .allowsHitTesting(false)
                .frame(width: layout.canvasWidth, height: layout.canvasHeight)

                Canvas { context, _ in
                    drawNodes(context: &context, data: data, layout: layout, centerID: center.persistentModelID)
                }
                .frame(width: layout.canvasWidth, height: layout.canvasHeight)
                .onTapGesture { location in
                    handleTap(at: location, layout: layout)
                }
                .contextMenu {
                    if let figID = rightClickFigureID,
                       let fig = figures.first(where: { $0.persistentModelID == figID }) {
                        Button("Show Details") { detailFigure = fig }
                        Divider()
                        Button("Recenter") { recenterTree(to: figID) }
                        if collapsedIDs.contains(fig.name) {
                            Button("Expand Branch") { collapsedIDs.remove(fig.name) }
                        } else {
                            Button("Collapse Branch") { collapsedIDs.insert(fig.name) }
                        }
                    }
                }
                .onContinuousHover { phase in
                    if case .active(let location) = phase {
                        rightClickFigureID = figureAt(location: location, in: layout)
                    } else {
                        rightClickFigureID = nil
                    }
                }

                if let figID = rightClickFigureID,
                   let frame = layout.nodeLayouts[figID],
                   let figure = figures.first(where: { $0.persistentModelID == figID }),
                   figure.mugshotImage != nil {
                    let size: CGFloat = 140
                    let below = frame.maxY + size < layout.canvasHeight
                    MugshotView(
                        image: figure.mugshotImage,
                        cropRect: ImageCropRect(encoded: figure.mugshotCropRect),
                        size: size,
                        figureType: figure.figureType,
                        identification: figure.mugshotIdentification
                    )
                    .allowsHitTesting(false)
                    .position(
                        x: frame.midX,
                        y: below ? frame.maxY + 28 + size / 2 : frame.minY - 28 - size / 2
                    )
                }
            }
            .padding(40)
        }
        .id("tree-\(center.persistentModelID)-\(generationsAbove)-\(generationsBelow)")
    }

    // MARK: - Generation Colors

    private func generationColor(for gen: Int) -> Color {
        let palette: [Color] = [
            Color(red: 0.75, green: 0.35, blue: 0.20),
            Color(red: 0.20, green: 0.50, blue: 0.70),
            Color(red: 0.45, green: 0.45, blue: 0.45),
            Color(red: 0.25, green: 0.60, blue: 0.40),
            Color(red: 0.60, green: 0.28, blue: 0.52),
        ]
        let idx = gen + 2
        return palette[max(0, min(idx, palette.count - 1))]
    }

    private func generationTint(for gen: Int) -> Color {
        let base = generationColor(for: gen)
        return base.opacity(0.04)
    }

    // MARK: - Generation Background

    private func drawGenerationBackground(context: inout GraphicsContext, data: LineageTreeData, layout: LineageLayout) {
        let levels = data.levels.sorted(by: { $0.first?.generation ?? 0 < $1.first?.generation ?? 0 })
        for level in levels {
            guard let gen = level.first?.generation,
                  let firstEntry = level.first,
                  let firstFrame = layout.nodeLayouts[firstEntry.primary.persistentModelID] else { continue }
            let rowY = firstFrame.minY - 6
            let rowH = metrics.cardHeight + 12
            let genRect = CGRect(x: 0, y: rowY, width: layout.canvasWidth, height: rowH)
            context.fill(Path(genRect), with: .color(generationTint(for: gen)))
        }
    }

    // MARK: - Bracket Drawing

    private func drawBrackets(context: inout GraphicsContext, data: LineageTreeData, layout: LineageLayout) {
        let lineColor = Color.secondary.opacity(0.45)
        let lineWidth: CGFloat = 2.0
        let style = StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)

        for segment in LineageTreeLayout.bracketSegments(data: data, layout: layout, metrics: metrics) {
            var path = Path()
            path.move(to: segment.start)
            path.addLine(to: segment.end)
            context.stroke(path, with: .color(lineColor), style: style)
        }
    }

    // MARK: - Node Drawing

    private func drawNodes(context: inout GraphicsContext, data: LineageTreeData, layout: LineageLayout, centerID: PersistentIdentifier) {
        for (figID, frame) in layout.nodeLayouts {
            let figure: Figure?
            let generation: Int
            if let dbFig = figures.first(where: { $0.persistentModelID == figID }) {
                figure = dbFig
                generation = data.entries.values.first(where: { $0.primary.persistentModelID == figID })?.generation ?? 0
            } else if let placeholder = data.entries.values.first(where: { $0.primary.persistentModelID == figID })?.primary {
                figure = placeholder
                generation = data.entries.values.first(where: { $0.primary.persistentModelID == figID })?.generation ?? 0
            } else if let partnerFig = data.entries.values.compactMap({ $0.partner }).first(where: { $0.persistentModelID == figID }) {
                figure = partnerFig
                generation = data.entries.values.first(where: { $0.partner?.persistentModelID == figID })?.generation ?? 0
            } else {
                continue
            }
            guard let figure else { continue }
            let isCenter = figID == centerID
            let alt = layout.figureAltCounts[figID] ?? 0
            drawCard(context: &context, figure: figure, frame: frame, generation: generation, isCenter: isCenter, altCount: alt)
        }
    }

    private func drawCard(context: inout GraphicsContext, figure: Figure, frame: CGRect, generation: Int, isCenter: Bool, altCount: Int) {
        let isUnknown = LineageTreeLayout.isUnknownParentName(figure.name)
        let color = isUnknown ? Color.gray : (figure.figureType?.color ?? .gray)
        let radius: CGFloat = 7
        let bgPath = Path(roundedRect: frame, cornerRadius: radius)
        context.fill(bgPath, with: .color(isUnknown ? Color.gray.opacity(0.06) : color.opacity(0.10)))

        if isCenter {
            context.fill(bgPath, with: .color(Color.accentColor.opacity(0.06)))
        }

        let borderColor = isCenter ? Color.accentColor : (isUnknown ? Color.secondary.opacity(0.35) : color.opacity(0.3))
        let borderWidth: CGFloat = isCenter ? 2 : (isUnknown ? 1 : 0.5)
        let borderDash: [CGFloat] = isUnknown ? [4, 3] : []
        context.stroke(bgPath, with: .color(borderColor), style: StrokeStyle(lineWidth: borderWidth, lineCap: .round, dash: borderDash))

        if isUnknown {
            let ghostPath = Path(ellipseIn: CGRect(x: frame.minX + 24, y: frame.minY + 10, width: 12, height: 12))
            context.stroke(ghostPath, with: .color(.secondary.opacity(0.4)), style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
            context.draw(
                Text("?").font(.system(size: 9, weight: .bold)).foregroundColor(.secondary.opacity(0.5)),
                at: CGPoint(x: frame.minX + 30, y: frame.minY + 16),
                anchor: .center
            )
            let shortName = figure.name.replacingOccurrences(of: "Unknown ", with: "")
            context.draw(
                Text(shortName.uppercased())
                    .font(.system(size: 7, weight: .bold))
                    .foregroundColor(.secondary.opacity(0.6)),
                at: CGPoint(x: frame.midX + 8, y: frame.midY - 1),
                anchor: .leading
            )
            return
        }

        let dotRect = CGRect(x: frame.minX + 12, y: frame.minY + 12, width: 7, height: 7)
        context.fill(Path(ellipseIn: dotRect), with: .color(color))

        let maxNameLen: Int = 14
        let displayName = figure.name.count > maxNameLen ? String(figure.name.prefix(maxNameLen - 1)) + "…" : figure.name
        let nameText = Text(displayName).font(.system(size: 11, weight: .semibold)).foregroundColor(.primary)
        context.draw(nameText, at: CGPoint(x: frame.minX + 26, y: frame.minY + 11), anchor: .topLeading)

        let typeText = figure.gender != .unknown
            ? Text(figure.gender.symbol + " ").font(.system(size: 9)) + Text(figure.figureType?.name ?? "").font(.system(size: 9)).foregroundColor(.secondary)
            : Text(figure.figureType?.name ?? "").font(.system(size: 9)).foregroundColor(.secondary)
        context.draw(
            typeText,
            at: CGPoint(x: frame.minX + 26, y: frame.minY + 32),
            anchor: .topLeading
        )

        if altCount > 0 {
            let badge = Text("+\(altCount)").font(.system(size: 8, weight: .bold)).foregroundColor(.white)
            let bw: CGFloat = altCount > 9 ? 24 : 18
            let badgeRect = CGRect(x: frame.maxX - bw - 2, y: frame.minY - 5, width: bw, height: 14)
            context.fill(Path(roundedRect: badgeRect, cornerRadius: 7), with: .color(Color.accentColor))
            context.draw(badge, at: CGPoint(x: badgeRect.midX, y: badgeRect.midY), anchor: .center)
        }
    }

    // MARK: - Interaction

    private func recenterTree(to figID: PersistentIdentifier) {
        guard figID != centerFigure?.persistentModelID,
              let fig = figures.first(where: { $0.persistentModelID == figID }) else { return }
        if let current = centerFigure {
            centerHistory.append(current)
        }
        withAnimation(.easeInOut(duration: 0.2)) {
            centerFigure = fig
            collapsedIDs.removeAll()
        }
    }

    private func goBack() {
        guard let previous = centerHistory.popLast() else { return }
        centerFigure = previous
        collapsedIDs.removeAll()
    }

    private func handleTap(at location: CGPoint, layout: LineageLayout) {
        let badgeW: CGFloat = 18
        let badgeH: CGFloat = 14
        for (figID, frame) in layout.nodeLayouts {
            let alt = layout.figureAltCounts[figID] ?? 0
            if alt > 0 {
                let bw: CGFloat = alt > 9 ? 24 : badgeW
                let badgeRect = CGRect(x: frame.maxX - bw - 2, y: frame.minY - 5, width: bw, height: badgeH)
                if badgeRect.contains(location) {
                    altForFigure = figures.first(where: { $0.persistentModelID == figID })
                    return
                }
            }
        }
        for (figID, frame) in layout.nodeLayouts {
            if frame.contains(location) {
                recenterTree(to: figID)
                return
            }
        }
    }

    private func figureAt(location: CGPoint, in layout: LineageLayout) -> PersistentIdentifier? {
        for (figID, frame) in layout.nodeLayouts where frame.contains(location) {
            return figID
        }
        return nil
    }

// MARK: - Sheet Views

private struct AlternativePartnersSheet: View {
    let figure: Figure
    let partners: [(figure: Figure, source: String?)]
    let onClose: () -> Void
    let onRecenter: (PersistentIdentifier) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Alternative partners of \(figure.name)")
                    .font(.headline)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Close")
            }
            .padding()
            Divider()
            if partners.isEmpty {
                Text("No alternative partners found").foregroundStyle(.secondary).padding()
                Spacer()
            } else {
                List(partners, id: \.figure.persistentModelID) { partner in
                    HStack(spacing: 8) {
                        Circle().fill(partner.figure.figureType?.color ?? .gray).frame(width: 8, height: 8)
                        Text(partner.figure.name).font(.body)
                        Text(partner.figure.figureType?.name ?? "").font(.caption).foregroundStyle(.secondary)
                        if let source = partner.source {
                            SourceBadgeView(name: source)
                        }
                        Spacer()
                        Button("Recenter") {
                            onRecenter(partner.figure.persistentModelID)
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.accentColor)
                    }
                    .padding(.horizontal)
                }
            }
        }
        .frame(width: 360, height: 300)
    }
}

private struct FigureDetailSheet: View {
    let figure: Figure
    let onClose: () -> Void
    let onRecenter: (PersistentIdentifier) -> Void

    var body: some View {
        NavigationStack {
            FigureQuicklookView(figure: figure)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close", action: onClose)
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button("Recenter Tree") {
                            onRecenter(figure.persistentModelID)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
        }
        .frame(minWidth: 500, minHeight: 400)
    }
}

    private func alternativePartners(of figure: Figure) -> [(figure: Figure, source: String?)] {
        let preferred = LineageTreeLayout.preferredPartner(of: figure, relationships: filteredRelationships)
        let rels = filteredRelationships.filter {
            ($0.relationshipType?.name == "Spouse" || $0.relationshipType?.name == "Consort") &&
            ($0.fromFigure?.persistentModelID == figure.persistentModelID || $0.toFigure?.persistentModelID == figure.persistentModelID)
        }
        var partners: [(figure: Figure, source: String?)] = []
        var seen = Set<PersistentIdentifier>()
        for rel in rels {
            let p = rel.fromFigure?.persistentModelID == figure.persistentModelID ? rel.toFigure : rel.fromFigure
            if let fig = p, seen.insert(fig.persistentModelID).inserted {
                partners.append((fig, rel.sourceDisplayName.isEmpty ? nil : rel.sourceDisplayName))
            }
        }
        if let pref = preferred {
            partners.removeAll { $0.figure.persistentModelID == pref.persistentModelID }
        }
        return partners
    }
}
