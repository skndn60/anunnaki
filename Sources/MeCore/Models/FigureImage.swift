import Foundation
import SwiftData

@Model
package final class ImageAsset {
    package var figures: [Figure] = []
    package var places: [Place] = []
    package var events: [Event] = []
    package var things: [Thing] = []
    package var filename: String
    package var caption: String
    package var source: String
    package var imageDescription: String = ""

    @Relationship(deleteRule: .nullify, inverse: \Tag.images)
    package var tags: [Tag] = []

    package init(
        figures: [Figure] = [],
        places: [Place] = [],
        events: [Event] = [],
        things: [Thing] = [],
        filename: String = "",
        caption: String = "",
        source: String = "",
        imageDescription: String = ""
    ) {
        self.figures = figures
        self.places = places
        self.events = events
        self.things = things
        self.filename = filename
        self.caption = caption
        self.source = source
        self.imageDescription = imageDescription
        self.tags = []
    }

    package var fileURL: URL? {
        guard !filename.isEmpty else { return nil }
        return Self.imagesDirectory.appendingPathComponent(filename)
    }

    package static var imagesDirectory: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Me", isDirectory: true)
            .appendingPathComponent("Images", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}
