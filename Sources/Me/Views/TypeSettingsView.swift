import SwiftUI
import SwiftData

struct TypeSettingsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                GroupBox {
                    VStack(alignment: .leading, spacing: 16) {
                        sectionHeader("Entity Types")
                        EntityTypeSubSection<FigureType>(
                            title: "Figure Types",
                            icon: "person.fill",
                            color: .blue
                        )
                        Divider()
                        EntityTypeSubSection<PlaceType>(
                            title: "Place Types",
                            icon: "building.columns",
                            color: .green
                        )
                        Divider()
                        EntityTypeSubSection<EventType>(
                            title: "Event Types",
                            icon: "bolt",
                            color: .orange
                        )
                        Divider()
                        EntityTypeSubSection<ThingType>(
                            title: "Thing Types",
                            icon: "cube.box",
                            color: .purple
                        )
                    }
                    .padding()
                }

                GroupBox {
                    VStack(alignment: .leading, spacing: 16) {
                        sectionHeader("Relationship Types")
                        RelationshipTypeSubSection()
                    }
                    .padding()
                }

                GroupBox {
                    VStack(alignment: .leading, spacing: 16) {
                        sectionHeader("Pantheons")
                        PantheonSubSection()
                    }
                    .padding()
                }

                GroupBox {
                    VStack(alignment: .leading, spacing: 16) {
                        sectionHeader("Association Role Types")
                        RoleTypeSubSection<FigurePlaceRoleType>(
                            title: "Figure ↔ Place",
                            icon: "person.fill.questionmark",
                            color: .teal
                        )
                        Divider()
                        RoleTypeSubSection<PlacePlaceRoleType>(
                            title: "Place ↔ Place",
                            icon: "building.2",
                            color: .green
                        )
                        Divider()
                        RoleTypeSubSection<EventEventRoleType>(
                            title: "Event ↔ Event",
                            icon: "bolt.horizontal",
                            color: .orange
                        )
                        Divider()
                        RoleTypeSubSection<EventPlaceRoleType>(
                            title: "Event ↔ Place",
                            icon: "mappin.and.ellipse",
                            color: .indigo
                        )
                    }
                    .padding()
                }
            }
            .padding()
        }
        .navigationTitle("Type Settings")
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.headline)
            .foregroundStyle(.secondary)
    }
}

// MARK: - Entity Type Sub-Section (FigureType, PlaceType, EventType)

private struct EntityTypeSubSection<T: EntityTypeProtocol>: View {
    let title: String
    let icon: String
    let color: Color

    @Environment(\.modelContext) private var modelContext
    @State private var items: [T] = []
    @State private var editingItem: T?
    @State private var showingAdd = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(color)
                Text(title)
                    .font(.callout.bold())
                Spacer()
                Text("\(items.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button(action: { showingAdd = true }) {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(color)
                }
                .buttonStyle(.plain)
                .help("Add \(title.lowercased())")
            }

            if items.isEmpty {
                Text("No \(title.lowercased())")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.leading, 4)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(items, id: \.persistentModelID) { item in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(item.uiColor)
                                .frame(width: 14, height: 14)
                            Image(systemName: item.uiIcon)
                                .font(.caption2)
                                .foregroundStyle(item.uiColor)
                                .frame(width: 12)
                            Text(item.uiName)
                                .font(.caption)
                            Text("(\(item.countValue) \(item.countLabel))")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                            Spacer()
                            Button("Edit") { editingItem = item }
                                .buttonStyle(.plain)
                                .font(.caption)
                                .foregroundColor(.accentColor)
                        }
                        .padding(.vertical, 3)
                        .padding(.horizontal, 6)
                        .background(.quaternary.opacity(0.15))
                        .cornerRadius(4)
                    }
                }
            }
        }
        .onAppear { reload() }
        .onChange(of: editingItem) { _, _ in if editingItem == nil { reload() } }
        .onChange(of: showingAdd) { _, _ in if !showingAdd { reload() } }
        .sheet(item: $editingItem) { item in
            EntityTypeEditSheetView<T>(item: item)
        }
        .sheet(isPresented: $showingAdd) {
            EntityTypeEditSheetView<T>(item: nil)
        }
    }

    private func reload() {
        items = (try? modelContext.fetch(FetchDescriptor<T>(sortBy: [SortDescriptor(\.name)]))) ?? []
    }
}

