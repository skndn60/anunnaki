import SwiftUI
import SwiftData
import AppKit

/// Time-focused OpenHistoricalMap embedded on a group's page when the group has a
/// linked era (e.g. a dynasty subgroup). Reuses the dynasty map's historical engine
/// (`DynastyHistoricalMapView`) and the shared App Settings presentation keys.
struct GroupEraMapView: View {
    let group: FigureGroup

    @Environment(\.modelContext) private var modelContext
    @AppStorage("dynastyMapHistoricalStartupZoom") private var historicalStartupZoom = 5.0
    @AppStorage("dynastyMapHistoricalTheme") private var historicalThemeRaw = HistoricalMapTheme.historical.rawValue
    @AppStorage("dynastyMapHistoricalLanguage") private var historicalLanguageRaw = HistoricalMapLanguage.english.rawValue
    @AppStorage("dynastyMapLabelSize") private var labelSizeRaw = MapLabelSize.medium.rawValue

    @State private var zoomController = MapZoomController()

    private var memberFigures: [Figure] {
        group.effectiveMemberItems(in: modelContext).compactMap { $0.figure }
    }

    /// ISO-like year at the middle of the era's computed span (negative = BCE),
    /// used by the OHM date filter — mirrors the dynasty map's `dynastyDateString`.
    private var dateString: String? {
        let timeline = SKLDatePropagator.compute(figures: memberFigures, eraOrder: [:]).first
        guard let start = timeline?.startBCE, let end = timeline?.endBCE else { return nil }
        let midpoint = (start + end) / 2
        if midpoint < 0 { return String(format: "-%04d", -midpoint) }
        return String(format: "%04d", midpoint)
    }

    private var dateCaption: String {
        guard let dateString else { return "" }
        let negative = dateString.hasPrefix("-")
        let number = Int(dateString) ?? 0
        return "c. \(abs(number))\(negative ? " BCE" : " CE")"
    }

    private var mappable: [DynastyMapPlace] {
        group.directPlaces.compactMap { place in
            guard let latitude = place.latitude, let longitude = place.longitude else { return nil }
            return DynastyMapPlace(
                name: place.name,
                latitude: latitude,
                longitude: longitude,
                colorHex: Self.colorHex(from: place.placeType?.color ?? Color(white: 0.6))
            )
        }
    }

    /// The place whose name appears in the era's name is treated as the capital
    /// (the same heuristic the dynasty map uses) and gets the focus + highlight.
    private var capitalIndex: Int? {
        guard let eraName = group.era?.name else { return nil }
        return mappable.firstIndex { eraName.contains($0.name) }
    }

    private static func colorHex(from color: Color) -> String {
        guard let rgb = NSColor(color).usingColorSpace(.sRGB) else { return "#999999" }
        let r = Int(round(rgb.redComponent * 255))
        let g = Int(round(rgb.greenComponent * 255))
        let b = Int(round(rgb.blueComponent * 255))
        return String(format: "#%02X%02X%02X", r, g, b)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "clock.arrow.circlepath")
                Text("Era map")
                if let eraName = group.era?.name, !eraName.isEmpty {
                    Text(eraName)
                        .fontWeight(.semibold)
                }
                if !dateCaption.isEmpty {
                    Text(dateCaption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .font(.caption)
            .foregroundStyle(.primary)

            DynastyHistoricalMapView(
                places: mappable,
                capitalIndex: capitalIndex,
                focusToken: 0,
                dynastyColorHex: group.colorHex,
                startupZoom: historicalStartupZoom,
                theme: HistoricalMapTheme(rawValue: historicalThemeRaw) ?? .historical,
                language: historicalLanguageRaw,
                labelSize: (MapLabelSize(rawValue: labelSizeRaw) ?? .medium).basePx,
                dateString: dateString,
                defaultCenter: (44.4, 33.3),
                onPlaceSelected: { _ in },
                zoomController: zoomController
            )
            .frame(height: 260)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            if mappable.isEmpty {
                Text("No placed members yet. Add places to this group to mark them on this historical map.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
