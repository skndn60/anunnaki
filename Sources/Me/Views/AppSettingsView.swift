import SwiftUI

struct AppSettingsView: View {
    @AppStorage("dynastyMapModernStartupZoom") private var modernStartupZoom = 6.0
    @AppStorage("dynastyMapHistoricalStartupZoom") private var historicalStartupZoom = 5.0
    @AppStorage("dynastyMapModernStyle") private var modernMapStyleRaw = ModernMapStyle.standard.rawValue
    @AppStorage("dynastyMapModernMuted") private var modernMapMuted = false
    @AppStorage("dynastyMapHistoricalTheme") private var historicalThemeRaw = HistoricalMapTheme.historical.rawValue
    @AppStorage("dynastyMapHistoricalLanguage") private var historicalLanguageRaw = HistoricalMapLanguage.english.rawValue
    @AppStorage("dynastyMapLabelSize") private var labelSizeRaw = MapLabelSize.medium.rawValue
    @AppStorage("dynastyMapDateFilter") private var dateFilterEnabled = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("App Settings")
                .font(.title2.bold())
            Text("General preferences. Settings apply the next time the relevant view opens.")
                .font(.callout)
                .foregroundStyle(.secondary)
            Divider()
            Form {
                Section {
                    zoomRow(
                        title: "Modern map startup zoom",
                        value: $modernStartupZoom,
                        caption: "Zoom used when the Dynasty Map opens with the Modern (MapKit) style."
                    )
                    zoomRow(
                        title: "Historical map startup zoom",
                        value: $historicalStartupZoom,
                        caption: "Zoom used when the Dynasty Map opens with the Historical (OpenHistoricalMap) style."
                    )
                    Divider()
                    Picker("Modern map style", selection: $modernMapStyleRaw) {
                        ForEach(ModernMapStyle.allCases) { style in
                            Text(style.displayName).tag(style.rawValue)
                        }
                    }
                    if modernMapStyleRaw == ModernMapStyle.standard.rawValue {
                        Toggle("Quiet modern basemap", isOn: $modernMapMuted)
                            .help("Uses a muted, less colorful standard basemap.")
                    }
                    Divider()
                    Picker("Historical map theme", selection: $historicalThemeRaw) {
                        ForEach(HistoricalMapTheme.allCases) { theme in
                            Text(theme.displayName).tag(theme.rawValue)
                        }
                    }
                    Picker("Historical map label language", selection: $historicalLanguageRaw) {
                        ForEach(HistoricalMapLanguage.allCases) { lang in
                            Text(lang.displayName).tag(lang.rawValue)
                        }
                    }
                    Picker("Map label size", selection: $labelSizeRaw) {
                        ForEach(MapLabelSize.allCases) { size in
                            Text(size.displayName).tag(size.rawValue)
                        }
                    }
                    Toggle("Filter historical map to dynasty era", isOn: $dateFilterEnabled)
                        .help("Experimental: OpenHistoricalMap coverage of deep-past eras is sparse.")
                } header: {
                    Text("Dynasty Map")
                } footer: {
                    Text("Higher zoom numbers show a closer view. The date filter fades features that did not yet exist in the selected dynasty's era.")
                }
            }
            .formStyle(.grouped)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func zoomRow(title: String, value: Binding<Double>, caption: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text(value.wrappedValue.formatted(.number.precision(.fractionLength(1))))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: 2...10, step: 0.5)
            Text(caption)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}
