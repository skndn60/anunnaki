import SwiftUI
import SwiftData

// MARK: - Timeline Axis

/// Piecewise year→x mapping that guarantees every dated era a minimum visual
/// width, so narrow eras (e.g. Creation of Mankind) remain comfortable scrollable
/// lanes instead of pin-thin slivers on a linear deep-time axis. Deep-time eras
/// keep their proportional width; only undersized eras are stretched.
struct TimelineAxis {
    let minYear: Int
    let maxYear: Int
    let width: CGFloat

    private struct Segment {
        let startYear: Int
        let endYear: Int
        let startX: CGFloat
        let endX: CGFloat

        var yearSpan: Int { endYear - startYear }
        var xSpan: CGFloat { endX - startX }
    }

    private let segments: [Segment]

    private init(minYear: Int, maxYear: Int, width: CGFloat, segments: [Segment]) {
        self.minYear = minYear
        self.maxYear = maxYear
        self.width = width
        self.segments = segments
    }

    var averagePointsPerYear: CGFloat {
        maxYear - minYear > 0 ? width / CGFloat(maxYear - minYear) : 1
    }

    func x(for year: Int) -> CGFloat {
        guard let first = segments.first, let last = segments.last else { return 0 }
        if year <= first.startYear { return first.startX }
        if year >= last.endYear { return last.endX }
        for segment in segments where year >= segment.startYear && year < segment.endYear {
            let slope = segment.yearSpan > 0 ? segment.xSpan / CGFloat(segment.yearSpan) : 0
            return segment.startX + CGFloat(year - segment.startYear) * slope
        }
        return 0
    }

    /// Builds an axis over [minYear, maxYear] where each dated era occupies at
    /// least `minEraWidth` points; gaps between/around eras stay proportional to
    /// `basePointsPerYear`. Eras are laid sequentially in chronological order.
    static func minimumWidth(
        minYear: Int,
        maxYear: Int,
        eras: [Era],
        minEraWidth: CGFloat,
        basePointsPerYear: CGFloat
    ) -> TimelineAxis {
        let dated: [(start: Int, end: Int)] = eras
            .compactMap { era in
                guard let start = era.startDate.startYear,
                      let end = era.endDate.endYear,
                      end > start else { return nil }
                return (start, end)
            }
            .sorted { $0.start < $1.start }

        var segments: [Segment] = []
        var curX: CGFloat = 0
        var cursorYear = minYear

        func appendGap(from fromYear: Int, to toYear: Int) {
            guard toYear > fromYear else { return }
            let width = CGFloat(toYear - fromYear) * basePointsPerYear
            segments.append(Segment(startYear: fromYear, endYear: toYear, startX: curX, endX: curX + width))
            curX += width
        }

        for era in dated {
            if era.start >= cursorYear {
                appendGap(from: cursorYear, to: era.start)
                let proportional = CGFloat(era.end - era.start) * basePointsPerYear
                let width = max(proportional, minEraWidth)
                segments.append(Segment(startYear: era.start, endYear: era.end, startX: curX, endX: curX + width))
                curX += width
                cursorYear = era.end
            }
        }
        appendGap(from: cursorYear, to: maxYear)

        return TimelineAxis(minYear: minYear, maxYear: maxYear, width: curX, segments: segments)
    }
}

// MARK: - Swimlane Mode

enum SwimlaneMode {
    case mythological
    case mythologicalTimed(axis: TimelineAxis)
    case historical(minYear: Int, pointsPerYear: CGFloat)

    var minYear: Int {
        switch self {
        case .mythological: return 0
        case .mythologicalTimed(let axis): return axis.minYear
        case .historical(let minYear, _): return minYear
        }
    }

    var pointsPerYear: CGFloat {
        switch self {
        case .mythological: return 1
        case .mythologicalTimed(let axis): return axis.averagePointsPerYear
        case .historical(_, let ppy): return ppy
        }
    }
}

// MARK: - Helpers

func figuresInEra(_ era: Era, from figures: [Figure]) -> [Figure] {
    figures
        .filter { $0.era?.persistentModelID == era.persistentModelID }
        .sorted { $0.birthDate.sortValue < $1.birthDate.sortValue }
}

func timelineTickInterval(for span: Int) -> Int {
    if span <= 500 { return 50 }
    if span <= 1200 { return 100 }
    if span <= 3000 { return 250 }
    return 500
}

// MARK: - Legend Icon

struct LegendIcon: View {
    let icon: String
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(color)
            Text(label)
        }
    }
}

// MARK: - Figure Swimlane Chip

struct FigureSwimlaneChip: View {
    let figure: Figure
    var onSelect: ((Figure) -> Void)?
    var onHoverChange: ((Figure, Bool) -> Void)?

