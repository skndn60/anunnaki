import SwiftUI
import SwiftData
import AppKit

/// Borderless splash panel content. Owned by the app delegate (not the main
/// window), so it is on screen from the very first frame while seeding runs.
struct SplashScreenView: View {
    var onContinue: (() -> Void)?

    @State private var isSeeding = true
    @Environment(\.modelContext) private var modelContext

    private static let minimumDisplayDuration: TimeInterval = 0.6

    var body: some View {
        ZStack {
            Color(red: 0.07, green: 0.14, blue: 0.32)
                .ignoresSafeArea()
            VStack(spacing: 0) {
                Spacer()
                appLogo
                Text("Me")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.white.opacity(0.95))
                    .padding(.top, 10)
                Spacer()
                splashStatus
                    .frame(height: 64)
                    .padding(.bottom, 16)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .contentShape(Rectangle())
        .onTapGesture { continueIfReady() }
        .onExitCommand { continueIfReady() }
        .animation(.easeInOut(duration: 0.35), value: isSeeding)
        .task {
            let container = modelContext.container
            let started = Date()
            SeedRunner.start(container: container) { failures in
                StartupReport.shared.migrationFailures = failures
                let remaining = max(0, Self.minimumDisplayDuration - Date().timeIntervalSince(started))
                DispatchQueue.main.asyncAfter(deadline: .now() + remaining) {
                    isSeeding = false
                }
            }
        }
    }

    private func continueIfReady() {
        guard !isSeeding else { return }
        onContinue?()
    }

    @ViewBuilder
    private var appLogo: some View {
        if let iconURL = Bundle.module.url(forResource: "AppIcon", withExtension: "png"),
           let nsImage = NSImage(contentsOf: iconURL) {
            Image(nsImage: nsImage)
                .resizable()
                .interpolation(.high)
                .frame(width: 110, height: 110)
        } else {
            Image(systemName: "sun.horizon.fill")
                .resizable()
                .frame(width: 140, height: 140)
                .foregroundStyle(.white.opacity(0.9))
        }
    }

    @ViewBuilder
    private var splashStatus: some View {
        if isSeeding {
            VStack(spacing: 14) {
                ProgressView()
                    .controlSize(.small)
                    .tint(.white)
                Text("Preparing database, please wait\u{2026}")
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.92))
            }
        } else {
            Button(action: continueIfReady) {
                VStack(spacing: 14) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(.white)
                    Text("Initialisation complete. Click to continue")
                        .font(.callout)
                        .foregroundStyle(.white.opacity(0.92))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.defaultAction)
        }
    }
}