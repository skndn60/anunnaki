import SwiftUI

/// A small icon-only button that fades in on hover. Clean and minimal.
struct IconActionButton: View {
    let icon: String
    let color: Color
    var isVisible: Bool = true
    var help: String? = nil
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isHovered ? color : color.opacity(0.5))
                .frame(width: 24, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(color.opacity(isHovered ? 0.12 : 0))
                )
        }
        .buttonStyle(.plain)
        .opacity(isVisible ? 1 : 0.3)
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .pointingHand()
        .help(help ?? "")
    }
}
