import Foundation

// MARK: - Types

struct WikiSearchResult: Identifiable, Decodable {
    let pageid: Int
    let title: String
    let snippet: String
    var id: Int { pageid }
}

struct WikiPage: Decodable {
    let pageid: Int
    let title: String
    let extract: String?
}

/// Decoded Wikidata entity (labels + claims).
struct WikidataEntity: Decodable {
    let id: String
    let labels: [String: WikidataLabel]?
    let claims: [String: [WikidataClaim]]?

    var englishLabel: String? { labels?["en"]?.value }
}

struct WikidataLabel: Decodable {
    let value: String
}

struct WikidataClaim: Decodable {
    let mainsnak: WikidataSnak?
    let rank: String?
}

struct WikidataSnak: Decodable {
    let datavalue: WikidataDataValue?
}

struct WikidataDataValue: Decodable {
    let type: String?
    let value: WikidataValue?
}

struct WikidataValue: Decodable {
    let id: String?        // wikibase-entityid
    let time: String?      // time
    let text: String?      // string
}

/// Parsed structured data extracted from a Wikidata entity.
struct ParsedWikidata {
    var figureType: Figure.FigureType?
    var gender: Figure.Gender?
    var domain: String?
    var placeType: Place.PlaceType?
    var eventType: Event.EventType?
    var relationships: [(type: Relationship.RelationshipType, targetID: String, targetLabel: String)] = []
}

// MARK: - Client

final class WikiClient {
    private let session = URLSession.shared
    private let wikiBase = URLComponents(string: "https://en.wikipedia.org/w/api.php")!
    private let dataBase = "https://www.wikidata.org/wiki/Special:EntityData"
    private let wikidataAPI = URLComponents(string: "https://www.wikidata.org/w/api.php")!

    func search(query: String) async throws -> [WikiSearchResult] {
        var components = wikiBase
        components.queryItems = [
            .init(name: "action", value: "query"),
            .init(name: "list", value: "search"),
            .init(name: "srwhat", value: "text"),
            .init(name: "srlimit", value: "10"),
            .init(name: "srsearch", value: query),
            .init(name: "format", value: "json"),
            .init(name: "origin", value: "*"),
        ]
        let (data, _) = try await session.data(from: components.url!)
        let envelope = try JSONDecoder().decode(SearchEnvelope.self, from: data)
        return envelope.query.search
    }

    func fetchExtract(title: String) async throws -> String {
        var components = wikiBase
        components.queryItems = [
            .init(name: "action", value: "query"),
            .init(name: "prop", value: "extracts"),
            .init(name: "exintro", value: "true"),
            .init(name: "explaintext", value: "true"),
            .init(name: "exchars", value: "3000"),
            .init(name: "titles", value: title),
            .init(name: "format", value: "json"),
            .init(name: "origin", value: "*"),
        ]
        let (data, _) = try await session.data(from: components.url!)
        let envelope = try JSONDecoder().decode(ExtractEnvelope.self, from: data)
        return envelope.query.pages.values.compactMap { $0.extract }.first ?? ""
    }

    /// Get the Wikidata Q identifier from a Wikipedia page title.
    func fetchWikidataID(title: String) async throws -> String? {
        var components = wikiBase
        components.queryItems = [
            .init(name: "action", value: "query"),
            .init(name: "prop", value: "pageprops"),
            .init(name: "titles", value: title),
            .init(name: "format", value: "json"),
            .init(name: "origin", value: "*"),
        ]
        let (data, _) = try await session.data(from: components.url!)
        let envelope = try JSONDecoder().decode(PagePropsEnvelope.self, from: data)
        return envelope.query.pages.values.compactMap { $0.pageprops?.wikibaseItem }.first
    }

    /// Fetch the full Wikidata entity JSON for a Q identifier.
    func fetchWikidataEntity(id: String) async throws -> WikidataEntity? {
        let url = URL(string: "\(dataBase)/\(id).json")!
        let (data, _) = try await session.data(from: url)
        let envelope = try JSONDecoder().decode(WikidataEnvelope.self, from: data)
        return envelope.entities[id]
    }

    /// Resolve one or more Q identifiers to their English labels.
    func resolveLabels(ids: [String]) async throws -> [String: String] {
        guard !ids.isEmpty else { return [:] }
        var components = wikidataAPI
        components.queryItems = [
            .init(name: "action", value: "wbgetentities"),
            .init(name: "ids", value: ids.joined(separator: "|")),
            .init(name: "props", value: "labels"),
            .init(name: "languages", value: "en"),
            .init(name: "format", value: "json"),
            .init(name: "origin", value: "*"),
        ]
        let (data, _) = try await session.data(from: components.url!)
        let envelope = try JSONDecoder().decode(LabelEnvelope.self, from: data)
        return envelope.entities.compactMapValues { $0.labels?["en"]?.value }
    }
}

// MARK: - Decoding helpers

private struct SearchEnvelope: Decodable {
    struct Query: Decodable { let search: [WikiSearchResult] }
    let query: Query
}

private struct ExtractEnvelope: Decodable {
    struct Query: Decodable { let pages: [String: WikiPage] }
    let query: Query
}

private struct PagePropsEnvelope: Decodable {
    struct Page: Decodable {
        struct PageProps: Decodable {
            let wikibaseItem: String?
        }
        let pageprops: PageProps?
    }
    struct Query: Decodable { let pages: [String: Page] }
    let query: Query
}

private struct WikidataEnvelope: Decodable {
    let entities: [String: WikidataEntity]
}

private struct LabelEnvelope: Decodable {
    struct Entity: Decodable {
        let labels: [String: WikidataLabel]?
    }
    let entities: [String: Entity]
}