// MARK: - Relationship Type Sub-Section

private struct RelationshipTypeSubSection: View {
    @Environment(\.modelContext) private var modelContext
    @State private var items: [RelationshipType] = []
    @State private var editingItem: RelationshipType?
    @State private var showingAdd = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "arrow.triangle.branch")
                    .font(.caption)
                    .foregroundStyle(.purple)
                Text("Relationship Types")
                    .font(.callout.bold())
                Spacer()
                Text("\(items.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button(action: { showingAdd = true }) {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.purple)
                }
                .buttonStyle(.plain)
                .help("Add relationship type")
            }

            if items.isEmpty {
                Text("No relationship types")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.leading, 4)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(items, id: \.persistentModelID) { item in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(item.color)
                                .frame(width: 14, height: 14)
                            Image(systemName: item.icon)
                                .font(.caption2)
                                .foregroundStyle(item.color)
                                .frame(width: 12)
                            Text(item.name)
                                .font(.caption)
                            Text(item.category)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(.quaternary.opacity(0.3))
                                .cornerRadius(3)
                            Text("(\(item.relationships.count) relationships)")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                            Spacer()
                            Button("Edit") { editingItem = item }
                                .buttonStyle(.plain)
                                .font(.caption)
                                .foregroundColor(.accentColor)
                        }
                        .padding(.vertical, 3)
                        .padding(.horizontal, 6)
                        .background(.quaternary.opacity(0.15))
                        .cornerRadius(4)
                    }
                }
            }
        }
        .onAppear { reload() }
        .onChange(of: editingItem) { _, _ in if editingItem == nil { reload() } }
        .onChange(of: showingAdd) { _, _ in if !showingAdd { reload() } }
        .sheet(item: $editingItem) { item in
            RelationshipTypeEditSheetView(item: item)
        }
        .sheet(isPresented: $showingAdd) {
            RelationshipTypeEditSheetView(item: nil)
        }
    }

    private func reload() {
        items = (try? modelContext.fetch(FetchDescriptor<RelationshipType>(sortBy: [SortDescriptor(\.name)]))) ?? []
    }
}

// MARK: - Role Type Sub-Section (FigurePlaceRoleType, etc.)

private struct RoleTypeSubSection<T: RoleTypeProtocol>: View {
    let title: String
    let icon: String
    let color: Color

    @Environment(\.modelContext) private var modelContext
    @State private var items: [T] = []
    @State private var editingItem: T?
    @State private var showingAdd = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(color)
                Text(title)
                    .font(.callout.bold())
                Spacer()
                Text("\(items.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button(action: { showingAdd = true }) {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(color)
                }
                .buttonStyle(.plain)
                .help("Add role type")
            }

            if items.isEmpty {
                Text("No \(title.lowercased()) role types")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.leading, 4)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(items, id: \.persistentModelID) { item in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(item.uiColor)
                                .frame(width: 14, height: 14)
                            Image(systemName: item.uiIcon)
                                .font(.caption2)
                                .foregroundStyle(item.uiColor)
                                .frame(width: 12)
                            Text(item.uiName)
                                .font(.caption)
                            Spacer()
                            Button("Edit") { editingItem = item }
                                .buttonStyle(.plain)
                                .font(.caption)
                                .foregroundColor(.accentColor)
                        }
                        .padding(.vertical, 3)
                        .padding(.horizontal, 6)
                        .background(.quaternary.opacity(0.15))
                        .cornerRadius(4)
                    }
                }
            }
        }
        .onAppear { reload() }
        .onChange(of: editingItem) { _, _ in if editingItem == nil { reload() } }
        .onChange(of: showingAdd) { _, _ in if !showingAdd { reload() } }
        .sheet(item: $editingItem) { item in
            RoleTypeEditSheetView<T>(item: item)
        }
        .sheet(isPresented: $showingAdd) {
            RoleTypeEditSheetView<T>(item: nil)
        }
    }

    private func reload() {
        items = (try? modelContext.fetch(FetchDescriptor<T>(sortBy: [SortDescriptor(\.name)]))) ?? []
    }
}

// MARK: - Edit Sheet Views

// Entity types: FigureType, PlaceType, EventType

