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
            .onAppear { dragStartWidth = width }
            .onHover { hovering in
                if hovering { NSCursor.resizeLeftRight.push() }
                else { NSCursor.pop() }
            }
            .gesture(
                DragGesture(minimumDistance: 5)
                    .onChanged { value in
                        let newWidth = min(max(range.lowerBound, dragStartWidth - value.translation.width), range.upperBound)
                        withAnimation(.none) { width = newWidth }
                    }
                    .onEnded { _ in
                        dragStartWidth = width
                    }
            )
    }
}
