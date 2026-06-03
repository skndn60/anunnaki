import Foundation
import SwiftData

/// An image attached to a figure — depictions from ancient art, seal cylinders, reliefs, etc.
@Model
final class FigureImage {
    var figure: Figure?
    var filename: String // stored filename in the app's images directory
    var caption: String
    var source: String // e.g. "British Museum, BM 124531"

    init(
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
    var fileURL: URL? {
        guard !filename.isEmpty else { return nil }
        return Self.imagesDirectory.appendingPathComponent(filename)
    }

    /// Directory where figure images are stored.
    static var imagesDirectory: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Me", isDirectory: true)
            .appendingPathComponent("Images", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}
