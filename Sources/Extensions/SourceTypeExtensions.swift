import SwiftUI

extension Source.SourceType {
    var color: Color {
        return .brown
    }

    var icon: String {
        switch self {
        case .ancientText: return "scroll"
        case .tablet: return "rectangle.portrait"
        case .inscription: return "text.alignleft"
        case .sealCylinder: return "cylinder"
        case .modernTranslation: return "book"
        case .scholarlyWork: return "graduationcap"
        case .kingList: return "list.number"
        case .hymn: return "music.note"
        case .other: return "doc"
        }
    }
}

extension Attachment.AttachmentType {
    var icon: String {
        switch self {
        case .onlineText: return "doc.text"
        case .translation: return "character.book.closed"
        case .image: return "photo"
        case .pdf: return "doc.richtext"
        case .video: return "play.rectangle"
        case .database: return "cylinder"
        case .article: return "newspaper"
        case .other: return "link"
        }
    }
}
