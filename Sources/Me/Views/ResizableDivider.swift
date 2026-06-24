import SwiftUI
import AppKit

/// A thin vertical divider that the user can drag to resize the detail panel width.
/// Usage: Replace `Divider()` with `ResizableDivider(width: $detailWidth).
struct ResizableDivider: View {
    @Binding var width: Double
    let range: ClosedRange<Double>
    @State private var dragStartWidth: Double = 320

    var body: some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.15))
            .frame(width: 4)
            .onHover { hovering in
                if hovering { NSCursor.resizeLeftRight.push() }
                else { NSCursor.pop() }
            }
            .gesture(
                DragGesture(minimumDistance: 5)
                    .onChanged { value in
                        width = min(max(range.lowerBound, dragStartWidth - value.translation.width), range.upperBound)
                    }
                    .onEnded { _ in
                        dragStartWidth = width
                    }
            )
    }
}
