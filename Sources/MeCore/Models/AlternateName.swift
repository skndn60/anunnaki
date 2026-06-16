import Foundation
import SwiftData

/// An alternate name or cross-cultural equivalent for a figure.
@Model
package final class AlternateName {
    package var figure: Figure?
    package var name: String
    package var tradition: Tradition
    package var nameType: NameType
    package var note: String // e.g. "Identified by Greek historians", "Same deity, Akkadian form"

    /// The cultural tradition this name belongs to.
    package enum Tradition: String, Codable, CaseIterable, Hashable {
        case sumerian = "Sumerian"
        case akkadian = "Akkadian"
        case babylonian = "Babylonian"
        case assyrian = "Assyrian"
        case egyptian = "Egyptian"
        case hurrian = "Hurrian"
        case hittite = "Hittite"
        case canaanite = "Canaanite"
        case greek = "Greek"
        case hebrew = "Hebrew"
        case persian = "Persian"
        case other = "Other"
    }

    /// The type of name equivalence.
    package enum NameType: String, Codable, CaseIterable, Hashable {
        case spelling = "Alternate Spelling"
        case translation = "Translation"
        case syncretism = "Syncretism"
        case epithet = "Epithet"
        case logographic = "Logographic Reading"
    }

    package init(
        figure: Figure? = nil,
        name: String = "",
        tradition: Tradition = .sumerian,
        nameType: NameType = .spelling,
        note: String = ""
    ) {
        self.figure = figure
        self.name = name
        self.tradition = tradition
        self.nameType = nameType
        self.note = note
    }
}
