import Foundation
import SwiftData

extension Migration {
    package static func ensureTimelineDefaults(context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<Timeline>())) ?? []
        guard existing.isEmpty else { return }
    }
}