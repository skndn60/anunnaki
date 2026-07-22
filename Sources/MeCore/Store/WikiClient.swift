import Foundation

// MARK: - Types

package struct WikiSearchResult: Identifiable, Decodable {
    package let pageid: Int
    package let title: String
    package let snippet: String
    package var id: Int { pageid }
}

package struct WikiPage: Decodable {
    package let pageid: Int
    package let title: String
    package let extract: String?
}

/// Decoded Wikidata entity (labels + claims).
package struct WikidataEntity: Decodable {
    package let id: String
    package let labels: [String: WikidataLabel]?
    package let claims: [String: [WikidataClaim]]?

    package var englishLabel: String? { labels?["en"]?.value }
}

package struct WikidataLabel: Decodable {
    package let value: String
}

package struct WikidataClaim: Decodable {
    package let mainsnak: WikidataSnak?
    package let rank: String?
}

package struct WikidataSnak: Decodable {
    package let datavalue: WikidataDataValue?
}

package struct WikidataDataValue: Decodable {
    package let type: String?
    package let value: WikidataValue?
}

package struct WikidataValue: Decodable {
    package let id: String?        // wikibase-entityid
    package let time: String?      // time
    package let text: String?      // string
}

/// Parsed structured data extracted from a Wikidata entity.
package struct ParsedWikidata {
    package init() {}

    package var figureType: String?
    package var gender: Figure.Gender?
    package var domain: String?
    package var placeType: String?
    package var eventType: String?
    package var relationships: [(type: String, targetID: String, targetLabel: String)] = []
}

// MARK: - Client

package final class WikiClient {
    package init() {}

    private let session = URLSession.shared
    private let wikiBase = URLComponents(string: "https://en.wikipedia.org/w/api.php")!
    private let dataBase = "https://www.wikidata.org/wiki/Special:EntityData"
    private let wikidataAPI = URLComponents(string: "https://www.wikidata.org/w/api.php")!

    package func search(query: String, offset: Int = 0) async throws -> (results: [WikiSearchResult], nextOffset: Int?) {
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
        if offset > 0 {
            components.queryItems!.append(.init(name: "sroffset", value: String(offset)))
        }
        let (data, _) = try await session.data(from: components.url!)
        let envelope = try JSONDecoder().decode(SearchEnvelope.self, from: data)
        let nextOffset = envelope.continue?.sroffset
        return (envelope.query.search, nextOffset)
    }

    package func fetchExtract(title: String) async throws -> String {
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
    package func fetchWikidataID(title: String) async throws -> String? {
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
    package func fetchWikidataEntity(id: String) async throws -> WikidataEntity? {
        let url = URL(string: "\(dataBase)/\(id).json")!
        let (data, _) = try await session.data(from: url)
        let envelope = try JSONDecoder().decode(WikidataEnvelope.self, from: data)
        return envelope.entities[id]
    }

    /// Resolve one or more Q identifiers to their English labels.
    package func resolveLabels(ids: [String]) async throws -> [String: String] {
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
    package struct Query: Decodable { let search: [WikiSearchResult] }
    package struct Continue: Decodable { let sroffset: Int? }
    package let query: Query
    package let `continue`: Continue?
}

private struct ExtractEnvelope: Decodable {
    package struct Query: Decodable { let pages: [String: WikiPage] }
    package let query: Query
}

private struct PagePropsEnvelope: Decodable {
    package struct Page: Decodable {
        package struct PageProps: Decodable {
            package let wikibaseItem: String?
        }
        package let pageprops: PageProps?
    }
    package struct Query: Decodable { let pages: [String: Page] }
    package let query: Query
}

private struct WikidataEnvelope: Decodable {
    package let entities: [String: WikidataEntity]
}

private struct LabelEnvelope: Decodable {
    package struct Entity: Decodable {
        package let labels: [String: WikidataLabel]?
    }
    package let entities: [String: Entity]
}
