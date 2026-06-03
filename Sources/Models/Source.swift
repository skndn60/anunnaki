import Foundation
import SwiftData

/// A reference source — an ancient text, modern translation, archaeological report, or scholarly work.
@Model
final class Source {
    var name: String
    var sourceType: SourceType
    var author: String // original author or modern translator/editor
    var language: String // e.g. "Sumerian", "Akkadian", "English translation"
    var period: String // e.g. "Old Babylonian", "Neo-Assyrian", "Modern"
    var sourceDescription: String
    var publicationInfo: String // e.g. "British Museum tablet BM 36322" or "Oxford University Press, 1989"
    var url: String // link to online resource if available

    @Relationship(deleteRule: .cascade, inverse: \Citation.source)
    var citations: [Citation] = []

    @Relationship(deleteRule: .cascade, inverse: \Attachment.source)
    var attachments: [Attachment] = []

    enum SourceType: String, Codable, CaseIterable, Hashable {
        case ancientText = "Ancient Text"
        case tablet = "Tablet"
        case inscription = "Inscription"
        case sealCylinder = "Seal/Cylinder"
        case modernTranslation = "Modern Translation"
        case scholarlyWork = "Scholarly Work"
        case kingList = "King List"
        case hymn = "Hymn/Prayer"
        case other = "Other"
    }

    init(
        name: String = "",
        sourceType: SourceType = .ancientText,
        author: String = "",
        language: String = "",
        period: String = "",
        sourceDescription: String = "",
        publicationInfo: String = "",
        url: String = ""
    ) {
        self.name = name
        self.sourceType = sourceType
        self.author = author
        self.language = language
        self.period = period
        self.sourceDescription = sourceDescription
        self.publicationInfo = publicationInfo
        self.url = url
    }
}
