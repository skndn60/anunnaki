import SwiftUI
import SwiftData

/// Shared split-screen "compare two entities" shell. Concrete per-entity compare
/// views (FigureCompareView, PlaceCompareView, ...) supply their own `@Query`
/// data plus the search/filter, pane-detail and picker-row closures; everything
/// structural (header, swap, picker, panes, 1100×700 frame) lives here once.
struct EntityCompareView<Item: PersistentModel, Detail: View, Row: View>: View {
    @State private var leftItem: Item
    @State private var rightItem: Item?
    @State private var pickerQuery = ""
    @Environment(\.dismiss) private var dismiss

    let allItems: [Item]
    let title: String
    let promptNoun: String
    let searchPlaceholder: String
    let name: (Item) -> String
    let filter: ([Item], String) -> [Item]
    let detail: (Item) -> Detail
    let row: (Item, String) -> Row

    init(
        allItems: [Item],
        initialItem: Item,
        title: String,
        promptNoun: String,
        searchPlaceholder: String,
        name: @escaping (Item) -> String,
        filter: @escaping ([Item], String) -> [Item],
        detail: @escaping (Item) -> Detail,
        row: @escaping (Item, String) -> Row
    ) {
        self.allItems = allItems
        _leftItem = State(initialValue: initialItem)
        self.title = title
        self.promptNoun = promptNoun
        self.searchPlaceholder = searchPlaceholder
        self.name = name
        self.filter = filter
        self.detail = detail
        self.row = row
    }

    private var pickerOptions: [Item] {
        let others = allItems.filter { $0.persistentModelID != leftItem.persistentModelID }
        return filter(others, pickerQuery)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            HStack(spacing: 0) {
                detail(leftItem)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                Divider()
                rightPane
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(width: 1100, height: 700)
        .background(Color(.windowBackgroundColor))
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(rightItem.map { "\(name(leftItem)) vs \(name($0))" } ?? "\(name(leftItem)) vs \u{2026}")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                swapItems()
            } label: {
                Image(systemName: "arrow.left.and.right")
            }
            .help("Swap the two \(promptNoun)s")
            .disabled(rightItem == nil)
            Button("Close") {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var rightPane: some View {
        if let right = rightItem {
            detail(right)
        } else {
            pickerColumn
        }
    }

    private var pickerColumn: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Choose a \(promptNoun) to compare with \(name(leftItem))")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                    TextField(searchPlaceholder, text: $pickerQuery)
                        .textFieldStyle(.roundedBorder)
                }
            }
            .padding(10)

            List(pickerOptions) { item in
                Button {
                    rightItem = item
                    pickerQuery = ""
                } label: {
                    row(item, pickerQuery)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .listStyle(.plain)
        }
    }

    private func swapItems() {
        guard let right = rightItem else { return }
        rightItem = leftItem
        leftItem = right
    }
}
