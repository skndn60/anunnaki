import SwiftUI
import SwiftData

/// Displays figures arranged along a chronological timeline of eras.
struct TimelineView: View {
    @Query(sort: \Era.orderIndex) private var eras: [Era]
    @Query private var figures: [Figure]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Timeline")
                    .font(.title2.bold())
                Spacer()
                // Legend
                HStack(spacing: 12) {
                    LegendDot(color: .purple, label: "Primordial")
                    LegendDot(color: .blue, label: "Deity")
                    LegendDot(color: .orange, label: "Semi-Divine")
                    LegendDot(color: .green, label: "Human")
                }
                .font(.caption)
            }
            .padding()

            Divider()

            if eras.isEmpty {
                emptyState
            } else {
                ScrollView([.horizontal, .vertical]) {
                    HStack(alignment: .top, spacing: 0) {
                        ForEach(eras) { era in
                            TimelineEraColumn(era: era, figures: figuresInEra(era))
                        }
                    }
                    .padding(30)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "calendar.day.timeline.left")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No eras defined")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("Add eras in the Eras input screen, then assign figures to eras to see them on the timeline.")
                .font(.body)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
            Spacer()
        }
    }

    /// Match figures to eras by checking if the figure's birth date era matches the era name.
    private func figuresInEra(_ era: Era) -> [Figure] {
        figures
            .filter { $0.birthDate.era == era.name }
            .sorted { $0.birthDate.sortValue < $1.birthDate.sortValue }
    }
}

/// A single column in the timeline representing one era.
struct TimelineEraColumn: View {
    let era: Era
    let figures: [Figure]

    var body: some View {
        VStack(spacing: 12) {
            // Era header
            VStack(spacing: 4) {
                Text(era.name)
                    .font(.headline)
                    .multilineTextAlignment(.center)

                // Date range
                HStack(spacing: 4) {
                    Text(era.startDate.displayLabel)
                    Text("→")
                    Text(era.endDate.displayLabel)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .frame(width: 180)

            // Vertical connector
            Rectangle()
                .fill(Color.accentColor.opacity(0.3))
                .frame(width: 2, height: 20)

            // Figures in this era
            if figures.isEmpty {
                Text("—")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(height: 40)
            } else {
                VStack(spacing: 8) {
                    ForEach(figures) { figure in
                        TimelineFigureChip(figure: figure)
                    }
                }
            }

            Spacer(minLength: 20)
        }
        .padding(.horizontal, 8)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(Color.secondary.opacity(0.1))
                .frame(width: 1)
        }
    }
}

/// A small chip showing a figure on the timeline.
struct TimelineFigureChip: View {
    let figure: Figure

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Circle()
                    .fill(chipColor)
                    .frame(width: 8, height: 8)
                Text(figure.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
            }
            Text(figure.birthDate.displayLabel)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(chipColor.opacity(0.1))
        )
    }

    private var chipColor: Color { figure.figureType?.color ?? .gray }
}

/// Small legend dot for the timeline header.
struct LegendDot: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
        }
    }
}
