import SwiftUI
import SwiftData

/// Natural language query interface — ask questions about the data.
struct QueryView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var queryText = ""
    @State private var result: QueryResult?

    var body: some View {
        VStack(spacing: 0) {
            // Query bar
            HStack {
                Text("Query")
                    .font(.title2.bold())
                Spacer()
            }
            .padding()

            HStack(spacing: 8) {
                Image(systemName: "questionmark.circle")
                    .foregroundStyle(.secondary)
                TextField("Ask a question... e.g. \"what do we know about Enki?\"", text: $queryText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { runQuery() }
                Button("Ask") { runQuery() }
                    .buttonStyle(.borderedProminent)
                    .disabled(queryText.isEmpty)
            }
            .padding(.horizontal)
            .padding(.bottom, 12)

            Divider()

            // Results
            ScrollView {
                if let result {
                    resultView(result)
                        .padding(20)
                } else {
                    VStack(spacing: 12) {
                        Spacer(minLength: 60)
                        Image(systemName: "text.magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("Ask a question about the data")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Try:")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                            queryExample("What do we know about Enki?")
                            queryExample("Children of Anu")
                            queryExample("What happened at Uruk?")
                            queryExample("Who is also known as Ishtar?")
                            queryExample("Tell me about the Great Flood")
                        }
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func runQuery() {
        let engine = QueryEngine(context: modelContext)
        result = engine.query(queryText)
    }

    private func queryExample(_ text: String) -> some View {
        Button(action: {
            queryText = text
            runQuery()
        }) {
            Text("  \"\(text)\"")
                .font(.callout)
                .foregroundStyle(Color.accentColor)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func resultView(_ result: QueryResult) -> some View {
        switch result {
        case .figure(let dossier):
            FigureDossierView(dossier: dossier)
        case .place(let dossier):
            PlaceDossierView(dossier: dossier)
        case .event(let dossier):
            EventDossierView(dossier: dossier)
        case .figureList(let title, let figures):
            FigureListDossierView(title: title, figures: figures)
        case .noMatch(let query):
            NoMatchView(query: query)
        }
    }
}

// MARK: - Figure Dossier

struct FigureDossierView: View {
    let dossier: FigureDossier

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(spacing: 12) {
                Circle()
                    .fill(dossier.figure.figureType.color.opacity(0.2))
                    .frame(width: 48, height: 48)
                    .overlay(
                        Image(systemName: dossier.figure.figureType.icon)
                            .font(.title3)
                            .foregroundStyle(dossier.figure.figureType.color)
                    )
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(dossier.figure.name)
                            .font(.title.bold())
                        Text(dossier.figure.gender.symbol)
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                    if !dossier.figure.title.isEmpty {
                        Text(dossier.figure.title)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(dossier.figure.figureType.rawValue)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(RoundedRectangle(cornerRadius: 4).fill(dossier.figure.figureType.color.opacity(0.12)))
                    Text(dossier.figure.birthDate.displayLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Also known as
            if !dossier.figure.alternateNames.isEmpty {
                HStack(spacing: 4) {
                    Text("Also known as:")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Text(dossier.figure.alternateNames.map { "\($0.name) (\($0.tradition.rawValue))" }.joined(separator: ", "))
                        .font(.callout)
                }
            }

            // Properties
            if !dossier.figure.domain.isEmpty {
                HStack(spacing: 4) {
                    Text("Domain:")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Text(dossier.figure.domain)
                        .font(.callout)
                }
            }

            // Description
            if !dossier.figure.figureDescription.isEmpty {
                Text(dossier.figure.figureDescription)
                    .font(.body)
            }

            Divider()

            // Family
            if !dossier.parents.isEmpty || !dossier.children.isEmpty || !dossier.spouses.isEmpty || !dossier.createdBy.isEmpty || !dossier.created.isEmpty {
                dossierSection("Family") {
                    if !dossier.parents.isEmpty {
                        dossierLine("Parents", dossier.parents.map(\.name).joined(separator: ", "))
                    }
                    if !dossier.spouses.isEmpty {
                        dossierLine("Spouse", dossier.spouses.map(\.name).joined(separator: ", "))
                    }
                    if !dossier.children.isEmpty {
                        dossierLine("Children", dossier.children.map(\.name).joined(separator: ", "))
                    }
                    if !dossier.createdBy.isEmpty {
                        dossierLine("Created by", dossier.createdBy.map(\.name).joined(separator: ", "))
                    }
                    if !dossier.created.isEmpty {
                        dossierLine("Creator of", dossier.created.map(\.name).joined(separator: ", "))
                    }
                }
            }

            // Place Associations
            if !dossier.placeAssociations.isEmpty {
                dossierSection("Associated Places") {
                    ForEach(dossier.placeAssociations) { assoc in
                        HStack(spacing: 8) {
                            Image(systemName: assoc.place?.placeType.icon ?? "mappin")
                                .font(.caption)
                                .foregroundStyle(.teal)
                                .frame(width: 14)
                            Text(assoc.role.rawValue)
                                .font(.caption)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(RoundedRectangle(cornerRadius: 3).fill(Color.teal.opacity(0.1)))
                            Text(assoc.place?.name ?? "?")
                                .font(.callout)
                                .fontWeight(.medium)
                            Spacer()
                            if !assoc.source.isEmpty {
                                Text(assoc.source)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                    .italic()
                            }
                        }
                    }
                }
            }

            // Events
            if !dossier.events.isEmpty {
                dossierSection("Events Involved") {
                    ForEach(dossier.events) { event in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: event.eventType.icon)
                                .font(.caption)
                                .foregroundStyle(event.eventType.color)
                                .frame(width: 14)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(event.name)
                                    .font(.callout)
                                    .fontWeight(.medium)
                                Text(event.eventDescription)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                                if !event.source.isEmpty {
                                    Text(event.source)
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                        .italic()
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            // Places
            if !dossier.places.isEmpty {
                dossierSection("Associated Places") {
                    ForEach(dossier.places) { place in
                        HStack(spacing: 8) {
                            Image(systemName: place.placeType.icon)
                                .font(.caption)
                                .foregroundStyle(.teal)
                                .frame(width: 14)
                            Text(place.name)
                                .font(.callout)
                                .fontWeight(.medium)
                            Text("(\(place.placeType.rawValue))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if !place.placeDescription.isEmpty {
                                Text("— \(place.placeDescription)")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
            }

            // Citations
            if !dossier.citations.isEmpty {
                dossierSection("Sources & Citations") {
                    ForEach(dossier.citations) { citation in
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
                            }
                        }
                    }
                }
            }
        }
    }

    private func dossierSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .padding(.top, 4)
            content()
        }
    }

    private func dossierLine(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label + ":")
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .trailing)
            Text(value)
                .font(.callout)
        }
    }
}

// MARK: - Place Dossier

struct PlaceDossierView: View {
    let dossier: PlaceDossier

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.teal.opacity(0.2))
                    .frame(width: 48, height: 48)
                    .overlay(Image(systemName: dossier.place.placeType.icon).foregroundStyle(.teal))
                VStack(alignment: .leading, spacing: 2) {
                    Text(dossier.place.name).font(.title.bold())
                    Text(dossier.place.placeType.rawValue).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                if !dossier.place.modernLocation.isEmpty {
                    Text(dossier.place.modernLocation)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if !dossier.place.placeDescription.isEmpty {
                Text(dossier.place.placeDescription).font(.body)
            }

            if !dossier.events.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    Text("Events Here").font(.headline)
                    ForEach(dossier.events) { event in
                        HStack(spacing: 8) {
                            Image(systemName: event.eventType.icon).font(.caption).foregroundStyle(event.eventType.color)
                            Text(event.name).font(.callout).fontWeight(.medium)
                            Text(event.date.displayLabel).font(.caption).foregroundStyle(.tertiary)
                        }
                    }
                }
            }

            if !dossier.figures.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    Text("Figures Associated").font(.headline)
                    Text(dossier.figures.map { "\($0.gender.symbol) \($0.name)" }.joined(separator: ", "))
                        .font(.callout)
                }
            }
        }
    }
}

// MARK: - Event Dossier

struct EventDossierView: View {
    let dossier: EventDossier

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Circle()
                    .fill(dossier.event.eventType.color.opacity(0.2))
                    .frame(width: 48, height: 48)
                    .overlay(Image(systemName: dossier.event.eventType.icon).foregroundStyle(dossier.event.eventType.color))
                VStack(alignment: .leading, spacing: 2) {
                    Text(dossier.event.name).font(.title.bold())
                    Text(dossier.event.eventType.rawValue).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Text(dossier.event.date.displayLabel).font(.caption).foregroundStyle(.secondary)
            }

            if !dossier.event.eventDescription.isEmpty {
                Text(dossier.event.eventDescription).font(.body)
            }

            if !dossier.event.source.isEmpty {
                Text("Source: \(dossier.event.source)").font(.caption).foregroundStyle(.tertiary).italic()
            }

            if !dossier.figures.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    Text("Figures Involved").font(.headline)
                    ForEach(dossier.figures) { figure in
                        HStack(spacing: 8) {
                            Circle().fill(figure.figureType.color).frame(width: 8, height: 8)
                            Text(figure.gender.symbol).font(.caption).foregroundStyle(.secondary)
                            Text(figure.name).font(.callout).fontWeight(.medium)
                            Text(figure.title).font(.caption).foregroundStyle(.tertiary).lineLimit(1)
                        }
                    }
                }
            }

            if let place = dossier.place {
                Divider()
                HStack(spacing: 8) {
                    Text("Location:").font(.callout).foregroundStyle(.secondary)
                    Image(systemName: place.placeType.icon).font(.caption).foregroundStyle(.teal)
                    Text(place.name).font(.callout).fontWeight(.medium)
                    if !place.modernLocation.isEmpty {
                        Text("(\(place.modernLocation))").font(.caption).foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }
}

// MARK: - Figure List Result

struct FigureListDossierView: View {
    let title: String
    let figures: [Figure]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.title2.bold())
            if figures.isEmpty {
                Text("None found").font(.callout).foregroundStyle(.secondary)
            } else {
                ForEach(figures) { figure in
                    HStack(spacing: 8) {
                        Circle().fill(figure.figureType.color).frame(width: 8, height: 8)
                        Text(figure.gender.symbol).font(.caption).foregroundStyle(.secondary)
                        Text(figure.name).font(.callout).fontWeight(.medium)
                        Text("— \(figure.title)").font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
            }
        }
    }
}

// MARK: - No Match

struct NoMatchView: View {
    let query: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "questionmark.circle")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text("No match found for \"\(query)\"")
                .font(.callout)
                .foregroundStyle(.secondary)
            Text("Try a figure name, place name, event name, or alternate name.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }
}
