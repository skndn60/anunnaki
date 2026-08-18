import SwiftUI
import SwiftData

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
                    Text(source.name).tag(source as Source?)
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
