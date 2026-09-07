import SwiftUI

/// Standard "Divider + uppercase caption + content" block used across the
/// detail views. Place/Event/Figure/Thing each repeated this shell (caption
/// styling, spacing) inline; the wrapper centralises the skeleton so a section
/// is just its title, an optional header accessory (e.g. an add/link button),
/// and its content rows.
struct DetailSection<Content: View, Accessory: View>: View {
    let title: String
    let content: Content
    let accessory: Accessory

    init(title: String, @ViewBuilder content: () -> Content) where Accessory == EmptyView {
        self.title = title
        self.content = content()
        self.accessory = EmptyView()
    }

    init(title: String, @ViewBuilder accessory: () -> Accessory, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
        self.accessory = accessory()
    }

    var body: some View {
        Divider()
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
                accessory
            }
            content
        }
    }
}
