import SwiftUI
import SwiftData

// MARK: - Swimlane Mode

enum SwimlaneMode {
    case mythological
    case historical(minYear: Int, pointsPerYear: CGFloat)

    var minYear: Int {
        switch self {
        case .mythological: return 0
        case .historical(let minYear, _): return minYear
        }
    }

    var pointsPerYear: CGFloat {
        switch self {
        case .mythological: return 1
        case .historical(_, let ppy): return ppy
        }
    }
}

// MARK: - Helpers

func figuresInEra(_ era: Era, from figures: [Figure]) -> [Figure] {
    figures
        .filter { $0.birthDate.era == era.name }
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

    @State private var isHovered = false

    static let chipWidth: CGFloat = 100

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
                .font(.caption2)
                .fontWeight(.medium)
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
                .stroke(chipColor.opacity(isHovered ? 0.5 : 0.3), lineWidth: 0.5)
        )
        .frame(width: Self.chipWidth)
        .scaleEffect(isHovered ? 1.1 : 1)
        .shadow(color: isHovered ? chipColor.opacity(0.3) : .clear, radius: isHovered ? 6 : 0, y: isHovered ? 3 : 0)
        .offset(y: isHovered ? -3 : 0)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onHover { isHovered = $0 }
        .help(figureHelp)
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
    let swimlaneWidth: CGFloat?
    let swimlaneHeight: CGFloat
    let mode: SwimlaneMode

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            titleLine
                .padding(.leading, eraStartX)
            swimlaneContent
        }
    }

    private var eraColor: Color {
        let palette: [Color] = [
            Color(hex: "D4A574") ?? Color(red: 0.83, green: 0.65, blue: 0.45),
            Color(hex: "8B7355") ?? Color(red: 0.55, green: 0.45, blue: 0.33),
            Color(hex: "7B9E7B") ?? Color(red: 0.48, green: 0.62, blue: 0.48),
            Color(hex: "A87B6B") ?? Color(red: 0.66, green: 0.48, blue: 0.42),
            Color(hex: "7B6BA8") ?? Color(red: 0.48, green: 0.42, blue: 0.66),
            Color(hex: "6BA89B") ?? Color(red: 0.42, green: 0.66, blue: 0.61),
            Color(hex: "B88B4B") ?? Color(red: 0.72, green: 0.55, blue: 0.29),
            Color(hex: "8B6B4B") ?? Color(red: 0.55, green: 0.42, blue: 0.29),
            Color(hex: "6B7B8B") ?? Color(red: 0.42, green: 0.48, blue: 0.55),
            Color(hex: "8B6B7B") ?? Color(red: 0.55, green: 0.42, blue: 0.48),
        ]
        return palette[abs(era.orderIndex) % palette.count]
    }

    private var eraStartX: CGFloat {
        guard case .historical(let minYear, let ppy) = mode,
              let sy = era.startDate.startYear else { return 0 }
        return CGFloat(sy - minYear) * ppy
    }

    private var titleLine: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(era.name)
                .font(.caption)
                .fontWeight(.medium)
            if !dateRangeLabel.isEmpty {
                Text(dateRangeLabel)
                    .font(.caption2)
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
        }
    }

    private func historicalSwimlane(containerWidth: CGFloat) -> some View {
        let minYear = mode.minYear
        let ppy = mode.pointsPerYear

        let chipWidth = FigureSwimlaneChip.chipWidth
        let minSpacing: CGFloat = 16
        var chipLayouts: [(figure: Figure, x: CGFloat, level: Int)] = []
        var exactCount = 0

        for figure in figures {
            if let year = figure.birthDate.startYear {
                let x = CGFloat(year - minYear) * ppy + chipWidth / 2
                chipLayouts.append((figure, x, 0))
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
                    chipLayouts.append((figure, x, 0))
                    estIdx += 1
                }
            }
        }

        chipLayouts.sort { $0.x < $1.x }

        if chipLayouts.count > 1 {
            var groupStart = 0
            for i in 1..<chipLayouts.count {
                if chipLayouts[i].x - chipLayouts[i-1].x >= chipWidth + minSpacing {
                    for j in groupStart..<i {
                        let idx = j - groupStart
                        chipLayouts[j].level = idx % 2 == 0 ? idx / 2 : -(idx + 1) / 2
                    }
                    groupStart = i
                }
            }
            for j in groupStart..<chipLayouts.count {
                let idx = j - groupStart
                chipLayouts[j].level = idx % 2 == 0 ? idx / 2 : -(idx + 1) / 2
            }
        }

        let minLevel = chipLayouts.map(\.level).min() ?? 0

        let eraStartX: CGFloat
        let eraEndX: CGFloat
        let hasValidDates: Bool
        if let startYear = era.startDate.startYear, let endYear = era.endDate.endYear, startYear < endYear {
            eraStartX = CGFloat(startYear - minYear) * ppy
            eraEndX = CGFloat(endYear - minYear) * ppy
            hasValidDates = true
        } else {
            eraStartX = 0
            eraEndX = 0
            hasValidDates = false
        }

        return AnyView(ZStack(alignment: .leading) {
            ForEach(figures) { figure in
                if let birthYear = figure.birthDate.startYear, let deathYear = figure.deathDate.endYear {
                    let birthX = CGFloat(birthYear - minYear) * ppy
                    let deathX = CGFloat(deathYear - minYear) * ppy
                    let barWidth = max(4, deathX - birthX)
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill((figure.figureType?.color ?? .gray).opacity(0.2))
                        .frame(width: barWidth, height: 4)
                        .position(x: birthX + barWidth / 2, y: swimlaneHeight / 2 + 12)
                }
            }
            .opacity(hasValidDates ? 1 : 0)

            eraBar(startX: eraStartX, endX: eraEndX)
                .opacity(hasValidDates ? 1 : 0)

            ForEach(chipLayouts, id: \.figure.id) { layout in
                FigureSwimlaneChip(figure: layout.figure)
                    .position(
                        x: layout.x,
                        y: 18 + CGFloat(layout.level - minLevel) * 28 + 14
                    )
            }
        }
        .frame(width: containerWidth, height: swimlaneHeight)
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
                        FigureSwimlaneChip(figure: figure)
                    }
                }
                .padding(.horizontal, 8)
            }
        }
    }
    .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(eraColor.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(eraColor.opacity(0.15), lineWidth: 0.5)
                )
                .padding(.horizontal, 2)
        )
    }

    private func eraBar(startX: CGFloat, endX: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(eraColor.opacity(0.12))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(eraColor.opacity(0.25), lineWidth: 0.5)
            )
            .frame(width: max(20, endX - startX), height: swimlaneHeight - 8)
            .position(x: (startX + endX) / 2, y: swimlaneHeight / 2)
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
