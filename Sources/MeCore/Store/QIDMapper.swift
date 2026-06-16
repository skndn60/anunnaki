import Foundation

package struct QIDMapper {
    private var figureTypes: [String: String] = [:]
    private var genders: [String: Figure.Gender] = [:]
    private var placeTypes: [String: String] = [:]
    private var eventTypes: [String: String] = [:]

    static func load() -> QIDMapper {
        guard let url = Bundle.module.url(forResource: "wikidata_qids", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let json = try? JSONDecoder().decode(RawMapping.self, from: data) else {
            return QIDMapper()
        }

        var mapper = QIDMapper()
        for (raw, qids) in json.figureTypes {
            for qid in qids { mapper.figureTypes[qid] = raw }
        }
        for (raw, qids) in json.genders {
            guard let g = Figure.Gender(rawValue: raw) else { continue }
            for qid in qids { mapper.genders[qid] = g }
        }
        for (raw, qids) in json.placeTypes {
            for qid in qids { mapper.placeTypes[qid] = raw }
        }
        for (raw, qids) in json.eventTypes {
            for qid in qids { mapper.eventTypes[qid] = raw }
        }
        return mapper
    }

    package func figureType(for qid: String) -> String? { figureTypes[qid] }
    package func gender(for qid: String) -> Figure.Gender? { genders[qid] }
    package func placeType(for qid: String) -> String? { placeTypes[qid] }
    package func eventType(for qid: String) -> String? { eventTypes[qid] }
}

private struct RawMapping: Decodable {
    package let figureTypes: [String: [String]]
    package let genders: [String: [String]]
    package let placeTypes: [String: [String]]
    package let eventTypes: [String: [String]]
}
