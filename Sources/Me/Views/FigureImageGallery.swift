import SwiftUI
import SwiftData
import AppKit
import UniformTypeIdentifiers

// MARK: - AppKit drag-drop target for reliable macOS file drops

private struct ImageDropTarget: NSViewRepresentable {
    @Binding var isTargeted: Bool
    let onDrop: (URL) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = _DropView()
        view.wantsLayer = true
        view.onDrop = onDrop
        view.onTargetedChange = { isTargeted = $0 }
        view.registerForDraggedTypes([.fileURL, NSPasteboard.PasteboardType("NSFilenamesPboardType")])
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let dropView = nsView as? _DropView else { return }
        dropView.onDrop = onDrop
    }
}

private class _DropView: NSView {
    var onDrop: ((URL) -> Void)?
    var onTargetedChange: ((Bool) -> Void)?

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        onTargetedChange?(true)
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        onTargetedChange?(false)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        onTargetedChange?(false)
        guard let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] else { return false }
        for url in urls {
            guard let typeID = try? url.resourceValues(forKeys: [.typeIdentifierKey]).typeIdentifier,
                  UTType(typeID)?.conforms(to: .image) == true else { continue }
            onDrop?(url)
        }
        return true
    }

}

// MARK: - SwiftUI DropDelegate fallback for file drops

private struct FileDropDelegate: DropDelegate {
    @Binding var isTargeted: Bool
    let onDrop: (URL) -> Void

    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [.fileURL])
    }

    func dropEntered(info: DropInfo) {
        isTargeted = true
    }

    func dropExited(info: DropInfo) {
        isTargeted = false
    }

    func performDrop(info: DropInfo) -> Bool {
        isTargeted = false
        guard let urls = NSPasteboard.general.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] else { return false }
        for url in urls {
            guard let typeID = try? url.resourceValues(forKeys: [.typeIdentifierKey]).typeIdentifier,
                  UTType(typeID)?.conforms(to: .image) == true else { continue }
            onDrop(url)
        }
        return true
    }
}

struct ImageGallery: View {
    @Environment(\.modelContext) private var modelContext
    let title: String
    let images: [ImageAsset]
    var onLinkImage: ((ImageAsset) -> Void)?
    var onSelectImage: ((ImageAsset) -> Void)?
    var maxDisplayCount: Int = 4
    @State private var showingFilePicker = false
    @State private var showingAll = false
    @State private var isDropTargeted = false
    @State private var imageToDelete: ImageAsset?
    @State private var showDeleteConfirm = false

    private var displayImages: [ImageAsset] {
        Array(images.prefix(maxDisplayCount))
    }

    private var hasMore: Bool { images.count > maxDisplayCount }

    var body: some View {
        ZStack {
            ImageDropTarget(isTargeted: $isDropTargeted, onDrop: { importFile(from: $0) })
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    Spacer()
                    Button(action: { showingFilePicker = true }) {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .buttonStyle(.plain)
                }

                if images.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "arrow.down.doc")
                            .font(.title2)
                            .foregroundStyle(.tertiary)
                        Text("Drop images here")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isDropTargeted ? Color.accentColor : Color(.separatorColor), lineWidth: isDropTargeted ? 2 : 1)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(isDropTargeted ? Color.accentColor.opacity(0.05) : Color.clear)
                            )
                    )
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 8) {
                        ForEach(displayImages) { image in
                            ImageThumbnail(image: image, onDelete: {
                                imageToDelete = image
                                showDeleteConfirm = true
                            }, onTap: {
                                onSelectImage?(image)
                            })
                        }
                    }

                    if hasMore {
                        Button(action: { showingAll = true }) {
                            Text("Show all \(images.count) images")
                                .font(.caption)
                                .foregroundStyle(Color.accentColor)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .onDrop(of: [.fileURL], delegate: FileDropDelegate(isTargeted: $isDropTargeted, onDrop: { importFile(from: $0) }))
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.image],
            allowsMultipleSelection: true
        ) { result in
            handleImport(result)
        }
        .alert("Delete Image?", isPresented: $showDeleteConfirm, presenting: imageToDelete) { image in
            Button("Delete", role: .destructive) {
                deleteImage(image)
            }
            Button("Cancel", role: .cancel) {}
        } message: { image in
            Text("Delete \"\(image.caption)\"? The image file will be removed.")
        }
    }

    private func importFile(from url: URL) {
        let filename = "\(UUID().uuidString)_\(url.lastPathComponent)"
        let destination = ImageAsset.imagesDirectory.appendingPathComponent(filename)
        do {
            try FileManager.default.copyItem(at: url, to: destination)
            let image = ImageAsset(
                filename: filename,
                caption: url.deletingPathExtension().lastPathComponent,
                source: ""
            )
            modelContext.insert(image)
            onLinkImage?(image)
        } catch { }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        guard let urls = try? result.get() else { return }
        for url in urls {
            guard url.startAccessingSecurityScopedResource() else { continue }
            defer { url.stopAccessingSecurityScopedResource() }

            let filename = "\(UUID().uuidString)_\(url.lastPathComponent)"
            let destination = ImageAsset.imagesDirectory.appendingPathComponent(filename)

            do {
                try FileManager.default.copyItem(at: url, to: destination)
                let image = ImageAsset(
                    filename: filename,
                    caption: url.deletingPathExtension().lastPathComponent,
                    source: ""
                )
                modelContext.insert(image)
                onLinkImage?(image)
            } catch {
                // silently skip failed imports
            }
        }
    }

    private func deleteImage(_ image: ImageAsset) {
        if let fileURL = image.fileURL {
            try? FileManager.default.removeItem(at: fileURL)
        }
        modelContext.delete(image)
    }
}

