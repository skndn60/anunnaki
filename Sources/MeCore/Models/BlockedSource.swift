import Foundation
import SwiftData

@Model
package final class BlockedSource {
    package var sourceURL: String
    package var sourceTitle: String
    package var blockedAt: Date

    package init(
        sourceURL: String = "",
        sourceTitle: String = "",
        blockedAt: Date = Date()
    ) {
        self.sourceURL = sourceURL
        self.sourceTitle = sourceTitle
        self.blockedAt = blockedAt
    }
}
