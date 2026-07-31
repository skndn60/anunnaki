import SwiftUI

struct AttributedPropertyView<Content: View>: View {
    let attributions: [ContentAttribution]
    let propertyName: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            content()
            if !matchingAttributions.isEmpty {
                ForEach(matchingAttributions, id: \.persistentModelID) { attr in
                    sourceBadge(for: attr)
                }
            }
        }
    }

    private var matchingAttributions: [ContentAttribution] {
        attributions.filter { $0.propertyName == propertyName }
    }

    private func sourceBadge(for attr: ContentAttribution) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "book.and.wrench")
                .font(.caption2)
                .foregroundStyle(.teal)
            Text(attr.source?.name ?? "Unknown source")
                .font(.caption2)
                .foregroundStyle(.teal)
            if let urlString = attr.url, !urlString.isEmpty, let url = URL(string: urlString) {
                Link(destination: url) {
                    Image(systemName: "arrow.up.forward.app")
                        .font(.caption2)
                        .foregroundStyle(.teal)
                }
            }
        }
        .padding(.leading, 2)
    }
}
