import SwiftUI

struct MythologicalDateEditor: View {
    let label: String
    @Binding var date: MythologicalDate

    @State private var startYearString: String = ""
    @State private var endYearString: String = ""
    @State private var isBCE: Bool = true

    var body: some View {
        Section(label) {
            TextField("Year", text: $startYearString, prompt: Text("e.g. 5500"))
                .onChange(of: startYearString) { _, _ in applyYears() }

            TextField("To (optional)", text: $endYearString, prompt: Text("leave blank for single year"))
                .onChange(of: endYearString) { _, _ in applyYears() }

            Picker("BCE/CE", selection: $isBCE) {
                Text("BCE").tag(true)
                Text("CE").tag(false)
            }
            .pickerStyle(.segmented)
            .onChange(of: isBCE) { _, _ in applyYears() }

            if rangeInvalid {
                Label("Year must be earlier than To", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Toggle("Approximate", isOn: $date.isApproximate)

            TextField("Period", text: $date.era, prompt: Text("e.g. Pre-Sumerian"))

            HStack {
                Text("Preview:")
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
            let ref = date.startYear ?? date.endYear ?? 0
            isBCE = ref < 0
            startYearString = date.startYear.map { "\(abs($0))" } ?? ""
            endYearString = date.endYear.map { "\(abs($0))" } ?? ""
        } else {
            startYearString = ""
            endYearString = ""
            isBCE = true
        }
    }

    private func applyYears() {
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
