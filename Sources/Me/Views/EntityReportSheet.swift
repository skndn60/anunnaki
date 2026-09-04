import SwiftUI
import SwiftData

// MARK: - Clickable entity link

struct EntityLink: View {
    let name: String
    let kind: EntityKind
    @Environment(\.openWindow) private var openWindow

    @State private var isHovered = false

    var body: some View {
        Button(action: {
            openWindow(id: "entity-report", value: EntityReportRequest(name: name, kind: kind.rawValue))
        }) {
            Text(name)
                .foregroundStyle(isHovered ? Color.accentColor : Color.primary)
                .underline(isHovered)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help("View \(kind.rawValue.lowercased()) \"\(name)\"")
    }
}

// MARK: - Report window

struct EntityReportWindow: View {
    let request: EntityReportRequest?
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var figure: Figure?
    @State private var place: Place?
    @State private var event: Event?
    @State private var loaded = false
    @State private var creatingFigure = false

    private var name: String { request?.name ?? "" }
    private var kind: String { request?.kind ?? "" }

    var body: some View {
        NavigationStack {
            Group {
                if !loaded {
                    ProgressView("Looking up \(name)")
                } else if let figure {
                    ScrollView {
                        FigureDossierView(dossier: buildFigureDossier(figure))
                            .padding(20)
                    }
                    .textSelection(.enabled)
                } else if let place {
                    ScrollView {
                        PlaceDossierView(dossier: buildPlaceDossier(place))
                            .padding(20)
                    }
                    .textSelection(.enabled)
                } else if let event {
                    ScrollView {
                        EventDossierView(dossier: buildEventDossier(event))
                            .padding(20)
                    }
                    .textSelection(.enabled)
                } else {
                    notFoundView
                }
            }
            .navigationTitle(name)
            .onAppear { resolve() }
            .sheet(isPresented: $creatingFigure) {
                FigureFormView(figure: nil)
            }
        }
    }

    @ViewBuilder
    private var notFoundView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: iconName)
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text(name)
                .font(.title.bold())
            Text("No \(kind) found with this name")
                .foregroundStyle(.secondary)
            if kind == EntityKind.figure.rawValue {
                Button("Create figure \"\(name)\"") {
                    creatingFigure = true
                }
                .buttonStyle(.borderedProminent)
            }
            Spacer()
        }
        .padding()
    }

    private var iconName: String {
        switch kind {
        case EntityKind.figure.rawValue: return "person.fill.questionmark"
        case EntityKind.place.rawValue: return "building.columns"
        case EntityKind.event.rawValue: return "bolt"
        default: return "questionmark"
        }
    }

    // MARK: - Lookup

    private func resolve() {
        let q = name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        switch kind {
        case EntityKind.figure.rawValue:
            let figures: [Figure] = modelContext.fetchAll()
            figure = figures.first(where: { $0.name.lowercased() == q })
        case EntityKind.place.rawValue:
            let places: [Place] = modelContext.fetchAll()
            place = places.first(where: { $0.name.lowercased() == q })
        case EntityKind.event.rawValue:
            let events: [Event] = modelContext.fetchAll()
            event = events.first(where: { $0.name.lowercased() == q })
        default:
            break
        }
        loaded = true
    }

    // MARK: - Dossier builders (delegated to ModelContext extension)

    private func buildFigureDossier(_ figure: Figure) -> FigureDossier {
        modelContext.buildFigureDossier(figure)
    }

    private func buildPlaceDossier(_ place: Place) -> PlaceDossier {
        modelContext.buildPlaceDossier(place)
    }

    private func buildEventDossier(_ event: Event) -> EventDossier {
        modelContext.buildEventDossier(event)
    }
}

enum EntityKind: String, CaseIterable {
    case figure = "Figure"
    case place = "Place"
    case event = "Event"
}
