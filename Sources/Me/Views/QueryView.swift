import SwiftUI
import SwiftData
import AppKit

/// Native NSTextField wrapper that handles focus correctly.
struct AppKitTextField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var onCommit: () -> Void

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField()
        field.placeholderString = placeholder
        field.bezelStyle = .roundedBezel
        field.stringValue = text
        field.delegate = context.coordinator
        return field
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        nsView.stringValue = text
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onCommit: onCommit)
    }

    class Coordinator: NSObject, NSTextFieldDelegate {
        @Binding var text: String
        let onCommit: () -> Void

        init(text: Binding<String>, onCommit: @escaping () -> Void) {
            self._text = text
            self.onCommit = onCommit
        }

        func controlTextDidChange(_ obj: Notification) {
            if let field = obj.object as? NSTextField {
                text = field.stringValue
            }
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                onCommit()
                return true
            }
            return false
        }
    }
}

/// Natural language query interface — ask questions about the data.
struct QueryView: View {
    @Environment(\.modelContext) private var modelContext
    var coordinator: NavigationCoordinator?
    @State private var queryText = ""
    @State private var result: QueryResult?
    @State private var ollamaReachable = false
    @State private var forceLLM = false
    @State private var isProcessing = false

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
                AppKitTextField(text: $queryText, placeholder: "Ask a question... e.g. \"what do we know about Enki?\"", onCommit: { runQuery() })
                Circle()
                    .fill(ollamaReachable ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                    .help(ollamaReachable ? "Ollama connected" : "Ollama not reachable")
                if isProcessing {
                    ProgressView()
                        .scaleEffect(0.65)
                        .help("Ollama is processing...")
                } else {
                    Button("Ask") { runQuery() }
                        .buttonStyle(.borderedProminent)
                        .disabled(queryText.isEmpty)
                }
                if ollamaReachable {
                    Button(action: { forceLLM.toggle() }) {
                        Image(systemName: forceLLM ? "brain" : "brain.head.profile")
                            .foregroundStyle(forceLLM ? Color.green : .secondary)
                    }
                    .buttonStyle(.plain)
                    .help(forceLLM ? "Skip regex, use local AI" : "Use local AI for all queries")
                }
                if result != nil {
                    Button("Clear") { clearQuery() }
                        .buttonStyle(.plain)
                        .foregroundColor(.secondary)
                        .keyboardShortcut(.escape)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 12)
            .task {
                let reachable = await Task.detached {
                    OllamaResolver().isReachable()
                }.value
                ollamaReachable = reachable
            }

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
                            queryExample("Enki's children")
                            queryExample("Enki's parents")
                            queryExample("Enki's spouse")
                            queryExample("Uruk's events")
                            queryExample("Great Flood's figures")
                            queryExample("What happened at Uruk?")
                            queryExample("Who is also known as Ishtar?")
                            queryExample("Tell me about the Great Flood")
                            queryExample("list all figures")
                            queryExample("all deities")
                            queryExample("female figures")
                            queryExample("wind gods")
                            queryExample("Ninurta's uncle")
                            queryExample("figures of the Early Dynastic Period")
                            queryExample("duration of the Early Dynastic Period")
                            queryExample("how long did the Antediluvian Period last")
                        }
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .textSelection(.enabled)
            .onAppear {
                queryText = coordinator?.recentQueryText ?? ""
                if result == nil { result = coordinator?.recentQueryResult }
            }
        }
    }

    private func clearQuery() {
        queryText = ""
        result = nil
    }

    private func runQuery() {
        if forceLLM {
            isProcessing = true
            Task {
                let resolver = OllamaResolver()
                let modelName = resolver.modelName
                if let answer = await resolver.resolveAsync(query: queryText, modelContext: modelContext) {
                    result = answer
                } else {
                    result = .answer("Ollama (\(modelName)) returned no response. Check that the model is downloaded and Ollama is serving on localhost:11434.")
                }
                isProcessing = false
            }
        } else {
            let engine = QueryEngine(context: modelContext)
            engine.fallbackResolver = OllamaResolver()
            result = engine.query(queryText)
        }
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

    private func saveQueryState() {
        coordinator?.recentQueryText = queryText
        coordinator?.recentQueryResult = result
    }

    @ViewBuilder
    private func resultView(_ result: QueryResult) -> some View {
        switch result {
        case .figure(let dossier):
            FigureDossierView(dossier: dossier, coordinator: coordinator, queryText: queryText)
        case .place(let dossier):
            PlaceDossierView(dossier: dossier, coordinator: coordinator, queryText: queryText)
        case .event(let dossier):
            EventDossierView(dossier: dossier, coordinator: coordinator, queryText: queryText)
        case .figureList(let title, let figures):
            FigureListDossierView(title: title, figures: figures.map { ($0, nil) }, coordinator: coordinator, queryText: queryText)
        case .figureListAnnotated(let title, let figures):
            FigureListDossierView(title: title, figures: figures, coordinator: coordinator, queryText: queryText)
        case .eventList(let title, let events):
            EventListDossierView(title: title, events: events, coordinator: coordinator, queryText: queryText)
        case .placeList(let title, let places):
            PlaceListDossierView(title: title, places: places, coordinator: coordinator, queryText: queryText)
        case .thing(let thing):
            ThingDossierView(thing: thing)
        case .thingList(let title, let things):
            ThingListDossierView(title: title, things: things)
        case .answer(let text):
            AnswerView(text: text)
        case .imageList(let title, let images):
            ImageListResultView(title: title, images: images)
        case .noMatch(let query):
            NoMatchView(query: query)
        }
    }
}

