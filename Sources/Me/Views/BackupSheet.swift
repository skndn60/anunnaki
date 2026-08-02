import SwiftUI
import AppKit

struct BackupSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var status = ""
    @State private var isFailure = false
    @State private var showRestoreConfirm = false
    @State private var selectedRestoreURL: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Backup & Restore")
                .font(.title2.bold())

            Text("Create a full snapshot of your database, or restore from an earlier one. Backups are copies of the entire store and include everything: figures, places, events, things, groups, sources, and their relationships.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 8) {
                Button {
                    Task { await backUpNow() }
                } label: {
                    Label("Back Up Now", systemImage: "archivebox")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    chooseRestore()
                } label: {
                    Label("Restore from Backup\u{2026}", systemImage: "arrow.uturn.backward.circle")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.bordered)

                if BackupService.isValidBackup(BackupService.storeDirectory.appendingPathComponent("MeBackup-prestore")) {
                    Text("A pre-restore safety copy exists on disk (MeBackup-prestore) from the last restore you performed.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            if !status.isEmpty {
                Label(status, systemImage: isFailure ? "exclamationmark.triangle" : "checkmark.circle")
                    .font(.callout)
                    .foregroundStyle(isFailure ? Color.red : Color.secondary)
            }

            Spacer()

            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.bordered)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 420, height: 260)
        .alert("Restore Backup?", isPresented: $showRestoreConfirm) {
            Button("Yes, Restore & Quit") {
                completeRestore()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The backup will be applied when Me relaunches. Quit now to complete the restore? Your current data will be saved to a safety copy (MeBackup-prestore).")
        }
    }

    private func backUpNow() async {
        status = ""
        isFailure = false
        switch await BackupService.chooseAndBackup() {
        case .success(let folder):
            status = "Backup created at \(folder.lastPathComponent)"
        case .failure(let error):
            isFailure = true
            status = error.localizedDescription
        }
    }

    private func chooseRestore() {
        let panel = NSOpenPanel()
        panel.title = "Choose a Backup Folder"
        panel.prompt = "Select"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }

        guard BackupService.isValidBackup(url) else {
            isFailure = true
            status = "That folder does not contain a Me.store backup."
            return
        }
        selectedRestoreURL = url
        showRestoreConfirm = true
    }

    private func completeRestore() {
        guard let url = selectedRestoreURL else { return }
        BackupService.stageRestore(from: url)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            NSApplication.shared.terminate(nil)
        }
    }
}