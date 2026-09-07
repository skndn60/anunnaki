import SwiftUI

struct BookmarkButtonView: View {
    let bookmark: Bookmark
    let onNavigate: () -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 2) {
            Button(action: onNavigate) {
                Image(systemName: bookmark.buttonIcon)
            }
            Menu {
                Button("Open \(bookmark.name)", action: onNavigate)
                Divider()
                Button("Remove Bookmark", role: .destructive, action: onRemove)
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .semibold))
            }
            .menuIndicator(.hidden)
        }
        .fixedSize()
        .help(bookmark.name)
    }
}
