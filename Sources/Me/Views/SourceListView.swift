import SwiftUI
import SwiftData

/// Library view for managing reference sources.
struct SourceListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var sources: [Source]

    private var sortedSources: [Source] {
        sources.sorted { ($0.sortName ?? sortName(for: $0.name)) < ($1.sortName ?? sortName(for: $1.name)) }
    }

    /// Sources grouped by the first letter of their effective sort key, for
    /// alphabetical letter dividers in the list.
    private var groupedSources: [(key: String, sources: [Source])] {
        Dictionary(grouping: sortedSources) { source in
            String((source.sortName ?? sortName(for: source.name)).uppercased().prefix(1))
        }
        .sorted { $0.key < $1.key }
        .map { (key: $0.key, sources: $0.value.sorted { ($0.sortName ?? sortName(for: $0.name)) < ($1.sortName ?? sortName(for: $1.name)) }) }
    }
    @AppStorage("sourceDetailWidth") private var detailWidth: Double = 320
    @State private var showingAddSheet = false
    @State private var editingSource: Source?
    @State private var selectedSourceID: PersistentIdentifier?
    @State private var showDeleteConfirm = false

    private var selectedSource: Source? {
        guard let id = selectedSourceID else { return nil }
        return sources.first { $0.persistentModelID == id }
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                HStack {
                    Text("Source Library")
                        .font(.title2.bold())
                    Spacer()
                    Button(action: { showingAddSheet = true }) {
                        Label("Add Source", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()

                Divider()

                if sources.isEmpty {
                    VStack(spacing: 12) {
                        Spacer()
                        Image(systemName: "books.vertical")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("No sources yet")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                        Text("Build your reference library of ancient texts, translations, and scholarly works.")
                            .font(.body)
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 300)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    List(selection: $selectedSourceID) {
                        ForEach(groupedSources, id: \.key) { group in
                            Section(header: Text(group.key).font(.largeTitle.bold()).foregroundStyle(.secondary)) {
                                ForEach(group.sources) { source in
                                    SourceRow(source: source)
                                        .tag(source.persistentModelID)
                                        .contextMenu {
                                            Button("Edit") { editingSource = source }
                                            Divider()
                                            Button("Delete", role: .destructive) {
                                                selectedSourceID = source.persistentModelID
                                                showDeleteConfirm = true
                                            }
                                        }
                                }
                            }
                        }
                    }
                    .listStyle(.inset(alternatesRowBackgrounds: true))
                }
            }
            .frame(minWidth: 450, maxWidth: .infinity)

            Group {
                if let source = selectedSource {
                    // ResizableDivider(width: $detailWidth, range: 200...800)
                    VStack(spacing: 0) {
                        DetailToolbar(
                            onEdit: { editingSource = source },
                            onDelete: { showDeleteConfirm = true },
                            onClose: { selectedSourceID = nil }
                        )
                    SourceDetailView(source: source)
                    }
                .frame(width: detailWidth)
                .frame(maxHeight: .infinity)
                .background(.thinMaterial)
                }
            }
            .transition(.move(edge: .trailing).combined(with: .opacity))
            .animation(.easeInOut(duration: 0.25), value: selectedSourceID)
        }
        .sheet(isPresented: $showingAddSheet) {
            SourceFormView(source: nil)
        }
        .sheet(item: $editingSource) { source in
            SourceFormView(source: source)
        }
        .alert("Delete Source?", isPresented: $showDeleteConfirm, presenting: selectedSource) { source in
            Button("Delete", role: .destructive) {
                selectedSourceID = nil
                modelContext.delete(source)
            }
            Button("Cancel", role: .cancel) {}
        } message: { source in
            Text("Delete \"\(source.name)\"? This cannot be undone.")
        }
    }

    private func sourceIcon(_ type: Source.SourceType) -> String { type.icon }
}

struct SourceRow: View {
    let source: Source

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: source.sourceType.icon)
                .font(.caption)
                .foregroundStyle(.brown)
                .frame(width: 16)
            Text(source.name)
                .fontWeight(.medium)
            Text(source.sourceType.rawValue)
                .font(.caption)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(RoundedRectangle(cornerRadius: 4).fill(Color.brown.opacity(0.12)))
            Text(source.language)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(source.period)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
    }
}

