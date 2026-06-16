import SwiftUI
import SwiftData

// MARK: - Clickable entity link

struct EntityLink: View {
    let name: String
    let kind: EntityReportSheet.EntityKind

    @State private var isHovered = false
    @State private var showSheet = false

    var body: some View {
        Button(action: { showSheet = true }) {
            Text(name)
                .foregroundStyle(isHovered ? Color.accentColor : Color.primary)
                .underline(isHovered)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help("View \(kind.rawValue.lowercased()) \"\(name)\"")
        .sheet(isPresented: $showSheet) {
            EntityReportSheet(name: name, kind: kind)
        }
    }
}

// MARK: - Report sheet

struct EntityReportSheet: View {
    let name: String
    let kind: EntityKind

    enum EntityKind: String, CaseIterable {
        case figure = "Figure"
        case place = "Place"
        case event = "Event"
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var figure: Figure?
    @State private var place: Place?
    @State private var event: Event?
    @State private var loaded = false
    @State private var creatingFigure = false

    var body: some View {
        NavigationStack {
            Group {
                if !loaded {
                    ProgressView("Looking up \(name)...")
                } else if let figure {
                    ScrollView {
                        FigureDossierView(dossier: buildFigureDossier(figure))
                            .padding(20)
                    }
                } else if let place {
                    ScrollView {
                        PlaceDossierView(dossier: buildPlaceDossier(place))
                            .padding(20)
                    }
                } else if let event {
                    ScrollView {
                        EventDossierView(dossier: buildEventDossier(event))
                            .padding(20)
                    }
                } else {
                    notFoundView
                }
            }
            .navigationTitle(name)
            .onAppear { resolve() }
            .sheet(isPresented: $creatingFigure) {
                FigureFormView(figure: nil)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .frame(width: 640, height: 520)
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
            Text("No \(kind.rawValue.lowercased()) found with this name")
                .foregroundStyle(.secondary)
            if kind == .figure {
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
        case .figure: return "person.fill.questionmark"
        case .place: return "building.columns"
        case .event: return "bolt"
        }
    }

    // MARK: - Lookup

    private func resolve() {
        let q = name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        switch kind {
        case .figure:
            let figures: [Figure] = modelContext.fetchAll()
            figure = figures.first(where: { $0.name.lowercased() == q })
        case .place:
            let places: [Place] = modelContext.fetchAll()
            place = places.first(where: { $0.name.lowercased() == q })
        case .event:
            let events: [Event] = modelContext.fetchAll()
            event = events.first(where: { $0.name.lowercased() == q })
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
