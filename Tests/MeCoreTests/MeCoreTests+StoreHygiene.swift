import XCTest
import SwiftData
@testable import MeCore

extension MeCoreTests {
    // MARK: - Store hygiene: no unchecked saves

    /// Tripwire #1 in `docs/QUALITY_RISKS.md`. A `try?` on a save discards the
    /// error, so a failed write leaves the in-memory context showing a change
    /// the store never received. Every save must go through `Commit.save`.
    /// The 409 `try?` sites on `fetch` are deliberately not covered: `?? []`
    /// degradation there is correct.
    func testNoUncheckedTrySaveInSources() throws {
        let root = try Self.repositoryRoot()
        let banned = try NSRegularExpression(
            pattern: "try\\?\\s*[A-Za-z_][A-Za-z0-9_.]*\\s*\\.\\s*save\\s*\\(\\s*\\)"
        )
        var offenders: [String] = []

        for path in try Self.sourceFiles(under: root) {
            let text = try String(contentsOf: path, encoding: .utf8)
            for (offset, rawLine) in text.components(separatedBy: .newlines).enumerated() {
                let line = Self.strippingComment(from: rawLine)
                let range = NSRange(location: 0, length: (line as NSString).length)
                guard banned.firstMatch(in: line, range: range) != nil else { continue }
                let rel = path.path.replacingOccurrences(of: root.path + "/", with: "")
                offenders.append("\(rel):\(offset + 1): \(rawLine.trimmingCharacters(in: .whitespaces))")
            }
        }

        XCTAssertTrue(
            offenders.isEmpty,
            """
            Found \(offenders.count) unchecked save(s). Use `Commit.save(context, "label")` \
            instead — it logs the failure and reports migration failures to the user.
            \(offenders.prefix(20).joined(separator: "\n"))
            """
        )
    }

    /// The commit path itself: a successful save reports no failure, and nested
    /// collection scopes unwind without leaking into each other. The failure
    /// branch is not asserted here — provoking a real SwiftData save error is
    /// not reliably reproducible across OS versions, and a flaky test is worse
    /// than an absent one. It is exercised for real on any launch where a
    /// migration fails.
    func testCommitCollectFailuresIsSilentOnSuccessAndUnwindsNestedScopes() {
        let container = makeContainer()
        let context = container.mainContext

        let failures = Commit.collectFailures {
            let figure = Figure(name: "Commit Probe", figureType: FigureType(name: "Deity", icon: "star", colorHex: "FF9500"))
            context.insert(figure)
            XCTAssertTrue(Commit.save(context, "testCommitProbe"))

            let nested = Commit.collectFailures {
                context.insert(Figure(name: "Nested Probe"))
                XCTAssertTrue(Commit.save(context, "testNestedProbe"))
            }
            XCTAssertTrue(nested.isEmpty)
        }

        XCTAssertTrue(failures.isEmpty, "A successful save must not be reported as a failure: \(failures)")

        let figures = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        XCTAssertTrue(figures.contains { $0.name == "Commit Probe" })
        XCTAssertTrue(figures.contains { $0.name == "Nested Probe" })
    }

    // MARK: - Helpers

    private static func repositoryRoot() throws -> URL {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0..<3 { url.deleteLastPathComponent() }
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
              isDirectory.boolValue,
              FileManager.default.fileExists(atPath: url.appendingPathComponent("Package.swift").path) else {
            throw XCTSkip("Could not locate the repository root from #filePath — lint not run.")
        }
        return url
    }

    private static func sourceFiles(under root: URL) throws -> [URL] {
        let sources = root.appendingPathComponent("Sources")
        guard let walker = FileManager.default.enumerator(at: sources, includingPropertiesForKeys: nil) else {
            throw XCTSkip("No Sources directory at \(sources.path) — lint not run.")
        }
        return walker.compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }.sorted { $0.path < $1.path }
    }

    private static func strippingComment(from line: String) -> String {
        guard let range = line.range(of: "//") else { return line }
        return String(line[line.startIndex..<range.lowerBound])
    }
}
