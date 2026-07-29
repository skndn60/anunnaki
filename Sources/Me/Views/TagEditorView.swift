import SwiftUI
import SwiftData

struct TagEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Tag.name) private var allTags: [Tag]
    @Binding var tags: [Tag]
    @State private var tagInputText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !tags.isEmpty {
                FlowLayout(spacing: 4) {
                    ForEach(tags) { tag in
                        HStack(spacing: 2) {
                            tagLabel(tag)
                            Button {
                                tags.removeAll { $0.persistentModelID == tag.persistentModelID }
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.secondary.opacity(0.08)))
                    }
                }
            }

            TextField("Add tag\u{2026}", text: $tagInputText)
                .textFieldStyle(.roundedBorder)

            if !tagInputText.isEmpty {
                let matching = allTags.filter { !tags.contains($0) && $0.name.localizedCaseInsensitiveContains(tagInputText) }
                if matching.isEmpty {
                    Button("Create \"\(tagInputText)\"") {
                        let tag = Tag(name: tagInputText)
                        modelContext.insert(tag)
                        tags.append(tag)
                        tagInputText = ""
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.orange)
                }
                ForEach(matching) { tag in
                    Button {
                        tags.append(tag)
                        tagInputText = ""
                    } label: {
                        tagLabel(tag)
                    }
                    .buttonStyle(.plain)
                }
            }

            if tagInputText.isEmpty {
                DisclosureGroup("All Tags (\(allTags.count))") {
                    if allTags.isEmpty {
                        Text("No tags yet. Type a name above to create one.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ScrollView(.vertical, showsIndicators: true) {
                            FlowLayout(spacing: 4) {
                                ForEach(allTags) { tag in
                                    let isSelected = tags.contains(tag)
                                    Button {
                                        if isSelected {
                                            tags.removeAll { $0.persistentModelID == tag.persistentModelID }
                                        } else {
                                            tags.append(tag)
                                        }
                                    } label: {
                                        HStack(spacing: 2) {
                                            tagLabel(tag)
                                            if isSelected {
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 8, weight: .bold))
                                                    .foregroundStyle(.green)
                                            }
                                        }
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3)
                                        .background(Capsule().fill(isSelected ? Color.green.opacity(0.12) : Color.secondary.opacity(0.06)))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .frame(maxHeight: 140)
                    }
                }
                .disclosureGroupStyle(.automatic)
                .font(.caption)
            }
        }
    }

    private func tagLabel(_ tag: Tag) -> some View {
        HStack(spacing: 4) {
            if let hex = tag.colorHex, !hex.isEmpty, let color = Color(hex: hex) {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
            }
            Text(tag.name)
                .foregroundStyle(.primary)
                .font(.caption)
        }
    }
}

struct TagTokenView: View {
    let tag: Tag

    var body: some View {
        HStack(spacing: 2) {
            if let hex = tag.colorHex, !hex.isEmpty, let color = Color(hex: hex) {
                Circle()
                    .fill(color)
                    .frame(width: 5, height: 5)
            }
            Text(tag.name)
                .font(.system(size: 8))
                .lineLimit(1)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 1)
        .background(Capsule().fill(Color.secondary.opacity(0.08)))
        .foregroundStyle(.secondary)
    }
}
