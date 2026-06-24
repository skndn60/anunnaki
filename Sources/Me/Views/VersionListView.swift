import SwiftUI
import SwiftData

struct VersionListView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var versions: [DataVersion] = []
    @State private var showingCommitSheet = false
    @State private var showingBranchSheet = false
    @State private var selectedVersion: DataVersion?
    @State private var versionToDelete: DataVersion?
    @State private var showCheckoutAlert = false
    @State private var showDeleteAlert = false
    @State private var isCheckingOut = false
    @State private var commitName = ""
    @State private var branchName = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Versions")
                    .font(.title2.bold())
                Spacer()
                Button(action: { showingCommitSheet = true }) {
                    Label("Commit", systemImage: "plus.circle")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()

            Divider()

            if versions.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("No versions yet")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Text("Commit a snapshot to save the current database state.")
                        .font(.body)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 300)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                List(versions, id: \.id, selection: $selectedVersion) { version in
                    VersionRow(version: version, onRestore: { restoreVersion(version) }, onDelete: { confirmDelete(version) })
                        .tag(version)
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }
        }
        .frame(minWidth: 450, maxWidth: .infinity, minHeight: 300)
        .onAppear { loadVersions() }
        .onChange(of: modelContext) { loadVersions() }
        .toolbar {
            if selectedVersion != nil {
                ToolbarItemGroup {
                    Button(action: { showingBranchSheet = true }) {
                        Label("Branch", systemImage: "arrow.triangle.branch")
                    }
                    Button(action: { showCheckoutAlert = true }) {
                        Label("Checkout", systemImage: "arrow.counterclockwise")
                    }
                    Button(role: .destructive, action: { showDeleteAlert = true }) {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .sheet(isPresented: $showingCommitSheet) {
            commitSheet
        }
        .sheet(isPresented: $showingBranchSheet) {
            branchSheet
        }
        .alert("Restore \(selectedVersion?.name ?? "")?", isPresented: $showCheckoutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Restore", role: .destructive) { restoreSelectedVersion() }
        } message: {
            Text("This replaces all current data with the snapshot. Your current state will be auto-saved as a new version first.")
        }
        .alert("Delete \(versionToDelete?.name ?? "")?", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) { deleteVersion(versionToDelete) }
        } message: {
            Text("Delete this version and its snapshot file? This cannot be undone.")
        }
        .overlay {
            if isCheckingOut {
                ZStack {
                    Color(.windowBackgroundColor).opacity(0.8)
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Checking out version\u{2026}")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .ignoresSafeArea()
            }
        }
    }

    private var commitSheet: some View {
        VStack(spacing: 0) {
            Text("Commit Snapshot")
                .font(.title3.bold())
                .padding()

            Form {
                TextField("Commit message", text: $commitName, prompt: Text("e.g. Added Gilgamesh lineage"))
            }
            .formStyle(.grouped)

            HStack {
                Button("Cancel") { showingCommitSheet = false }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Commit") { commitSnapshot() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(commitName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()
        }
        .frame(width: 420, height: 180)
    }

    private var branchSheet: some View {
        VStack(spacing: 0) {
            Text("Create Branch")
                .font(.title3.bold())
                .padding()

            Form {
                TextField("Branch name", text: $branchName, prompt: Text("e.g. experimental-edits"))
                if let v = selectedVersion {
                    Text("From: \(v.name) (\(v.branch))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)

            HStack {
                Button("Cancel") { showingBranchSheet = false }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Create") { branchVersion() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(branchName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()
        }
        .frame(width: 420, height: 220)
    }

    private func loadVersions() {
        versions = VersionManager.log(context: modelContext)
    }

    private func commitSnapshot() {
        _ = VersionManager.commit(name: commitName, context: modelContext)
        commitName = ""
        showingCommitSheet = false
        loadVersions()
    }

    private func restoreSelectedVersion() {
        guard let version = selectedVersion else { return }
        restoreVersion(version)
    }

    private func restoreVersion(_ version: DataVersion) {
        isCheckingOut = true
        Task {
            await MainActor.run {
                VersionManager.checkout(version: version, context: modelContext)
                try? modelContext.save()
                isCheckingOut = false
                selectedVersion = nil
                loadVersions()
            }
        }
    }

    private func confirmDelete(_ version: DataVersion) {
        versionToDelete = version
        showDeleteAlert = true
    }

    private func branchVersion() {
        guard let version = selectedVersion else { return }
        _ = VersionManager.branch(name: branchName, fromVersion: version, context: modelContext)
        branchName = ""
        showingBranchSheet = false
        loadVersions()
    }

    private func deleteVersion(_ version: DataVersion?) {
        guard let version else { return }
        if selectedVersion?.id == version.id { selectedVersion = nil }
        versionToDelete = nil
        VersionManager.delete(version: version, context: modelContext)
        loadVersions()
    }
}

struct VersionRow: View {
    let version: DataVersion
    let onRestore: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(version.name)
                    .fontWeight(.medium)
                HStack(spacing: 6) {
                    Text(version.timestamp, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(version.timestamp, style: .time)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if version.branch != "main" {
                Text(version.branch)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.accentColor.opacity(0.12))
                    )
            }
            Button("Restore", role: .destructive, action: onRestore)
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
        .contextMenu {
            Button(action: onRestore) {
                Label("Restore This Version", systemImage: "arrow.counterclockwise")
            }
            Divider()
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}
