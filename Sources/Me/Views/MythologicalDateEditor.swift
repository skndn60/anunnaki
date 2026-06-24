import SwiftUI

/// A reusable form section for editing a MythologicalDate with range support.
struct MythologicalDateEditor: View {
    let label: String
    @Binding var date: MythologicalDate

    @State private var hasYear: Bool = false
    @State private var startYearString: String = ""
    @State private var endYearString: String = ""
    @State private var isBCE: Bool = true

    var body: some View {
        Section(label) {
            Toggle("Has numeric year", isOn: $hasYear)
                .onChange(of: hasYear) { _, newValue in
                    if !newValue {
                        date.startYear = nil
                        date.endYear = nil
                    } else {
                        applyYears()
                    }
                }

            if hasYear {
                HStack {
                    TextField("Start year", text: $startYearString, prompt: Text("e.g. 1240"))
                        .onChange(of: startYearString) { _, _ in applyYears() }

                    Picker("", selection: $isBCE) {
                        Text("BCE").tag(true)
                        Text("CE").tag(false)
                    }
                    .frame(width: 80)
                    .onChange(of: isBCE) { _, _ in applyYears() }
                }
                .help("Earliest possible date")

                HStack {
                    TextField("End year", text: $endYearString, prompt: Text("Optional — leave blank if unknown"))
                        .onChange(of: endYearString) { _, _ in applyYears() }
                }
                .help("Latest possible date (leave blank for a single year)")

                if rangeInvalid {
                    Label("Start year must be earlier than end year (start: \(startYearString), end: \(endYearString))", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Toggle("Approximate", isOn: $date.isApproximate)
            }

            TextField("Era", text: $date.era, prompt: Text("e.g. Before the Flood"))

            HStack {
                Text("Displays as:")
                    .foregroundStyle(.secondary)
                Text(date.displayLabel)
                    .fontWeight(.medium)
            }
            .font(.caption)
        }
        .onAppear { loadFromDate() }
    }

    private func loadFromDate() {
        if date.startYear != nil || date.endYear != nil {
            hasYear = true
            let ref = date.startYear ?? date.endYear ?? 0
            isBCE = ref < 0
            startYearString = date.startYear.map { "\(abs($0))" } ?? ""
            endYearString = date.endYear.map { "\(abs($0))" } ?? ""
        } else {
            hasYear = false
            startYearString = ""
            endYearString = ""
            isBCE = true
        }
    }

    private func applyYears() {
        guard hasYear else {
            date.startYear = nil
            date.endYear = nil
            return
        }
        date.startYear = parseYear(startYearString)
        date.endYear = parseYear(endYearString)
    }

    private var rangeInvalid: Bool {
        guard let s = parseYear(startYearString), let e = parseYear(endYearString) else { return false }
        return s > e
    }

    private func parseYear(_ str: String) -> Int? {
        guard let value = Int(str), value > 0 else { return nil }
        return isBCE ? -value : value
    }
}
