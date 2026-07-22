import SwiftUI
import SwiftData

struct TimelinePostView: View {
    @Query(sort: \Era.orderIndex) private var eras: [Era]
    @Query private var figures: [Figure]

    private let pointsPerYear: CGFloat = 4
    private let swimlaneHeight: CGFloat = 120

    private var postFloodEras: [Era] {
        eras.filter { $0.orderIndex >= 7 }
    }

    private var postFloodErasWithFigures: [Era] {
        postFloodEras.filter { era in
            figures.contains { $0.birthDate.era == era.name }
        }
    }

    private var bceMinYear: Int {
        (postFloodErasWithFigures.compactMap(\.startDate.startYear).min()) ?? -2900
    }

    private var bceMaxYear: Int {
        (postFloodErasWithFigures.compactMap(\.endDate.endYear).max()) ?? -1794
    }

    private var bceSpan: Int {
        max(1, bceMaxYear - bceMinYear)
    }

    private var timelineWidth: CGFloat {
        CGFloat(bceSpan) * pointsPerYear
    }

    var body: some View {
        if postFloodEras.isEmpty {
            emptyState
        } else {
            ScrollView([.horizontal, .vertical]) {
                VStack(alignment: .leading, spacing: 0) {
                    bceAxisHeader
                    historicalSection
                }
                .padding(20)
            }
        }
    }

    private var bceAxisHeader: some View {
        let tickInterval = timelineTickInterval(for: bceSpan)
        let ticks = stride(from: bceMinYear, through: bceMaxYear, by: tickInterval)

        return ZStack(alignment: .topLeading) {
            ForEach(Array(ticks), id: \.self) { year in
                let x = CGFloat(year - bceMinYear) * pointsPerYear
                if x > 0 {
                    Text(NumberFormatter.localizedString(from: NSNumber(value: abs(year)), number: .decimal))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .position(x: x, y: 8)
                }
            }
        }
        .frame(width: timelineWidth, height: 16)
        .overlay(alignment: .topLeading) {
            Text("BCE")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.leading, 2)
        }
        .padding(.bottom, 4)
    }

    private var historicalSection: some View {
        let gridInterval = timelineTickInterval(for: bceSpan)
        let gridTicks = stride(from: bceMinYear, through: bceMaxYear, by: gridInterval)

        return ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 2) {
                sectionHeader("Post-Flood")
                ForEach(postFloodErasWithFigures) { era in
                    EraSwimlaneRow(
                        era: era,
                        figures: figuresInEra(era, from: figures),
                        swimlaneWidth: timelineWidth,
                        swimlaneHeight: swimlaneHeight,
                        mode: .historical(
                            minYear: bceMinYear,
                            pointsPerYear: pointsPerYear
                        )
                    )
                }
            }
            .overlay(alignment: .topLeading) {
                GeometryReader { geo in
                    let headerHeight: CGFloat = 28
                    let gridHeight = geo.size.height - headerHeight
                    ZStack(alignment: .topLeading) {
                        ForEach(Array(gridTicks), id: \.self) { year in
                            let x = CGFloat(year - bceMinYear) * pointsPerYear
                            Rectangle()
                                .fill(.black.opacity(0.35))
                                .frame(width: 1, height: gridHeight)
                                .position(x: x, y: headerHeight + gridHeight / 2)
                        }
                    }
                }
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(.tertiary)
            .textCase(.uppercase)
            .padding(.vertical, 6)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "calendar.day.timeline.left")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No post-flood eras defined")
                .font(.title3)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }
}