// MARK: - Image List Result

private struct ImageListResultView: View {
    let title: String
    let images: [ImageAsset]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(title)
                    .font(.title2.bold())
                if images.isEmpty {
                    Text("No images found")
                        .foregroundStyle(.secondary)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                        ForEach(images) { image in
                            ImageThumbnail(image: image, onDelete: {}, onTap: {})
                        }
                    }
                }
            }
            .padding(20)
            .textSelection(.enabled)
        }
    }
}

// MARK: - Figure Dossier

struct FigureDossierView: View {
    let dossier: FigureDossier
    var coordinator: NavigationCoordinator?
    var queryText: String = ""

    private func pushQueryBreadcrumbAndNavigate() {
        coordinator?.pushQueryBreadcrumb(queryText: queryText)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            FigureHeaderView(figure: dossier.figure, showBirthDate: true)

            // Action buttons
            HStack(spacing: 8) {
                Button(action: {
                    pushQueryBreadcrumbAndNavigate()
                    coordinator?.navigateToFigure(dossier.figure.persistentModelID, name: dossier.figure.name)
                }) {
                    Label("Open in Sidebar", systemImage: "sidebar.left")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button(action: {
                    pushQueryBreadcrumbAndNavigate()
                    coordinator?.navigateToLineageFigure(dossier.figure.persistentModelID)
                }) {
                    Label("Show Lineage", systemImage: "tree")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.bottom, 4)

            // Found via alias
            if let alias = dossier.matchedAliasName {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.caption)
                        .foregroundStyle(.orange)
                    Text("Found via alias \"\(alias)\"")
                        .font(.callout)
                        .foregroundStyle(.orange)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.orange.opacity(0.08))
                )
            }

