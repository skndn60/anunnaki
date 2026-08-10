import SwiftUI
import SwiftData

struct EraDetailView: View {
    let era: Era
    @Environment(\.openWindow) private var openWindow
    @Query private var allFigures: [Figure]
    @State private var selectedFigure: Figure?

    private var eraFigures: [Figure] {
        var seen = Set<String>()
        return allFigures.filter {
            guard $0.era?.persistentModelID == era.persistentModelID else { return false }
            return seen.insert($0.name).inserted
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 12) {
                    Circle()
                        .fill(Color.orange.opacity(0.2))
                        .frame(width: 44, height: 44)
                        .overlay(
                            Image(systemName: "clock.arrow.circlepath")
                                .foregroundStyle(.orange)
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(era.name)
                            .font(.title2.bold())
                        Text("Period \(era.orderIndex)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }

                Divider()

                LazyVGrid(columns: [GridItem(.fixed(110), alignment: .trailing), GridItem(.flexible(), alignment: .leading)], alignment: .leading, spacing: 10) {
                    PropertyRow(label: "Start Date", value: era.startDate.displayLabel)
                    PropertyRow(label: "End Date", value: era.endDate.displayLabel)
                }

                if era.startDate.startYear != nil && era.endDate.endYear != nil {
                    let years = era.startDate.sortValue - era.endDate.sortValue
                    if years > 0 {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Duration")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                            Text("\(years) years")
                                .font(.body)
                        }
                    }
                }

                if !era.eraDescription.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Description")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                        Text(era.eraDescription)
                            .font(.body)
                    }
                }

                if !eraFigures.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Figures (\(eraFigures.count))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)

                        ForEach(eraFigures) { figure in
                            HStack(spacing: 8) {
                                Text(figure.gender.symbol)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(figure.name)
                                    .font(.callout)
                                    .fontWeight(.medium)
                                    .onTapGesture { selectedFigure = figure }
                                Spacer()
                                if figure.birthDate.startYear != nil || figure.birthDate.endYear != nil {
                                    Text(figure.birthDate.displayLabel)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                Spacer()
            }
            .padding(20)
            .textSelection(.enabled)
        }
        .onChange(of: selectedFigure) { _, newValue in
            if let figure = newValue {
                openWindow(id: "figure-quickview", value: figure.persistentModelID)
                selectedFigure = nil
            }
        }
    }
}

struct FigureQuicklookWindow: View {
    let figureID: PersistentIdentifier?
    @Environment(\.modelContext) private var modelContext
    @State private var figure: Figure?

    var body: some View {
        Group {
            if let figure {
                FigureQuicklookContent(figure: figure)
            } else {
                Text("Figure not found")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            guard let figureID else { return }
            let fetch = FetchDescriptor<Figure>(predicate: #Predicate { $0.persistentModelID == figureID })
            figure = try? modelContext.fetch(fetch).first
        }
    }
}

private struct FigureQuicklookContent: View {
    let figure: Figure

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Circle()
                    .fill(figure.figureType?.color ?? .gray)
                    .frame(width: 32, height: 32)
                    .overlay(
                        Text(figure.gender.symbol)
                            .font(.caption)
                            .foregroundStyle(.white)
                    )

                VStack(alignment: .leading, spacing: 1) {
                    Text(figure.name)
                        .font(.headline)
                    Text(figure.figureType?.name ?? "Unknown")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            if !figure.domain.isEmpty {
                PropertyRow(label: "Domain", value: figure.domain)
            }

            if figure.birthDate.startYear != nil || figure.birthDate.endYear != nil {
                PropertyRow(label: "Birth", value: figure.birthDate.displayLabel)
            }

            if figure.deathDate.startYear != nil || figure.deathDate.endYear != nil {
                PropertyRow(label: "Death", value: figure.deathDate.displayLabel)
            }

            if !figure.figureDescription.isEmpty || figure.richDescription != nil {
                RichTextDisplay(richData: figure.richDescription, fallback: figure.figureDescription)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(6)
            }
        }
        .padding(16)
    }
}
