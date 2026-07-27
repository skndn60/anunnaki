import SwiftUI
import SwiftData

struct TimelinePostView: View {
    @Query(sort: \Era.orderIndex) private var eras: [Era]
    @Query private var figures: [Figure]
    @Query private var events: [Event]
    @Query(sort: \Place.name) private var places: [Place]
    @State private var detailFigure: Figure?
    @State private var selectedEvent: Event?

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
            .sheet(item: $selectedEvent) { event in
                NavigationStack {
                    TimelineEventDetailView(event: event)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Close") { selectedEvent = nil }
                            }
                        }
                }
                .frame(minWidth: 400, minHeight: 300)
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
                        .font(.system(.callout, design: .serif))
                        .foregroundStyle(.primary)
                        .position(x: x, y: 12)
                }
            }
        }
        .frame(width: timelineWidth, height: 24)
        .overlay(alignment: .topLeading) {
            Text("BCE")
                .font(.system(.callout, design: .serif))
                .foregroundStyle(.primary)
                .padding(.leading, 2)
        }
        .padding(.bottom, 8)
    }

    private var historicalSection: some View {
        let gridInterval = timelineTickInterval(for: bceSpan)
        let gridTicks = stride(from: bceMinYear, through: bceMaxYear, by: gridInterval)

        return ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 5) {
                sectionHeader("Post-Flood")
                let mapPlaces = places.filter { $0.latitude != nil && $0.longitude != nil }
                ForEach(postFloodErasWithFigures) { era in
                    EraSwimlaneRow(
                        era: era,
                        figures: figuresInEra(era, from: figures),
                        events: eventsInEra(era, from: events),
                        places: mapPlaces,
                        swimlaneWidth: timelineWidth,
                        swimlaneHeight: swimlaneHeight,
                        mode: .historical(
                            minYear: bceMinYear,
                            pointsPerYear: pointsPerYear
                        ),
                        onSelectFigure: { detailFigure = $0 },
                        onSelectEvent: { selectedEvent = $0 }
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

    private func eventsInEra(_ era: Era, from events: [Event]) -> [Event] {
        events
            .filter { $0.era == era.name }
            .sorted { ($0.date.startYear ?? Int.max) < ($1.date.startYear ?? Int.max) }
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

struct TimelineEventDetailView: View {
    let event: Event

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    if let type = event.eventType {
                        Image(systemName: type.icon)
                            .foregroundStyle(type.color)
                        Text(type.name)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(type.color.opacity(0.15))
                            .cornerRadius(4)
                    }
                    Text(event.name)
                        .font(.title2)
                        .fontWeight(.bold)
                }
                if event.date.displayLabel != "Unknown" {
                    Text(event.date.displayLabel)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if !event.eventDescription.isEmpty {
                    Text(event.eventDescription)
                        .font(.body)
                }
                if !event.source.isEmpty {
                    Text("Source: \(event.source)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding()
        }
    }
}
