import SwiftUI

/// Shared "alternative" picker: a `+N` accent capsule button that presents a
/// popover listing alternative items and reports the selection through
/// `onSelect`.
///
/// This component owns only popover presentation + selection state. Row
/// rendering (symbols, source badges, per-row background tint) and the action
/// taken on selection stay with the caller, so the same selector serves
/// alternative couples, alternative figures, and any other alternatives pick.
struct AltSelector<Item: Identifiable, Row: View>: View {
    let title: String
    let items: [Item]
    let minWidth: CGFloat
    let helpText: String
    @ViewBuilder let row: (Item) -> Row
    let onSelect: (Item) -> Void

    @State private var showingPopover = false

    init(
        title: String,
        items: [Item],
        minWidth: CGFloat = 160,
        helpText: String,
        onSelect: @escaping (Item) -> Void,
        @ViewBuilder row: @escaping (Item) -> Row
    ) {
        self.title = title
        self.items = items
        self.minWidth = minWidth
        self.helpText = helpText
        self.onSelect = onSelect
        self.row = row
    }

    var body: some View {
        Button(action: { showingPopover = true }) {
            Text("+\(items.count)")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color.accentColor))
        }
        .buttonStyle(.plain)
        .help(helpText)
        .popover(isPresented: $showingPopover) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.caption.bold())
                    .padding(.bottom, 2)
                ForEach(items) { item in
                    Button(action: {
                        showingPopover = false
                        onSelect(item)
                    }) {
                        row(item)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
            .frame(minWidth: minWidth, minHeight: 40)
        }
    }
}