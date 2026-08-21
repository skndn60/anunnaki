import SwiftUI

struct WizardContainer<Content: View>: View {
    let title: String
    let step: Int
    let totalSteps: Int
    let stepLabels: [String]
    let canGoBack: Bool
    let canGoNext: Bool
    let saveLabel: String
    let iconName: String?
    let iconColor: Color?
    /// The entity's name, shown in small type under the title on later steps
    /// so the user doesn't have to go back to the first screen to see it.
    var entityName: String? = nil
    let onCancel: () -> Void
    let onBack: () -> Void
    let onNext: () -> Void
    let onSave: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: 0) {
            if let iconName, let iconColor {
                decoration(iconName: iconName, color: iconColor)
            }

            VStack(spacing: 0) {
                Text(title)
                    .font(.title3.bold())
                    .padding(.top)
                    .padding(.horizontal)

                if let entityName, !entityName.isEmpty, step > 0 {
                    Text(entityName)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .padding(.horizontal)
                        .padding(.top, 2)
                }

                stepIndicator
                    .padding(.vertical, 8)

                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                Divider()
                bottomBar
                    .padding()
            }
        }
    }

    private func decoration(iconName: String, color: Color) -> some View {
        ZStack {
            LinearGradient(
                colors: [color.opacity(0.25), color.opacity(0.08), color.opacity(0.02)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(spacing: 0) {
                ForEach(0..<4, id: \.self) { i in
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: CGFloat(4 + i * 2), height: CGFloat(4 + i * 2))
                }
                Spacer()
            }
            .padding(.top, 16)

            Image(systemName: iconName)
                .font(.system(size: 56))
                .foregroundStyle(color.opacity(0.35))

            VStack(spacing: 0) {
                Spacer()
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(color.opacity(0.12))
                        .frame(width: CGFloat(6 - i), height: CGFloat(6 - i))
                        .padding(.bottom, 4)
                }
            }
            .padding(.bottom, 16)
        }
        .frame(width: 150)
        .frame(maxHeight: .infinity)
        .clipped()
    }

    private var stepIndicator: some View {
        VStack(spacing: 6) {
            HStack(spacing: 0) {
                ForEach(0..<totalSteps, id: \.self) { i in
                    let isActive = i == step
                    let isComplete = i < step
                    Circle()
                        .fill(isActive ? Color.accentColor : isComplete ? Color.green : Color.gray.opacity(0.3))
                        .frame(width: 10, height: 10)
                        .overlay(
                            Circle()
                                .stroke(isActive ? Color.accentColor : Color.clear, lineWidth: 2)
                                .scaleEffect(1.4)
                        )
                    if i < totalSteps - 1 {
                        Rectangle()
                            .fill(i < step ? Color.green : Color.gray.opacity(0.2))
                            .frame(height: 2)
                            .frame(maxWidth: 40)
                    }
                }
            }

            Text(stepLabels[safe: step] ?? "")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
    }

    private var bottomBar: some View {
        HStack {
            Button("Cancel", action: onCancel)
                .keyboardShortcut(.cancelAction)
            Spacer()
            if canGoBack {
                Button("Back", action: onBack)
            }
            if step < totalSteps - 1 {
                Button("Next", action: onNext)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canGoNext)
            } else {
                Button(saveLabel, action: onSave)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canGoNext)
                    .buttonStyle(.borderedProminent)
            }
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
