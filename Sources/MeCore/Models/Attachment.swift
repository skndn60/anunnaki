import Foundation
import SwiftData

/// A reference link or resource attached to a source — URLs to online texts,
/// images of tablets, PDFs, scholarly articles, etc.
@Model
package final class Attachment {
    package var source: Source?
    package var title: String
    package var url: String
    package var attachmentType: AttachmentType
    package var note: String?

    package enum AttachmentType: String, Codable, CaseIterable, Hashable {
        case onlineText = "Online Text"
        case translation = "Translation"
        case image = "Image/Photo"
        case pdf = "PDF"
        case video = "Video"
        case database = "Database Entry"
        case article = "Article"
        case other = "Other"
    }

    package init(
        source: Source? = nil,
        title: String = "",
        url: String = "",
        attachmentType: AttachmentType = .onlineText,
        note: String? = nil
    ) {
        self.source = source
        self.title = title
        self.url = url
        self.attachmentType = attachmentType
        self.note = note
    }
}
