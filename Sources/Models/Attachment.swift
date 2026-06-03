import Foundation
import SwiftData

/// A reference link or resource attached to a source — URLs to online texts,
/// images of tablets, PDFs, scholarly articles, etc.
@Model
final class Attachment {
    var source: Source?
    var title: String
    var url: String
    var attachmentType: AttachmentType
    var note: String?

    enum AttachmentType: String, Codable, CaseIterable, Hashable {
        case onlineText = "Online Text"
        case translation = "Translation"
        case image = "Image/Photo"
        case pdf = "PDF"
        case video = "Video"
        case database = "Database Entry"
        case article = "Article"
        case other = "Other"
    }

    init(
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
