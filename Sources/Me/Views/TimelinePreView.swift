import AppKit
import SwiftUI
import SwiftData

struct TimelinePreView: View {
    @Query(sort: \Era.orderIndex) private var eras: [Era]
    @Query private var figures: [Figure]
    @Query(sort: \Place.name) private var places: [Place]
    @State private var detailFigure: Figure?

    private let swimlaneHeight: CGFloat = 64
    private let targetTimelineWidth: CGFloat = 1600

    private var preFloodEras: [Era] {
        eras.filter { $0.orderIndex < 7 }
    }

    private var preFloodErasWithFigures: [Era] {
        preFloodEras.filter { !figuresInEra($0, from: figures).isEmpty }
    }

    private var minYear: Int {
        (preFloodErasWithFigures.compactMap(\.startDate.startYear).min()) ?? -450000
    }

    private var maxYear: Int {
        (preFloodErasWithFigures.compactMap(\.endDate.endYear).max()) ?? -28000
    }

    private var span: Int {
        max(1, maxYear - minYear)
    }

    private var axis: TimelineAxis {
        let pointsPerYear = span > 0 ? targetTimelineWidth / CGFloat(span) : 1
        return TimelineAxis.linear(minYear: minYear, maxYear: maxYear, pointsPerYear: pointsPerYear)
    }

    private var timelineWidth: CGFloat {
        axis.width
    }

    var body: some View {
        if preFloodEras.isEmpty {
            emptyState
        } else {
            GeometryReader { geo in
                ScrollView([.horizontal, .vertical]) {
                    VStack(alignment: .leading, spacing: 0) {
                        preFloodAxisHeader
                        preFloodSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                    .frame(minWidth: geo.size.width, minHeight: geo.size.height, alignment: .topLeading)
                }
            }
            .sheet(item: $detailFigure) { figure in
                NavigationStack {
                    FigureQuicklookView(figure: figure)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Close") { detailFigure = nil }
                            }
                        }
                }
                .frame(minWidth: 500, minHeight: 400)
            }
        }
    }

    private var preFloodAxisHeader: some View {
        let tickInterval = preFloodTickInterval(for: span)
        let ticks = stride(from: minYear, through: maxYear, by: tickInterval)

        return ZStack(alignment: .topLeading) {
            ForEach(Array(ticks), id: \.self) { year in
                tickLabel(for: year)
            }
        }
        .frame(width: timelineWidth, height: 24)
        .padding(.bottom, 8)
    }

    private func tickLabel(for year: Int) -> some View {
        let label = NumberFormatter.localizedString(from: NSNumber(value: abs(year)), number: .decimal) + " BCE"
        let half = measure(label) / 2
        let maxX = max(half, timelineWidth - half)
        let x = min(max(axis.x(for: year), half), maxX)
        return Text(label)
            .font(.system(.callout, design: .serif))
            .foregroundStyle(.primary)
            .position(x: x, y: 12)
    }

    private func measure(_ text: String) -> CGFloat {
        let base = NSFont.systemFont(ofSize: 12)
        let descriptor = base.fontDescriptor.withDesign(NSFontDescriptor.SystemDesign.serif) ?? base.fontDescriptor
        let font = NSFont(descriptor: descriptor, size: base.pointSize) ?? base
        return (text as NSString).size(withAttributes: [.font: font]).width
    }

    private var preFloodSection: some View {
        let boundaryYears = Set(preFloodErasWithFigures.flatMap { era in
            [era.startDate.startYear, era.endDate.endYear].compactMap { $0 }
        })

        return ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 5) {
                sectionHeader("Pre-Flood")
                let mapPlaces = places.filter { $0.latitude != nil && $0.longitude != nil }
                ForEach(preFloodErasWithFigures) { era in
                    EraSwimlaneRow(
                        era: era,
                        figures: figuresInEra(era, from: figures),
                        events: [],
                        places: mapPlaces,
                        swimlaneWidth: timelineWidth,
                        swimlaneHeight: swimlaneHeight,
                        mode: .mythologicalTimed(axis: axis),
                        onSelectFigure: { detailFigure = $0 }
                    )
                }
            }
            .overlay(alignment: .topLeading) {
                GeometryReader { geo in
                    let headerHeight: CGFloat = 28
                    let gridHeight = geo.size.height - headerHeight
                    ZStack(alignment: .topLeading) {
                        ForEach(Array(boundaryYears), id: \.self) { year in
                            let x = axis.x(for: year)
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

    private func preFloodTickInterval(for span: Int) -> Int {
        if span <= 60000 { return 10000 }
        if span <= 150000 { return 25000 }
        return 50000
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
            Text("No pre-flood eras defined")
                .font(.title3)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }
}