private struct EntityTypeEditSheetView<T: EntityTypeProtocol>: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss
    let item: T?

    @State private var name = ""
    @State private var icon = ""
    @State private var color: Color = .gray

    private var isEditing: Bool { item != nil }

    var body: some View {
        VStack(spacing: 0) {
            Text(isEditing ? "Edit Type" : "Add Type")
                .font(.title3.bold())
                .padding()
            Form {
                TextField("Name", text: $name, prompt: Text("e.g. Deity, City, Battle"))
                TextField("SF Symbol", text: $icon, prompt: Text("e.g. star, building.2, bolt"))
                ColorPicker("Color", selection: $color, supportsOpacity: false)
            }
            .formStyle(.grouped)
            .padding()
            HStack {
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
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
        guard let item else { return }
        name = item.name
        icon = item.uiIcon
        color = item.uiColor
    }

    private func save() {
        if let existing = item {
            existing.name = name
            (existing as? any IconColorSettable)?.setIcon(icon)
            (existing as? any IconColorSettable)?.setColorHex(color.hex)
        } else if let made = T.make(name: name, icon: icon, colorHex: color.hex) {
            modelContext.insert(made)
        }
        try? modelContext.save()
        dismiss()
    }
}

private protocol IconColorSettable {
    func setIcon(_ icon: String)
    func setColorHex(_ hex: String)
}
extension FigureType: IconColorSettable {
    func setIcon(_ i: String) { icon = i }
    func setColorHex(_ h: String) { colorHex = h }
}
extension PlaceType: IconColorSettable {
    func setIcon(_ i: String) { icon = i }
    func setColorHex(_ h: String) { colorHex = h }
}
extension EventType: IconColorSettable {
    func setIcon(_ i: String) { icon = i }
    func setColorHex(_ h: String) { colorHex = h }
}
extension ThingType: IconColorSettable {
    func setIcon(_ i: String) { icon = i }
    func setColorHex(_ h: String) { colorHex = h }
}
extension RelationshipType: IconColorSettable {
    func setIcon(_ i: String) { icon = i }
    func setColorHex(_ h: String) { colorHex = h }
}
extension FigurePlaceRoleType: IconColorSettable {
    func setIcon(_ i: String) { icon = i }
    func setColorHex(_ h: String) { colorHex = h }
}
extension PlacePlaceRoleType: IconColorSettable {
    func setIcon(_ i: String) { icon = i }
    func setColorHex(_ h: String) { colorHex = h }
}
extension EventEventRoleType: IconColorSettable {
    func setIcon(_ i: String) { icon = i }
    func setColorHex(_ h: String) { colorHex = h }
}
extension EventPlaceRoleType: IconColorSettable {
    func setIcon(_ i: String) { icon = i }
    func setColorHex(_ h: String) { colorHex = h }
}

// Relationship type

private struct RelationshipTypeEditSheetView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss
    let item: RelationshipType?

    @State private var name = ""
    @State private var icon = ""
    @State private var color: Color = .gray
    @State private var category = ""

    private var isEditing: Bool { item != nil }

    var body: some View {
        VStack(spacing: 0) {
            Text(isEditing ? "Edit Type" : "Add Type")
                .font(.title3.bold())
                .padding()
            Form {
                TextField("Name", text: $name, prompt: Text("e.g. Father, Ally, Commander"))
                TextField("SF Symbol", text: $icon, prompt: Text("e.g. heart, person.2.fill"))
                TextField("Category", text: $category, prompt: Text("e.g. parent, social, military"))
                ColorPicker("Color", selection: $color, supportsOpacity: false)
            }
            .formStyle(.grouped)
            .padding()
            HStack {
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button(isEditing ? "Save" : "Add") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.isEmpty || icon.isEmpty || category.isEmpty)
            }
            .padding()
        }
        .frame(width: 380, height: 340)
        .onAppear { loadIfEditing() }
    }

    private func loadIfEditing() {
        guard let item else { return }
        name = item.name
        icon = item.icon
        color = Color(hex: item.colorHex) ?? .gray
        category = item.category
    }

    private func save() {
        if let item {
            item.name = name
            item.icon = icon
            item.colorHex = color.hex
            item.category = category
        } else {
            let newItem = RelationshipType(name: name, icon: icon, colorHex: color.hex, category: category)
            modelContext.insert(newItem)
        }
        try? modelContext.save()
        dismiss()
    }
}

