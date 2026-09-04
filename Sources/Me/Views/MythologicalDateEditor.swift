import SwiftUI
import SwiftData

struct MythologicalDateEditor: View {
    let label: String
    @Binding var date: MythologicalDate
    /// The figure form supplies its own standalone Period picker instead, so
    /// the era link stays independent of any dates.
    var showsPeriodField: Bool = true

    @Environment(\.modelContext) private var modelContext
    @State private var startYearString: String = ""
    @State private var endYearString: String = ""
    @State private var isBCE: Bool = true
    @State private var eraNames: [String] = []

    var body: some View {
        Section(label) {
            TextField("Year", text: $startYearString, prompt: Text("5500"))
                .textFieldStyle(.roundedBorder)
                .onChange(of: startYearString) { _, _ in applyYears() }

            TextField("To (optional)", text: $endYearString, prompt: Text("leave blank for single year"))
                .textFieldStyle(.roundedBorder)
                .onChange(of: endYearString) { _, _ in applyYears() }

            Picker("BCE/CE", selection: $isBCE) {
                Text("BCE").tag(true)
                Text("CE").tag(false)
            }
            .pickerStyle(.segmented)
            .onChange(of: isBCE) { _, _ in applyYears() }

            if endYearString.isEmpty {
                Picker("Qualifier", selection: $date.qualifier) {
                    ForEach(MythologicalDate.DateQualifier.allCases, id: \.self) { q in
                        Text(q.label).tag(q)
                    }
                }
                .pickerStyle(.segmented)
            }

            if rangeInvalid {
                Label("Year must be earlier than To", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Toggle("Approximate", isOn: $date.isApproximate)

            if showsPeriodField {
                Picker("Period", selection: $date.era) {
                    Text("None").tag("")
                    ForEach(eraNames, id: \.self) { name in
                        Text(name).tag(name)
                    }
                    if !date.era.isEmpty && !eraNames.contains(date.era) {
                        Text("\(date.era) (not in era list)").tag(date.era)
                    }
                }
            }

            HStack {
                Text("Preview:")
                    .foregroundStyle(.secondary)
                Text(date.displayLabel)
                    .fontWeight(.medium)
            }
            .font(.caption)
        }
        .onAppear { loadFromDate() }
        .task { loadEraNames() }
    }

    private func loadEraNames() {
        let descriptor = FetchDescriptor<Era>(sortBy: [SortDescriptor(\Era.orderIndex)])
        eraNames = ((try? modelContext.fetch(descriptor)) ?? []).map(\.name)
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
