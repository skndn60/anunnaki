import SwiftUI

struct PointingHandModifier: ViewModifier {
    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .onHover { inside in
                isHovered = inside
                if inside {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
    }
}

extension View {
    func pointingHand() -> some View {
        modifier(PointingHandModifier())
    }
}
