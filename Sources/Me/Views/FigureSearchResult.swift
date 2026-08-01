import SwiftUI
import SwiftData

struct FigureSearchResult: Identifiable, Equatable {
    let figure: Figure
    let matchedAlternateName: String?

    var id: PersistentIdentifier { figure.persistentModelID }

    var displayName: String {
        if let alt = matchedAlternateName {
            return "\(figure.name) as \(alt)"
        }
        return figure.name
    }
}

extension Figure {
    func matchedAlternateName(for query: String) -> String? {
        guard !query.isEmpty else { return nil }
        return alternateNames.first { $0.name.localizedCaseInsensitiveContains(query) }?.name
    }
}

func searchFigures(_ figures: [Figure], query: String) -> [FigureSearchResult] {
    guard !query.isEmpty else {
        return figures.map { FigureSearchResult(figure: $0, matchedAlternateName: nil) }
    }
    return figures.compactMap { figure in
        if figure.name.localizedCaseInsensitiveContains(query) {
            return FigureSearchResult(figure: figure, matchedAlternateName: nil)
        }
        if let alt = figure.matchedAlternateName(for: query) {
            return FigureSearchResult(figure: figure, matchedAlternateName: alt)
        }
        return nil
    }
}
