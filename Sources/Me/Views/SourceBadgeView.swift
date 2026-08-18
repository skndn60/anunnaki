import SwiftUI

/// A small book-icon capsule labelling the text a claim is attested by.
/// Clicking opens the source URL when one is available.
struct SourceBadgeView: View {
    let name: String
    var url: String?

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "book.closed")
                .font(.system(size: 8))
            Text(name)
                .font(.caption2)
                .lineLimit(1)
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 5)
        .padding(.vertical, 1)
        .background(Capsule().fill(Color.secondary.opacity(0.12)))
        .contentShape(Capsule())
        .onTapGesture {
            if let url, let nsURL = URL(string: url) {
                NSWorkspace.shared.open(nsURL)
            }
        }
        .help(url ?? name)
    }
}
