import SwiftUI
import SwiftData

/// Section showing associated places for a figure with comments editing.
struct PlacesSection: View {
    let figure: Figure
    let filterText: String
    var onSelectPlace: ((Place) -> Void)?

    @Environment(\.modelContext) private var modelContext

    private func matchesFilter(_ text: String) -> Bool {
        guard !filterText.isEmpty else { return true }
        return text.localizedCaseInsensitiveContains(filterText)
    }

    var body: some View {
        Divider()
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Associated Places")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
                Button(action: { showPlaceLinkPopover = true }) {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .bold))
                }
                .buttonStyle(.plain)
                .help("Link a place")
                .popover(isPresented: $showPlaceLinkPopover) {
                    PlaceLinkPopover(
                        figure: figure,
                        searchText: $placeSearchText,
                        selectedPlace: $selectedPlaceForLink,
                        selectedRole: $selectedPlaceRole,
                        isPresented: $showPlaceLinkPopover
                    )
                    .frame(width: 340, height: 400)
                }
            }

            if figure.placeAssociations.isEmpty {
                Text("No places linked")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 4)
            } else {
                let filteredPlaces = filterText.isEmpty ? figure.placeAssociations : figure.placeAssociations.filter {
                    matchesFilter($0.place?.name ?? "") || matchesFilter($0.roleType?.name ?? "") || matchesFilter($0.source)
                }
                ForEach(filteredPlaces) { assoc in
                    VStack(alignment: .leading, spacing: 2) {
                        FigurePlaceAssociationRow(association: assoc, onSelectPlace: onSelectPlace, onDelete: {
                            assocToDelete = assoc
                            showDeleteConfirm = true
                        })
                        if editingCommentsID == assoc.persistentModelID {
                            HStack(spacing: 4) {
                                TextField("Comments", text: $editingCommentsText)
                                    .textFieldStyle(.plain)
                                    .font(.caption)
                                    .onSubmit {
                                        assoc.comments = editingCommentsText.isEmpty ? nil : editingCommentsText
                                        editingCommentsID = nil
                                        try? modelContext.save()
                                    }
                                Button(action: {
                                    assoc.comments = editingCommentsText.isEmpty ? nil : editingCommentsText
                                    editingCommentsID = nil
                                    try? modelContext.save()
                                }) {
                                    Image(systemName: "checkmark")
                                        .font(.caption2)
                                        .foregroundStyle(.green)
                                }
                                .buttonStyle(.plain)
                                Button(action: {
                                    editingCommentsID = nil
                                }) {
                                    Image(systemName: "xmark")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.leading, 22)
                        } else if let comments = assoc.comments, !comments.isEmpty {
                            Button(action: {
                                editingCommentsText = comments
                                editingCommentsID = assoc.persistentModelID
                            }) {
                                HStack(spacing: 4) {
                                    Text(comments)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Image(systemName: "pencil")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .buttonStyle(.plain)
                            .padding(.leading, 22)
                        } else {
                            Button(action: {
                                editingCommentsText = ""
                                editingCommentsID = assoc.persistentModelID
                            }) {
                                HStack(spacing: 4) {
                                    Text("Add comment…")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                    Image(systemName: "plus")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .buttonStyle(.plain)
                            .padding(.leading, 22)
                        }
                    }
                }
            }
        }
        .alert("Delete Place Association?", isPresented: $showDeleteConfirm, presenting: assocToDelete) { assoc in
            Button("Delete", role: .destructive) {
                modelContext.delete(assoc)
                try? modelContext.save()
            }
            Button("Cancel", role: .cancel) {}
        } message: { assoc in
            Text("Delete the association between \(figure.name) and \(assoc.place?.name ?? "?")?")
        }
    }

    @State private var showPlaceLinkPopover = false
    @State private var placeSearchText = ""
    @State private var selectedPlaceForLink: Place?
    @State private var selectedPlaceRole: FigurePlaceRoleType?
    @State private var editingCommentsID: PersistentIdentifier?
    @State private var editingCommentsText: String = ""
    @State private var assocToDelete: FigurePlaceAssociation?
    @State private var showDeleteConfirm = false
}

private struct PlaceLinkPopover: View {
    let figure: Figure
    @Binding var searchText: String
    @Binding var selectedPlace: Place?
    @Binding var selectedRole: FigurePlaceRoleType?
    @Binding var isPresented: Bool

    @Environment(\.modelContext) private var modelContext
    @State private var allRoles: [FigurePlaceRoleType] = []
    @State private var comments: String = ""

    private var allPlaces: [Place] {
        (try? modelContext.fetch(FetchDescriptor<Place>(sortBy: [SortDescriptor(\.name)]))) ?? []
    }

    private var filteredPlaces: [Place] {
        let linked = Set(figure.placeAssociations.compactMap { $0.place?.persistentModelID })
        let available = allPlaces.filter { !linked.contains($0.persistentModelID) }
        if searchText.isEmpty { return available }
        return available.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search places…", text: $searchText)
                    .textFieldStyle(.roundedBorder)
            }

            if filteredPlaces.isEmpty {
                Text("No matching places")
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 20)
            } else {
                List(filteredPlaces, id: \.persistentModelID) { place in
                    Button(action: { selectedPlace = place }) {
                        HStack(spacing: 10) {
                            Image(systemName: place.placeType?.icon ?? "mappin")
                                .font(.caption)
                                .foregroundStyle(.teal)
                                .frame(width: 16)
                            Text(place.name)
                                .font(.body)
                            if !place.modernLocation.isEmpty {
                                Text(place.modernLocation)
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            Spacer()
                            if selectedPlace?.persistentModelID == place.persistentModelID {
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
                        Text("Select…").tag(nil as FigurePlaceRoleType?)
                        ForEach(allRoles, id: \.persistentModelID) { role in
                            HStack(spacing: 6) {
                                Image(systemName: role.icon)
                                Text(role.name)
                            }
                            .tag(role as FigurePlaceRoleType?)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Comments:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("e.g. first antediluvian king", text: $comments)
                        .textFieldStyle(.plain)
                        .padding(8)
                        .background(Color(.textBackgroundColor))
                        .cornerRadius(6)
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
                    .disabled(selectedPlace == nil || selectedRole == nil)
                }
            }
        }
        .padding()
        .onAppear {
            allRoles = (try? modelContext.fetch(FetchDescriptor<FigurePlaceRoleType>(sortBy: [SortDescriptor(\.name)]))) ?? []
        }
    }

    private func createAssociation() {
        guard let place = selectedPlace, let role = selectedRole else { return }
        let assoc = FigurePlaceAssociation(comments: comments.isEmpty ? nil : comments)
        modelContext.insert(assoc)
        figure.placeAssociations.append(assoc)
        place.figureAssociations.append(assoc)
        role.associations.append(assoc)
        try? modelContext.save()
    }
}