    @State private var isHovered = false

    static let chipWidth: CGFloat = 110

    var body: some View {
        HStack(spacing: 4) {
            if let icon = figure.figureType?.icon {
                Image(systemName: icon)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(chipColor)
            } else {
                Circle()
                    .fill(chipColor)
                    .frame(width: 6, height: 6)
            }
            Text(figure.name)
                .font(.system(.caption, design: .serif))
                .fontWeight(.semibold)
                .lineLimit(1)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(chipColor.opacity(isHovered ? 0.18 : 0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(chipColor.opacity(isHovered ? 0.7 : 0.6), lineWidth: 1)
        )
        .frame(width: Self.chipWidth)
        .scaleEffect(isHovered ? 1.1 : 1)
        .shadow(color: isHovered ? chipColor.opacity(0.3) : .clear, radius: isHovered ? 6 : 0, y: isHovered ? 3 : 0)
        .offset(y: isHovered ? -3 : 0)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onHover { inside in
            isHovered = inside
            onHoverChange?(figure, inside)
        }
        .help(figureHelp)
        .onTapGesture { onSelect?(figure) }
    }

    private var figureHelp: String {
        let type = figure.figureType?.name ?? "Unknown"
        let birth = figure.birthDate.displayLabel
        let death = figure.deathDate.displayLabel
        return "\(figure.name) — \(type)\n\(birth) → \(death)"
    }

    private var chipColor: Color { figure.figureType?.color ?? .gray }
}

// MARK: - Era Swimlane Row

struct EraSwimlaneRow: View {
    let era: Era
    let figures: [Figure]
    let events: [Event]
    let places: [Place]
    let swimlaneWidth: CGFloat?
    let swimlaneHeight: CGFloat
    let mode: SwimlaneMode
    var showReignBars: Bool = true
    var onSelectFigure: ((Figure) -> Void)?
    var onSelectEvent: ((Event) -> Void)?

    @State private var hoveredFigureID: PersistentIdentifier?

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            titleLine
                .padding(.leading, eraStartX)
            swimlaneContent
        }
    }

    private var eraColor: Color {
        let palette: [Color] = [
            Color(hex: "C4895B"), // Terracotta
            Color(hex: "3A6B9F"), // Lapis Lazuli
            Color(hex: "C8943C"), // Gold
            Color(hex: "5A5A5A"), // Obsidian
            Color(hex: "8B6C4A"), // Cedar
            Color(hex: "5B7B6B"), // Patina
            Color(hex: "6B5B7B"), // Amethyst
            Color(hex: "8B4A4A"), // Pomegranate
            Color(hex: "B8A88A"), // Alabaster
            Color(hex: "4A6B6B"), // Euphrates
        ]
        return palette[abs(era.orderIndex) % palette.count]
    }

    private var eraStartX: CGFloat {
        switch mode {
        case .historical(let minYear, let ppy):
            guard let sy = era.startDate.startYear else { return 0 }
            return CGFloat(sy - minYear) * ppy
        case .mythologicalTimed(let axis):
            guard let sy = era.startDate.startYear else { return 0 }
            return axis.x(for: sy)
        case .mythological:
            return 0
        }
    }

    @State private var showCityMap = false

    private var cityName: String? {
        let words = era.name.split(separator: " ")
        guard let last = words.last else { return nil }
        let city = String(last).trimmingCharacters(in: .punctuationCharacters)
        return places.contains(where: { $0.name == city }) ? city : nil
    }

