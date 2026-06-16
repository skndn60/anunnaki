import Foundation

/// Maps Wikidata claims to our model types.
package struct WikidataParser {
    package let qidMapper: QIDMapper

    package init(qidMapper: QIDMapper = .load()) {
        self.qidMapper = qidMapper
    }

    package func parse(_ entity: WikidataEntity) -> ParsedWikidata {
        var result = ParsedWikidata()
        guard let claims = entity.claims else { return result }

        for (prop, claimList) in claims {
            guard let first = claimList.first(where: { $0.rank != "deprecated" }),
                  let snak = first.mainsnak,
                  let dv = snak.datavalue,
                  let value = dv.value,
                  let targetID = value.id else { continue }

            switch prop {
            case "P31": // instance of
                applyInstanceOf(targetID, to: &result)
            case "P21": // sex/gender
                result.gender = qidMapper.gender(for: targetID)
            case "P22": // father
                result.relationships.append((.father, targetID, ""))
            case "P25": // mother
                result.relationships.append((.mother, targetID, ""))
            case "P26": // spouse
                result.relationships.append((.spouse, targetID, ""))
            case "P40": // child
                result.relationships.append((.father, targetID, ""))
            case "P3373": // sibling
                result.relationships.append((.sibling, targetID, ""))
            default:
                break
            }
        }

        return result
    }

    // MARK: - Instance of (P31) mapping

    private func applyInstanceOf(_ qid: String, to result: inout ParsedWikidata) {
        if let ft = qidMapper.figureType(for: qid) {
            result.figureType = ft
        } else if let pt = qidMapper.placeType(for: qid) {
            result.placeType = pt
        } else if let et = qidMapper.eventType(for: qid) {
            result.eventType = et
        }
    }
}
