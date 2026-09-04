import SwiftUI

struct ToolbarButton {
    let icon: String
    let color: Color
    let help: String
    var isEnabled: Bool = true
    let action: () -> Void
}

struct DetailToolbar: View {
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onClose: () -> Void
    var onEditDescription: (() -> Void)? = nil
    var leadingButtons: [ToolbarButton] = []

    var body: some View {
        HStack(spacing: 8) {
            IconActionButton(icon: "pencil", color: .accentColor, help: "Edit", action: onEdit)
            if let onEditDescription {
                IconActionButton(icon: "square.and.pencil", color: .accentColor, help: "Edit description", action: onEditDescription)
            }
            IconActionButton(icon: "trash", color: .red, help: "Delete", action: onDelete)

            ForEach(leadingButtons.indices, id: \.self) { index in
                let btn = leadingButtons[index]
                IconActionButton(icon: btn.icon, color: btn.color, help: btn.help, action: btn.action)
                    .disabled(!btn.isEnabled)
            }

            Spacer()

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .background(RoundedRectangle(cornerRadius: 5).fill(Color.secondary.opacity(0.1)))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 8)
    }
}
