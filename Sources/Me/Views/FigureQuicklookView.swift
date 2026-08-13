import SwiftUI
import SwiftData

struct FigureQuicklookView: View {
    let figure: Figure
    var onSelectFigure: ((Figure) -> Void)?
    var onSelectPlace: ((Place) -> Void)?
    var onSelectEvent: ((Event) -> Void)?

    @Environment(\.modelContext) private var modelContext

    private var relationships: [Relationship] {
        let all: [Relationship] = modelContext.fetchAll()
        return all.filter { $0.fromFigure?.name == figure.name || $0.toFigure?.name == figure.name }
    }

    private var groupedRelationships: [(type: String, figures: [Figure], isOutgoing: Bool)] {
        let dict = Dictionary(grouping: relationships) { rel in
            (rel.relationshipType?.name ?? "?")
        }
        return dict.compactMap { type, rels in
            let incoming = rels.filter { $0.toFigure?.persistentModelID == figure.persistentModelID }.compactMap { $0.fromFigure }
            let outgoing = rels.filter { $0.fromFigure?.persistentModelID == figure.persistentModelID }.compactMap { $0.toFigure }
            guard !incoming.isEmpty || !outgoing.isEmpty else { return nil }
            return (type, incoming + outgoing, false)
        }.sorted { $0.type < $1.type }
    }

    private var figureEvents: [Event] {
        let all: [Event] = modelContext.fetchAll()
        return all.filter { $0.involvedFigures.contains(where: { $0.persistentModelID == figure.persistentModelID }) }
    }

    private var figureCitations: [Citation] {
        let all: [Citation] = modelContext.fetchAll()
        return all.filter { $0.safeEntityName == figure.name && $0.safeEntityType == .figure }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                FigureHeaderView(figure: figure, showBirthDate: true)

                if !figure.figureDescription.isEmpty {
                    FigureDescriptionView(text: figure.figureDescription, richData: figure.richDescription)
                }

                Divider()

                PropertyGrid

                if !figure.alternateNames.isEmpty {
                    Divider()
                    AlternateNamesSection
                }

                if !groupedRelationships.isEmpty {
                    Divider()
                    RelationshipsSection
                }

                if !figure.placeAssociations.isEmpty {
                    Divider()
                    PlaceAssociationsSection
                }

                if !figureEvents.isEmpty {
                    Divider()
                    EventsSection
                }

                if !figure.images.isEmpty {
                    Divider()
                    ImageGallery(
                        title: "Images (\(figure.images.count))",
                        images: figure.images,
                        onLinkImage: { asset in
                            asset.figures.append(figure)
                        }
                    )
                }

                if !figure.tags.isEmpty {
                    Divider()
                    TagsSection
                }

                if !figureCitations.isEmpty {
                    Divider()
                    CitationsSection
                }

                Spacer()
            }
            .padding(20)
        }
        .textSelection(.enabled)
    }

    private var PropertyGrid: some View {
        LazyVGrid(columns: [GridItem(.fixed(100), alignment: .trailing), GridItem(.flexible(), alignment: .leading)], alignment: .leading, spacing: 10) {
            Text("Domain").font(.caption).foregroundStyle(.secondary)
            Text(figure.domain.isEmpty ? "—" : figure.domain).font(.callout)
            Text("Birth").font(.caption).foregroundStyle(.secondary)
            Text(figure.birthDate.displayLabel).font(.callout)
            Text("Death").font(.caption).foregroundStyle(.secondary)
            Text(figure.deathDate.displayLabel).font(.callout)
            Text("Cause of Death").font(.caption).foregroundStyle(.secondary)
            Text(figure.causeOfDeath ?? "Unknown").font(.callout)
            Text("Source").font(.caption).foregroundStyle(.secondary)
            Text(figure.source.isEmpty ? "—" : figure.source).font(.callout)
        }
    }

    private var AlternateNamesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Also Known As")
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            ForEach(figure.sortedAlternateNames) { altName in
                HStack(spacing: 8) {
                    Text(altName.name)
                        .font(.callout)
                        .fontWeight(.medium)
                    Text(altName.tradition.rawValue)
                        .font(.caption2)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(RoundedRectangle(cornerRadius: 3).fill(Color.secondary.opacity(0.1)))
                    Text(altName.nameType.rawValue)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
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

    private var RelationshipsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Relationships")
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            ForEach(groupedRelationships, id: \.type) { group in
                ForEach(group.figures, id: \.persistentModelID) { relFigure in
                    FigureRelationshipRow(
                        relationshipTypeName: group.type,
                        relative: relFigure,
                        onSelectFigure: onSelectFigure
                    )
                }
            }
        }
    }

    private var PlaceAssociationsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Associated Places")
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            ForEach(figure.placeAssociations) { assoc in
                FigurePlaceAssociationRow(association: assoc, onSelectPlace: onSelectPlace)
            }
        }
    }

    private var EventsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Events")
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            ForEach(figureEvents) { event in
                HStack(spacing: 8) {
                    Image(systemName: event.eventType?.icon ?? "bolt")
                        .font(.caption)
                        .foregroundStyle(event.eventType?.color ?? .gray)
                        .frame(width: 14)
                    if let onSelectEvent {
                        Button(action: { onSelectEvent(event) }) {
                            Text(event.name)
                                .font(.callout)
                                .fontWeight(.medium)
                                .foregroundStyle(Color.accentColor)
                                .underline()
                        }
                        .buttonStyle(.plain)
                        .pointingHand()
                    } else {
                        EntityLink(name: event.name, kind: .event)
                            .font(.callout)
                    }
                    Text(event.eventType?.name ?? "Other")
                        .font(.caption2)
                        .foregroundStyle(event.eventType?.color ?? .gray)
                    Spacer()
                    Text(event.date.displayLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var TagsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tags")
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            FlowLayout(spacing: 4) {
                ForEach(figure.tags) { tag in
                    TagTokenView(tag: tag)
                }
            }
        }
    }

    private var CitationsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sources & Citations")
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            ForEach(figureCitations) { citation in
                FigureCitationsRow(citation: citation)
            }
        }
    }
}
