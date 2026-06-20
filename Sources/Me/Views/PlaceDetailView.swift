import SwiftUI
import SwiftData

/// Detail panel showing all properties of a selected place.
struct PlaceDetailView: View {
    let place: Place
    var onSelectFigure: ((Figure) -> Void)?
    var onSelectEvent: ((Event) -> Void)?
    var onSelectImage: ((ImageAsset) -> Void)?
    @Environment(\.modelContext) private var modelContext

    private var relatedEvents: [Event] {
        place.eventAssociations.compactMap { $0.event }
    }

    private var relatedFigures: [Figure] {
        let figureSet = relatedEvents.flatMap { $0.involvedFigures }
        // Deduplicate
        var seen = Set<PersistentIdentifier>()
        return figureSet.filter { seen.insert($0.persistentModelID).inserted }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack(spacing: 12) {
                    Circle()
                        .fill(Color.teal.opacity(0.2))
                        .frame(width: 44, height: 44)
                        .overlay(
                            Image(systemName: placeIcon)
                                .foregroundStyle(.teal)
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(place.name)
                            .font(.title2.bold())
                        Text(place.placeType?.name ?? "City")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if place.isConcept {
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
                LazyVGrid(columns: [GridItem(.fixed(110), alignment: .trailing), GridItem(.flexible(), alignment: .leading)], alignment: .leading, spacing: 10) {
                    if !place.modernLocation.isEmpty {
                        PropertyRow(label: "Modern Location", value: place.modernLocation)
                    }
                    if !place.source.isEmpty {
                        PropertyRow(label: "Source", value: place.source)
                    }
                }

                // Description
                if !place.placeDescription.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Description")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                        Text(place.placeDescription)
                            .font(.body)
                    }
                }

                // Figure associations (patron deity, ruler, etc.)
                if !place.figureAssociations.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Associated Figures")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)

                        ForEach(place.figureAssociations) { assoc in
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(assoc.figure?.figureType?.color ?? .gray)
                                    .frame(width: 8, height: 8)
                                Text(assoc.figure?.gender.symbol ?? "?")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Button(action: {
                                    if let fig = assoc.figure { onSelectFigure?(fig) }
                                }) {
                                    Text(assoc.figure?.name ?? "?")
                                        .font(.callout)
                                        .fontWeight(.medium)
                                        .foregroundStyle(Color.accentColor)
                                        .underline()
                                }
                                .buttonStyle(.plain)
                                Text("— \(assoc.role.rawValue)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                            }
                        }
                    }
                }

                // Events at this place
                if !relatedEvents.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Events Here")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)

                        ForEach(relatedEvents) { event in
                            HStack(spacing: 8) {
                                Image(systemName: eventIcon(event.eventType))
                                    .font(.caption)
                                    .foregroundStyle(eventColor(event.eventType))
                                    .frame(width: 14)
                                VStack(alignment: .leading, spacing: 2) {
                                    Button(action: { onSelectEvent?(event) }) {
                                        Text(event.name)
                                            .font(.callout)
                                            .fontWeight(.medium)
                                            .foregroundStyle(Color.accentColor)
                                            .underline()
                                    }
                                    .buttonStyle(.plain)
                                    Text(event.date.displayLabel)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }

                // Figures associated with this place
                if !relatedFigures.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Associated Figures")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)

                        FlowLayout(spacing: 6) {
                            ForEach(relatedFigures) { figure in
                                Button(action: { onSelectFigure?(figure) }) {
                                    HStack(spacing: 3) {
                                        Text(figure.gender.symbol)
                                            .font(.system(size: 9))
                                        Text(figure.name)
                                            .font(.caption)
                                    }
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(figure.figureType?.color.opacity(0.1) ?? .gray.opacity(0.1))
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                // Images
                Divider()
                ImageGallery(
                    title: "Images",
                    images: place.images,
                    onLinkImage: { asset in
                        asset.places.append(place)
                    },
                    onSelectImage: onSelectImage
                )

                // Tags
                if !place.tags.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tags")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)

                        FlowLayout(spacing: 4) {
                            ForEach(place.tags) { tag in
                                TagTokenView(tag: tag)
                            }
                        }
                    }
                }

                // Citations
                if !placeCitations.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Sources & Citations")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)

                        ForEach(placeCitations) { citation in
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

                Spacer()
                MapPreviewButton(place: place)
            }
            .padding(20)
        }
    }

    private var placeIcon: String { place.placeType?.icon ?? "mappin" }

    private var placeCitations: [Citation] {
        let all: [Citation] = modelContext.fetchAll()
        return all.filter { $0.safeEntityName == place.name && $0.safeEntityType == .place }
    }

    private func eventIcon(_ type: EventType?) -> String { type?.icon ?? "bolt" }

    private func eventColor(_ type: EventType?) -> Color { type?.color ?? .gray }

}

/// Simple flow layout for wrapping chips.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            totalHeight = y + rowHeight
        }

        return (CGSize(width: maxWidth, height: totalHeight), positions)
    }
}
