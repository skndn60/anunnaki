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

    /// Comparison-table cells citing this source. Set links via this side
    /// (the annotated inverse) per the codebase convention.
    @Relationship(deleteRule: .nullify, inverse: \PopupTableCell.sourceRef)
    package var popupTableCells: [PopupTableCell] = []

    /// Comparison-table cell attributions (many-to-many) linking to this Source.
    /// Set links via this annotated side per the codebase convention.
    @Relationship(deleteRule: .nullify, inverse: \CellSource.sourceRef)
    package var cellListSources: [CellSource] = []

    /// Comparison tables whose content is attributed to this source. Set links
    /// via this side (the annotated inverse) per the codebase convention.
    @Relationship(deleteRule: .nullify, inverse: \PopupTable.sourceRef)
    package var popupTables: [PopupTable] = []

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

    /// Finds the `Source` row that best matches a free-text citation name.
    /// Matches exactly (normalized: case/hyphen/space/punctuation-insensitive)
    /// first, then by containment so "An=Anum" links to "Lexical God List
    /// An = Anum (Tablet IV)". Among containment matches the shortest (most
    /// specific) name wins, and the candidate must be at least 3 characters so
    /// shared single words don't create spurious links.
    package static func bestMatch(forCandidate candidate: String, among sources: [Source]) -> Source? {
        let candidateKey = NameDuplicateCheck.normalizedKey(candidate)
        guard !candidateKey.isEmpty else { return nil }

        if let exact = sources.first(where: { NameDuplicateCheck.normalizedKey($0.name) == candidateKey }) {
            return exact
        }

        let contained = sources.filter { source in
            let sk = NameDuplicateCheck.normalizedKey(source.name)
            guard sk != candidateKey, candidateKey.count >= 3 else { return false }
            return sk.contains(candidateKey) || candidateKey.contains(sk)
        }.sorted { $0.name.count < $1.name.count }
        return contained.first
    }
}
