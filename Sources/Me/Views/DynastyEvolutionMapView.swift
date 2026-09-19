import SwiftUI
import SwiftData

struct DynastyEvolutionMapView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Era.orderIndex) private var eras: [Era]
    @Query private var places: [Place]
    @Query private var figures: [Figure]

    @AppStorage("dynastyMapHistoricalStartupZoom") private var historicalStartupZoom = 5.0
    @AppStorage("dynastyMapHistoricalTheme") private var historicalThemeRaw = HistoricalMapTheme.historical.rawValue
    @AppStorage("dynastyMapHistoricalLanguage") private var historicalLanguageRaw = HistoricalMapLanguage.english.rawValue
    @AppStorage("dynastyMapLabelSize") private var labelSizeRaw = MapLabelSize.medium.rawValue
    @AppStorage("dynastyEvolutionDateFilter") private var dateFilterEnabled = false
    @AppStorage("dynastyEvolutionAnimateBoundaries") private var animateBoundaries = true
    @AppStorage("mapHideBasemapCities") private var hideBasemapCities = true

    enum PlaySpeed: String, CaseIterable, Identifiable {
        case slow = "Slow"
        case normal = "Normal"
        case fast = "Fast"
        case custom = "Custom"
        var id: String { rawValue }
        var yearsPerSecond: Double {
            switch self {
            case .slow: return 20
            case .normal: return 60
            case .fast: return 150
            case .custom: return 0
            }
        }
    }

    @AppStorage("dynastyEvolutionPlaySpeed") private var playSpeedRaw = PlaySpeed.normal.rawValue
    @AppStorage("dynastyEvolutionCustomSpeed") private var customSpeed = 60.0

    private var playSpeed: PlaySpeed {
        get { PlaySpeed(rawValue: playSpeedRaw) ?? .normal }
        nonmutating set { playSpeedRaw = newValue.rawValue }
    }

    private var playSpeedBinding: Binding<PlaySpeed> {
        Binding(get: { playSpeed }, set: { playSpeed = $0 })
    }

    private var playRate: Double {
        playSpeed == .custom ? clampedCustomSpeed : playSpeed.yearsPerSecond
    }

    private var clampedCustomSpeed: Double {
        min(max(customSpeed, 5), 2000)
    }

    @State private var currentYear: Double = -2600
    @State private var isPlaying = false
    @State private var detailPlace: Place?
    @State private var detailFigure: Figure?
    @State private var zoomController = MapZoomController()
    @State private var cachedRuns: [DynastyRun] = []
    @State private var runsLoaded = false
    @State private var territoryZoom: CGFloat = 1.0

    private var allPlaces: [Place] {
        places.filter { $0.latitude != nil && $0.longitude != nil }
    }

    private var eraOrder: [String: Int] {
        Dictionary(eras.map { ($0.name, $0.orderIndex) }, uniquingKeysWith: { first, _ in first })
    }

    private var sklFigureIDs: [PersistentIdentifier] {
        figures.compactMap { $0.source.contains("Sumerian King List") ? $0.persistentModelID : nil }
    }

    private var sklFigures: [Figure] {
        figures.filter { $0.source.contains("Sumerian King List") }
    }

    private struct DataSignature: Equatable {
        let sklIDs: [PersistentIdentifier]
        let eraOrder: [String: Int]
    }

    private var dataSignature: DataSignature {
        DataSignature(sklIDs: sklFigureIDs, eraOrder: eraOrder)
    }

    private var runs: [DynastyRun] { cachedRuns }

    private func rebuildRuns() {
        let timeline = SKLDatePropagator.compute(figures: sklFigures, eraOrder: eraOrder)
        var built: [DynastyRun] = []
        for (index, dynasty) in timeline.enumerated() {
            guard let start = dynasty.startBCE, let end = dynasty.endBCE else { continue }
            let geo = boundaryGeoJSON(forDynastyNamed: dynasty.name)
            guard let geo else { continue }
            let capital = capitalPin(for: dynasty.name)
            built.append(DynastyRun(
                id: index,
                name: dynasty.name,
                startBCE: start,
                endBCE: end,
                color: dynastyColor(for: index),
                geoJSON: geo,
                ring: decodedRing(from: geo),
                capital: capital.name,
                capitalLat: capital.lat,
                capitalLon: capital.lon,
                reigns: dynasty.reigns,
                kingCount: dynasty.reigns.count
            ))
        }
        cachedRuns = built
        runsLoaded = true
        if let bounds = axisBounds, currentYear < bounds.min || currentYear > bounds.max {
            currentYear = bounds.min
        }
    }

    private var axisBounds: (min: Double, max: Double)? {
        guard let lo = runs.map({ Double($0.startBCE) }).min(),
              let hi = runs.map({ Double($0.endBCE) }).max() else { return nil }
        return (min(lo, hi), max(lo, hi))
    }

    private var effectiveYear: Double {
        guard let bounds = axisBounds else { return currentYear }
        return min(max(currentYear, bounds.min), bounds.max)
    }

    private var currentRunIndex: Int? {
        let y = effectiveYear
        return runs.indices
            .filter { Double(runs[$0].startBCE) <= y && y <= Double(runs[$0].endBCE) }
            .max { runs[$0].startBCE < runs[$1].startBCE }
    }

    private var currentRun: DynastyRun? {
        guard let index = currentRunIndex, runs.indices.contains(index) else { return nil }
        return runs[index]
    }

    private func boundaryGeoJSON(forDynastyNamed name: String) -> String? {
        eras.first { $0.name == name }?.boundaryGeoJSON
    }

    private func decodedRing(from geoJSON: String?) -> [[Double]]? {
        guard let geoJSON,
              let data = geoJSON.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let coordinates = object["coordinates"] as? [[[Double]]],
              let ring = coordinates.first,
              ring.count >= 3 else { return nil }
        return ring
    }

    private func capitalPin(for dynastyName: String) -> (name: String?, lat: Double?, lon: Double?) {
        if let last = dynastyName.components(separatedBy: "of ").last?.trimmingCharacters(in: .whitespaces),
           let place = allPlaces.first(where: { $0.name.caseInsensitiveCompare(last) == .orderedSame }) {
            return (place.name, place.latitude, place.longitude)
        }
        for place in allPlaces where dynastyName.contains(place.name) {
            return (place.name, place.latitude, place.longitude)
        }
        return (nil, nil, nil)
    }

    private var currentRuler: SKLDatePropagator.ComputedReign? {
        guard let reigns = currentRun?.reigns else { return nil }
        return reigns.first { reign in
            guard let start = reign.startBCE, let end = reign.endBCE else { return false }
            return Double(start) <= effectiveYear && effectiveYear <= Double(end)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if allPlaces.isEmpty || (runsLoaded && runs.isEmpty) {
                emptyState
            } else if !runsLoaded {
                ProgressView("Computing dynasty chronology\u{2026}")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                HSplitView {
                    mapPanel
                    infoPanel
                }
                Divider()
                VStack(spacing: 8) {
                    timelineStrip
                    filmstrip
                }
                .padding(.top, 10)
                .padding(.bottom, 12)
            }
        }
        .sheet(item: $detailFigure) { figure in
            NavigationStack {
                FigureQuicklookView(figure: figure)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { detailFigure = nil }
                        }
                    }
            }
            .frame(minWidth: 500, minHeight: 400)
        }
        .sheet(item: $detailPlace) { place in
            NavigationStack {
                PlaceDetailView(place: place)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { detailPlace = nil }
                        }
                    }
            }
            .frame(width: 560, height: 600)
        }
        .task { rebuildRuns() }
        .task(id: isPlaying) {
            guard isPlaying else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 100_000_000)
                guard !Task.isCancelled else { return }
                advance()
            }
        }
        .onChange(of: dataSignature) { _, _ in
            rebuildRuns()
        }
        .onChange(of: currentRun?.id) { _, _ in
            guard currentRun != nil else { return }
            territoryZoom = 0.86
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 60_000_000)
                guard !Task.isCancelled else { return }
                withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
                    territoryZoom = 1.0
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Dynasty Evolution")
                    .font(.title2.bold())
                Spacer()
                yearBadge
                Button {
                    isPlaying.toggle()
                } label: {
                    Label(isPlaying ? "Pause" : "Play", systemImage: isPlaying ? "pause.fill" : "play.fill")
                        .frame(minWidth: 72)
                }
                .buttonStyle(.borderedProminent)
                .tint(currentRun?.color ?? .accentColor)

                Button {
                    step(-25)
                } label: {
                    Image(systemName: "backward.end.fill")
                }
                .help("Step back 25 years")

                Button {
                    step(25)
                } label: {
                    Image(systemName: "forward.end.fill")
                }
                .help("Step forward 25 years")

                Picker("Speed", selection: playSpeedBinding) {
                    ForEach(PlaySpeed.allCases) { speed in
                        Text(speed.rawValue).tag(speed)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 230)
                .help("Playback speed")

                Toggle(isOn: $dateFilterEnabled) {
                    Text("OHM date filter")
                        .font(.caption)
                }
                .toggleStyle(.switch)
                .controlSize(.small)
                .help("Make the historical map itself change while playing")

                Toggle(isOn: $hideBasemapCities) {
                    Text("Base map cities")
                        .font(.caption)
                }
                .toggleStyle(.switch)
                .controlSize(.small)
                .help("Hide city labels drawn by the base map")

                Toggle(isOn: $animateBoundaries) {
                    Text("Grow borders")
                        .font(.caption)
                }
                .toggleStyle(.switch)
                .controlSize(.small)
                .help("Grow each dynasty's territory from its center when it becomes current")

                Button {
                    isPlaying = false
                    if let bounds = axisBounds { currentYear = bounds.min }
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
                .help("Rewind to the start")
            }
            HStack {
                Text("\(runs.count) dynasties, \(allPlaces.count) cities — drag the strip or play to watch the borders change")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if playSpeed == .custom {
                    HStack(spacing: 6) {
                        Text("\(Int(clampedCustomSpeed.rounded())) yrs/s")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(minWidth: 52, alignment: .trailing)
                        TextField("Rate", value: $customSpeed, format: .number.precision(.fractionLength(0)))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 66)
                            .controlSize(.small)
                            .onSubmit { customSpeed = clampedCustomSpeed }
                    }
                }
                if let bounds = axisBounds {
                    Text("\(abs(Int(bounds.max.rounded()))) BCE")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding()
    }

    private var yearBadge: some View {
        let year = Int(effectiveYear.rounded())
        let label = year < 0 ? "c. \(abs(year)) BCE" : "c. \(year) CE"
        return Text(label)
            .font(.system(.headline, design: .rounded).monospacedDigit())
            .foregroundStyle(currentRun?.color ?? .secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: 7).fill((currentRun?.color ?? .gray).opacity(0.12)))
    }

    // MARK: - Map

    private var mapPanel: some View {
        ZStack(alignment: .topTrailing) {
            DynastyHistoricalMapView(
                places: mapPlaces,
                capitalIndex: capitalIndex,
                focusToken: currentRunIndex ?? -1,
                dynastyColorHex: capitalColorHex,
                startupZoom: historicalStartupZoom,
                theme: HistoricalMapTheme(rawValue: historicalThemeRaw) ?? .historical,
                language: historicalLanguageRaw,
                labelSize: (MapLabelSize(rawValue: labelSizeRaw) ?? .medium).basePx,
                dateString: dateString,
                hideBasemapCities: hideBasemapCities,
                boundaryGeoJSON: currentRun?.geoJSON,
                previewBoundaryGeoJSON: nil,
                previewColorHex: "#E0432F",
                defaultCenter: nil,
                onPlaceSelected: { index in
                    guard allPlaces.indices.contains(index) else { return }
                    detailPlace = allPlaces[index]
                },
                zoomController: zoomController,
                animateBoundaryTransitions: animateBoundaries
            )
            MapZoomButtons(controller: zoomController)
                .padding(8)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding()
    }

    private var mapPlaces: [DynastyMapPlace] {
        allPlaces.map { place in
            DynastyMapPlace(
                name: place.name,
                latitude: place.latitude!,
                longitude: place.longitude!,
                colorHex: colorHex(from: place.placeType?.color ?? Color(white: 0.6))
            )
        }
    }

    private var capitalIndex: Int? {
        guard let capital = currentRun?.capital else { return nil }
        return allPlaces.firstIndex(where: { $0.name == capital })
    }

    private var capitalColorHex: String {
        currentRun.map { colorHex(from: $0.color) } ?? "#999999"
    }

    private var dateString: String? {
        guard dateFilterEnabled else { return nil }
        let year = Int((effectiveYear / 20).rounded() * 20)
        if year < 0 { return String(format: "-%04d", -year) }
        return String(format: "%04d", year)
    }

    // MARK: - Info panel

    private var infoPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let run = currentRun {
                HStack(spacing: 8) {
                    Circle().fill(run.color).frame(width: 14, height: 14)
                    Text(run.name)
                        .font(.title3.bold())
                }
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("c. \(abs(run.startBCE))\u{2013}\(abs(run.endBCE)) BCE")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 14) {
                    Label("\(run.kingCount) kings", systemImage: "crown.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if run.spanYears > 0 {
                        Label("\(run.spanYears.formatted()) yrs", systemImage: "clock")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if let capital = run.capital {
                    HStack(spacing: 6) {
                        Image(systemName: "building.columns")
                            .font(.caption)
                            .foregroundColor(run.color)
                        Text("Capital: \(capital)")
                            .font(.subheadline)
                    }
                }

                if let ruler = currentRuler {
                    Divider()
                    Text("Ruling")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Button {
                        detailFigure = ruler.figure
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "person.crop.circle.fill")
                                .foregroundStyle(run.color)
                            Text(ruler.figure.name)
                                .lineLimit(1)
                            Spacer()
                            Text(ruler.display)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .pointingHand()
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Territory")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(nsColor: .controlBackgroundColor))
                        if let ring = run.ring {
                            Canvas { context, size in
                                    drawRing(ring, in: &context, size: size, color: run.color, fillOpacity: 0.4, lineWidth: 2.5, shrink: 0.8, upShift: 40)
                                    drawCapitalPin(ring: ring, name: run.capital, lat: run.capitalLat, lon: run.capitalLon, in: &context, size: size, color: run.color, shrink: 0.8, upShift: 40)
                                }
                            .scaleEffect(territoryZoom)
                        } else {
                            Text("no territory drawn")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text(run.name)
                            .font(.system(size: 88, weight: .black, design: .rounded))
                            .foregroundStyle(run.color.opacity(0.16))
                            .lineLimit(1)
                            .minimumScaleFactor(0.18)
                            .allowsTightening(true)
                            .padding(.horizontal, 12)
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(nsColor: .separatorColor).opacity(0.3), lineWidth: 1)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 160)
                    .frame(maxHeight: .infinity)
                }
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "triangle.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(.tertiary)
                    Text("Interregnum")
                        .font(.title3.bold())
                        .foregroundStyle(.secondary)
                    Text("No dynasty ruled at c. \(abs(Int(effectiveYear.rounded()))) BCE.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            Spacer(minLength: 0)
        }
        .padding()
        .frame(minWidth: 250, idealWidth: 300)
    }

    // MARK: - Timeline strip

    private var timelineStrip: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let bounds = axisBounds ?? (min: -2400, max: -1760)
            let fraction = (effectiveYear - bounds.min) / (bounds.max - bounds.min)

            ZStack {
                Rectangle()
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .overlay(Rectangle().fill(Color(nsColor: .separatorColor).opacity(0.12)))

                ForEach(runs) { run in
                    let startFrac = (Double(run.startBCE) - bounds.min) / (bounds.max - bounds.min)
                    let endFrac = (Double(run.endBCE) - bounds.min) / (bounds.max - bounds.min)
                    let spanFrac = max(0.004, endFrac - startFrac)
                    Rectangle()
                        .fill(run.color.opacity(currentRunIndex == run.id ? 0.95 : 0.6))
                        .overlay(
                            Group {
                                if spanFrac * width >= 46 {
                                    Text(run.name)
                                        .font(.system(size: 9, weight: .semibold))
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                        .padding(.horizontal, 3)
                                }
                            },
                            alignment: .leading
                        )
                        .frame(width: spanFrac * width)
                        .position(x: (startFrac + spanFrac / 2) * width, y: 15)
                }

                Rectangle()
                    .fill(.primary)
                    .frame(width: 2, height: 22)
                    .position(x: fraction * width, y: 15)
                    .shadow(color: .black.opacity(0.4), radius: 1)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in scrub(toX: value.location.x, width: width) }
            )
            .overlay(alignment: .top) {
                Text("c. \(abs(Int(effectiveYear.rounded()))) BCE")
                    .font(.caption2.bold())
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(.regularMaterial, in: Capsule())
                    .position(x: fraction * width, y: -2)
            }
        }
        .frame(height: 30)
        .padding(.horizontal)
    }

    private func scrub(toX x: CGFloat, width: CGFloat) {
        guard let bounds = axisBounds, width > 0 else { return }
        let f = min(max(x / width, 0), 1)
        currentYear = bounds.min + (bounds.max - bounds.min) * Double(f)
        isPlaying = false
    }

    // MARK: - Filmstrip

    private var filmstrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(runs) { run in
                    TerritoryThumb(
                        run: run,
                        isCurrent: currentRunIndex == run.id,
                        action: { jump(to: run) }
                    )
                }
            }
            .padding(.horizontal)
        }
    }

    private func jump(to run: DynastyRun) {
        currentYear = (Double(run.startBCE) + Double(run.endBCE)) / 2
        isPlaying = false
    }

    // MARK: - Playback

    private func advance() {
        guard let bounds = axisBounds else { return }
        let step = playRate * 0.1
        var year = effectiveYear + step
        if year > bounds.max { year = bounds.min }
        currentYear = year
    }

    private func step(_ delta: Double) {
        guard let bounds = axisBounds else { return }
        currentYear = min(max(effectiveYear + delta, bounds.min), bounds.max)
        isPlaying = false
    }

    // MARK: - Shared helpers

    private let dynastyColors: [Color] = [
        Color(red: 0.85, green: 0.40, blue: 0.20),
        Color(red: 0.20, green: 0.50, blue: 0.70),
        Color(red: 0.80, green: 0.60, blue: 0.15),
        Color(red: 0.60, green: 0.25, blue: 0.55),
        Color(red: 0.25, green: 0.65, blue: 0.40),
        Color(red: 0.70, green: 0.30, blue: 0.30),
        Color(red: 0.40, green: 0.35, blue: 0.75),
        Color(red: 0.75, green: 0.55, blue: 0.35),
        Color(red: 0.30, green: 0.60, blue: 0.60),
        Color(red: 0.80, green: 0.45, blue: 0.10),
    ]

    private func dynastyColor(for index: Int) -> Color {
        dynastyColors[index % dynastyColors.count]
    }

    private func colorHex(from color: Color) -> String {
        guard let rgb = NSColor(color).usingColorSpace(.sRGB) else { return "#999999" }
        let r = Int(round(rgb.redComponent * 255))
        let g = Int(round(rgb.greenComponent * 255))
        let b = Int(round(rgb.blueComponent * 255))
        return String(format: "#%02X%02X%02X", r, g, b)
    }

    private func drawRing(_ ring: [[Double]], in context: inout GraphicsContext, size: CGSize, color: Color, fillOpacity: Double, lineWidth: CGFloat, shrink: CGFloat = 1, upShift: CGFloat = 0) {
        guard let projection = ringProjection(ring, size: size, shrink: shrink, upShift: upShift) else { return }
        let points = ring.dropLast(ring.last == ring.first ? 1 : 0)
        var path = Path()
        path.move(to: projection.point(lon: points[0][0], lat: points[0][1]))
        for coord in points.dropFirst() {
            path.addLine(to: projection.point(lon: coord[0], lat: coord[1]))
        }
        path.closeSubpath()
        context.fill(path, with: .color(color.opacity(fillOpacity)))
        context.stroke(path, with: .color(color), lineWidth: lineWidth)
    }

    private struct RingProjection {
        let scale: CGFloat
        let ox: CGFloat
        let oy: CGFloat
        let minLon: Double
        let maxLat: Double

        func point(lon: Double, lat: Double) -> CGPoint {
            CGPoint(x: ox + CGFloat(lon - minLon) * scale, y: oy + CGFloat(maxLat - lat) * scale)
        }
    }

    private func ringProjection(_ ring: [[Double]], size: CGSize, shrink: CGFloat = 1, upShift: CGFloat = 0) -> RingProjection? {
        guard ring.count >= 3 else { return nil }
        let points = ring.dropLast(ring.last == ring.first ? 1 : 0)
        guard points.count >= 3,
              let minLon = (points.map { $0[0] }.min()),
              let maxLon = (points.map { $0[0] }.max()),
              let minLat = (points.map { $0[1] }.min()),
              let maxLat = (points.map { $0[1] }.max()) else { return nil }
        let spanLon = max(maxLon - minLon, 0.001)
        let spanLat = max(maxLat - minLat, 0.001)
        let padding: CGFloat = 8
        let scale = min((size.width - padding * 2) / spanLon, (size.height - padding * 2) / spanLat) * shrink
        let drawW = spanLon * scale
        let drawH = spanLat * scale
        return RingProjection(
            scale: scale,
            ox: (size.width - drawW) / 2,
            oy: (size.height - drawH) / 2 - upShift,
            minLon: minLon,
            maxLat: maxLat
        )
    }

    private func drawCapitalPin(ring: [[Double]], name: String?, lat: Double?, lon: Double?, in context: inout GraphicsContext, size: CGSize, color: Color, shrink: CGFloat = 1, upShift: CGFloat = 0) {
        guard let name, let lat, let lon,
              let projection = ringProjection(ring, size: size, shrink: shrink, upShift: upShift) else { return }
        let center = projection.point(lon: lon, lat: lat)
        guard center.x >= 6, center.y >= 6, center.x <= size.width - 6, center.y <= size.height - 6 else { return }
        let dotRadius: CGFloat = 12.5
        let dotRect = CGRect(x: center.x - dotRadius, y: center.y - dotRadius, width: dotRadius * 2, height: dotRadius * 2)
        context.fill(Path(ellipseIn: dotRect), with: .color(color.opacity(0.95)))
        context.stroke(Path(ellipseIn: dotRect), with: .color(.white.opacity(0.9)), lineWidth: 1.5)

        let label = Text(name)
            .font(.system(size: 22, weight: .heavy, design: .rounded))
            .foregroundColor(color)
        let gap: CGFloat = dotRadius + 10
        let leftRoom = center.x - 4
        let rightRoom = size.width - center.x - 4
        if rightRoom >= 110 {
            context.draw(label, at: CGPoint(x: center.x + gap, y: center.y), anchor: .leading)
        } else if leftRoom >= 110 {
            context.draw(label, at: CGPoint(x: center.x - gap, y: center.y), anchor: .trailing)
        } else {
            context.draw(label, at: CGPoint(x: center.x, y: center.y + gap + 10), anchor: .center)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "map")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No map data")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("Seed the database with --reseed to load places.")
                .font(.body)
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Supporting types

private struct DynastyRun: Identifiable {
    let id: Int
    let name: String
    let startBCE: Int
    let endBCE: Int
    let color: Color
    let geoJSON: String?
    let ring: [[Double]]?
    let capital: String?
    let capitalLat: Double?
    let capitalLon: Double?
    let reigns: [SKLDatePropagator.ComputedReign]
    let kingCount: Int

    var spanYears: Int { abs(startBCE - endBCE) }

    var midBCE: Double { (Double(startBCE) + Double(endBCE)) / 2 }
}

private struct TerritoryThumb: View {
    let run: DynastyRun
    let isCurrent: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Canvas { context, size in
                    if let ring = run.ring {
                        let points = ring.dropLast(ring.last == ring.first ? 1 : 0)
                        guard points.count >= 3,
                              let minLon = (points.map { $0[0] }.min()),
                              let maxLon = (points.map { $0[0] }.max()),
                              let minLat = (points.map { $0[1] }.min()),
                              let maxLat = (points.map { $0[1] }.max()) else { return }
                        let spanLon = max(maxLon - minLon, 0.001)
                        let spanLat = max(maxLat - minLat, 0.001)
                        let padding: CGFloat = 6
                        let scale = min((size.width - padding * 2) / spanLon, (size.height - padding * 2) / spanLat)
                        let ox = (size.width - spanLon * scale) / 2
                        let oy = (size.height - spanLat * scale) / 2
                        func point(_ coord: [Double]) -> CGPoint {
                            CGPoint(x: ox + CGFloat(coord[0] - minLon) * scale, y: oy + CGFloat(maxLat - coord[1]) * scale)
                        }
                        var path = Path()
                        path.move(to: point(points[0]))
                        for coord in points.dropFirst() { path.addLine(to: point(coord)) }
                        path.closeSubpath()
                        context.fill(path, with: .color(run.color.opacity(isCurrent ? 0.6 : 0.35)))
                        context.stroke(path, with: .color(run.color), lineWidth: isCurrent ? 2.5 : 1.2)
                    }
                }
                .frame(width: 116, height: 74)
                .background(RoundedRectangle(cornerRadius: 7).fill(Color(nsColor: .controlBackgroundColor)))
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(isCurrent ? run.color : Color(nsColor: .separatorColor).opacity(0.5), lineWidth: isCurrent ? 2 : 1)
                )

                Text(run.name)
                    .font(.caption2)
                    .lineLimit(1)
                    .frame(width: 116)
                Text("c. \(abs(run.startBCE))\u{2013}\(abs(run.endBCE)) BCE")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(width: 116)
            }
            .foregroundStyle(.primary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .pointingHand()
        .help("Jump to the \(run.name)")
    }
}