            // Also known as
            if !dossier.figure.alternateNames.isEmpty {
                HStack(spacing: 4) {
                    Text("Also known as:")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    ForEach(Array(dossier.figure.alternateNames.enumerated()), id: \.element.id) { i, alt in
                        EntityLink(name: alt.name, kind: .figure)
                            .font(.callout)
                        if i < dossier.figure.alternateNames.count - 1 {
                            Text(",")
                                .foregroundStyle(.secondary)
                        }
                    }
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
            FigureDescriptionView(text: dossier.figure.figureDescription)

            Divider()

            // Family
            if !dossier.parents.isEmpty || !dossier.children.isEmpty || !dossier.spouses.isEmpty || !dossier.createdBy.isEmpty || !dossier.created.isEmpty {
                dossierSection("Family") {
                    FigureDossierRelationshipList(label: "Parents", figures: dossier.parents)
                    FigureDossierRelationshipList(label: "Spouse", figures: dossier.spouses)
                    FigureDossierRelationshipList(label: "Children", figures: dossier.children)
                    FigureDossierRelationshipList(label: "Created by", figures: dossier.createdBy)
                    FigureDossierRelationshipList(label: "Creator of", figures: dossier.created)
                }
            }

            // Place Associations
            if !dossier.placeAssociations.isEmpty {
                dossierSection("Associated Places") {
                    ForEach(dossier.placeAssociations) { assoc in
                        FigurePlaceAssociationDossierRow(association: assoc)
                    }
                }
            }

            // Events
            if !dossier.events.isEmpty {
                dossierSection("Events Involved") {
                    ForEach(dossier.events) { event in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: event.eventType?.icon ?? "bolt")
                                .font(.caption)
                                .foregroundStyle(event.eventType?.color ?? .gray)
                                .frame(width: 14)
                            VStack(alignment: .leading, spacing: 2) {
                                EntityLink(name: event.name, kind: .event)
                                    .font(.callout)
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
                            Image(systemName: place.placeType?.icon ?? "mappin")
                                .font(.caption)
                                .foregroundStyle(.teal)
                                .frame(width: 14)
                            EntityLink(name: place.name, kind: .place)
                                .font(.callout)
                            Text("(\(place.placeType?.name ?? "City"))")
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
                        FigureCitationsRow(citation: citation)
                    }
                }
            }

            // Images
            if !dossier.figure.images.isEmpty {
                Divider()
                ImageGallery(
                    title: "Images (\(dossier.figure.images.count))",
                    images: dossier.figure.images,
                    onLinkImage: { asset in
                        asset.figures.append(dossier.figure)
                    }
                )
                .padding(.top, 4)
            }
        }
        .textSelection(.enabled)
    }

    private func dossierSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .padding(.top, 4)
            content()
        }
    }

}

// MARK: - Place Dossier

struct PlaceDossierView: View {
    let dossier: PlaceDossier
    var coordinator: NavigationCoordinator?
    var queryText: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.teal.opacity(0.2))
                    .frame(width: 48, height: 48)
                    .overlay(Image(systemName: dossier.place.placeType?.icon ?? "mappin").foregroundStyle(.teal))
                VStack(alignment: .leading, spacing: 2) {
                    Text(dossier.place.name).font(.title.bold())
                    Text(dossier.place.placeType?.name ?? "City").font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: {
                    coordinator?.pushQueryBreadcrumb(queryText: queryText)
                    coordinator?.navigateToPlace(dossier.place.persistentModelID, name: dossier.place.name)
                }) {
                    Label("Open", systemImage: "sidebar.left")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                MapPreviewButton(place: dossier.place)
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
                            Image(systemName: event.eventType?.icon ?? "bolt").font(.caption).foregroundStyle(event.eventType?.color ?? .gray)
                            EntityLink(name: event.name, kind: .event).font(.callout)
                            Text(event.date.displayLabel).font(.caption).foregroundStyle(.tertiary)
                        }
                    }
                }
            }

            if !dossier.figures.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    Text("Figures Associated").font(.headline)
                    ForEach(dossier.figures) { figure in
                        HStack(spacing: 4) {
                            Text(figure.gender.symbol).font(.caption).foregroundStyle(.secondary)
                            EntityLink(name: figure.name, kind: .figure).font(.callout)
                        }
                    }
                }
            }

            // Images
            if !dossier.place.images.isEmpty {
                Divider()
                ImageGallery(
                    title: "Images (\(dossier.place.images.count))",
                    images: dossier.place.images,
                    onLinkImage: { asset in
                        asset.places.append(dossier.place)
                    }
                )
                .padding(.top, 4)
            }
        }
        .textSelection(.enabled)
    }
}

// MARK: - Event Dossier

