import SwiftUI

extension View {
    func alternatingRowBackground(index: Int) -> some View {
        background(index.isMultiple(of: 2) ? Color.clear : Color(nsColor: .alternatingContentBackgroundColors[1]))
    }
}