    private var titleLine: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                if let city = cityName, let r = era.name.range(of: city) {
                    let prefix = String(era.name[era.name.startIndex..<r.lowerBound])
                    let suffix = String(era.name[r.upperBound...])
                    Text(prefix)
                    Button(city) { showCityMap = true }
                        .buttonStyle(.plain)
                        .foregroundColor(.orange)
                        .underline()
                        .onHover { inside in
                            if inside { NSCursor.pointingHand.push() }
                            else { NSCursor.pop() }
                        }
                    Text(suffix)
                } else {
                    Text(era.name)
                }
            }
            .font(.system(size: 16, design: .serif))
            .fontWeight(.semibold)
            .popover(isPresented: $showCityMap) {
                if let city = cityName {
                    CityMapView(cityName: city, places: places)
                        .padding()
                }
            }
            if !dateRangeLabel.isEmpty {
                Text(dateRangeLabel)
                    .font(.system(.callout, design: .serif))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.leading, 4)
    }

    @ViewBuilder
    private var swimlaneContent: some View {
        switch mode {
        case .historical:
            if let w = swimlaneWidth {
                historicalSwimlane(containerWidth: w)
            }
        case .mythological:
            mythologicalSwimlane
        case .mythologicalTimed(let axis):
            mythologicalTimedSwimlane(axis: axis)
        }
    }

    private func historicalSwimlane(containerWidth: CGFloat) -> some View {
        let minYear = mode.minYear
        let ppy = mode.pointsPerYear

        let chipWidth = FigureSwimlaneChip.chipWidth
        let minSpacing: CGFloat = 16
        var chipLayouts: [(figure: Figure, x: CGFloat, level: Int, chipY: CGFloat)] = []

        if SKLTimelineLayout.isDynastyEra(figures) {
            // SKL dynasty: the SKL's ruler sequence is authoritative and its reign
            // lengths/dates are not — place rulers in reign order at equal slots
            // across the dynasty's own band (dates stay as "couleur locale").
            let eraStart = era.startDate.startYear ?? minYear
            let eraEnd: Int
            if let rawEnd = era.endDate.startYear ?? era.endDate.endYear, rawEnd > eraStart {
                eraEnd = rawEnd
            } else {
                eraEnd = eraStart + 200
            }
            let span = max(1, eraEnd - eraStart)
            let slots = SKLTimelineLayout.dynastySlotCenters(count: figures.count, spanYears: span)
            for (i, figure) in SKLTimelineLayout.dynastyOrderedFigures(figures).enumerated() {
                let year = eraStart + slots[i]
                let x = CGFloat(year - minYear) * ppy + chipWidth / 2
                chipLayouts.append((figure, x, 0, 0))
            }
        } else {
            var exactCount = 0

            for figure in figures {
                if let year = figure.birthDate.startYear {
                    let x = CGFloat(year - minYear) * ppy + chipWidth / 2
                    chipLayouts.append((figure, x, 0, 0))
                    exactCount += 1
                }
            }

            let estimatedCount = figures.count - exactCount
            if estimatedCount > 0 {
                let eraStart = era.startDate.startYear ?? minYear
                let eraEnd: Int
                if let rawEnd = era.endDate.startYear ?? era.endDate.endYear, rawEnd > eraStart {
                    eraEnd = rawEnd
                } else {
                    eraEnd = eraStart + 200
                }
                let span = max(1, eraEnd - eraStart)
                let step = CGFloat(span) / CGFloat(estimatedCount + 1)
                var estIdx = 0
                for figure in figures {
                    if figure.birthDate.startYear == nil {
                        let estYear = eraStart + Int(step * CGFloat(estIdx + 1))
                        let x = CGFloat(estYear - minYear) * ppy + chipWidth / 2
                        chipLayouts.append((figure, x, 0, 0))
                        estIdx += 1
                    }
                }
            }
        }

        chipLayouts.sort { $0.x < $1.x }

        if chipLayouts.count > 1 {
            var levelRanges: [Int: [CGFloat]] = [:]
            let levelOrder: [Int] = [0, -1, 1, -2, 2, -3, 3, -4, 4, -5, 5, -6, 6]

            for i in 0..<chipLayouts.count {
                let x = chipLayouts[i].x
                var placed = false
                for level in levelOrder {
                    let existing = levelRanges[level] ?? []
                    let overlaps = existing.contains { abs($0 - x) < chipWidth + minSpacing }
                    if !overlaps {
                        chipLayouts[i].level = level
                        levelRanges[level, default: []].append(x)
                        placed = true
                        break
                    }
                }
                if !placed {
                    let nextLevel = (levelRanges.keys.max() ?? 0) + 1
                    chipLayouts[i].level = nextLevel
                    levelRanges[nextLevel, default: []].append(x)
                }
            }
        }

        let minLevel = chipLayouts.map(\.level).min() ?? 0
        let maxLevel = chipLayouts.map(\.level).max() ?? 0
        let totalLevels = maxLevel - minLevel + 1
        let contentHeight = min(max(swimlaneHeight, CGFloat(totalLevels) * 25 + 24), swimlaneHeight * 3)
        let levelCenter = CGFloat(minLevel + maxLevel) / 2.0
        for i in chipLayouts.indices {
            chipLayouts[i].chipY = contentHeight / 2 + (CGFloat(chipLayouts[i].level) - levelCenter) * 25
        }

        let eraStartX: CGFloat
        let eraEndX: CGFloat
        if let startYear = era.startDate.startYear, let endYear = era.endDate.endYear, startYear < endYear {
            eraStartX = CGFloat(startYear - minYear) * ppy
            eraEndX = CGFloat(endYear - minYear) * ppy
        } else {
            eraStartX = 0
            eraEndX = 0
        }

        var eventLayouts: [(event: Event, x: CGFloat)] = []
        for event in events {
            if let year = event.date.startYear {
                let x = CGFloat(year - minYear) * ppy
                eventLayouts.append((event, x))
            }
        }

        return AnyView(ZStack(alignment: .leading) {
            if showReignBars {
                ForEach(figures) { figure in
                    if let birthYear = figure.birthDate.startYear, let deathYear = figure.deathDate.endYear {
                        let birthX = CGFloat(birthYear - minYear) * ppy
                        let deathX = CGFloat(deathYear - minYear) * ppy
                        let barWidth = max(4, deathX - birthX)
                        let isHovered = hoveredFigureID == figure.persistentModelID
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill((figure.figureType?.color ?? .gray).opacity(isHovered ? 0.7 : 0.22))
                            .frame(width: barWidth, height: isHovered ? 6 : 4)
                            .position(x: birthX + barWidth / 2, y: contentHeight / 2 + 12)
                            .onHover { inside in hoveredFigureID = inside ? figure.persistentModelID : nil }
                            .help("\(figure.name) — \(figure.birthDate.displayLabel) → \(figure.deathDate.displayLabel)")
                    }
                }
            }

            eraBar(startX: eraStartX, endX: eraEndX, height: contentHeight)

            ForEach(chipLayouts, id: \.figure.id) { layout in
                FigureSwimlaneChip(
                    figure: layout.figure,
                    onSelect: onSelectFigure,
                    onHoverChange: { figure, inside in
                        hoveredFigureID = inside ? figure.persistentModelID : nil
                    }
                )
                .position(x: layout.x, y: layout.chipY)
            }

            ForEach(eventLayouts, id: \.event.id) { layout in
                let color = layout.event.eventType?.color ?? .gray
                VStack(spacing: 1) {
                    Image(systemName: layout.event.eventType?.icon ?? "flag.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(color)
                    Text(layout.event.name)
                        .font(.system(size: 10))
                        .lineLimit(1)
                        .foregroundStyle(.secondary)
                }
                .frame(width: 80)
                .position(x: layout.x, y: contentHeight - 10)
                .help(layout.event.name)
                .onTapGesture { onSelectEvent?(layout.event) }
            }
        }
        .frame(width: containerWidth, height: contentHeight)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(
                    LinearGradient(
                        colors: [eraColor.opacity(0.12), eraColor.opacity(0.18)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(eraColor.opacity(0.25), lineWidth: 0.5)
                )
                .padding(.horizontal, 2)
        )
        )
    }




    private var mythologicalSwimlane: some View {
        HStack(spacing: 0) {
            if figures.isEmpty {
                Text("—")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(figures) { figure in
                        FigureSwimlaneChip(figure: figure, onSelect: onSelectFigure)
                    }
                }
                .padding(.horizontal, 8)
            }
        }
    }
    .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(
                    LinearGradient(
                        colors: [eraColor.opacity(0.12), eraColor.opacity(0.18)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(eraColor.opacity(0.25), lineWidth: 0.5)
                )
                .padding(.horizontal, 2)
        )
    }

    private func mythologicalTimedSwimlane(axis: TimelineAxis) -> some View {
        let startX = eraStartX
        let endX: CGFloat
        if let sy = era.startDate.startYear, let ey = era.endDate.endYear, sy < ey {
            endX = axis.x(for: ey)
        } else {
            endX = startX + max(200 * axis.averagePointsPerYear, 20)
        }
        let railWidth = max(0, (swimlaneWidth ?? 0) - startX)
        return ZStack(alignment: .leading) {
            eraBar(startX: startX, endX: endX, height: swimlaneHeight)
            if figures.isEmpty {
                Text("—")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .offset(x: startX + 4)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(figures) { figure in
                            FigureSwimlaneChip(figure: figure, onSelect: onSelectFigure)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                }
                .frame(width: railWidth, height: swimlaneHeight)
                .offset(x: startX)
            }
        }
        .frame(width: swimlaneWidth ?? 0, height: swimlaneHeight)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(
                    LinearGradient(
                        colors: [eraColor.opacity(0.06), eraColor.opacity(0.10)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .padding(.horizontal, 2)
        )
    }

    private func eraBar(startX: CGFloat, endX: CGFloat, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(eraColor.opacity(0.25))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(eraColor.opacity(0.35), lineWidth: 0.5)
            )
            .frame(width: max(20, endX - startX), height: height - 8)
            .position(x: (startX + endX) / 2, y: height / 2)
    }

    private var dateRangeLabel: String {
        let start = era.startDate
        let end = era.endDate
        if start.startYear == nil && start.endYear == nil && end.startYear == nil && end.endYear == nil {
            return ""
        }
        let startLabel = start.displayLabel
        let endLabel = end.displayLabel
        if startLabel == endLabel { return startLabel }
        return "\(startLabel) → \(endLabel)"
    }
}