private struct AllImagesGallery: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss
    let title: String
    let images: [ImageAsset]
    var onLinkImage: ((ImageAsset) -> Void)?
    var onSelectImage: ((ImageAsset) -> Void)?
    @State private var showingFilePicker = false
    @State private var imageToDelete: ImageAsset?
    @State private var showDeleteConfirm = false

    private let columns = [GridItem(.adaptive(minimum: 120), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(images) { image in
                        ImageThumbnail(image: image, onDelete: {
                            imageToDelete = image
                            showDeleteConfirm = true
                        }, onTap: {
                            onSelectImage?(image)
                        })
                    }
                }
                .padding()
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingFilePicker = true }) {
                        Image(systemName: "plus")
                    }
                    .help("Add image")
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .frame(width: 600, height: 500)
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.image],
            allowsMultipleSelection: true
        ) { result in
            handleImport(result)
        }
        .alert("Delete Image?", isPresented: $showDeleteConfirm, presenting: imageToDelete) { image in
            Button("Delete", role: .destructive) {
                deleteImage(image)
            }
            Button("Cancel", role: .cancel) {}
        } message: { image in
            Text("Delete \"\(image.caption)\"? The image file will be removed.")
        }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        guard let urls = try? result.get() else { return }
        for url in urls {
            guard url.startAccessingSecurityScopedResource() else { continue }
            defer { url.stopAccessingSecurityScopedResource() }

            let filename = "\(UUID().uuidString)_\(url.lastPathComponent)"
            let destination = ImageAsset.imagesDirectory.appendingPathComponent(filename)

            do {
                try FileManager.default.copyItem(at: url, to: destination)
                let image = ImageAsset(
                    filename: filename,
                    caption: url.deletingPathExtension().lastPathComponent,
                    source: ""
                )
                modelContext.insert(image)
                onLinkImage?(image)
            } catch {
                // silently skip failed imports
            }
        }
    }

    private func deleteImage(_ image: ImageAsset) {
        if let fileURL = image.fileURL {
            try? FileManager.default.removeItem(at: fileURL)
        }
        modelContext.delete(image)
    }
}

struct ImageThumbnail: View {
    let image: ImageAsset
    let onDelete: () -> Void
    let onTap: () -> Void
    @State private var isHovered = false
    @State private var thumbnail: NSImage?

