import Foundation
import CoreGraphics

/// A normalized crop rectangle (0...1 relative to the full image) stored as the
/// compact string `"x,y,w,h"`. A mugshot is rendered by cropping the *original*
/// statue photo with this rect on the fly — the source file is never duplicated.
package struct ImageCropRect: Equatable {
    package var x: Double
    package var y: Double
    package var width: Double
    package var height: Double

    package init(x: Double, y: Double, width: Double, height: Double) {
        self.x = Self.clamp(x)
        self.y = Self.clamp(y)
        self.width = max(0, min(1 - Self.clamp(x), width))
        self.height = max(0, min(1 - Self.clamp(y), height))
    }

    package init?(encoded: String?) {
        guard let encoded, !encoded.isEmpty else { return nil }
        let parts = encoded.split(separator: ",").compactMap { Double($0) }
        guard parts.count == 4 else { return nil }
        self.init(x: parts[0], y: parts[1], width: parts[2], height: parts[3])
    }

    package func encoded() -> String {
        let rounded = [x, y, width, height].map { String(format: "%.4f", $0) }
        return rounded.joined(separator: ",")
    }

    package var cgRect: CGRect {
        CGRect(x: x, y: y, width: width, height: height)
    }

    package static let full = ImageCropRect(x: 0, y: 0, width: 1, height: 1)

    private static func clamp(_ value: Double) -> Double {
        max(0, min(1, value))
    }
}
