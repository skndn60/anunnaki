import SwiftUI
import SwiftData

/// Detail panel showing all properties of a selected event.
struct EventDetailView: View {
    let event: Event
    @Query private var figures: [Figure]
    @Query private var places: [Place]

    private var involvedFigures: [Figure] { event.involvedFigures }

    private var eventPlace: Place? { event.place }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack(spacing: 12) {
                    Circle()
                        .fill(eventColor.opacity(0.2))
                        .frame(width: 44, height: 44)
                        .overlay(
                            Image(systemName: eventIcon)
                                .foregroundStyle(eventColor)
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(event.name)
                            .font(.title2.bold())
                        Text(event.eventType.rawValue)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }

                Divider()

                // Properties
                LazyVGrid(columns: [GridItem(.fixed(80), alignment: .trailing), GridItem(.flexible(), alignment: .leading)], alignment: .leading, spacing: 10) {
                    PropertyRow(label: "Date", value: event.date.displayLabel)
                    if !event.era.isEmpty {
                        PropertyRow(label: "Era", value: event.era)
                    }
                    if event.place != nil {
                        Text("Place")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 4) {
                            Image(systemName: "mappin")
                                .font(.caption2)
                                .foregroundStyle(.teal)
                            Text(event.place?.name ?? "")
                                .font(.callout)
                        }
                    }
                    if !event.source.isEmpty {
                        PropertyRow(label: "Source", value: event.source)
                    }
                }

                // Description
                if !event.eventDescription.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Description")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                        Text(event.eventDescription)
                            .font(.body)
                    }
                }

                // Involved Figures
                if !involvedFigures.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Involved Figures")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)

                        ForEach(involvedFigures) { figure in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(figureColor(figure.figureType).opacity(0.2))
                                    .frame(width: 28, height: 28)
                                    .overlay(
                                        Text(figure.gender.symbol)
                                            .font(.system(size: 12))
                                    )

                                VStack(alignment: .leading, spacing: 1) {
                                    Text(figure.name)
                                        .font(.callout)
                                        .fontWeight(.medium)
                                    if !figure.title.isEmpty {
                                        Text(figure.title)
                                            .font(.caption)
                                            .foregroundStyle(.tertiary)
                                            .lineLimit(1)
                                    }
                                }

                                Spacer()

                                Text(figure.figureType.rawValue)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }

                // Place detail snippet
                if let place = eventPlace {
                    Divider()
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Location")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)

                        HStack(spacing: 8) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.teal)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(place.name)
                                    .font(.callout)
                                    .fontWeight(.medium)
                                if !place.modernLocation.isEmpty {
                                    Text(place.modernLocation)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        if !place.placeDescription.isEmpty {
                            Text(place.placeDescription)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .lineLimit(3)
                        }
                    }
                }

                Spacer()
            }
            .padding(20)
        }
    }

    private var eventIcon: String { event.eventType.icon }

    private var eventColor: Color { event.eventType.color }

    private func figureColor(_ type: Figure.FigureType) -> Color { type.color }
}
