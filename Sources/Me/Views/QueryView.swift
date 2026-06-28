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
                AppKitTextField(text: $queryText, placeholder: "Ask a question... e.g. \"what do we know about Enki?\"", onCommit: { runQuery() })
                Button("Ask") { runQuery() }
                    .buttonStyle(.borderedProminent)
                    .disabled(queryText.isEmpty)
                if result != nil {
                    Button("Clear") { clearQuery() }
                        .buttonStyle(.plain)
                        .foregroundColor(.secondary)
                        .keyboardShortcut(.escape)
                }
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

        }
    }

    private func clearQuery() {
        queryText = ""
        result = nil
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
        case .eventList(let title, let events):
            EventListDossierView(title: title, events: events)
        case .placeList(let title, let places):
            PlaceListDossierView(title: title, places: places)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(spacing: 12) {
                Circle()
                    .fill(dossier.figure.figureType?.color.opacity(0.2) ?? .gray.opacity(0.2))
                    .frame(width: 48, height: 48)
                    .overlay(
                        Image(systemName: dossier.figure.figureType?.icon ?? "questionmark")
                            .font(.title3)
                            .foregroundStyle(dossier.figure.figureType?.color ?? .gray)
                    )
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(dossier.figure.name)
                            .font(.title.bold())
                        Text(dossier.figure.gender.symbol)
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                    if let disambiguation = dossier.figure.disambiguation, !disambiguation.isEmpty {
                        Text(disambiguation)
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                    }
                    if !dossier.figure.title.isEmpty {
                        Text(dossier.figure.title)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(dossier.figure.figureType?.name ?? "Unknown")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(RoundedRectangle(cornerRadius: 4).fill(dossier.figure.figureType?.color.opacity(0.12) ?? .gray.opacity(0.12)))
                    Text(dossier.figure.birthDate.displayLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

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
            if !dossier.figure.figureDescription.isEmpty {
                Text(dossier.figure.figureDescription)
                    .font(.body)
            }

            Divider()

            // Family
            if !dossier.parents.isEmpty || !dossier.children.isEmpty || !dossier.spouses.isEmpty || !dossier.createdBy.isEmpty || !dossier.created.isEmpty {
                dossierSection("Family") {
                    if !dossier.parents.isEmpty {
                        entityLine(label: "Parents") {
                            ForEach(dossier.parents, id: \.persistentModelID) { parent in
                                EntityLink(name: parent.name, kind: .figure)
                            }
                        }
                    }
                    if !dossier.spouses.isEmpty {
                        entityLine(label: "Spouse") {
                            ForEach(dossier.spouses, id: \.persistentModelID) { spouse in
                                EntityLink(name: spouse.name, kind: .figure)
                            }
                        }
                    }
                    if !dossier.children.isEmpty {
                        entityLine(label: "Children") {
                            ForEach(dossier.children, id: \.persistentModelID) { child in
                                EntityLink(name: child.name, kind: .figure)
                            }
                        }
                    }
                    if !dossier.createdBy.isEmpty {
                        entityLine(label: "Created by") {
                            ForEach(dossier.createdBy, id: \.persistentModelID) { fig in
                                EntityLink(name: fig.name, kind: .figure)
                            }
                        }
                    }
                    if !dossier.created.isEmpty {
                        entityLine(label: "Creator of") {
                            ForEach(dossier.created, id: \.persistentModelID) { fig in
                                EntityLink(name: fig.name, kind: .figure)
                            }
                        }
                    }
                }
            }

            // Place Associations
            if !dossier.placeAssociations.isEmpty {
                dossierSection("Associated Places") {
                    ForEach(dossier.placeAssociations) { assoc in
                        HStack(spacing: 8) {
                            Image(systemName: assoc.place?.placeType?.icon ?? "mappin")
                                .font(.caption)
                                .foregroundStyle(.teal)
                                .frame(width: 14)
                            Text(assoc.roleType?.name ?? "—")
                                .font(.caption)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(RoundedRectangle(cornerRadius: 3).fill(Color.teal.opacity(0.1)))
                            if let place = assoc.place {
                                EntityLink(name: place.name, kind: .place)
                                    .font(.callout)
                            } else {
                                Text("?")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            }
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

    private func entityLine<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label + ":")
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .trailing)
            HStack(spacing: 4) {
                content()
            }
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
                    .overlay(Image(systemName: dossier.place.placeType?.icon ?? "mappin").foregroundStyle(.teal))
                VStack(alignment: .leading, spacing: 2) {
                    Text(dossier.place.name).font(.title.bold())
                    Text(dossier.place.placeType?.name ?? "City").font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
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
    let figures: [Figure]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.title2.bold())
            if figures.isEmpty {
                Text("None found").font(.callout).foregroundStyle(.secondary)
            } else {
                ForEach(figures) { figure in
                    HStack(spacing: 8) {
                        Circle().fill(figure.figureType?.color ?? .gray).frame(width: 8, height: 8)
                        Text(figure.gender.symbol).font(.caption).foregroundStyle(.secondary)
                        EntityLink(name: figure.name, kind: .figure).font(.callout)
                        Text("— \(figure.title)").font(.caption).foregroundStyle(.secondary).lineLimit(1)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.title2.bold())
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

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.title2.bold())
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

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "text.alignleft")
                .font(.title3)
                .foregroundColor(.accentColor)
                .frame(width: 24)
            Text(text)
                .font(.body)
                .foregroundColor(.primary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.accentColor.opacity(0.06))
        )
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
