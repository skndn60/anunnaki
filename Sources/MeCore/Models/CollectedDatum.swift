import Foundation
import SwiftData

@Model
package final class CollectedDatum {
    package var content: String
    package var sourceURL: String
    package var sourceTitle: String
    package var acquiredAt: Date
    package var agent: Agent?
    package var isReviewed: Bool?

    package init(
        content: String = "",
        sourceURL: String = "",
        sourceTitle: String = "",
        acquiredAt: Date = Date(),
        agent: Agent? = nil,
        isReviewed: Bool = false
    ) {
        self.content = content
        self.sourceURL = sourceURL
        self.sourceTitle = sourceTitle
        self.acquiredAt = acquiredAt
        self.agent = agent
        self.isReviewed = isReviewed
    }
}
