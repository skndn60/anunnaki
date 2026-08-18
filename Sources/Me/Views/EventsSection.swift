import SwiftUI
import SwiftData

/// Section showing events a figure is involved in.
struct EventsSection: View {
    let figure: Figure
    let filterText: String
    var onSelectEvent: ((Event) -> Void)?
    var onSelectPlace: ((Place) -> Void)?

    @Environment(\.modelContext) private var modelContext

    private func matchesFilter(_ text: String) -> Bool {
        guard !filterText.isEmpty else { return true }
        return text.localizedCaseInsensitiveContains(filterText)
    }

    var body: some View {
        let allFigureEvents: [Event] = modelContext.fetchAll().filter {
            $0.involvedFigures.contains(where: { $0.persistentModelID == figure.persistentModelID })
        }
        let figureEvents = filterText.isEmpty ? allFigureEvents : allFigureEvents.filter {
            matchesFilter($0.name) || matchesFilter($0.eventType?.name ?? "") || matchesFilter($0.date.displayLabel)
        }
        if !figureEvents.isEmpty {
            Divider()
            VStack(alignment: .leading, spacing: 8) {
                Text("Events")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                ForEach(figureEvents) { event in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Image(systemName: event.eventType?.icon ?? "bolt")
                                .font(.caption)
                                .foregroundStyle(event.eventType?.color ?? .gray)
                                .frame(width: 14)
                            Button(action: { onSelectEvent?(event) }) {
                                Text(event.name)
                                    .font(.callout)
                                    .fontWeight(.medium)
                                    .foregroundStyle(Color.accentColor)
                                    .underline()
                            }
                            .buttonStyle(.plain)
                            .pointingHand()
                            Text(event.eventType?.name ?? "Other")
                                .font(.caption2)
                                .foregroundStyle(event.eventType?.color ?? .gray)
                Spacer()
                            Text(event.date.displayLabel)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if !event.placeAssociations.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "mappin")
                                    .font(.caption2)
                                    .foregroundStyle(.teal)
                                ForEach(Array(event.placeAssociations.enumerated()), id: \.element.id) { idx, assoc in
                                    Button(action: {
                                        if let p = assoc.place { onSelectPlace?(p) }
                                    }) {
                                        Text(assoc.place?.name ?? "?")
                                            .font(.caption)
                                            .foregroundStyle(Color.accentColor)
                                            .underline()
                                    }
                                    .buttonStyle(.plain)
                                    .pointingHand()
                                    if idx < event.placeAssociations.count - 1 {
                                        Text("·")
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                            }
                            .padding(.leading, 22)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
}