// MARK: - Source Detail

struct SourceDetailView: View {
    let source: Source
    @Query private var figures: [Figure]
    @Query private var citations: [Citation]

    private var sourceCitations: [Citation] {
        citations.filter { $0.source?.persistentModelID == source.persistentModelID }
    }

    private var sourceFigures: [Figure] {
        figures.filter { $0.source == source.name }.sorted { $0.name < $1.name }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text(source.name)
                        .font(.title3.bold())
                    Text(source.sourceType.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Divider()

                // Metadata
                LazyVGrid(columns: [GridItem(.fixed(90), alignment: .trailing), GridItem(.flexible(), alignment: .leading)], spacing: 8) {
                    if !source.author.isEmpty {
                        Text("Author").font(.caption).foregroundStyle(.secondary)
                        Text(source.author)
                    }
                    if !source.language.isEmpty {
                        Text("Language").font(.caption).foregroundStyle(.secondary)
                        Text(source.language)
                    }
                    if !source.period.isEmpty {
                        Text("Period").font(.caption).foregroundStyle(.secondary)
                        Text(source.period)
                    }
                    if !source.publicationInfo.isEmpty {
                        Text("Publication").font(.caption).foregroundStyle(.secondary)
                        Text(source.publicationInfo)
                    }
                }
                .font(.callout)

                if !source.sourceDescription.isEmpty || source.richDescription != nil {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Description")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                        LinkedDescription(text: source.sourceDescription, richData: source.richDescription)
                            .font(.body)
                    }
                }

                // Figures using this source
                if !sourceFigures.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Figures (\(sourceFigures.count))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                        ForEach(sourceFigures) { figure in
                            HStack(spacing: 8) {
                                Image(systemName: figure.figureType?.icon ?? "questionmark")
                                    .font(.caption)
                                    .foregroundStyle(figure.figureType?.color ?? .gray)
                                    .frame(width: 14)
                                Text(figure.name)
                                    .font(.callout)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }

                // Citations using this source
                if !sourceCitations.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Citations (\(sourceCitations.count))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)

                        ForEach(sourceCitations) { citation in
                            HStack(alignment: .top, spacing: 8) {
                                Text(citation.safeEntityType.rawValue)
                                    .font(.caption2)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 2)
                                    .background(RoundedRectangle(cornerRadius: 3).fill(Color.secondary.opacity(0.1)))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(citation.safeEntityName)
                                        .font(.callout)
                                        .fontWeight(.medium)
                                    if !citation.safeLocation.isEmpty {
                                        Text(citation.safeLocation)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    if !citation.safeNote.isEmpty {
                                        Text(citation.safeNote)
                                            .font(.caption)
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }

                // Comparison-table cells citing this source
                TableCellsSection(source: source)

                // Attachments / References
                Divider()
                AttachmentsSection(source: source)
            }
            .padding(20)
            .textSelection(.enabled)
        }
    }
}

/// Section listing comparison-table cells that cite `source`, from both the
/// legacy single-source link (`Source.popupTableCells`) and the newer multi-
/// source `CellSource` attributions (`Source.cellListSources`).
private struct TableCellsSection: View {
    let source: Source
    @State private var previewItem: TableCellPreviewItem?

    private var cells: [(table: String, attribute: String, column: String, location: String?, value: String?)] {
        var rows: [(table: String, attribute: String, column: String, location: String?, value: String?)] = []
        var seen = Set<PersistentIdentifier>()
        for cell in source.popupTableCells {
            guard seen.insert(cell.persistentModelID).inserted else { continue }
            rows.append((table: cell.table?.name ?? "Table", attribute: cell.attribute?.name ?? "", column: columnName(for: cell), location: nil, value: cell.value))
        }
        for cellSource in source.cellListSources {
            guard let cell = cellSource.cell, seen.insert(cell.persistentModelID).inserted else { continue }
            rows.append((table: cell.table?.name ?? "Table", attribute: cell.attribute?.name ?? "", column: columnName(for: cell), location: cellSource.location, value: cell.value))
        }
        return rows.sorted {
            let tableComparison = $0.table.localizedCaseInsensitiveCompare($1.table)
            if tableComparison != .orderedSame { return tableComparison == .orderedAscending }
            return $0.attribute.localizedCaseInsensitiveCompare($1.attribute) == .orderedAscending
        }
    }

