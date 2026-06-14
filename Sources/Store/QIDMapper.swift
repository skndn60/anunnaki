import Foundation

struct QIDMapper {
    private var figureTypes: [String: Figure.FigureType] = [:]
    private var genders: [String: Figure.Gender] = [:]
    private var placeTypes: [String: Place.PlaceType] = [:]
    private var eventTypes: [String: Event.EventType] = [:]

    static func load() -> QIDMapper {
        guard let url = Bundle.main.url(forResource: "wikidata_qids", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let json = try? JSONDecoder().decode(RawMapping.self, from: data) else {
            return QIDMapper()
        }

        var mapper = QIDMapper()
        for (raw, qids) in json.figureTypes {
            guard let ft = Figure.FigureType(rawValue: raw) else { continue }
            for qid in qids { mapper.figureTypes[qid] = ft }
        }
        for (raw, qids) in json.genders {
            guard let g = Figure.Gender(rawValue: raw) else { continue }
            for qid in qids { mapper.genders[qid] = g }
        }
        for (raw, qids) in json.placeTypes {
            guard let pt = Place.PlaceType(rawValue: raw) else { continue }
            for qid in qids { mapper.placeTypes[qid] = pt }
        }
        for (raw, qids) in json.eventTypes {
            guard let et = Event.EventType(rawValue: raw) else { continue }
            for qid in qids { mapper.eventTypes[qid] = et }
        }
        return mapper
    }

    func figureType(for qid: String) -> Figure.FigureType? { figureTypes[qid] }
    func gender(for qid: String) -> Figure.Gender? { genders[qid] }
    func placeType(for qid: String) -> Place.PlaceType? { placeTypes[qid] }
    func eventType(for qid: String) -> Event.EventType? { eventTypes[qid] }
}

private struct RawMapping: Decodable {
    let figureTypes: [String: [String]]
    let genders: [String: [String]]
    let placeTypes: [String: [String]]
    let eventTypes: [String: [String]]
}
