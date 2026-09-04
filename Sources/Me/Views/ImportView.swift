import SwiftUI
import SwiftData

private let wikiClient = WikiClient()

struct ImportView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var searchText = ""
    @State private var results: [WikiSearchResult] = []
    @State private var selectedResult: WikiSearchResult?
    @State private var extract: String = ""
    @State private var isSearching = false
    @State private var isFetching = false
    @State private var isImporting = false
    @State private var errorMessage: String?
    @State private var importMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Import from Wikipedia")
                    .font(.title2.bold())
                Spacer()
            }
            .padding()

            HStack(spacing: 8) {
                Image(systemName: "globe")
                    .foregroundStyle(.secondary)
                TextField("Search Wikipedia", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { runSearch() }
                Button("Search") { runSearch() }
                    .buttonStyle(.borderedProminent)
                    .disabled(searchText.isEmpty || isSearching)
            }
            .padding(.horizontal)
            .padding(.bottom, 12)

            Divider()

            if let errorMessage {
                ContentUnavailableView(
                    "Error",
                    systemImage: "exclamationmark.triangle",
                    description: Text(errorMessage)
                )
            } else if let importMessage {
                ContentUnavailableView(
                    "Imported",
                    systemImage: "checkmark.circle",
                    description: Text(importMessage)
                )
                .foregroundStyle(.green)
            } else if isSearching {
                Spacer()
                ProgressView("Searching Wikipedia")
                Spacer()
            } else if isFetching || isImporting {
                Spacer()
                ProgressView(isImporting ? "Parsing structured data" : "Loading article")
                Spacer()
            } else if let result = selectedResult, !extract.isEmpty {
                extractView(result)
            } else if results.isEmpty {
                emptyView
            } else {
                resultsList
            }
        }
    }

    // MARK: - Subviews

    private var emptyView: some View {
        VStack(spacing: 12) {
            Spacer(minLength: 60)
            Image(systemName: "globe")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Search Wikipedia for content to import")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("Results are auto-matched to figures, places, and events in your database.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .frame(width: 320)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var resultsList: some View {
        List(results) { result in
            Button {
                selectResult(result)
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.title)
                        .font(.headline)
                    Text(result.snippet.strippingHTML)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private func extractView(_ result: WikiSearchResult) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(result.title)
                    .font(.title.bold())

                Text(extract)
                    .font(.body)

                Button("Import into database") {
                    isImporting = true
                    errorMessage = nil
                    importMessage = nil
                    Task { await performImport(title: result.title, extract: extract) }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isImporting)
            }
            .padding(20)
        }
    }

    // MARK: - Actions

    private func runSearch() {
        guard !searchText.isEmpty else { return }
        isSearching = true
        errorMessage = nil
        importMessage = nil
        selectedResult = nil
        extract = ""
        results = []

        Task {
            do {
                (results, _) = try await wikiClient.search(query: searchText)
                isSearching = false
            } catch {
                errorMessage = error.localizedDescription
                isSearching = false
            }
        }
    }

    private func selectResult(_ result: WikiSearchResult) {
        selectedResult = result
        extract = ""
        isFetching = true
        errorMessage = nil
        importMessage = nil

        Task {
            do {
                let text = try await wikiClient.fetchExtract(title: result.title)
                extract = text
                isFetching = false
            } catch {
                errorMessage = error.localizedDescription
                isFetching = false
            }
        }
    }

    @MainActor
    private func performImport(title: String, extract: String) async {
        let wikiURL = "https://en.wikipedia.org/wiki/\(title.replacingOccurrences(of: " ", with: "_"))"
        let query = title.lowercased()

        let service = ImportService(modelContext: modelContext)
        let parsed = await service.fetchWikidata(title: title) ?? (ParsedWikidata(), [])

        let figures: [Figure] = modelContext.fetchAll()
        let places: [Place] = modelContext.fetchAll()
        let events: [Event] = modelContext.fetchAll()

        let matchQueries = query.count > 1 ? [query, String(query.dropLast())] : [query]

        for mq in matchQueries {
            if let figure = service.matchFigure(query: mq, in: figures) {
                service.createCitation(sourceTitle: title, wikiURL: wikiURL, extract: extract, entityName: figure.name, entityType: .figure)
                service.applyToFigure(figure, parsed: parsed.0, extract: extract, wikiURL: wikiURL, allFigures: figures)
                try? modelContext.save()
                importMessage = "Imported into figure \"\(figure.name)\"."
                isImporting = false
                return
            }
        }

        if let place = service.matchPlace(query: query, in: places) {
            service.createCitation(sourceTitle: title, wikiURL: wikiURL, extract: extract, entityName: place.name, entityType: .place)
            service.applyToPlace(place, parsed: parsed.0, extract: extract, wikiURL: wikiURL)
            try? modelContext.save()
            importMessage = "Imported into place \"\(place.name)\"."
            isImporting = false
            return
        }

        if let event = service.matchEvent(query: query, in: events) {
            service.createCitation(sourceTitle: title, wikiURL: wikiURL, extract: extract, entityName: event.name, entityType: .event)
            service.applyToEvent(event, parsed: parsed.0, extract: extract, wikiURL: wikiURL)
            try? modelContext.save()
            importMessage = "Imported into event \"\(event.name)\"."
            isImporting = false
            return
        }

        service.createStandaloneSource(title: title, extract: extract, wikiURL: wikiURL)
        try? modelContext.save()
        importMessage = "No matching entity found."
        isImporting = false
    }
}

// MARK: - HTML stripping

private extension String {
    var strippingHTML: String {
        self.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#[0-9]+;", with: "", options: .regularExpression)
    }
}