    private func columnName(for cell: PopupTableCell) -> String {
        if let figure = cell.figure { return figure.name }
        if let column = cell.column { return column.name }
        return ""
    }

    var body: some View {
        let rows = cells
        if !rows.isEmpty {
            Divider()
            VStack(alignment: .leading, spacing: 8) {
                Text("Table Cells (\(rows.count))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "tablecells")
                            .font(.caption)
                            .foregroundStyle(Color.teal)
                            .frame(width: 14)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(row.table)
                                .font(.callout)
                                .fontWeight(.medium)
                            HStack(spacing: 4) {
                                Text(row.attribute).font(.caption).foregroundStyle(.secondary)
                                if !row.column.isEmpty {
                                    Text("\u{00b7}").foregroundStyle(.tertiary)
                                    Text(row.column).font(.caption).foregroundStyle(.secondary)
                                }
                                if let location = row.location, !location.isEmpty {
                                    Text("\u{00b7}").foregroundStyle(.tertiary)
                                    Text(location).font(.caption).foregroundStyle(.tertiary)
                                }
                            }
                        }
                        Spacer(minLength: 0)
                        if row.value != nil {
                            Image(systemName: "text.alignleft")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.vertical, 2)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        previewItem = TableCellPreviewItem(
                            table: row.table,
                            attribute: row.attribute,
                            column: row.column,
                            value: row.value ?? ""
                        )
                    }
                }
            }
            .popover(item: $previewItem, arrowEdge: .trailing) { item in
                TableCellPreviewPopover(item: item)
            }
        }
    }
}

private struct TableCellPreviewItem: Identifiable {
    let table: String
    let attribute: String
    let column: String
    let value: String
    var id: String { "\(table)-\(attribute)-\(column)" }
}

private struct TableCellPreviewPopover: View {
    let item: TableCellPreviewItem
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(item.table)
                .font(.headline)
            HStack(spacing: 4) {
                Text(item.attribute).font(.subheadline).foregroundStyle(.secondary)
                if !item.column.isEmpty {
                    Text("\u{00b7}").foregroundStyle(.tertiary)
                    Text(item.column).font(.subheadline).foregroundStyle(.secondary)
                }
            }
            Divider()
            Text(item.value.isEmpty ? "—" : item.value)
                .font(.body)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .frame(minWidth: 260, maxWidth: 400)
    }
}

