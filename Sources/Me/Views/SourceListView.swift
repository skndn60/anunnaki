import SwiftUI
import SwiftData

/// Library view for managing reference sources.
struct SourceListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var sources: [Source]
    @AppStorage("sourceDetailWidth") private var detailWidth: Double = 320
    @State private var showingAddSheet = false
    @State private var editingSource: Source?
    @State private var selectedSourceID: PersistentIdentifier?

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
                    List(sources, selection: $selectedSourceID) { source in
                        SourceRow(source: source)
                            .tag(source.persistentModelID)
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
                            onDelete: {
                                selectedSourceID = nil
                                modelContext.delete(source)
                            },
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
        }
        .animation(.easeInOut(duration: 0.25), value: selectedSourceID)
        .sheet(isPresented: $showingAddSheet) {
            SourceFormView(source: nil)
        }
        .sheet(item: $editingSource) { source in
            SourceFormView(source: source)
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

                if !source.sourceDescription.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Description")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                        Text(source.sourceDescription)
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

                // Attachments / References
                Divider()
                AttachmentsSection(source: source)
            }
            .padding(20)
            .textSelection(.enabled)
        }
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
    @State private var publicationInfo = ""
    @State private var url = ""

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
                }

                Section("Description") {
                    TextEditor(text: $sourceDescription)
                        .frame(minHeight: 80)
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
        .frame(width: 540, height: 580)
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
        publicationInfo = source.publicationInfo
        url = source.url
    }

    private func save() {
        if let source {
            source.name = name
            source.sourceType = sourceType
            source.author = author
            source.language = language
            source.period = period
            source.sourceDescription = sourceDescription
            source.publicationInfo = publicationInfo
            source.url = url
        } else {
            let newSource = Source(
                name: name, sourceType: sourceType,
                author: author, language: language, period: period,
                sourceDescription: sourceDescription,
                publicationInfo: publicationInfo, url: url
            )
            modelContext.insert(newSource)
        }
        dismiss()
    }
}
