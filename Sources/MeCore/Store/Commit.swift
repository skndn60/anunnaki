import Foundation
import os
import SwiftData

/// The single place where a write to the store is committed.
///
/// A bare `try?` on a save is banned: it discards the error, so a failed write
/// leaves the in-memory context showing a change the store never got, with no
/// signal anywhere. Every save goes through here so a failure is always logged,
/// and — inside `collectFailures` — always reported to the user.
package enum Commit {
    package static let logger = Logger(subsystem: "com.me.app", category: "store")

    private static let stackLock = NSLock()
    private static var collectors: [FailureCollector] = []

    /// Commits pending changes. `what` names the operation for the log line and
    /// for the startup report; prefer the enclosing function's name.
    @discardableResult
    package static func save(_ context: ModelContext, _ what: String) -> Bool {
        do {
            try context.save()
            return true
        } catch {
            logger.error("Save failed [\(what, privacy: .public)]: \(error, privacy: .public)")
            stackLock.lock()
            collectors.last?.record(what)
            stackLock.unlock()
            return false
        }
    }

    /// Runs `body` with failure collection active and returns the distinct
    /// operations whose save failed, in first-failure order. Saves made outside
    /// a `collectFailures` scope are logged only — they are user-initiated and
    /// individually reproducible, so there is nothing to report at startup.
    package static func collectFailures(_ body: () -> Void) -> [String] {
        let collector = FailureCollector()
        stackLock.lock()
        collectors.append(collector)
        stackLock.unlock()
        defer {
            stackLock.lock()
            if !collectors.isEmpty { collectors.removeLast() }
            stackLock.unlock()
        }
        body()
        return collector.names
    }
}

private final class FailureCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var seen: [String] = []

    func record(_ name: String) {
        lock.lock()
        defer { lock.unlock() }
        if !seen.contains(name) { seen.append(name) }
    }

    var names: [String] {
        lock.lock()
        defer { lock.unlock() }
        return seen
    }
}
