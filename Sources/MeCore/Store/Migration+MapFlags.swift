import Foundation
import SwiftData

extension Migration {
    /// Place type names that represent bodies of water; normalised lowercased
    /// substrings used to recognise water types the user created on their own.
    package static let waterTypeTokens = [
        "sea", "gulf", "river", "lake", "ocean", "marsh", "swamp", "water",
    ]

    /// Curated list of culturally significant city/landmark names that should be
    /// visible on the overview map even when minor places are hidden. Normalised
    /// lowercased names.
    package static let majorPlaceNames: Set<String> = [
        "ur", "uruk", "babylon", "akkad", "eridu", "kish", "nippur", "lagash",
        "larsa", "sippar", "girsu", "umma", "adab", "isin", "eshnunna", "mari",
        "ebla", "assur", "nineveh", "susa", "der", "dilbat", "borsippa",
    ]

    /// Flags `PlaceType.isWater` for types whose name matches a water token and
    /// `Place.isMajor` for the curated landmark list. Additive + idempotent:
    /// user-set values are only written when currently nil.
    package static func ensureMapFlags(context: ModelContext) {
        var changed = false

        let types = (try? context.fetch(FetchDescriptor<PlaceType>())) ?? []
        for type in types where type.isWater == nil {
            let name = type.name.lowercased()
            if waterTypeTokens.contains(where: { name.contains($0) }) {
                type.isWater = true
                changed = true
            }
        }

        let places = (try? context.fetch(FetchDescriptor<Place>())) ?? []
        for place in places where place.isMajor == nil {
            if majorPlaceNames.contains(place.name.lowercased()) {
                place.isMajor = true
                changed = true
            }
        }

        for place in places where place.zoomLevel == nil && place.isMajor == true {
            place.zoomLevel = 0
            changed = true
        }

        if changed { try? context.save() }
    }
}