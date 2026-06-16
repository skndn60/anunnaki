import Foundation
import SwiftData

/// An image attached to a figure — depictions from ancient art, seal cylinders, reliefs, etc.
@Model
package final class FigureImage {
    package var figure: Figure?
    package var filename: String // stored filename in the app's images directory
    package var caption: String
    package var source: String // e.g. "British Museum, BM 124531"

    package init(
        figure: Figure? = nil,
        filename: String = "",
        caption: String = "",
        source: String = ""
    ) {
        self.figure = figure
        self.filename = filename
        self.caption = caption
        self.source = source
    }

    /// Full URL to the stored image file.
    package var fileURL: URL? {
        guard !filename.isEmpty else { return nil }
        return Self.imagesDirectory.appendingPathComponent(filename)
    }

    /// Directory where figure images are stored.
    package static var imagesDirectory: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Me", isDirectory: true)
            .appendingPathComponent("Images", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}
