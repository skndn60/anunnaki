import SwiftUI
import SwiftData

/// Reusable breadcrumb trail bar.
struct BreadcrumbBar: View {
    let breadcrumbs: [(id: PersistentIdentifier, name: String)]
    let onNavigate: (Int) -> Void
    let onClear: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(Array(breadcrumbs.enumerated()), id: \.offset) { index, crumb in
                    if index > 0 {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 8))
                            .foregroundStyle(.tertiary)
                    }
                    Button(action: { onNavigate(index) }) {
                        Text(crumb.name)
                            .font(.caption)
                            .foregroundStyle(index == breadcrumbs.count - 1 ? Color.primary : Color.accentColor)
                            .fontWeight(index == breadcrumbs.count - 1 ? .semibold : .regular)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
                Button(action: onClear) {
                    Image(systemName: "xmark.circle")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
            .padding(.vertical, 4)
        }
        .background(Color.secondary.opacity(0.04))
    }
}