struct EventDossierView: View {
    let dossier: EventDossier
    var coordinator: NavigationCoordinator?
    var queryText: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Circle()
                    .fill((dossier.event.eventType?.color ?? .gray).opacity(0.2))
                    .frame(width: 48, height: 48)
                    .overlay(Image(systemName: dossier.event.eventType?.icon ?? "bolt").foregroundStyle(dossier.event.eventType?.color ?? .gray))
                VStack(alignment: .leading, spacing: 2) {
                    Text(dossier.event.name).font(.title.bold())
                    Text(dossier.event.eventType?.name ?? "Other").font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: {
                    coordinator?.pushQueryBreadcrumb(queryText: queryText)
                    coordinator?.navigateToEvent(dossier.event.persistentModelID, name: dossier.event.name)
                }) {
                    Label("Open", systemImage: "sidebar.left")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
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
                            Circle().fill(figure.figureType?.color ?? .gray).frame(width: 8, height: 8)
                            Text(figure.gender.symbol).font(.caption).foregroundStyle(.secondary)
                            EntityLink(name: figure.name, kind: .figure).font(.callout)
                            Text(figure.title).font(.caption).foregroundStyle(.tertiary).lineLimit(1)
                        }
                    }
                }
            }

            if !dossier.places.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 4) {
                    Text("Locations:").font(.callout).foregroundStyle(.secondary)
                    ForEach(dossier.places, id: \.persistentModelID) { place in
                        HStack(spacing: 8) {
                            Image(systemName: place.placeType?.icon ?? "mappin").font(.caption).foregroundStyle(.teal)
                            EntityLink(name: place.name, kind: .place).font(.callout)
                            if !place.modernLocation.isEmpty {
                                Text("(\(place.modernLocation))").font(.caption).foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
            }

            // Images
            if !dossier.event.images.isEmpty {
                Divider()
                ImageGallery(
                    title: "Images (\(dossier.event.images.count))",
                    images: dossier.event.images,
                    onLinkImage: { asset in
                        asset.events.append(dossier.event)
                    }
                )
                .padding(.top, 4)
            }
        }
        .textSelection(.enabled)
    }
}

// MARK: - Figure List Result

struct FigureListDossierView: View {
    let title: String
    let figures: [(Figure, String?)]
    var coordinator: NavigationCoordinator?
    var queryText: String = ""
    @State private var copied = false

    private var hasAnnotations: Bool {
        figures.contains(where: { $0.1 != nil })
    }

    private var sourceName: String {
        if let range = title.range(of: " of ") {
            String(title[range.upperBound...])
        } else {
            title
        }
    }

    private var summary: String? {
        guard hasAnnotations, !figures.isEmpty else { return nil }
        let total = figures.count
        let males = figures.filter { $0.0.gender == .male }.count
        let females = figures.filter { $0.0.gender == .female }.count
        let fullCount = figures.filter { $0.1 == nil }.count
        let halfCount = figures.filter { $0.1 == "half sibling" }.count
        let name = sourceName
        var parts: [String] = ["I found \(total) \(total == 1 ? "person" : "persons") sharing a parent with \(name)"]
        if males > 0, females > 0 {
            parts.append("\(males) \(males == 1 ? "male" : "males") and \(females) \(females == 1 ? "female" : "females")")
        }
        if fullCount > 0 {
            parts.append("\(fullCount) \(fullCount == 1 ? "is" : "are") full \(fullCount == 1 ? "sibling" : "siblings")")
        }
        if halfCount > 0 {
            parts.append("\(halfCount) \(halfCount == 1 ? "is" : "are") half \(halfCount == 1 ? "sibling" : "siblings")")
        }
        return parts.joined(separator: ". ") + "."
    }