    var body: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .topTrailing) {
                if let nsImage = thumbnail {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 100, height: 80)
                        .clipped()
                        .cornerRadius(6)
                        .onTapGesture(perform: onTap)
                } else {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.secondary.opacity(0.1))
                        .frame(width: 100, height: 80)
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundStyle(.tertiary)
                        )
                        .onTapGesture(perform: onTap)
                }

                if isHovered {
                    Button(action: onDelete) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 16, height: 16)
                            .background(Circle().fill(Color.red).frame(width: 16, height: 16))
                    }
                    .help("Delete image")
                    .buttonStyle(.plain)
                    .padding(4)
                }
            }
            .onHover { isHovered = $0 }

            Text(image.caption)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(width: 100)
        }
        .task(priority: .background) {
            guard let url = image.fileURL else { return }
            let result = await Task.detached {
                decodeImage(url: url, maxPixelSize: 200)
            }.value
            thumbnail = result
        }
    }
}

struct ImageDetailWindow: View {
    let imageID: PersistentIdentifier?
    @Environment(\.modelContext) private var modelContext
    @State private var image: ImageAsset?

    var body: some View {
        Group {
            if let image {
                ImageDetailContent(image: image)
            } else {
                Text("Image not found")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            guard let imageID else { return }
            let fetch = FetchDescriptor<ImageAsset>(predicate: #Predicate { $0.persistentModelID == imageID })
            image = try? modelContext.fetch(fetch).first
        }
    }
}

struct ImageDetailContent: View {
    let image: ImageAsset
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss
    @Query(sort: \Figure.name) private var figures: [Figure]
    @Query(sort: \Place.name) private var places: [Place]
    @Query(sort: \Event.name) private var events: [Event]
    @Query(sort: \Thing.name) private var things: [Thing]
    @Query(sort: \Tag.name) private var allTags: [Tag]
    @Query(sort: \Source.name) private var sources: [Source]

    @State private var previewImage: NSImage?
    @State private var caption: String = ""
    @State private var selectedSource: Source?
    @State private var imageDescription: String = ""
    @State private var figureSearchText = ""
    @State private var placeSearchText = ""
    @State private var eventSearchText = ""
    @State private var thingSearchText = ""
    @State private var tagInputText: String = ""

    var body: some View {
        HStack(spacing: 0) {
            imagePanel
            Divider()
            editorPanel
        }
        .frame(minWidth: 700, minHeight: 500)
        .task(priority: .userInitiated) {
            guard let url = image.fileURL else { return }
            let result = await Task.detached {
                decodeImage(url: url, maxPixelSize: 2400)
            }.value
            previewImage = result
        }
        .onAppear {
            caption = image.caption
            selectedSource = sources.first(where: { $0.name == image.source })
            imageDescription = image.imageDescription
        }
        .onChange(of: caption) { _, newValue in image.caption = newValue }
        .onChange(of: selectedSource) { _, newValue in image.source = newValue?.name ?? "" }
        .onChange(of: imageDescription) { _, newValue in image.imageDescription = newValue }
    }

    private var imagePanel: some View {
        VStack(spacing: 8) {
            if !caption.isEmpty {
                Text(caption)
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if !imageDescription.isEmpty {
                Text(imageDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let nsImage = previewImage {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding()
        .frame(minWidth: 300)
    }

    private var editorPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Details")
                    .font(.headline)
                    .padding(.top, 4)

                Group {
                    TextField("Caption", text: $caption, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(1...3)
                    TextField("Description", text: $imageDescription, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(2...6)
                    SourcePickerView(selection: $selectedSource, sources: sources)
                }

                Divider()

                searchableLinkedSection(
                    title: "Associated Figures",
                    items: image.figures,
                    icon: "person.fill",
                    searchText: $figureSearchText,
                    allEntities: figures,
                    alreadyLinked: image.figures,
                    onLink: { $0.images.append(image) },
                    onRemove: { fig in fig.images.removeAll { $0.persistentModelID == image.persistentModelID } }
                )

                searchableLinkedSection(
                    title: "Associated Places",
                    items: image.places,
                    icon: "mappin",
                    searchText: $placeSearchText,
                    allEntities: places,
                    alreadyLinked: image.places,
                    onLink: { $0.images.append(image) },
                    onRemove: { place in place.images.removeAll { $0.persistentModelID == image.persistentModelID } }
                )

                searchableLinkedSection(
                    title: "Associated Events",
                    items: image.events,
                    icon: "bolt.fill",
                    searchText: $eventSearchText,
                    allEntities: events,
                    alreadyLinked: image.events,
                    onLink: { $0.images.append(image) },
                    onRemove: { evt in evt.images.removeAll { $0.persistentModelID == image.persistentModelID } }
                )

                searchableLinkedSection(
                    title: "Associated Things",
                    items: image.things,
                    icon: "cube.box",
                    searchText: $thingSearchText,
                    allEntities: things,
                    alreadyLinked: image.things,
                    onLink: { $0.images.append(image) },
                    onRemove: { thg in thg.images.removeAll { $0.persistentModelID == image.persistentModelID } }
                )

                TextField("Add tag\u{2026}", text: $tagInputText)
                    .textFieldStyle(.roundedBorder)

                if !tagInputText.isEmpty {
                    let matching = allTags.filter { !image.tags.contains($0) && $0.name.localizedCaseInsensitiveContains(tagInputText) }
                    if matching.isEmpty {
                        Button("Create \"\(tagInputText)\"") {
                            let tag = Tag(name: tagInputText)
                            modelContext.insert(tag)
                            image.tags = image.tags + [tag]
                            try? modelContext.save()
                            tagInputText = ""
                        }
                        .buttonStyle(.plain)
                    }
                    ForEach(matching) { tag in
                        Button {
                            image.tags = image.tags + [tag]
                            try? modelContext.save()
                            tagInputText = ""
                        } label: {
                            tagLabel(tag)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Spacer(minLength: 16)

                HStack {
                    Button("Delete Image", role: .destructive) {
                        if let url = image.fileURL {
                            try? FileManager.default.removeItem(at: url)
                        }
                        modelContext.delete(image)
                        dismiss()
                    }
                    Spacer()
                    Button("Done") {
                        try? modelContext.save()
                        dismiss()
                    }
                        .keyboardShortcut(.defaultAction)
                }
            }
            .padding()
        }
        .frame(width: 300)
    }

    private func tagLabel(_ tag: Tag) -> some View {
        HStack(spacing: 4) {
            if let hex = tag.colorHex, !hex.isEmpty {
                let color = Color(hex: hex)
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
            }
            Text(tag.name)
                .foregroundStyle(.primary)
        }
    }

    @ViewBuilder
    private func searchableLinkedSection<Entity: PersistentModel>(
        title: String,
        items: [Entity],
        icon: String,
        searchText: Binding<String>,
        allEntities: [Entity],
        alreadyLinked: [Entity],
        onLink: @escaping (Entity) -> Void,
        onRemove: @escaping (Entity) -> Void
    ) -> some View where Entity: AnyObject {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(title) (\(items.count))")
                .font(.subheadline.bold())
            if items.isEmpty {
                Text("None")
                    .foregroundStyle(.tertiary)
            }
            ForEach(items, id: \.persistentModelID) { entity in
                HStack {
                    Label(entityName(entity), systemImage: icon)
                    Spacer()
                    Button("Remove") {
                        onRemove(entity)
                        try? modelContext.save()
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.red)
                }
            }
            TextField("Search \(title.lowercased())", text: searchText)
                .textFieldStyle(.roundedBorder)
            if !searchText.wrappedValue.isEmpty {
                let filtered = allEntities.filter { e in
                    !alreadyLinked.contains(where: { $0.persistentModelID == e.persistentModelID })
                        && entityName(e).localizedCaseInsensitiveContains(searchText.wrappedValue)
                }
                if filtered.isEmpty {
                    Text("No matches")
                        .foregroundStyle(.tertiary)
                        .font(.caption)
                } else {
                    ForEach(filtered, id: \.persistentModelID) { entity in
                        Button {
                            onLink(entity)
                            searchText.wrappedValue = ""
                        } label: {
                            Label(entityName(entity), systemImage: icon)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func entityName(_ entity: some Any) -> String {
        if let fig = entity as? Figure { return fig.name }
        if let place = entity as? Place { return place.name }
        if let evt = entity as? Event { return evt.name }
        if let thing = entity as? Thing { return thing.name }
        return "?"
    }
}

private func decodeImage(url: URL?, maxPixelSize: Int) -> NSImage? {
    guard let url else { return nil }
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
    let options: [CFString: Any] = [
        kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        kCGImageSourceCreateThumbnailFromImageAlways: true
    ]
    guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
    return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
}
