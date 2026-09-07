import SwiftUI
import SwiftData

/// Split-screen compare of two figures. All structure lives in
/// `EntityCompareView`; this type only supplies figure data + closures.
struct FigureCompareView: View {
    @Query(sort: \Figure.name) private var allFigures: [Figure]
    private let figure: Figure

    init(figure: Figure) {
        self.figure = figure
    }

    var body: some View {
        EntityCompareView(
            allItems: allFigures,
            initialItem: figure,
            title: "Compare Figures",
            promptNoun: "figure",
            searchPlaceholder: "Search figures\u{2026}",
            name: { $0.name },
            filter: { items, query in
                searchFigures(items, query: query).map(\.figure)
            },
            detail: { FigureDetailView(figure: $0) },
            row: { figure, query in
                HStack(spacing: 10) {
                    Text(figure.gender.symbol)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 14)
                    Text(displayName(for: figure, query: query))
                        .font(.body)
                    Spacer()
                }
            }
        )
    }

    private func displayName(for figure: Figure, query: String) -> String {
        if let alt = figure.matchedAlternateName(for: query) {
            return "\(figure.name) as \(alt)"
        }
        return figure.name
    }
}
