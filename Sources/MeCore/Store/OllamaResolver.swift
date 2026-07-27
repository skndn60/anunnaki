import Foundation
import SwiftData

package final class OllamaResolver: QueryResolver {
    private let host: String
    private let port: Int
    private let timeout: TimeInterval
    package let modelName: String

    private static let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 120
        return URLSession(configuration: config)
    }()

    package init(host: String = "localhost", port: Int = 11434, model: String? = nil, timeout: TimeInterval = 60) {
        self.host = host
        self.port = port
        self.timeout = timeout
        if let model {
            self.modelName = model
        } else {
            self.modelName = Self.discoverModel(host: host, port: port) ?? "llama3.1:latest"
        }
    }

    private static func discoverModel(host: String, port: Int) -> String? {
        guard let url = URL(string: "http://\(host):\(port)/api/tags") else { return nil }
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let models = json["models"] as? [[String: Any]] else { return nil }

        let names = models.compactMap { $0["name"] as? String }

        let preferred = ["llama3.1", "llama3", "gemma4", "mistral", "phi3", "qwen2.5"]
        for prefix in preferred {
            if let match = names.first(where: { $0.hasPrefix(prefix) }) {
                return match
            }
        }
        return names.first
    }

    package func isReachable() -> Bool {
        guard let url = URL(string: "http://\(host):\(port)/api/tags") else { return false }
        return (try? Data(contentsOf: url)) != nil
    }

    package func resolve(query: String, modelContext: ModelContext) -> QueryResult? {
        let context = buildContext(modelContext: modelContext)
        let prompt = buildPrompt(query: query, context: context)
        guard let responseText = sendPrompt(prompt) else { return nil }
        return .answer(responseText.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    package func resolveAsync(query: String, modelContext: ModelContext) async -> QueryResult? {
        let context = buildContext(modelContext: modelContext)
        let prompt = buildPrompt(query: query, context: context)
        guard let responseText = await sendPromptAsync(prompt) else { return nil }
        return .answer(responseText.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private func buildContext(modelContext: ModelContext) -> String {
        let figures = (try? modelContext.fetch(FetchDescriptor<Figure>(sortBy: [SortDescriptor(\.orderIndex)]))) ?? []
        let places = (try? modelContext.fetch(FetchDescriptor<Place>(sortBy: [SortDescriptor(\.name)]))) ?? []
        let events = (try? modelContext.fetch(FetchDescriptor<Event>(sortBy: [SortDescriptor(\.name)]))) ?? []
        let eras = (try? modelContext.fetch(FetchDescriptor<Era>(sortBy: [SortDescriptor(\.orderIndex)]))) ?? []
        let relationships = (try? modelContext.fetch(FetchDescriptor<Relationship>())) ?? []

        var lines: [String] = []
        let trim: (String, Int) -> String = { $0.count > $1 ? String($0.prefix($1)) + "..." : $0 }

        lines.append("FIGURES:")
        for f in figures.prefix(8) {
            var parts = ["- \(f.name)"]
            if let type = f.figureType?.name { parts.append("(\(type))") }
            if !f.domain.isEmpty { parts.append("domain: \(f.domain)") }
            if !f.figureDescription.isEmpty { parts.append(trim(f.figureDescription, 40)) }
            let parentRels = relationships.filter { $0.toFigure?.persistentModelID == f.persistentModelID && $0.relationshipType?.category == "parent" }
            if !parentRels.isEmpty {
                parts.append("parents: \(parentRels.compactMap { $0.fromFigure?.name }.joined(separator: ", "))")
            }
            let childRels = relationships.filter { $0.fromFigure?.persistentModelID == f.persistentModelID && $0.relationshipType?.category == "parent" }
            if !childRels.isEmpty {
                parts.append("children: \(childRels.compactMap { $0.toFigure?.name }.joined(separator: ", "))")
            }
            lines.append(parts.joined(separator: " "))
        }
        if figures.count > 8 {
            let names = figures.dropFirst(8).compactMap { $0.figureType?.name }.map { "\($0)" }.isEmpty
                ? figures.dropFirst(8).map { $0.name }.joined(separator: ", ")
                : figures.dropFirst(8).map { "\($0.name)(\($0.figureType?.name ?? "?"))" }.joined(separator: ", ")
            lines.append("... +\(figures.count - 8) more: \(names)")
        }

        if !places.isEmpty {
            lines.append("")
            lines.append("PLACES:")
            for p in places.prefix(8) {
                var parts = ["- \(p.name)"]
                if let type = p.placeType?.name { parts.append("(\(type))") }
                if !p.placeDescription.isEmpty { parts.append(trim(p.placeDescription, 40)) }
                lines.append(parts.joined(separator: " "))
            }
            if places.count > 8 {
                let names = places.dropFirst(8).map(\.name).joined(separator: ", ")
                lines.append("... +\(places.count - 8) more: \(names)")
            }
        }

        if !events.isEmpty {
            lines.append("")
            lines.append("EVENTS:")
            for e in events.prefix(8) {
                var parts = ["- \(e.name)"]
                if let type = e.eventType?.name { parts.append("(\(type))") }
                if !e.eventDescription.isEmpty { parts.append(trim(e.eventDescription, 40)) }
                if e.date != .unknown { parts.append("(\(e.date.displayLabel))") }
                lines.append(parts.joined(separator: " "))
            }
            if events.count > 8 {
                let names = events.dropFirst(8).map(\.name).joined(separator: ", ")
                lines.append("... +\(events.count - 8) more: \(names)")
            }
        }

        if !eras.isEmpty {
            lines.append("")
            lines.append("ERAS:")
            for e in eras {
                var parts = ["- \(e.name)"]
                if e.startDate != .unknown { parts.append("(\(e.startDate.displayLabel))") }
                if e.endDate != .unknown { parts.append("→ \(e.endDate.displayLabel)") }
                lines.append(parts.joined(separator: " "))
            }
        }

        return lines.joined(separator: "\n")
    }

    private func buildPrompt(query: String, context: String) -> String {
        """
        You are a knowledgeable assistant about Mesopotamian and Sumerian mythology. \
        Below is the complete database content — use it as your primary source of truth:

        \(context)

        User query: \(query)

        Answer using the database data above. Prefer facts from the database over \
        your general knowledge. If the database lacks relevant information, say so and \
        note that your answer comes from general knowledge.
        """
    }

    private func sendPrompt(_ prompt: String) -> String? {
        guard let url = URL(string: "http://\(host):\(port)/api/generate") else { return nil }

        let body: [String: Any] = [
            "model": modelName,
            "prompt": prompt,
            "stream": false
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = jsonData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = timeout

        var result: (Data?, URLResponse?, Error?)?
        let semaphore = DispatchSemaphore(value: 0)

        let task = Self.session.dataTask(with: request) { data, response, error in
            result = (data, response, error)
            semaphore.signal()
        }
        task.resume()
        _ = semaphore.wait(timeout: .now() + timeout)
        task.cancel()

        if let error = result?.2 { return "Error: \(error.localizedDescription)" }
        guard let data = result?.0, let httpResponse = result?.1 as? HTTPURLResponse else {
            return nil
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let body = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]).flatMap { $0["error"] as? String } ?? "HTTP \(httpResponse.statusCode)"
            return "Error: Ollama returned \(body)"
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let responseText = json["response"] as? String else {
            return nil
        }

        return responseText
    }

    private func sendPromptAsync(_ prompt: String) async -> String? {
        guard let url = URL(string: "http://\(host):\(port)/api/generate") else { return nil }

        let body: [String: Any] = [
            "model": modelName,
            "prompt": prompt,
            "stream": false
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = jsonData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = timeout

        let (data, response, error) = await withCheckedContinuation { (continuation: CheckedContinuation<(Data?, URLResponse?, Error?), Never>) in
            Self.session.dataTask(with: request) { data, response, error in
                continuation.resume(returning: (data, response, error))
            }.resume()
        }

        if let error { return "Error: \(error.localizedDescription)" }
        guard let data, let httpResponse = response as? HTTPURLResponse else {
            return nil
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let body = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]).flatMap { $0["error"] as? String } ?? "HTTP \(httpResponse.statusCode)"
            return "Error: Ollama returned \(body)"
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let responseText = json["response"] as? String else {
            return nil
        }

        return responseText
    }
}
