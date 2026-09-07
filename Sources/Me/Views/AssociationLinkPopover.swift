import SwiftUI
import SwiftData

/// Shared shell for "search for an entity and link it" popovers
/// (PlaceLinkPopover, EventPlaceLinkPopover, EventThingLinkPopover, …).
///
/// The entity types differ across callers (place/event/thing/figure) and some
/// selections carry extra context (e.g. a matched alternate name), so the shell
/// is generic over an `Identifiable` item whose `ID` is a `PersistentIdentifier`.
/// Callers supply the candidate list (already excluding linked entities), a row
/// builder, and a footer (role picker, comments, Link/Cancel). The search field,
/// list with selection checkmark, and empty state live here once.
struct AssociationLinkPopover<Item: Identifiable, Row: View, Footer: View>: View {
    let searchPlaceholder: String
    let emptyText: String
    let items: [Item]
    let isSelected: (Item) -> Bool
    let onSelect: (Item) -> Void
    var showsSearchIcon: Bool = true
    @ViewBuilder let row: (Item) -> Row
    @ViewBuilder let footer: () -> Footer

    @Binding var searchText: String
    @Binding var isPresented: Bool

    init(
        searchPlaceholder: String,
        emptyText: String,
        items: [Item],
        isSelected: @escaping (Item) -> Bool,
        onSelect: @escaping (Item) -> Void,
        showsSearchIcon: Bool = true,
        searchText: Binding<String>,
        isPresented: Binding<Bool>,
        @ViewBuilder row: @escaping (Item) -> Row,
        @ViewBuilder footer: @escaping () -> Footer
    ) {
        self.searchPlaceholder = searchPlaceholder
        self.emptyText = emptyText
        self.items = items
        self.isSelected = isSelected
        self.onSelect = onSelect
        self.showsSearchIcon = showsSearchIcon
        self.row = row
        self.footer = footer
        _searchText = searchText
        _isPresented = isPresented
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                if showsSearchIcon {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                }
                TextField(searchPlaceholder, text: $searchText)
                    .textFieldStyle(.roundedBorder)
            }

            if items.isEmpty {
                Text(emptyText)
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 20)
            } else {
                List(items) { item in
                    Button(action: { onSelect(item) }) {
                        HStack(spacing: 10) {
                            row(item)
                            Spacer()
                            if isSelected(item) {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.plain)
            }

            Divider()

            footer()
        }
        .padding()
    }
}

/// Row contents shared by the place/event link popovers: a small colored icon
/// next to a title with an optional muted subtitle.
struct LinkCandidateRow: View {
    let icon: String
    let color: Color
    let title: String
    var subtitle: String? = nil

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.body)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }
}
