import SwiftUI
import SwiftData

struct TimelineContainerView: View {
    @State private var selectedSegment: TimelineSegment = .pre
    @AppStorage("timelineShowReignBars") private var showReignBars = false
    @Query private var figureTypes: [FigureType]

    enum TimelineSegment: String, CaseIterable {
        case pre = "Pre-Flood"
        case post = "Post-Flood"
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            switch selectedSegment {
            case .pre:
                TimelinePreView()
            case .post:
                TimelinePostView(showReignBars: showReignBars)
            }
        }
    }

    private var header: some View {
        HStack {
            Text("Timeline")
                .font(.title2.bold())
            Spacer()
            Picker("Period", selection: $selectedSegment) {
                ForEach(TimelineSegment.allCases, id: \.self) { segment in
                    Text(segment.rawValue).tag(segment)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 220)
            Spacer()
            if selectedSegment == .post {
                Toggle("Reign bars", isOn: $showReignBars)
                    .toggleStyle(.checkbox)
                    .help("Show each ruler's reign/lifespan bar; hover a bar or its chip to see whose it is.")
            }
            HStack(spacing: 12) {
                ForEach(figureTypes) { type in
                    LegendIcon(icon: type.icon, color: type.color, label: type.name)
                }
            }
            .font(.caption)
        }
        .padding()
    }
}
