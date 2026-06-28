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
                                deleteImage(image)
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

    private let columns = [GridItem(.adaptive(minimum: 120), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(images) { image in
                        ImageThumbnail(image: image, onDelete: {
                            deleteImage(image)
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

    @State private var previewImage: NSImage?
    @State private var caption: String = ""
    @State private var source: String = ""
    @State private var searchText: String = ""
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
            source = image.source
        }
        .onChange(of: caption) { _, newValue in image.caption = newValue }
        .onChange(of: source) { _, newValue in image.source = newValue }
    }

    private var imagePanel: some View {
        VStack(spacing: 8) {
            if !caption.isEmpty {
                Text(caption)
                    .font(.headline)
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
                    TextField("Caption", text: $caption)
                        .textFieldStyle(.roundedBorder)
                    TextField("Source", text: $source)
                        .textFieldStyle(.roundedBorder)
                }

                Divider()

                linkedSection(title: "Associated Figures (\(image.figures.count))", icon: "person.fill") {
                    if image.figures.isEmpty {
                        Text("None").foregroundStyle(.tertiary)
                    }
                    ForEach(image.figures) { fig in
                        HStack {
                            Label(fig.name, systemImage: "person.fill")
                            Spacer()
                            Button("Remove") {
                                image.figures.removeAll { $0.persistentModelID == fig.persistentModelID }
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.red)
                        }
                    }
                }

                linkedSection(title: "Associated Places (\(image.places.count))", icon: "mappin") {
                    if image.places.isEmpty {
                        Text("None").foregroundStyle(.tertiary)
                    }
                    ForEach(image.places) { place in
                        HStack {
                            Label(place.name, systemImage: "mappin")
                            Spacer()
                            Button("Remove") {
                                image.places.removeAll { $0.persistentModelID == place.persistentModelID }
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.red)
                        }
                    }
                }

                linkedSection(title: "Associated Events (\(image.events.count))", icon: "bolt.fill") {
                    if image.events.isEmpty {
                        Text("None").foregroundStyle(.tertiary)
                    }
                    ForEach(image.events) { evt in
                        HStack {
                            Label(evt.name, systemImage: "bolt.fill")
                            Spacer()
                            Button("Remove") {
                                image.events.removeAll { $0.persistentModelID == evt.persistentModelID }
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.red)
                        }
                    }
                }

                linkedSection(title: "Associated Things (\(image.things.count))", icon: "cube.box") {
                    if image.things.isEmpty {
                        Text("None").foregroundStyle(.tertiary)
                    }
                    ForEach(image.things) { thg in
                        HStack {
                            Label(thg.name, systemImage: "cube.box")
                            Spacer()
                            Button("Remove") {
                                image.things.removeAll { $0.persistentModelID == thg.persistentModelID }
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.red)
                        }
                    }
                }

                linkedSection(title: "Tags (\(image.tags.count))", icon: "tag") {
                    if image.tags.isEmpty {
                        Text("None").foregroundStyle(.tertiary)
                    }
                    ForEach(image.tags) { tag in
                        HStack {
                            tagLabel(tag)
                            Spacer()
                            Button("Remove") {
                                image.tags = image.tags.filter { $0.persistentModelID != tag.persistentModelID }
                                try? modelContext.save()
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.red)
                        }
                    }
                }

                Divider()

                Text("Add Links")
                    .font(.subheadline.bold())

                TextField("Search figures, places, events, or things\u{2026}", text: $searchText)
                    .textFieldStyle(.roundedBorder)

                if !searchText.isEmpty {
                    let filteredFigures = figures.filter { !image.figures.contains($0) && $0.name.localizedCaseInsensitiveContains(searchText) }
                    let filteredPlaces = places.filter { !image.places.contains($0) && $0.name.localizedCaseInsensitiveContains(searchText) }
                    let filteredEvents = events.filter { !image.events.contains($0) && $0.name.localizedCaseInsensitiveContains(searchText) }
                    let filteredThings = things.filter { !image.things.contains($0) && $0.name.localizedCaseInsensitiveContains(searchText) }

                    if filteredFigures.isEmpty && filteredPlaces.isEmpty && filteredEvents.isEmpty && filteredThings.isEmpty {
                        Text("No matches").foregroundStyle(.tertiary)
                    } else {
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(filteredFigures) { fig in
                                Button {
                                    image.figures.append(fig)
                                    searchText = ""
                                } label: {
                                    Label(fig.name, systemImage: "person.fill")
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .buttonStyle(.plain)
                            }
                            ForEach(filteredPlaces) { place in
                                Button {
                                    image.places.append(place)
                                    searchText = ""
                                } label: {
                                    Label(place.name, systemImage: "mappin")
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .buttonStyle(.plain)
                            }
                            ForEach(filteredEvents) { evt in
                                Button {
                                    image.events.append(evt)
                                    searchText = ""
                                } label: {
                                    Label(evt.name, systemImage: "bolt.fill")
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .buttonStyle(.plain)
                            }
                            ForEach(filteredThings) { thg in
                                Button {
                                    image.things.append(thg)
                                    searchText = ""
                                } label: {
                                    Label(thg.name, systemImage: "cube.box")
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

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
            if let hex = tag.colorHex, !hex.isEmpty, let color = Color(hex: hex) {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
            }
            Text(tag.name)
                .foregroundStyle(.primary)
        }
    }

    private func linkedSection(title: String, icon: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.bold())
            content()
        }
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
