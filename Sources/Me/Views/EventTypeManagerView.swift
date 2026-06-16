import SwiftUI
import SwiftData

struct EventTypeManagerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss

    @State private var eventTypes: [EventType] = []
    @State private var editingType: EventType?
    @State private var showingAdd = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Event Types")
                    .font(.title3.bold())
                Spacer()
                Button(action: { showingAdd = true }) {
                    Label("Add Type", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(eventTypes, id: \.persistentModelID) { type in
                        HStack(spacing: 10) {
                            Circle()
                                .fill(type.color)
                                .frame(width: 20, height: 20)
                            Image(systemName: type.icon)
                                .font(.caption)
                                .foregroundStyle(type.color)
                                .frame(width: 16)
                            Text(type.name)
                                .fontWeight(.medium)
                            Spacer()
                            Text("\(type.events.count) events")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Button("Edit") {
                                editingType = type
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(.accentColor)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        Divider()
                    }
                }
            }

            HStack {
                Button("Close") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
            }
            .padding()
        }
        .frame(width: 480, height: 400)
        .onAppear { reload() }
        .onChange(of: showingAdd) { _, _ in if !showingAdd { reload() } }
        .onChange(of: editingType) { _, _ in if editingType == nil { reload() } }
        .sheet(item: $editingType) { type in
            EventTypeEditView(type: type)
        }
        .sheet(isPresented: $showingAdd) {
            EventTypeEditView(type: nil)
        }
    }

    private func reload() {
        eventTypes = (try? modelContext.fetch(FetchDescriptor<EventType>(sortBy: [SortDescriptor(\.name)]))) ?? []
    }
}

private struct EventTypeEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss
    let type: EventType?

    @State private var name = ""
    @State private var icon = ""
    @State private var color: Color = .gray

    private var isEditing: Bool { type != nil }

    var body: some View {
        VStack(spacing: 0) {
            Text(isEditing ? "Edit Type" : "Add Type")
                .font(.title3.bold())
                .padding()

            Form {
                TextField("Name", text: $name, prompt: Text("e.g. Battle, Flood, Creation"))
                TextField("SF Symbol", text: $icon, prompt: Text("e.g. shield, water.waves, sparkles"))
                ColorPicker("Color", selection: $color, supportsOpacity: false)
            }
            .formStyle(.grouped)
            .padding()

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button(isEditing ? "Save" : "Add") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.isEmpty || icon.isEmpty)
            }
            .padding()
        }
        .frame(width: 380, height: 300)
        .onAppear { loadIfEditing() }
    }

    private func loadIfEditing() {
        guard let type else { return }
        name = type.name
        icon = type.icon
        color = Color(hex: type.colorHex) ?? .gray
    }

    private func save() {
        if let type {
            type.name = name
            type.icon = icon
            type.colorHex = color.hex
        } else {
            let newType = EventType(name: name, icon: icon, colorHex: color.hex)
            modelContext.insert(newType)
        }
        try? modelContext.save()
        dismiss()
    }
}
