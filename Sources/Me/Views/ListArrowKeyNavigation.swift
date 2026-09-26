import SwiftUI
import SwiftData

/// Restores Up/Down arrow selection for a `List(selection:)` on macOS 27, where
/// the native list stopped taking keyboard focus and stopped moving its
/// selection on arrow keys.
///
/// `.focusable()` puts the list back in the key view loop, `.focusEffectDisabled()`
/// suppresses the focus ring that made the earlier fix unacceptable, `.focused`
/// gives the list focus when it appears, and the `onKeyPress` handlers move the
/// selection explicitly through `orderedIDs` (rows in on-screen order). `ID` is
/// the row tag type — `PersistentIdentifier` for the entity lists and
/// `SidebarSelection` for the sidebar.
private struct ListArrowKeyNavigation<ID: Hashable>: ViewModifier {
    @Binding var selection: ID?
    let orderedIDs: [ID]
    @FocusState private var focused: Bool

    func body(content: Content) -> some View {
        content
            .focusable()
            .focusEffectDisabled()
            .focused($focused)
            .onAppear { focused = true }
            .onKeyPress(.upArrow) { move(by: -1) }
            .onKeyPress(.downArrow) { move(by: 1) }
    }

    private func move(by offset: Int) -> KeyPress.Result {
        guard !orderedIDs.isEmpty else { return .ignored }
        let currentIndex = selection.flatMap { orderedIDs.firstIndex(of: $0) }
        let target: Int
        if offset < 0 {
            target = currentIndex.map { max(0, $0 - 1) } ?? orderedIDs.count - 1
        } else {
            target = currentIndex.map { min(orderedIDs.count - 1, $0 + 1) } ?? 0
        }
        selection = orderedIDs[target]
        return .handled
    }
}

extension View {
    func listArrowKeyNavigation<ID: Hashable>(
        selection: Binding<ID?>,
        orderedIDs: [ID]
    ) -> some View {
        modifier(ListArrowKeyNavigation(selection: selection, orderedIDs: orderedIDs))
    }
}