// Role types

private struct RoleTypeEditSheetView<T: RoleTypeProtocol>: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss
    let item: T?

    @State private var name = ""
    @State private var icon = ""
    @State private var color: Color = .gray

    private var isEditing: Bool { item != nil }

    var body: some View {
        VStack(spacing: 0) {
            Text(isEditing ? "Edit Role Type" : "Add Role Type")
                .font(.title3.bold())
                .padding()
            Form {
                TextField("Name", text: $name, prompt: Text("e.g. Located Within, Caused"))
                TextField("SF Symbol", text: $icon, prompt: Text("e.g. arrow.right.circle"))
                ColorPicker("Color", selection: $color, supportsOpacity: false)
            }
            .formStyle(.grouped)
            .padding()
            HStack {
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
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
        guard let item else { return }
        name = item.name
        icon = item.uiIcon
        color = item.uiColor
    }

    private func save() {
        if let existing = item {
            existing.name = name
            (existing as? any IconColorSettable)?.setIcon(icon)
            (existing as? any IconColorSettable)?.setColorHex(color.hex)
        } else if let made = T.make(name: name, icon: icon, colorHex: color.hex) {
            modelContext.insert(made)
        }
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Shared Protocols

private protocol EntityTypeProtocol: PersistentModel {
    var name: String { get set }
    var uiName: String { get }
    var uiIcon: String { get }
    var uiColor: Color { get }
    var countValue: Int { get }
    var countLabel: String { get }
    static func make(name: String, icon: String, colorHex: String) -> Self?
}

private protocol RoleTypeProtocol: PersistentModel {
    var name: String { get set }
    var uiName: String { get }
    var uiIcon: String { get }
    var uiColor: Color { get }
    static func make(name: String, icon: String, colorHex: String) -> Self?
}

extension FigureType: EntityTypeProtocol {
    var uiName: String { name }
    var uiIcon: String { icon }
    var uiColor: Color { color }
    var countValue: Int { figures.count }
    var countLabel: String { "figures" }
    static func make(name: String, icon: String, colorHex: String) -> FigureType? {
        FigureType(name: name, icon: icon, colorHex: colorHex)
    }
}
extension PlaceType: EntityTypeProtocol {
    var uiName: String { name }
    var uiIcon: String { icon }
    var uiColor: Color { color }
    var countValue: Int { places.count }
    var countLabel: String { "places" }
    static func make(name: String, icon: String, colorHex: String) -> PlaceType? {
        PlaceType(name: name, icon: icon, colorHex: colorHex)
    }
}
extension EventType: EntityTypeProtocol {
    var uiName: String { name }
    var uiIcon: String { icon }
    var uiColor: Color { color }
    var countValue: Int { events.count }
    var countLabel: String { "events" }
    static func make(name: String, icon: String, colorHex: String) -> EventType? {
        EventType(name: name, icon: icon, colorHex: colorHex)
    }
}
extension ThingType: EntityTypeProtocol {
    var uiName: String { name }
    var uiIcon: String { icon }
    var uiColor: Color { color }
    var countValue: Int { things.count }
    var countLabel: String { "things" }
    static func make(name: String, icon: String, colorHex: String) -> ThingType? {
        ThingType(name: name, icon: icon, colorHex: colorHex)
    }
}

extension FigurePlaceRoleType: RoleTypeProtocol {
    var uiName: String { name }
    var uiIcon: String { icon }
    var uiColor: Color { color }
    static func make(name: String, icon: String, colorHex: String) -> FigurePlaceRoleType? {
        FigurePlaceRoleType(name: name, icon: icon, colorHex: colorHex)
    }
}
extension PlacePlaceRoleType: RoleTypeProtocol {
    var uiName: String { name }
    var uiIcon: String { icon }
    var uiColor: Color { color }
    static func make(name: String, icon: String, colorHex: String) -> PlacePlaceRoleType? {
        PlacePlaceRoleType(name: name, icon: icon, colorHex: colorHex)
    }
}
extension EventEventRoleType: RoleTypeProtocol {
    var uiName: String { name }
    var uiIcon: String { icon }
    var uiColor: Color { color }
    static func make(name: String, icon: String, colorHex: String) -> EventEventRoleType? {
        EventEventRoleType(name: name, icon: icon, colorHex: colorHex)
    }
}
extension EventPlaceRoleType: RoleTypeProtocol {
    var uiName: String { name }
    var uiIcon: String { icon }
    var uiColor: Color { color }
    static func make(name: String, icon: String, colorHex: String) -> EventPlaceRoleType? {
        EventPlaceRoleType(name: name, icon: icon, colorHex: colorHex)
    }
}

// MARK: - Pantheon Sub-Section

private struct PantheonSubSection: View {
    @Environment(\.modelContext) private var modelContext
    @State private var items: [Pantheon] = []
    @State private var editingItem: Pantheon?
    @State private var showingAdd = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "building.columns.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.teal)
                Text("Pantheons")
                    .font(.callout.bold())
                Spacer()
                Text("\(items.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button(action: { showingAdd = true }) {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.teal)
                }
                .buttonStyle(.plain)
                .help("Add pantheon")
            }

            if items.isEmpty {
                Text("No pantheons")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.leading, 4)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(items, id: \.persistentModelID) { item in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(item.color)
                                .frame(width: 14, height: 14)
                            Image(systemName: item.icon)
                                .font(.caption2)
                                .foregroundStyle(item.color)
                                .frame(width: 12)
                            Text(item.name)
                                .font(.caption)
                            if !item.pantheonDescription.isEmpty {
                                Text(item.pantheonDescription)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                    .lineLimit(1)
                            }
                            Text("(\(item.figures.count) figures)")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                            Spacer()
                            Button("Edit") { editingItem = item }
                                .buttonStyle(.plain)
                                .font(.caption)
                                .foregroundColor(.accentColor)
                        }
                        .padding(.vertical, 3)
                        .padding(.horizontal, 6)
                        .background(.quaternary.opacity(0.15))
                        .cornerRadius(4)
                    }
                }
            }
        }
        .onAppear { reload() }
        .onChange(of: editingItem) { _, _ in if editingItem == nil { reload() } }
        .onChange(of: showingAdd) { _, _ in if !showingAdd { reload() } }
        .sheet(item: $editingItem) { item in
            PantheonEditSheetView(item: item)
        }
        .sheet(isPresented: $showingAdd) {
            PantheonEditSheetView(item: nil)
        }
    }

    private func reload() {
        items = (try? modelContext.fetch(FetchDescriptor<Pantheon>(sortBy: [SortDescriptor(\.name)]))) ?? []
    }
}

