import Foundation
import SwiftData

private struct FigureBlurbImport: Codable {
    let name: String
    let description: String
}

private struct FigureBlurbsRoot: Codable {
    let figures: [FigureBlurbImport]
}

extension Migration {
    /// Fill empty `figureDescription`s from figure_blurbs.json. Only touches figures
    /// whose description is blank/whitespace, keyed by exact name; additive + idempotent.
    package static func ensureMissingFigureDescriptions(context: ModelContext) {
        let url: URL? = {
            if let u = Bundle.module.url(forResource: "figure_blurbs", withExtension: "json") { return u }
            return Bundle.main.url(forResource: "figure_blurbs", withExtension: "json")
        }()
        guard let url,
              let data = try? Data(contentsOf: url),
              let root = try? JSONDecoder().decode(FigureBlurbsRoot.self, from: data) else {
            return
        }
        let blurbs: [String: String] = Dictionary(
            root.figures.map { ($0.name, $0.description) },
            uniquingKeysWith: { first, _ in first }
        )

        let figures = (try? context.fetch(FetchDescriptor<Figure>())) ?? []
        var didChange = false
        for figure in figures {
            let trimmed = figure.figureDescription.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.isEmpty, let blurb = blurbs[figure.name] else { continue }
            figure.figureDescription = blurb
            didChange = true
        }
        if didChange {
            try? context.save()
        }
    }
}
