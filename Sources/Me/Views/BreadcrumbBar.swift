import SwiftUI
import SwiftData

struct Breadcrumb: Identifiable {
    let id: PersistentIdentifier
    let name: String
    let icon: String
}

/// Reusable breadcrumb trail bar styled like a Finder path strip.
struct BreadcrumbBar: View {
    let breadcrumbs: [Breadcrumb]
    let onNavigate: (Int) -> Void
    let onClear: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            ScrollView(.horizontal) {
                HStack(spacing: 4) {
                    ForEach(Array(breadcrumbs.enumerated()), id: \.offset) { index, crumb in
                        if index > 0 {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9))
                                .foregroundStyle(.tertiary)
                        }
                        Button(action: { onNavigate(index) }) {
                            HStack(spacing: 4) {
                                Image(systemName: crumb.icon)
                                    .font(.system(size: 10))
                                    .foregroundStyle(crumb.icon == "person.3" ? Color.accentColor : .secondary)
                                Text(crumb.name)
                                    .font(.subheadline)
                                    .foregroundStyle(index == breadcrumbs.count - 1 ? Color.primary : Color.accentColor)
                                    .fontWeight(index == breadcrumbs.count - 1 ? .semibold : .regular)
                            }
                        }
                        .buttonStyle(.plain)
                        .pointingHand()
                    }
                    Spacer()
                    Button(action: onClear) {
                        Image(systemName: "xmark.circle")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                    .pointingHand()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
            }
            .background(Color(.controlBackgroundColor))
            Divider()
        }
    }
}
