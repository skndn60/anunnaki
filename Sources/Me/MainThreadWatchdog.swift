import Foundation

final class MainThreadWatchdog: @unchecked Sendable {
    static let shared = MainThreadWatchdog()

    private let lock = NSLock()
    private var lastHeartbeat = Date()
    private var heartbeats = 0
    private var lastCapture = Date.distantPast
    private var task: Task<Void, Never>?

    private let pingInterval: UInt64 = 1_000_000_000
    private let stallThreshold: TimeInterval = 3
    private let captureCooldown: TimeInterval = 300

    func start() {
        guard task == nil else { return }
        task = Task.detached(priority: .utility) { [weak self] in
            await self?.run()
        }
    }

    private func run() async {
        while !Task.isCancelled {
            DispatchQueue.main.async { [weak self] in
                self?.respondedToPing()
            }
            try? await Task.sleep(nanoseconds: pingInterval)
            checkStall()
        }
    }

    private func respondedToPing() {
        lock.lock()
        lastHeartbeat = Date()
        heartbeats += 1
        lock.unlock()
    }

    private func checkStall() {
        lock.lock()
        let gap = Date().timeIntervalSince(lastHeartbeat)
        let beatCount = heartbeats
        let cooldownRemaining = captureCooldown - Date().timeIntervalSince(lastCapture)
        lock.unlock()

        guard beatCount >= 3 else { return }
        guard gap > stallThreshold else { return }
        guard cooldownRemaining <= 0 else { return }

        lock.lock()
        lastCapture = Date()
        lock.unlock()

        captureSample()
    }

    private func captureSample() {
        let base = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Logs")
            .appendingPathComponent("DiagnosticReports")
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        let stamp = formatter.string(from: Date())
        let fileURL = base.appendingPathComponent("Me_hang_\(stamp).spin")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sample")
        process.arguments = [String(ProcessInfo.processInfo.processIdentifier), "5", "-file", fileURL.path]
        process.terminationHandler = { _ in
            NSLog("[MainThreadWatchdog] wrote hang report to %@", fileURL.path)
        }
        try? process.run()
        process.waitUntilExit()
    }
}