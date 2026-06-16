import SwiftUI
import SwiftData

/// Detail panel showing all properties of a selected event.
struct EventDetailView: View {
    let event: Event
    @Environment(\.modelContext) private var modelContext
    @Query private var figures: [Figure]
    @Query private var places: [Place]

    private var involvedFigures: [Figure] { event.involvedFigures }

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
                        Text(event.eventType?.name ?? "Other")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if event.isConcept {
                        Text("Concept")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(.orange.opacity(0.12))
                            )
                    }
                }

                Divider()

                // Properties
                LazyVGrid(columns: [GridItem(.fixed(80), alignment: .trailing), GridItem(.flexible(), alignment: .leading)], alignment: .leading, spacing: 10) {
                    PropertyRow(label: "Date", value: event.date.displayLabel)
                    if !event.era.isEmpty {
                        PropertyRow(label: "Era", value: event.era)
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
                                    .fill(figure.figureType?.color.opacity(0.2) ?? .gray.opacity(0.2))
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

                                Text(figure.figureType?.name ?? "Unknown")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }

                // Citations
                if !eventCitations.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Sources & Citations")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)

                        ForEach(eventCitations) { citation in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "doc.text")
                                    .font(.caption)
                                    .foregroundStyle(.brown)
                                    .frame(width: 14)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text("\(citation.source?.name ?? "Unknown"), \(citation.safeLocation)")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                    Text(citation.safeNote)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(3)
                                }
                            }
                        }
                    }
                }

                // Associated places
                let associatedPlaces = event.placeAssociations
                if !associatedPlaces.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Locations")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)

                        ForEach(associatedPlaces) { assoc in
                            if let place = assoc.place {
                                HStack(spacing: 8) {
                                    Image(systemName: "mappin.circle.fill")
                                        .font(.callout)
                                        .foregroundStyle(.teal)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(place.name)
                                            .font(.callout)
                                            .fontWeight(.medium)
                                        HStack(spacing: 4) {
                                            Text(assoc.role.rawValue)
                                                .font(.caption2)
                                                .padding(.horizontal, 4)
                                                .padding(.vertical, 1)
                                                .background(RoundedRectangle(cornerRadius: 3).fill(Color.teal.opacity(0.12)))
                                            if !place.modernLocation.isEmpty {
                                                Text(place.modernLocation)
                                                    .font(.caption)
                                                    .foregroundStyle(.tertiary)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Spacer()
            }
            .padding(20)
        }
    }

    private var eventIcon: String { event.eventType?.icon ?? "bolt" }

    private var eventCitations: [Citation] {
        let all: [Citation] = modelContext.fetchAll()
        return all.filter { $0.safeEntityName == event.name && $0.safeEntityType == .event }
    }

    private var eventColor: Color { event.eventType?.color ?? .gray }

}
