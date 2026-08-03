import Foundation

/// Append-only JSON log of every "Add from Text" operation, stored next to the database
/// so adds can be reverted from the history panel even after the app has been quit.
enum FromTextLog {

    private static let fileName = "from_text_log.json"
    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    private static var fileURL: URL {
        BackupService.storeDirectory.appendingPathComponent(fileName)
    }

    static func load() -> [FromTextApplyRecord] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        return (try? decoder.decode([FromTextApplyRecord].self, from: data)) ?? []
    }

    private static func save(_ records: [FromTextApplyRecord]) {
        do {
            let data = try encoder.encode(records)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            // The log is best-effort; failing to persist must never block an add.
        }
    }

    static func append(_ record: FromTextApplyRecord) {
        var records = load()
        records.removeAll { $0.id == record.id }
        records.append(record)
        save(records)
    }

    static func markReverted(id: UUID) {
        var records = load()
        guard let index = records.firstIndex(where: { $0.id == id }) else { return }
        records[index].revertedAt = Date()
        save(records)
    }
}
