import Foundation
import SwiftData

@Model
package final class DictionaryEntry {
    package var english: String
    package var sumerian: String
    package var entryDescription: String
    package var cuneiform: String?
    package var partOfSpeech: String?
    package var pronunciation: String?
    package var alternateEnglish: [String]?

    package init(
        english: String = "",
        sumerian: String = "",
        entryDescription: String = "",
        cuneiform: String? = nil,
        partOfSpeech: String? = nil,
        pronunciation: String? = nil,
        alternateEnglish: [String]? = nil
    ) {
        self.english = english
        self.sumerian = sumerian
        self.entryDescription = entryDescription
        self.cuneiform = cuneiform
        self.partOfSpeech = partOfSpeech
        self.pronunciation = pronunciation
        self.alternateEnglish = alternateEnglish
    }
}