/// Section showing attachments for a source, with ability to add new ones.
struct AttachmentsSection: View {
    @Environment(\.modelContext) private var modelContext
    let source: Source
    @State private var showingAddSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("References & Links")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
                Button(action: { showingAddSheet = true }) {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .bold))
                }
                .buttonStyle(.plain)
                .help("Add reference")
            }

            if source.attachments.isEmpty {
                Text("No references attached yet")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 4)
            } else {
                ForEach(source.attachments) { attachment in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: attachmentIcon(attachment.attachmentType))
                            .font(.caption)
                            .foregroundStyle(Color.accentColor)
                            .frame(width: 14)

                        VStack(alignment: .leading, spacing: 2) {
                            if attachment.url.isEmpty {
                                Text(attachment.title)
                                    .font(.callout)
                                    .fontWeight(.medium)
                            } else {
                                Link(attachment.title, destination: URL(string: attachment.url) ?? URL(string: "about:blank")!)
                                    .font(.callout)
                                    .fontWeight(.medium)
                            }

                            HStack(spacing: 6) {
                                Text(attachment.attachmentType.rawValue)
                                    .font(.caption2)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(RoundedRectangle(cornerRadius: 3).fill(Color.secondary.opacity(0.08)))
                                if let note = attachment.note, !note.isEmpty {
                                    Text(note)
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                            }

                            if !attachment.url.isEmpty {
                                Text(attachment.url)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                        }

                        Spacer()

                        Button(action: { modelContext.delete(attachment) }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AttachmentFormView(source: source)
        }
    }

    private func attachmentIcon(_ type: Attachment.AttachmentType) -> String { type.icon }
}

/// Form for adding an attachment to a source.
struct AttachmentFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss

    let source: Source

    @State private var title = ""
    @State private var url = ""
    @State private var attachmentType: Attachment.AttachmentType = .onlineText
    @State private var note = ""

    var body: some View {
        VStack(spacing: 0) {
            Text("Add Reference")
                .font(.title3.bold())
                .padding()

            Form {
                Section("Reference Details") {
                    TextField("Title", text: $title, prompt: Text("e.g. ETCSL Sumerian King List translation"))
                    TextField("URL", text: $url, prompt: Text("https://..."))
                    Picker("Type", selection: $attachmentType) {
                        ForEach(Attachment.AttachmentType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    TextField("Note", text: $note, prompt: Text("Optional description"))
                }
            }
            .formStyle(.grouped)

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Add") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(title.isEmpty)
            }
            .padding()
        }
        .frame(width: 480, height: 320)
    }

    private func save() {
        let attachment = Attachment(
            source: source,
            title: title, url: url,
            attachmentType: attachmentType,
            note: note.isEmpty ? nil : note
        )
        modelContext.insert(attachment)
        dismiss()
    }
}// MARK: - Source Form

struct SourceFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss

    let source: Source?

    @State private var name = ""
    @State private var sourceType: Source.SourceType = .ancientText
    @State private var author = ""
    @State private var language = ""
    @State private var period = ""
    @State private var sourceDescription = ""
    @State private var richDescription: Data? = nil
    @State private var publicationInfo = ""
    @State private var url = ""
    @State private var sortName = ""

    private var isEditing: Bool { source != nil }

    var body: some View {
        VStack(spacing: 0) {
            Text(isEditing ? "Edit Source" : "Add Source")
                .font(.title3.bold())
                .padding()

            Form {
                Section("Source Details") {
                    TextField("Name", text: $name, prompt: Text("e.g. Enuma Elish"))
                    Picker("Type", selection: $sourceType) {
                        ForEach(Source.SourceType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    TextField("Author / Translator", text: $author, prompt: Text("e.g. Stephanie Dalley"))
                    TextField("Language", text: $language, prompt: Text("e.g. Akkadian, English translation"))
                    TextField("Period", text: $period, prompt: Text("e.g. Old Babylonian, 7th century BCE"))
                }

                Section("Publication") {
                    TextField("Publication Info", text: $publicationInfo, prompt: Text("e.g. British Museum, BM 36322"))
                    TextField("URL", text: $url, prompt: Text("e.g. https://etcsl.orinst.ox.ac.uk/..."))
                    TextField("Sort key (overrides alphabetical sorting)", text: $sortName, prompt: Text("e.g. Flood for \"The Great Flood\""))
                }

                Section("Description") {
                    RichTextEditorSection(richData: $richDescription, plainText: $sourceDescription)
                        .frame(minHeight: 220)
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
        .frame(width: 540, height: 720)
        .onAppear { loadIfEditing() }
    }

    private func loadIfEditing() {
        guard let source else { return }
        name = source.name
        sourceType = source.sourceType
        author = source.author
        language = source.language
        period = source.period
        sourceDescription = source.sourceDescription
        richDescription = source.richDescription
        publicationInfo = source.publicationInfo
        url = source.url
        sortName = source.sortName ?? ""
    }

    private func save() {
        if let source {
            source.name = name
            source.sourceType = sourceType
            source.author = author
            source.language = language
            source.period = period
            source.sourceDescription = sourceDescription
            source.richDescription = richDescription
            source.publicationInfo = publicationInfo
            source.url = url
            source.sortName = sortName.isEmpty ? nil : sortName
        } else {
            let newSource = Source(
                name: name, sourceType: sourceType,
                author: author, language: language, period: period,
                sourceDescription: sourceDescription,
                richDescription: richDescription,
                publicationInfo: publicationInfo, url: url,
                sortName: sortName.isEmpty ? nil : sortName
            )
            modelContext.insert(newSource)
        }
        dismiss()
    }
}
