import Foundation
import SwiftData

package enum OllamaPrepareResult {
    case ready(modelName: String)
    case serverUnavailable
    case modelUnavailable(modelName: String)
}

package final class OllamaResolver: QueryResolver {
    private let host: String
    private let port: Int
    private let timeout: TimeInterval
    package private(set) var modelName: String

    private static let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 600
        return URLSession(configuration: config)
    }()

    /// Session used for generation (model warm-up and real queries). Model
    /// cold-load and the first token of a large-context prompt can take well past
    /// the 60s request timeout after a fresh boot, so every `/api/generate` call
    /// rides this long-timeout session — not just the warm-up.
    private static let generationSession: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 300
        config.timeoutIntervalForResource = 600
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

    package func isReachableAsync() async -> Bool {
        guard let url = URL(string: "http://\(host):\(port)/api/tags") else { return false }
        do {
            let (_, response) = try await Self.session.data(from: url)
            guard let http = response as? HTTPURLResponse else { return false }
            return (200...299).contains(http.statusCode)
        } catch {
            return false
        }
    }

    /// Ensures an Ollama server is running: probes the API, and if it is down
    /// launches the Ollama menu-bar app and polls until it answers (or times out).
    package func ensureRunning(maxWait: TimeInterval = 25) async -> Bool {
        if await isReachableAsync() { return true }
        launchOllamaApp()
        let deadline = Date().addingTimeInterval(maxWait)
        while Date() < deadline {
            try? await Task.sleep(nanoseconds: 500_000_000)
            if await isReachableAsync() { return true }
        }
        return false
    }

    private func launchOllamaApp() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-a", "Ollama"]
        try? process.run()
    }

    /// Full readiness pipeline for one answer: ensure the server is running, pick
    /// the installed model, then warm it so the model's cold-load latency is not
    /// paid inside the user's real query (which would otherwise time out).
    package func prepare() async -> OllamaPrepareResult {
        guard await ensureRunning() else { return .serverUnavailable }
        refreshModelName()
        let warmOK = await warmUpModel()
        guard warmOK else { return .modelUnavailable(modelName: modelName) }
        return .ready(modelName: modelName)
    }

    /// Re-picks the model from what Ollama actually has installed. Discovery runs
    /// before the server is booted in `init`, so it may have fallen back to the
    /// default; once reachable we re-check (still preferring llama3.1).
    private func refreshModelName() {
        if let discovered = Self.discoverModel(host: host, port: port) {
            modelName = discovered
        }
    }

    /// Sends a warm-up generation that forces Ollama to load `modelName` into
    /// memory and produce a full short answer. Runs on the long-timeout session
    /// because the first request after a cold start blocks until the model
    /// finishes loading. Asking for a real paragraph (not one word) means the
    /// model's first *sustained* generation is this warm-up — a freshly loaded
    /// model can otherwise truncate its very first real answer.
    private func warmUpModel() async -> Bool {
        guard let url = URL(string: "http://\(host):\(port)/api/generate") else { return false }

        let body: [String: Any] = [
            "model": modelName,
            "prompt": "Write a short paragraph (3-4 sentences) about the ancient Mesopotamian city of Ur and its significance.",
            "stream": false,
            "keep_alive": "10m",
            "options": ["num_predict": 120],
        ]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else { return false }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = jsonData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 300

        do {
            let (_, response) = try await Self.generationSession.data(for: request)
            guard let http = response as? HTTPURLResponse else { return false }
            return (200...299).contains(http.statusCode)
        } catch {
            return false
        }
    }

    package func resolve(query: String, modelContext: ModelContext) -> QueryResult? {
        let context = buildContext(query: query, modelContext: modelContext)
        let prompt = buildPrompt(query: query, context: context)
        guard let responseText = sendPrompt(prompt) else { return nil }
        return .answer(responseText.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    package func resolveAsync(query: String, modelContext: ModelContext) async -> QueryResult? {
        let context = buildContext(query: query, modelContext: modelContext)
        let prompt = buildPrompt(query: query, context: context)

        // After a cold start the first real generation can fail: a transport
        // timeout before the first token, or a truncated answer that stops after
        // the refusal boilerplate. Retry once — by then the model is warm and the
        // second attempt is the real answer.
        for attempt in 0..<2 {
            guard let response = await sendPromptAsync(prompt), !response.isEmpty else { continue }
            let trimmed = response.trimmingCharacters(in: .whitespacesAndNewlines)
            if response.hasPrefix("Error:") {
                if attempt == 0 { continue }
                return .answer(trimmed)
            }
            if attempt == 0 && isTruncatedAnswer(trimmed) { continue }
            return .answer(trimmed)
        }
        return nil
    }

    /// Heuristic for a first-pass truncation: a complete answer is at least a few
    /// sentences. A suspiciously short reply that stops after the boilerplate
    /// ("the database lacks relevant information") is treated as truncated.
    private func isTruncatedAnswer(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }
        if trimmed.count >= 160 { return false }
        let refusalMarkers = [
            "does not have this information",
            "doesn't have this information",
            "does not provide information",
            "doesn't provide information",
            "does not contain information",
            "doesn't contain information",
            "lacks relevant information",
            "no information",
        ]
        let lower = trimmed.lowercased()
        return refusalMarkers.contains { lower.contains($0) }
    }

    private func buildContext(query: String, modelContext: ModelContext) -> String {
        let figures = (try? modelContext.fetch(FetchDescriptor<Figure>(sortBy: [SortDescriptor(\.orderIndex)]))) ?? []
        let places = (try? modelContext.fetch(FetchDescriptor<Place>(sortBy: [SortDescriptor(\.name)]))) ?? []
        let events = (try? modelContext.fetch(FetchDescriptor<Event>(sortBy: [SortDescriptor(\.name)]))) ?? []
        let eras = (try? modelContext.fetch(FetchDescriptor<Era>(sortBy: [SortDescriptor(\.orderIndex)]))) ?? []
        let relationships = (try? modelContext.fetch(FetchDescriptor<Relationship>())) ?? []

        // Entities actually referenced by the query are included in FULL detail,
        // so the LLM always has the record(s) it is being asked about. Matching
        // uses the shared RetrievalIndex vocabulary (canonical name, alternate
        // names, sort-name overrides) so it stays consistent with QueryEngine.
        let index = RetrievalIndex(
            figures: figures,
            places: places,
            events: events,
            things: [],
            alternateNames: (try? modelContext.fetch(FetchDescriptor<AlternateName>())) ?? []
        )
        let highlightedFigures = index.figuresMentioned(in: query)
        let highlightedPlaces = index.placesMentioned(in: query)
        let highlightedEvents = index.eventsMentioned(in: query)

        let overviewFigures = figures.filter { f in !highlightedFigures.contains { $0.persistentModelID == f.persistentModelID } }
        let overviewPlaces = places.filter { p in !highlightedPlaces.contains { $0.persistentModelID == p.persistentModelID } }
        let overviewEvents = events.filter { e in !highlightedEvents.contains { $0.persistentModelID == e.persistentModelID } }

        var lines: [String] = []
        let trim: (String, Int) -> String = { $0.count > $1 ? String($0.prefix($1)) + "..." : $0 }

        if !highlightedEvents.isEmpty {
            lines.append("RELEVANT EVENTS:")
            for e in highlightedEvents {
                var parts = ["- \(e.name)"]
                if let type = e.eventType?.name { parts.append("(\(type))") }
                if e.date != .unknown { parts.append("Date: \(e.date.displayLabel)") }
                if !e.eventDescription.isEmpty { parts.append("Description: \(e.eventDescription)") }
                lines.append(parts.joined(separator: " "))
            }
        }
        if !highlightedPlaces.isEmpty {
            lines.append("RELEVANT PLACES:")
            for p in highlightedPlaces {
                var parts = ["- \(p.name)"]
                if let type = p.placeType?.name { parts.append("(\(type))") }
                if !p.placeDescription.isEmpty { parts.append("Description: \(p.placeDescription)") }
                lines.append(parts.joined(separator: " "))
            }
        }
        if !highlightedFigures.isEmpty {
            lines.append("RELEVANT FIGURES:")
            for f in highlightedFigures {
                var parts = ["- \(f.name)"]
                if let type = f.figureType?.name { parts.append("(\(type))") }
                if !f.domain.isEmpty { parts.append("domain: \(f.domain)") }
                if !f.figureDescription.isEmpty { parts.append("Description: \(f.figureDescription)") }
                let parentRels = relationships.filter { $0.toFigure?.persistentModelID == f.persistentModelID && $0.relationshipType?.category == "parent" }
                if !parentRels.isEmpty {
                    parts.append("parents: \(parentRels.compactMap { $0.fromFigure?.name }.joined(separator: ", "))")
                }
                let childRels = relationships.filter { $0.fromFigure?.persistentModelID == f.persistentModelID && $0.relationshipType?.category == "parent" }
                if !childRels.isEmpty {
                    parts.append("children: \(childRels.compactMap { $0.toFigure?.name }.joined(separator: ", "))")
                }
                if f.birthDate != .unknown { parts.append("Dates: \(f.birthDate.displayLabel)") }
                lines.append(parts.joined(separator: " "))
            }
        }

        if !highlightedFigures.isEmpty || !highlightedPlaces.isEmpty || !highlightedEvents.isEmpty {
            lines.append("---")
        }

        lines.append("FIGURES:")
        for f in overviewFigures.prefix(8) {
            var parts = ["- \(f.name)"]
            if let type = f.figureType?.name { parts.append("(\(type))") }
            if !f.domain.isEmpty { parts.append("domain: \(f.domain)") }
            if !f.figureDescription.isEmpty { parts.append(trim(f.figureDescription, 40)) }
            lines.append(parts.joined(separator: " "))
        }
        if overviewFigures.count > 8 {
            let names = overviewFigures.dropFirst(8).map { "\($0.name)(\($0.figureType?.name ?? "?"))" }.joined(separator: ", ")
            lines.append("... +\(overviewFigures.count - 8) more: \(names)")
        }

        if !overviewPlaces.isEmpty {
            lines.append("")
            lines.append("PLACES:")
            for p in overviewPlaces.prefix(8) {
                var parts = ["- \(p.name)"]
                if let type = p.placeType?.name { parts.append("(\(type))") }
                if !p.placeDescription.isEmpty { parts.append(trim(p.placeDescription, 40)) }
                lines.append(parts.joined(separator: " "))
            }
            if overviewPlaces.count > 8 {
                let names = overviewPlaces.dropFirst(8).map(\.name).joined(separator: ", ")
                lines.append("... +\(overviewPlaces.count - 8) more: \(names)")
            }
        }

        if !overviewEvents.isEmpty {
            lines.append("")
            lines.append("EVENTS:")
            for e in overviewEvents.prefix(8) {
                var parts = ["- \(e.name)"]
                if let type = e.eventType?.name { parts.append("(\(type))") }
                if !e.eventDescription.isEmpty { parts.append(trim(e.eventDescription, 40)) }
                if e.date != .unknown { parts.append("(\(e.date.displayLabel))") }
                lines.append(parts.joined(separator: " "))
            }
            if overviewEvents.count > 8 {
                let names = overviewEvents.dropFirst(8).map(\.name).joined(separator: ", ")
                lines.append("... +\(overviewEvents.count - 8) more: \(names)")
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
            "stream": true
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = jsonData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 300

        let bytes: URLSession.AsyncBytes
        let response: URLResponse
        do {
            (bytes, response) = try await Self.generationSession.bytes(for: request)
        } catch {
            return "Error: \(error.localizedDescription)"
        }
        guard let http = response as? HTTPURLResponse else { return nil }

        var errorBody = ""
        var responseText = ""
        do {
            for try await line in bytes.lines {
                guard let data = line.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
                if let chunk = json["response"] as? String {
                    responseText += chunk
                }
                if let error = json["error"] as? String, !error.isEmpty {
                    errorBody = error
                }
                if (json["done"] as? Bool) == true {
                    break
                }
            }
        } catch {
            return "Error: \(error.localizedDescription)"
        }

        if let httpError = streamError(httpStatusCode: http.statusCode, errorBody: errorBody) {
            return httpError
        }
        return responseText.isEmpty ? nil : responseText
    }

    private func streamError(httpStatusCode: Int, errorBody: String) -> String? {
        guard !(200...299).contains(httpStatusCode) else { return nil }
        let body = errorBody.isEmpty ? "HTTP \(httpStatusCode)" : errorBody
        return "Error: Ollama returned \(body)"
    }
}
