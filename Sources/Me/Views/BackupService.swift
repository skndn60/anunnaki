import Foundation
import AppKit
import os

/// Snapshot-level backup and restore of the entire SwiftData store.
/// Backups are plain copies of the store's backing files; restoring happens
/// on the next launch, before the container is opened, so it is safe.
enum BackupService {

    private static let logger = Logger(subsystem: "com.me.app", category: "backup")
    /// UserDefaults key holding a pending restore source directory, consumed at next launch.
    static let pendingRestoreKey = "com.me.app.pendingRestoreDirectory"

    private static let fileName = "Me.store"
    private static let sidecarNames = ["Me.store-shm", "Me.store-wal"]

    static var storeFileURL: URL {
        storeURL() // defined in AnunnakiApp.swift
    }

    static var storeDirectory: URL {
        storeFileURL.deletingLastPathComponent()
    }

    /// Copy the store (and sidecar WAL/SHM if present) into a timestamped folder under `parent`.
    static func makeBackup(in parent: URL) throws -> URL {
        let fm = FileManager.default
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let folder = parent.appendingPathComponent("MeBackup-\(stamp)")
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)

        var copied = 0
        for name in [fileName] + sidecarNames {
            let src = storeDirectory.appendingPathComponent(name)
            guard fm.fileExists(atPath: src.path) else { continue }
            try fm.copyItem(at: src, to: folder.appendingPathComponent(name))
            copied += 1
        }
        guard copied > 0 else {
            throw BackupError.noStoreFiles
        }
        return folder
    }

    /// True if `directory` looks like a backup folder (contains a `Me.store`).
    static func isValidBackup(_ directory: URL) -> Bool {
        FileManager.default.fileExists(atPath: directory.appendingPathComponent(fileName).path)
    }

    /// Request a save panel and create a backup. Runs on the main thread (AppKit panels).
    @MainActor
    static func chooseAndBackup() async -> Result<URL, BackupError> {
        let panel = NSOpenPanel()
        panel.title = "Choose Where to Save the Backup"
        panel.prompt = "Back Up Here"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else {
            return .failure(.cancelled)
        }
        do {
            let folder = try makeBackup(in: url)
            return .success(folder)
        } catch {
            return .failure(error as? BackupError ?? .writeFailed)
        }
    }

    /// Stage a restore: record the backup directory to be applied at next launch.
    static func stageRestore(from directory: URL) {
        UserDefaults.standard.set(directory.path, forKey: pendingRestoreKey)
        logger.notice("Staged restore from \(directory.path, privacy: .public)")
    }

    /// Apply a staged restore if requested. MUST run before the ModelContainer opens
    /// (and after force-reseed logic so the two never fight). Safe to run on every launch.
    static func applyPendingRestoreIfNeeded() {
        let defaults = UserDefaults.standard
        guard let dirPath = defaults.string(forKey: pendingRestoreKey), !dirPath.isEmpty else { return }
        defaults.removeObject(forKey: pendingRestoreKey)

        let dir = URL(fileURLWithPath: dirPath, isDirectory: true)
        let fm = FileManager.default
        guard fm.fileExists(atPath: dir.appendingPathComponent(fileName).path) else {
            logger.warning("Pending restore directory has no store; ignoring: \(dir.path, privacy: .public)")
            return
        }

        // Safety: keep a copy of the current store before overwriting it.
        let backupDir = storeDirectory.appendingPathComponent("MeBackup-prestore")
        try? fm.removeItem(at: backupDir)
        if fm.fileExists(atPath: storeFileURL.path) {
            try? fm.createDirectory(at: backupDir, withIntermediateDirectories: true)
            for name in [fileName] + sidecarNames {
                let src = storeDirectory.appendingPathComponent(name)
                guard fm.fileExists(atPath: src.path) else { continue }
                try? fm.copyItem(at: src, to: backupDir.appendingPathComponent(name))
            }
        }

        // Replace current store files with those from the backup folder.
        for name in [fileName] + sidecarNames {
            let current = storeDirectory.appendingPathComponent(name)
            if fm.fileExists(atPath: current.path) { try? fm.removeItem(at: current) }
            let src = dir.appendingPathComponent(name)
            if fm.fileExists(atPath: src.path) { try? fm.copyItem(at: src, to: current) }
        }
        logger.notice("Restored store from \(dir.path, privacy: .public); pre-restore copy at \(backupDir.path, privacy: .public)")
    }
}

enum BackupError: LocalizedError {
    case cancelled
    case noStoreFiles
    case writeFailed

    var errorDescription: String? {
        switch self {
        case .cancelled: return "Cancelled."
        case .noStoreFiles: return "No database store was found to back up."
        case .writeFailed: return "The backup could not be written."
        }
    }
}