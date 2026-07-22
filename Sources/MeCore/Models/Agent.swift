import Foundation
import SwiftData

@Model
package final class Agent {
    package var name: String
    package var missionParameter: String
    package var status: String
    package var createdAt: Date
    package var updatedAt: Date
    package var currentPhase: Int
    package var cursor: String
    package var targetCount: Int
    package var currentActivity: String = ""

    @Relationship(deleteRule: .cascade, inverse: \CollectedDatum.agent)
    package var collectedData: [CollectedDatum] = []

    @Relationship(deleteRule: .cascade, inverse: \BlindSpot.agent)
    package var blindSpots: [BlindSpot] = []

    package var statusEnum: AgentStatus {
        get { AgentStatus(rawValue: status) ?? .idle }
        set { status = newValue.rawValue }
    }

    package init(
        name: String = "",
        missionParameter: String = "",
        status: AgentStatus = .idle,
        phase: Int = 1,
        cursor: String = "",
        targetCount: Int = 10
    ) {
        self.name = name
        self.missionParameter = missionParameter
        self.status = status.rawValue
        self.createdAt = Date()
        self.updatedAt = Date()
        self.currentPhase = phase
        self.cursor = cursor
        self.targetCount = targetCount
        self.currentActivity = ""
    }
}

package enum AgentStatus: String, Codable, CaseIterable {
    case idle = "Idle"
    case running = "Running"
    case paused = "Paused"
    case completed = "Completed"
    case failed = "Failed"
}