private struct PantheonEditSheetView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss
    let item: Pantheon?

    @State private var name = ""
    @State private var pantheonDescription = ""
    @State private var icon = ""
    @State private var color: Color = .gray

    private var isEditing: Bool { item != nil }

    var body: some View {
        VStack(spacing: 0) {
            Text(isEditing ? "Edit Pantheon" : "Add Pantheon")
                .font(.title3.bold())
                .padding()
            Form {
                TextField("Name", text: $name, prompt: Text("e.g. Mesopotamian, Greek"))
                TextField("Description", text: $pantheonDescription, prompt: Text("e.g. Gods of ancient Sumer and Akkad"))
                TextField("SF Symbol", text: $icon, prompt: Text("e.g. building.columns.circle.fill"))
                ColorPicker("Color", selection: $color, supportsOpacity: false)
            }
            .formStyle(.grouped)
            .padding()
            HStack {
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button(isEditing ? "Save" : "Add") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.isEmpty || icon.isEmpty)
            }
            .padding()
        }
        .frame(width: 380, height: 360)
        .onAppear { loadIfEditing() }
    }

    private func loadIfEditing() {
        guard let item else { return }
        name = item.name
        pantheonDescription = item.pantheonDescription
        icon = item.icon
        color = item.color
    }

    private func save() {
        if let item {
            item.name = name
            item.pantheonDescription = pantheonDescription
            item.icon = icon
            item.colorHex = color.hex
        } else {
            let newItem = Pantheon(name: name, pantheonDescription: pantheonDescription, icon: icon, colorHex: color.hex)
            modelContext.insert(newItem)
        }
        try? modelContext.save()
        dismiss()
    }
}
