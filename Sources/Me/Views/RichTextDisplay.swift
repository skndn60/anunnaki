import SwiftUI
import AppKit

struct RichTextDisplay: View {
    let richData: Data?
    let fallback: String
    var stripForegroundColor: Bool = false

    var body: some View {
        if let data = richData,
           let nsAttributedString = try? NSAttributedString(
            data: data,
            options: [.documentType: NSAttributedString.DocumentType.rtf],
            documentAttributes: nil
           ) {
            Text(AttributedString(cleaned(nsAttributedString)))
        } else if !fallback.isEmpty {
            Text(fallback)
        }
    }

    private func cleaned(_ attributedString: NSAttributedString) -> NSAttributedString {
        let mutable = NSMutableAttributedString(attributedString: attributedString)
        let range = NSRange(location: 0, length: mutable.length)
        mutable.removeAttribute(.backgroundColor, range: range)
        if stripForegroundColor {
            mutable.removeAttribute(.foregroundColor, range: range)
        }
        return mutable
    }
}
