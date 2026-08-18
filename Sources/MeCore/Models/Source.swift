import Foundation
import SwiftData

/// A reference source — an ancient text, modern translation, archaeological report, or scholarly work.
@Model
package final class Source {
    package var name: String
    package var sourceType: SourceType
    package var author: String // original author or modern translator/editor
    package var language: String // e.g. "Sumerian", "Akkadian", "English translation"
    package var period: String // e.g. "Old Babylonian", "Neo-Assyrian", "Modern"
    package var sourceDescription: String
    package var publicationInfo: String // e.g. "British Museum tablet BM 36322" or "Oxford University Press, 1989"
    package var url: String // link to online resource if available

    @Relationship(deleteRule: .cascade, inverse: \Citation.source)
    package var citations: [Citation] = []

    @Relationship(deleteRule: .cascade, inverse: \Attachment.source)
    package var attachments: [Attachment] = []

    /// Lineage/other relationships attested by this source. Set links via
    /// this side (the annotated inverse) per the codebase convention.
    @Relationship(deleteRule: .nullify, inverse: \Relationship.sourceRef)
    package var relationships: [Relationship] = []

    package enum SourceType: String, Codable, CaseIterable, Hashable {
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

    package init(
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