    private var listText: String {
        figures.map { "\($0.0.name) — \($0.0.title)" }.joined(separator: "\n")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(.title2.bold())
                Spacer()
                Button(action: {
                    let pb = NSPasteboard.general
                    pb.clearContents()
                    pb.setString(listText, forType: .string)
                    copied = true
                    Task { try? await Task.sleep(nanoseconds: 1_500_000_000); copied = false }
                }) {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        .font(.caption)
                        .foregroundStyle(copied ? .green : .secondary)
                }
                .buttonStyle(.plain)
                .help("Copy list")
            }
            if let summary {
                Text(summary)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 4)
            }
            if figures.isEmpty {
                Text("None found").font(.callout).foregroundStyle(.secondary)
            } else {
                ForEach(figures.indices, id: \.self) { i in
                    let figure = figures[i].0
                    let annotation = figures[i].1
                    HStack(spacing: 8) {
                        Circle().fill(figure.figureType?.color ?? .gray).frame(width: 8, height: 8)
                        Text(figure.gender.symbol).font(.caption).foregroundStyle(.secondary)
                        EntityLink(name: figure.name, kind: .figure).font(.callout)
                        Text("— \(figure.title)").font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        if let annotation {
                            Text("(\(annotation))")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        Spacer()
                        Button(action: {
                            coordinator?.pushQueryBreadcrumb(queryText: queryText)
                            coordinator?.navigateToFigure(figure.persistentModelID, name: figure.name)
                        }) {
                            Label("Open", systemImage: "sidebar.left")
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                        .help("Open in sidebar")
                    }
                }
            }
        }
    }
}

// MARK: - Event List Result

struct EventListDossierView: View {
    let title: String
    let events: [Event]
    var coordinator: NavigationCoordinator?
    var queryText: String = ""
    @State private var copied = false

    private var listText: String {
        events.map { "\($0.name) (\($0.date.displayLabel))" }.joined(separator: "\n")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(.title2.bold())
                Spacer()
                Button(action: {
                    let pb = NSPasteboard.general
                    pb.clearContents()
                    pb.setString(listText, forType: .string)
                    copied = true
                    Task { try? await Task.sleep(nanoseconds: 1_500_000_000); copied = false }
                }) {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        .font(.caption)
                        .foregroundStyle(copied ? .green : .secondary)
                }
                .buttonStyle(.plain)
                .help("Copy list")
            }
            if events.isEmpty {
                Text("None found").font(.callout).foregroundStyle(.secondary)
            } else {
                ForEach(events) { event in
                    HStack(spacing: 8) {
                        Image(systemName: event.eventType?.icon ?? "bolt")
                            .font(.caption)
                            .foregroundStyle(event.eventType?.color ?? .gray)
                        EntityLink(name: event.name, kind: .event).font(.callout)
                        Text(event.date.displayLabel).font(.caption).foregroundStyle(.tertiary)
                        Spacer()
                        Button(action: {
                            coordinator?.pushQueryBreadcrumb(queryText: queryText)
                            coordinator?.navigateToEvent(event.persistentModelID, name: event.name)
                        }) {
                            Label("Open", systemImage: "sidebar.left")
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                        .help("Open in sidebar")
                    }
                }
            }
        }
    }
}

// MARK: - Place List Result

struct PlaceListDossierView: View {
    let title: String
    let places: [Place]
    var coordinator: NavigationCoordinator?
    var queryText: String = ""
    @State private var copied = false

    private var listText: String {
        places.map { "\($0.name) (\($0.placeType?.name ?? "City"))" }.joined(separator: "\n")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(.title2.bold())
                Spacer()
                Button(action: {
                    let pb = NSPasteboard.general
                    pb.clearContents()
                    pb.setString(listText, forType: .string)
                    copied = true
                    Task { try? await Task.sleep(nanoseconds: 1_500_000_000); copied = false }
                }) {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        .font(.caption)
                        .foregroundStyle(copied ? .green : .secondary)
                }
                .buttonStyle(.plain)
                .help("Copy list")
            }
            if places.isEmpty {
                Text("None found").font(.callout).foregroundStyle(.secondary)
            } else {
                ForEach(places) { place in
                    HStack(spacing: 8) {
                        Image(systemName: place.placeType?.icon ?? "mappin")
                            .font(.caption)
                            .foregroundStyle(.teal)
                        EntityLink(name: place.name, kind: .place).font(.callout)
                        Text(place.placeType?.name ?? "City").font(.caption).foregroundStyle(.tertiary)
                        Spacer()
                        Button(action: {
                            coordinator?.pushQueryBreadcrumb(queryText: queryText)
                            coordinator?.navigateToPlace(place.persistentModelID, name: place.name)
                        }) {
                            Label("Open", systemImage: "sidebar.left")
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                        .help("Open in sidebar")
                    }
                }
            }
        }
    }
}

