import SwiftUI
import SwiftData

/// Detail panel showing all properties of a selected place.
struct PlaceDetailView: View {
    let place: Place
    var onSelectFigure: ((Figure) -> Void)?
    var onSelectEvent: ((Event) -> Void)?
    var onSelectImage: ((ImageAsset) -> Void)?
    var backLabel: String?
    var onBack: (() -> Void)?
    @Environment(\.modelContext) private var modelContext
    @State private var altToDelete: AlternateName?
    @State private var showDeleteAltConfirm = false

    private var relatedEvents: [Event] {
        place.eventAssociations.compactMap { $0.event }
    }

    private var relatedFigures: [Figure] {
        let figureSet = relatedEvents.flatMap { $0.involvedFigures }
        var seen = Set<PersistentIdentifier>()
        return figureSet.filter { seen.insert($0.persistentModelID).inserted }
    }

    private var placeAssociations: [PlacePlaceAssociation] {
        let all: [PlacePlaceAssociation] = modelContext.fetchAll()
        return all.filter { $0.fromPlace == place || $0.toPlace == place }
    }

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

                // Stickies
                StickyNoteSection(stickies: place.stickies) { text in
                    let note = StickyNote(text: text, place: place)
                    modelContext.insert(note)
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

                // Alternate Names
                if !place.alternateNames.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Also Known As")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)

                        ForEach(place.alternateNames) { altName in
                            HStack(spacing: 8) {
                                Text(altName.name)
                                    .font(.callout)
                                    .fontWeight(.medium)
                                Text(altName.tradition.rawValue)
                                    .font(.caption2)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(Color.secondary.opacity(0.1))
                                    )
                                Text(altName.nameType.rawValue)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                Spacer()
                                Button(action: {
                                    altToDelete = altName
                                    showDeleteAltConfirm = true
                                }) {
                                    Image(systemName: "trash")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.red.opacity(0.7))
                                }
                                .buttonStyle(.plain)
                                .help("Delete alternate name")
                            }
                            if !altName.note.isEmpty {
                                Text(altName.note)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .padding(.leading, 4)
                            }
                        }
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
                                .pointingHand()
                                Text("— \(assoc.roleType?.name ?? "—")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                            }
                        }
                    }
                }

                // Place associations (containment, proximity, etc.)
                if !placeAssociations.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Related Places")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)

                        ForEach(placeAssociations) { assoc in
                            HStack(spacing: 8) {
                                if assoc.fromPlace == place {
                                    Text(assoc.toPlace?.name ?? "?")
                                        .font(.callout)
                                        .fontWeight(.medium)
                                    Text(assoc.roleType?.name ?? "—")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text("←")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                    Text(place.name)
                                        .font(.callout)
                                        .foregroundStyle(.secondary)
                                } else {
                                    Text(place.name)
                                        .font(.callout)
                                        .foregroundStyle(.secondary)
                                    Text("→")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                    Text(assoc.roleType?.name ?? "—")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(assoc.fromPlace?.name ?? "?")
                                        .font(.callout)
                                        .fontWeight(.medium)
                                }
                                Spacer()
                                Text(assoc.source)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                    .lineLimit(1)
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
                                    .pointingHand()
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
                                .pointingHand()
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
        .alert("Delete Alternate Name?", isPresented: $showDeleteAltConfirm, presenting: altToDelete) { altName in
            Button("Delete", role: .destructive) {
                modelContext.delete(altName)
                try? modelContext.save()
            }
            Button("Cancel", role: .cancel) {}
        } message: { altName in
            Text("Delete \"\(altName.name)\" (\(altName.tradition.rawValue)) from \(altName.place?.name ?? "?")?")
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
