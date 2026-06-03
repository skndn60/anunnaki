import SwiftUI
import SwiftData

/// Input screen for managing eras (time periods for the timeline).
struct EraListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Era.orderIndex) private var eras: [Era]
    @State private var showingAddSheet = false
    @State private var editingEra: Era?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Eras")
                    .font(.title2.bold())
                Spacer()
                Button(action: { showingAddSheet = true }) {
                    Label("Add Era", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()

            Divider()

            if eras.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("No eras defined")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Text("Define time periods to organize figures on the timeline.")
                        .font(.body)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 300)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                List(eras) { era in
                    EraRow(era: era, onEdit: { editingEra = era }, onDelete: { modelContext.delete(era) })
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            EraFormView(era: nil)
        }
        .sheet(item: $editingEra) { era in
            EraFormView(era: era)
        }
    }
}

struct EraRow: View {
    let era: Era
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Text("\(era.orderIndex)")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .frame(width: 20)
            Text(era.name)
                .fontWeight(.medium)
            Text(era.startDate.displayLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("→")
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Text(era.endDate.displayLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
            if !era.eraDescription.isEmpty {
                Text(era.eraDescription)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            Spacer()
        }
    }
}

// MARK: - Era Form

struct EraFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss

    let era: Era?

    @State private var name = ""
    @State private var orderIndex = 0
    @State private var eraDescription = ""
    @State private var startDate: MythologicalDate = .unknown
    @State private var endDate: MythologicalDate = .unknown

    private var isEditing: Bool { era != nil }

    var body: some View {
        VStack(spacing: 0) {
            Text(isEditing ? "Edit Era" : "Add Era")
                .font(.title3.bold())
                .padding()

            Form {
                Section("Era Details") {
                    TextField("Name", text: $name, prompt: Text("e.g. Before the Flood"))
                    Stepper("Order: \(orderIndex)", value: $orderIndex, in: 0...100)
                }

                MythologicalDateEditor(label: "Start", date: $startDate)
                MythologicalDateEditor(label: "End", date: $endDate)

                Section("Description") {
                    TextEditor(text: $eraDescription)
                        .frame(minHeight: 60)
                }
            }
            .formStyle(.grouped)

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button(isEditing ? "Save" : "Add") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.isEmpty)
            }
            .padding()
        }
        .frame(width: 500, height: 580)
        .onAppear { loadIfEditing() }
    }

    private func loadIfEditing() {
        guard let era else { return }
        name = era.name
        orderIndex = era.orderIndex
        eraDescription = era.eraDescription
        startDate = era.startDate
        endDate = era.endDate
    }

    private func save() {
        if let era {
            era.name = name
            era.orderIndex = orderIndex
            era.eraDescription = eraDescription
            era.startDate = startDate
            era.endDate = endDate
        } else {
            let newEra = Era(
                name: name, orderIndex: orderIndex,
                eraDescription: eraDescription,
                startDate: startDate, endDate: endDate
            )
            modelContext.insert(newEra)
        }
        dismiss()
    }
}
