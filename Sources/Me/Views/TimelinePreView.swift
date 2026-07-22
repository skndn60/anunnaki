import SwiftUI
import SwiftData

struct TimelinePreView: View {
    @Query(sort: \Era.orderIndex) private var eras: [Era]
    @Query private var figures: [Figure]

    private let swimlaneHeight: CGFloat = 56

    private var preFloodEras: [Era] {
        eras.filter { $0.orderIndex < 7 }
    }

    var body: some View {
        if preFloodEras.isEmpty {
            emptyState
        } else {
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 0) {
                    sectionHeader("Pre-Flood")
                    ForEach(preFloodEras.filter { !figuresInEra($0, from: figures).isEmpty }) { era in
                        EraSwimlaneRow(
                            era: era,
                            figures: figuresInEra(era, from: figures),
                            swimlaneWidth: nil,
                            swimlaneHeight: swimlaneHeight,
                            mode: .mythological
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(.tertiary)
            .textCase(.uppercase)
            .padding(.vertical, 6)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "calendar.day.timeline.left")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No pre-flood eras defined")
                .font(.title3)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }
}
