import SwiftUI
import SwiftData

extension Source {
    /// Disambiguates same-titled sources in pickers and menus: appends the
    /// author when present, else the publication info. Falls back to the bare
    /// title so unnamed sources still read cleanly.
    var pickerLabel: String {
        if !author.isEmpty { return "\(name) — \(author)" }
        if !publicationInfo.isEmpty { return "\(name) — \(publicationInfo)" }
        return name
    }
}

/// A picker over the existing `Source` entities, with a "None" option.
/// Using existing sources (rather than free text) prevents spelling drift
/// across relationships that attest the same text.
struct SourcePickerView: View {
    @Binding var selection: Source?
    let sources: [Source]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Picker("Source", selection: $selection) {
                Text("None").tag(nil as Source?)
                ForEach(sources, id: \.persistentModelID) { source in
                    Text(source.pickerLabel).tag(source as Source?)
                }
            }
            if !sources.isEmpty {
                Text("Pick an existing source to keep spellings consistent.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}
