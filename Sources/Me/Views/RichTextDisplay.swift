import SwiftUI
import AppKit

struct RichTextDisplay: View {
    let richData: Data?
    let fallback: String

    var body: some View {
        if let data = richData,
           let nsAttributedString = try? NSAttributedString(
            data: data,
            options: [.documentType: NSAttributedString.DocumentType.rtf],
            documentAttributes: nil
           ) {
            Text(AttributedString(nsAttributedString))
        } else if !fallback.isEmpty {
            Text(fallback)
        }
    }
}
