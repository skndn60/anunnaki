import SwiftUI
import SwiftData

struct PlaceTypeManagerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss

    @State private var placeTypes: [PlaceType] = []
    @State private var editingType: PlaceType?
    @State private var showingAdd = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Place Types")
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
                    ForEach(placeTypes, id: \.persistentModelID) { type in
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
                            Text("\(type.places.count) places")
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
            PlaceTypeEditView(type: type)
        }
        .sheet(isPresented: $showingAdd) {
            PlaceTypeEditView(type: nil)
        }
    }

    private func reload() {
        placeTypes = (try? modelContext.fetch(FetchDescriptor<PlaceType>(sortBy: [SortDescriptor(\.name)]))) ?? []
    }
}

private struct PlaceTypeEditView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss
    let type: PlaceType?

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
                TextField("Name", text: $name, prompt: Text("e.g. City, Temple, Region"))
                TextField("SF Symbol", text: $icon, prompt: Text("e.g. building.2, building.columns, map"))
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
            let newType = PlaceType(name: name, icon: icon, colorHex: color.hex)
            modelContext.insert(newType)
        }
        try? modelContext.save()
        dismiss()
    }
}
