import SwiftUI

/// A reusable form section for editing a MythologicalDate.
struct MythologicalDateEditor: View {
    let label: String
    @Binding var date: MythologicalDate

    @State private var hasYear: Bool = false
    @State private var yearString: String = ""
    @State private var isBCE: Bool = true

    var body: some View {
        Section(label) {
            Toggle("Has numeric year", isOn: $hasYear)
                .onChange(of: hasYear) { _, newValue in
                    if !newValue {
                        date.year = nil
                    } else {
                        applyYear()
                    }
                }

            if hasYear {
                HStack {
                    TextField("Year", text: $yearString, prompt: Text("e.g. 445000"))
                        .onChange(of: yearString) { _, _ in applyYear() }

                    Picker("", selection: $isBCE) {
                        Text("BCE").tag(true)
                        Text("CE").tag(false)
                    }
                    .frame(width: 80)
                    .onChange(of: isBCE) { _, _ in applyYear() }
                }

                Toggle("Approximate", isOn: $date.isApproximate)
            }

            TextField("Era", text: $date.era, prompt: Text("e.g. Before the Flood"))

            // Preview
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
        if let year = date.year {
            hasYear = true
            isBCE = year < 0
            yearString = "\(abs(year))"
        } else {
            hasYear = false
            yearString = ""
            isBCE = true
        }
    }

    private func applyYear() {
        guard hasYear, let value = Int(yearString), value > 0 else {
            if hasYear && yearString.isEmpty {
                date.year = nil
            }
            return
        }
        date.year = isBCE ? -value : value
    }
}
