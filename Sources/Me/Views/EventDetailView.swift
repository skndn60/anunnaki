import SwiftUI
import SwiftData

/// Detail panel showing all properties of a selected event.
struct EventDetailView: View {
    let event: Event
    var onSelectFigure: ((Figure) -> Void)?
    var onSelectPlace: ((Place) -> Void)?
    var onSelectImage: ((ImageAsset) -> Void)?
    var backLabel: String?
    var onBack: (() -> Void)?
    @Environment(\.modelContext) private var modelContext
    @Query private var figures: [Figure]
    @Query private var places: [Place]

    private var involvedFigures: [Figure] { event.involvedFigures }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let backLabel, let onBack {
                    Button(action: onBack) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.caption2.weight(.semibold))
                            Text("Back to \(backLabel)")
                                .font(.caption)
                        }
                        .foregroundColor(.accentColor)
                    }
                    .buttonStyle(.plain)
                    .pointingHand()
                }

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

                // Stickies
                StickyNoteSection(stickies: event.stickies) { text in
                    let note = StickyNote(text: text, event: event)
                    modelContext.insert(note)
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
                                    Button(action: { onSelectFigure?(figure) }) {
                                        Text(figure.name)
                                            .font(.callout)
                                            .fontWeight(.medium)
                                            .foregroundStyle(Color.accentColor)
                                            .underline()
                                    }
                                    .buttonStyle(.plain)
                                    .pointingHand()
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
                                        Button(action: { onSelectPlace?(place) }) {
                                            Text(place.name)
                                                .font(.callout)
                                                .fontWeight(.medium)
                                                .foregroundStyle(Color.accentColor)
                                                .underline()
                                        }
                                        .buttonStyle(.plain)
                                        .pointingHand()
                                        HStack(spacing: 4) {
                                            Text(assoc.roleType?.name ?? "—")
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

                // Images
                Divider()
                ImageGallery(
                    title: "Images",
                    images: event.images,
                    onLinkImage: { asset in
                        asset.events.append(event)
                    },
                    onSelectImage: onSelectImage
                )

                // Tags
                if !event.tags.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tags")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)

                        FlowLayout(spacing: 4) {
                            ForEach(event.tags) { tag in
                                TagTokenView(tag: tag)
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
