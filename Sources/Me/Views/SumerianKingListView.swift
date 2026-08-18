import SwiftUI
import SwiftData

struct SumerianKingListView: View {
    var coordinator: NavigationCoordinator?

    @Environment(\.modelContext) private var modelContext
    @Query private var figures: [Figure]
    @Query(sort: \Era.orderIndex) private var eras: [Era]

    @AppStorage("sklDetailWidth") private var detailWidth: Double = 320
    @State private var selectedFigureID: PersistentIdentifier?
    @State private var imageDetailImage: ImageAsset?
    @State private var showDeleteConfirm = false
    @State private var editingFigure: Figure?

    private var eraOrder: [String: Int] {
        Dictionary(uniqueKeysWithValues: eras.map { ($0.name, $0.orderIndex) })
    }

    private var sklFigures: [Figure] {
        figures.filter { $0.source.contains("Sumerian King List") }
    }

    private var timeline: [SKLDatePropagator.DynastyTimeline] {
        SKLDatePropagator.compute(figures: sklFigures, eraOrder: eraOrder)
    }

    private var selectedFigure: Figure? {
        guard let id = selectedFigureID else { return nil }
        return sklFigures.first { $0.persistentModelID == id }
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                header
                Divider()
                if sklFigures.isEmpty {
                    emptyState
                } else {
                    kingList
                }
            }
            .frame(minWidth: 500, maxWidth: .infinity)

            Group {
                if let figure = selectedFigure {
                    // ResizableDivider(width: $detailWidth, range: 200...800)
                    detailPanel(figure: figure)
                    .frame(width: detailWidth)
                    .frame(maxHeight: .infinity)
                    .background(.thinMaterial)
                }
            }
            .transition(.move(edge: .trailing).combined(with: .opacity))
            .animation(.easeInOut(duration: 0.25), value: selectedFigureID)
        }
        .onChange(of: selectedFigureID) { _, newValue in
            if newValue == nil { selectedFigureID = nil }
        }
        .alert("Delete King?", isPresented: $showDeleteConfirm, presenting: selectedFigure) { figure in
            Button("Delete", role: .destructive) { deleteFigure(figure) }
            Button("Cancel", role: .cancel) {}
        } message: { figure in
            Text("Delete \"\(figure.name)\"? This cannot be undone.")
        }
        .sheet(item: $editingFigure) { figure in
            FigureFormView(figure: figure)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("Sumerian King List")
                .font(.title2.bold())
            Spacer()
            Text("\(sklFigures.count) kings")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "list.star")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No king list data")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("Seed the database with --reseed to load the Sumerian King List.")
                .font(.body)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - King List

    private var kingList: some View {
        List(selection: $selectedFigureID) {
            ForEach(timeline, id: \.name) { dynasty in
                Section {
                    ForEach(dynasty.reigns, id: \.figure.persistentModelID) { reign in
                        KingRow(reign: reign)
                            .tag(reign.figure.persistentModelID)
                            .contextMenu {
                                Button("Edit") {
                                    editingFigure = reign.figure
                                }
                                Button("Show in Lineage Tree") {
                                    coordinator?.navigateToLineageFigure(reign.figure.persistentModelID)
                                }
                                Divider()
                                Button("Delete", role: .destructive) {
                                    selectedFigureID = reign.figure.persistentModelID
                                    showDeleteConfirm = true
                                }
                            }
                    }
                } header: {
                    HStack(spacing: 8) {
                        Text(dynasty.name)
                            .font(.title3.bold())
                            .foregroundStyle(.primary)
                        Text("\(dynasty.reigns.count) kings")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        if let s = dynasty.startBCE, let e = dynasty.endBCE {
                            Text("c. \(abs(s))\u{2013}\(abs(e)) BC")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        if dynasty.totalYears > 0 {
                            Text("Duration: \(dynasty.totalYears.formatted()) years")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
    }

    // MARK: - Detail Panel

    private func detailPanel(figure: Figure) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                IconActionButton(icon: "pencil", color: .accentColor, help: "Edit") {
                    editingFigure = figure
                }
                IconActionButton(icon: "trash", color: .red, help: "Delete") {
                    showDeleteConfirm = true
                }
                Spacer()
                Button(action: { selectedFigureID = nil }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 22, height: 22)
                        .background(RoundedRectangle(cornerRadius: 5).fill(Color.secondary.opacity(0.1)))
                }
                .buttonStyle(.plain)
                .help("Close")
            }
            .padding(.vertical, 8)
            FigureDetailView(figure: figure, onSelectFigure: { selected in
                coordinator?.pushHistory(id: selected.persistentModelID, name: selected.name, item: .figures)
                selectedFigureID = selected.persistentModelID
            }, onSelectPlace: { place in
                coordinator?.navigateToPlace(place.persistentModelID, name: place.name)
            }, onSelectEvent: { event in
                coordinator?.navigateToEvent(event.persistentModelID, name: event.name)
            }, onSelectImage: { imageDetailImage = $0 })
        }
    }

    private func deleteFigure(_ figure: Figure) {
        if selectedFigureID == figure.persistentModelID {
            selectedFigureID = nil
        }
        withAnimation { modelContext.delete(figure) }
    }
}

// MARK: - King Row

private struct KingRow: View {
    let reign: SKLDatePropagator.ComputedReign

    private var figure: Figure { reign.figure }

    private var reignLength: ReignLength? {
        if let years = figure.reignYears {
            return ReignLength(years: years, display: "\(Self.yearString(years)) years")
        }
        return ReignLength.parse(from: figure.figureDescription)
    }

    private static func yearString(_ years: Int) -> String {
        let fmt = NumberFormatter()
        fmt.numberStyle = .decimal
        fmt.locale = Locale(identifier: "en_US")
        return fmt.string(from: NSNumber(value: years)) ?? "\(years)"
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "crown.fill")
                .font(.system(size: 10))
                .foregroundStyle(.orange)
                .frame(width: 14)
            VStack(alignment: .leading, spacing: 0) {
                Text(figure.name)
                    .fontWeight(.medium)
                if let disambiguation = figure.disambiguation, !disambiguation.isEmpty {
                    Text(disambiguation)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(minWidth: 140, alignment: .leading)
            if let reignLength {
                Text(reignLength.display)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(width: 120, alignment: .leading)
            } else {
                Text("Unknown")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .frame(width: 120, alignment: .leading)
            }
            Text(reign.display)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 140, alignment: .leading)
            if !figure.figureDescription.isEmpty {
                Text(String(figure.figureDescription.prefix(60)).replacingOccurrences(of: "\n", with: " "))
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .mugshotHover(figure, arrowEdge: .leading)
    }
}
