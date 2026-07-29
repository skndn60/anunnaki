import SwiftUI

struct DescriptionEditorSheet: View {
    @Environment(\.dismiss) var dismiss

    let entityName: String
    @Binding var richDescription: Data?
    @Binding var plainDescription: String
    var onSave: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            Text("Edit \(entityName) Description")
                .font(.headline)
                .padding()

            RichTextEditorSection(richData: $richDescription, plainText: $plainDescription)
                .padding(.horizontal)
                .frame(minHeight: 250)

            Divider()

            HStack {
                Button("Cancel", action: { dismiss() })
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Save") {
                    onSave?()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: 640, height: 480)
    }
}