// MARK: - No Match

// MARK: - Answer

struct AnswerView: View {
    let text: String
    @State private var copied = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "brain")
                .font(.title3)
                .foregroundColor(.accentColor)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Text("Ollama")
                        .font(.caption2.bold())
                        .foregroundColor(.accentColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.accentColor.opacity(0.1))
                        )
                    Spacer()
                    Button(action: {
                        let pb = NSPasteboard.general
                        pb.clearContents()
                        pb.setString(text, forType: .string)
                        copied = true
                        Task { try? await Task.sleep(nanoseconds: 1_500_000_000); copied = false }
                    }) {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                            .font(.caption)
                            .foregroundStyle(copied ? .green : .secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Copy answer")
                }
                Text(text)
                    .font(.system(size: 15))
                    .foregroundColor(.primary)
                    .lineSpacing(4)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.accentColor.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.accentColor.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
        .padding(.top, 20)
    }
}

struct NoMatchView: View {
    let query: String

    private let examples: [(label: String, query: String)] = [
        ("Figure details", "Enki"),
        ("Parents", "Enki's mom"),
        ("Children count", "how many children did Anu have"),
        ("Synonym search", "how many kids does Anu have"),
        ("Yes/No question", "Was Enki a deity or a human?"),
        ("Type count", "how many deities"),
        ("Relationships", "Enki's children"),
        ("Timeline", "Sumerian King List"),
    ]

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "questionmark.circle")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text("No match found for \"\(query)\"")
                .font(.callout)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                Text("Try one of these:")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.bottom, 4)
                ForEach(examples, id: \.query) { example in
                    HStack(spacing: 6) {
                        Text(example.label)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .frame(width: 100, alignment: .trailing)
                        Text("\"\(example.query)\"")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }
}

// MARK: - Thing Dossier

private struct ThingDossierView: View {
    let thing: Thing

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "cube.box")
                    .font(.title2)
                    .foregroundStyle(.cyan)
                    .frame(width: 32)
                Text(thing.name)
                    .font(.title.bold())
            }

            if !thing.thingDescription.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Description")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(thing.thingDescription)
                        .font(.body)
                }
            }

            if !thing.source.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Source")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(thing.source)
                        .font(.body)
                }
            }

            if !thing.figureAssociations.isEmpty {
                label("Associated Figures")
                ForEach(thing.figureAssociations) { assoc in
                    Text("\(assoc.figure?.name ?? "?") (\(assoc.roleType?.name ?? "related"))")
                        .font(.subheadline)
                }
            }

            if !thing.placeAssociations.isEmpty {
                label("Associated Places")
                ForEach(thing.placeAssociations) { assoc in
                    Text("\(assoc.place?.name ?? "?") (\(assoc.roleType?.name ?? "related"))")
                        .font(.subheadline)
                }
            }

            if !thing.eventAssociations.isEmpty {
                label("Associated Events")
                ForEach(thing.eventAssociations) { assoc in
                    Text("\(assoc.event?.name ?? "?") (\(assoc.roleType?.name ?? "related"))")
                        .font(.subheadline)
                }
            }

            if !thing.tags.isEmpty {
                label("Tags")
                Text(thing.tags.map(\.name).joined(separator: ", "))
                    .font(.subheadline)
            }
        }
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.top, 4)
    }
}

private struct ThingListDossierView: View {
    let title: String
    let things: [Thing]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.title3.bold())
            if things.isEmpty {
                Text("No things found")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            } else {
                ForEach(things) { thing in
                    HStack(spacing: 8) {
                        Image(systemName: "cube.box")
                            .font(.caption)
                            .foregroundStyle(.cyan)
                        Text(thing.name)
                            .font(.subheadline)
                        if !thing.thingDescription.isEmpty {
                            Text(thing.thingDescription)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                        }
                    }
                }
            }
        }
    }
}
