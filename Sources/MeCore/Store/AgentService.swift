import Foundation
import SwiftData

package struct CollectedJSON: Codable {
    let schema: String
    let acquiredAt: Date
    let source: SourceMeta
    let data: Payload

    package struct SourceMeta: Codable {
        let url: String
        let title: String
        let domain: String
        let type: String
    }

    package struct Payload: Codable {
        let title: String
        let extract: String
        let categories: [String]
        let wikidataId: String?
        let links: [LinkItem]
    }

    package struct LinkItem: Codable {
        let title: String
        let url: String
    }
}

package final class AgentService {
    package nonisolated static let shared = AgentService()
    package nonisolated static var container: ModelContainer?
    private var tasks: [PersistentIdentifier: Task<Void, Never>] = [:]

    private init() {}

    package func dispatchAgent(_ agent: Agent, context: ModelContext) {
        let id = agent.persistentModelID
        let parameter = agent.missionParameter
        let targetCount = agent.targetCount
        let initialCursor = agent.cursor
        let blocked = fetchBlockedURLs(context: context)

        agent.statusEnum = .running
        agent.updatedAt = Date()
        try? context.save()

        tasks[id] = Task {
            await runMission(id: id, parameter: parameter, targetCount: targetCount, cursor: initialCursor, blockedURLs: blocked)
        }
    }

    private func fetchBlockedURLs(context: ModelContext) -> Set<String> {
        let allBlocked: [BlockedSource] = context.fetchAll()
        return Set(allBlocked.map { $0.sourceURL })
    }

    package func pauseAgent(_ agent: Agent, context: ModelContext) {
        agent.statusEnum = .paused
        agent.updatedAt = Date()
        try? context.save()
    }

    package func resumeAgent(_ agent: Agent, context: ModelContext) {
        agent.statusEnum = .running
        agent.updatedAt = Date()
        try? context.save()
    }

    package func recallAgent(_ agent: Agent, context: ModelContext) {
        let id = agent.persistentModelID
        tasks[id]?.cancel()
        tasks[id] = nil
        agent.statusEnum = .idle
        agent.updatedAt = Date()
        try? context.save()
    }

    package func deleteAgent(_ agent: Agent, context: ModelContext) {
        let id = agent.persistentModelID
        tasks[id]?.cancel()
        tasks[id] = nil
        context.delete(agent)
        do {
            try context.save()
            NSLog("[AgentService] deleted agent: %@", agent.name)
        } catch {
            NSLog("[AgentService] save failed: %@", error.localizedDescription)
        }
    }

    private func runMission(id: PersistentIdentifier, parameter: String, targetCount: Int, cursor: String, blockedURLs: Set<String>) async {
        let client = WikiClient()
        var currentOffset = Int(cursor) ?? 0
        var currentCursor = cursor

        while !Task.isCancelled {
            let agentStatus = await readAgentStatus(id: id)
            if agentStatus == .paused {
                await Task.yield()
                continue
            }

            await setActivity(id: id, activity: "Searching Wikipedia\u{2026}")

            do {
                let (results, nextOffset) = try await client.search(query: parameter, offset: currentOffset)

                for result in results {
                    if Task.isCancelled { break }

                    let shouldStop = await shouldStopMission(id: id, targetCount: targetCount)
                    if shouldStop { break }

                    let encodedTitle = result.title.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? result.title
                    let wikiURL = "https://en.wikipedia.org/wiki/\(encodedTitle)"
                    if blockedURLs.contains(wikiURL) { continue }

                    try? await Task.sleep(nanoseconds: 600_000_000)
                    await setActivity(id: id, activity: "Fetching: \(result.title)")
                    let extract = (try? await client.fetchExtract(title: result.title)) ?? ""

                    let json = CollectedJSON(
                        schema: "me/agent/v1",
                        acquiredAt: Date(),
                        source: .init(
                            url: wikiURL,
                            title: result.title,
                            domain: "en.wikipedia.org",
                            type: "wikipedia"
                        ),
                        data: .init(
                            title: result.title,
                            extract: extract,
                            categories: [],
                            wikidataId: nil,
                            links: []
                        )
                    )

                    let encoder = JSONEncoder()
                    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                    let jsonData = (try? encoder.encode(json)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
                    currentCursor = String(currentOffset)

                    await saveCollectedDatum(id: id, agentCursor: currentCursor, jsonData: jsonData, wikiURL: wikiURL, title: result.title)
                }

                if let next = nextOffset {
                    currentOffset = next
                } else {
                    break
                }

                if results.isEmpty {
                    break
                }

            } catch {
                if Task.isCancelled { break }
                await failAgent(id: id)
                tasks[id] = nil
                return
            }
        }

        await completeAgent(id: id)
        tasks[id] = nil
    }

    @MainActor
    private func readAgentStatus(id: PersistentIdentifier) -> AgentStatus? {
        guard let container = Self.container else { return nil }
        let context = ModelContext(container)
        return (context.model(for: id) as? Agent)?.statusEnum
    }

    @MainActor
    private func shouldStopMission(id: PersistentIdentifier, targetCount: Int) -> Bool {
        guard let container = Self.container else { return true }
        let context = ModelContext(container)
        guard let agent = context.model(for: id) as? Agent else { return true }
        if agent.statusEnum == .paused { return true }
        if agent.collectedData.count >= targetCount { return true }
        return false
    }

    @MainActor
    private func setActivity(id: PersistentIdentifier, activity: String) {
        guard let container = Self.container else { return }
        let context = ModelContext(container)
        guard let agent = context.model(for: id) as? Agent else { return }
        agent.currentActivity = activity
        try? context.save()
    }

    @MainActor
    private func saveCollectedDatum(id: PersistentIdentifier, agentCursor: String, jsonData: String, wikiURL: String, title: String) {
        guard let container = Self.container else { return }
        let context = ModelContext(container)
        guard let agent = context.model(for: id) as? Agent else { return }
        let datum = CollectedDatum(content: jsonData, sourceURL: wikiURL, sourceTitle: title, acquiredAt: Date())
        datum.agent = agent
        context.insert(datum)
        agent.collectedData.append(datum)
        agent.cursor = agentCursor
        agent.currentActivity = ""
        agent.updatedAt = Date()
        try? context.save()
    }

    @MainActor
    private func failAgent(id: PersistentIdentifier) {
        guard let container = Self.container else { return }
        let context = ModelContext(container)
        guard let agent = context.model(for: id) as? Agent else { return }
        agent.statusEnum = .failed
        agent.updatedAt = Date()
        try? context.save()
    }

    @MainActor
    private func completeAgent(id: PersistentIdentifier) {
        guard let container = Self.container else { return }
        let context = ModelContext(container)
        guard let agent = context.model(for: id) as? Agent else { return }
        if Task.isCancelled {
            agent.statusEnum = .idle
        } else if agent.statusEnum == .running {
            agent.statusEnum = .completed
        }
        agent.updatedAt = Date()
        try? context.save()
    }
}
