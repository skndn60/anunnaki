import SwiftUI
import SwiftData

/// Section showing associated things for a figure.
struct ThingsSection: View {
    let figure: Figure
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        Divider()
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Associated Things")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
                Button(action: { showThingLinkPopover = true }) {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .bold))
                }
                .buttonStyle(.plain)
                .help("Link a thing")
                .popover(isPresented: $showThingLinkPopover) {
                    ThingLinkPopover(
                        figure: figure,
                        searchText: $thingSearchText,
                        selectedThing: $selectedThingForLink,
                        selectedRole: $selectedThingRole,
                        isPresented: $showThingLinkPopover
                    )
                    .frame(width: 340, height: 400)
                }
            }

            if figure.thingAssociations.isEmpty {
                Text("No things linked")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 4)
            } else {
                ForEach(figure.thingAssociations) { assoc in
                    if let thing = assoc.thing {
                        HStack(spacing: 8) {
                            Image(systemName: thing.thingType?.icon ?? "shippingbox")
                                .font(.callout)
                                .foregroundStyle(thing.thingType?.color ?? .brown)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(assoc.displayName.map { "\(thing.name) as \($0)" } ?? thing.name)
                                    .font(.callout)
                                    .fontWeight(.medium)
                                HStack(spacing: 4) {
                                    Text(assoc.roleType?.displayName(isReverse: true) ?? "—")
                                        .font(.caption2)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 1)
                                        .background(RoundedRectangle(cornerRadius: 3).fill((thing.thingType?.color ?? .brown).opacity(0.12)))
                                    if !assoc.source.isEmpty {
                                        Text(assoc.source)
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                            }
                            Spacer()
                            Button(action: {
                                assocToDelete = assoc
                                showDeleteConfirm = true
                            }) {
                                Image(systemName: "trash")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.red.opacity(0.7))
                            }
                            .buttonStyle(.plain)
                            .help("Remove thing")
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .alert("Remove Thing?", isPresented: $showDeleteConfirm, presenting: assocToDelete) { assoc in
            Button("Remove", role: .destructive) {
                modelContext.delete(assoc)
                try? modelContext.save()
            }
            Button("Cancel", role: .cancel) {}
        } message: { assoc in
            Text("Remove the association between \(figure.name) and \(assoc.thing?.name ?? "?")?")
        }
    }

    @State private var showThingLinkPopover = false
    @State private var thingSearchText = ""
    @State private var selectedThingForLink: Thing?
    @State private var selectedThingRole: ThingFigureRoleType?
    @State private var assocToDelete: ThingFigureAssociation?
    @State private var showDeleteConfirm = false
}

private struct ThingLinkPopover: View {
    let figure: Figure
    @Binding var searchText: String
    @Binding var selectedThing: Thing?
    @Binding var selectedRole: ThingFigureRoleType?
    @Binding var isPresented: Bool

    @Environment(\.modelContext) private var modelContext
    @State private var allRoles: [ThingFigureRoleType] = []

    private var allThings: [Thing] {
        (try? modelContext.fetch(FetchDescriptor<Thing>(sortBy: [SortDescriptor(\.name)]))) ?? []
    }

    private var filteredThings: [Thing] {
        let linked = Set(figure.thingAssociations.compactMap { $0.thing?.persistentModelID })
        let available = allThings.filter { !linked.contains($0.persistentModelID) }
        if searchText.isEmpty { return available }
        return available.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search things…", text: $searchText)
                    .textFieldStyle(.roundedBorder)
            }

            if filteredThings.isEmpty {
                Text("No matching things")
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 20)
            } else {
                List(filteredThings, id: \.persistentModelID) { thing in
                    Button(action: { selectedThing = thing }) {
                        HStack(spacing: 10) {
                            Image(systemName: thing.thingType?.icon ?? "shippingbox")
                                .font(.caption)
                                .foregroundStyle(thing.thingType?.color ?? .brown)
                                .frame(width: 16)
                            Text(thing.name)
                                .font(.body)
                            Spacer()
                            if selectedThing?.persistentModelID == thing.persistentModelID {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.plain)
            }

            Divider()

            VStack(spacing: 8) {
                HStack {
                    Text("Role:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Picker("Role", selection: $selectedRole) {
                        Text("Select…").tag(nil as ThingFigureRoleType?)
                        ForEach(allRoles, id: \.persistentModelID) { role in
                            HStack(spacing: 6) {
                                Image(systemName: role.icon)
                                Text(role.name)
                            }
                            .tag(role as ThingFigureRoleType?)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                }

                HStack {
                    Spacer()
                    Button("Cancel") { isPresented = false }
                        .buttonStyle(.bordered)
                    Button("Link") {
                        createAssociation()
                        isPresented = false
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedThing == nil || selectedRole == nil)
                }
            }
        }
        .padding()
        .onAppear {
            allRoles = (try? modelContext.fetch(FetchDescriptor<ThingFigureRoleType>(sortBy: [SortDescriptor(\.name)]))) ?? []
        }
    }

    private func createAssociation() {
        guard let thing = selectedThing, let role = selectedRole else { return }
        let assoc = ThingFigureAssociation(figure: figure)
        modelContext.insert(assoc)
        figure.thingAssociations.append(assoc)
        thing.figureAssociations.append(assoc)
        role.associations.append(assoc)
        try? modelContext.save()
    }
}