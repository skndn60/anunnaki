import SwiftUI
import AppKit

/// Set/edit/remove a figure's mugshot: choose (or import) a statue photo, drag a
/// circular crop over the face, and record how the statue was identified. The crop
/// is stored as normalized metadata on the figure — the source image stays whole.
struct MugshotSheet: View {
    let figure: Figure
    var onClose: (() -> Void)? = nil

    @Environment(\.modelContext) private var modelContext

    @State private var selectedImage: ImageAsset?
    @State private var crop: ImageCropRect
    @State private var identification: String
    @State private var sourceNote: String
    @State private var showingFilePicker = false
    @State private var editorImage: NSImage?

    private static let identificationOptions: [(label: String, value: String)] = [
        ("Inscribed (name on statue)", "inscribed"),
        ("Conventional (scholarly consensus)", "conventional"),
        ("Hypothetical (museum-label guess)", "hypothetical"),
        ("Unknown", "unknown"),
    ]

    init(figure: Figure, onClose: (() -> Void)? = nil) {
        self.figure = figure
        self.onClose = onClose
        _selectedImage = State(initialValue: figure.mugshotImage)
        _crop = State(initialValue: ImageCropRect(encoded: figure.mugshotCropRect) ?? .full)
        _identification = State(initialValue: figure.mugshotIdentification ?? "unknown")
        _sourceNote = State(initialValue: figure.mugshotImage?.source ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Mugshot")
                    .font(.title3.bold())
                Text(figure.name)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("SOURCE IMAGE")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    if figure.images.isEmpty {
                        Text("No images yet — import a statue photo.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(height: 72, alignment: .topLeading)
                    } else {
                        ScrollView(.horizontal) {
                            HStack(spacing: 8) {
                                ForEach(figure.images) { image in
                                    MugshotImageThumb(
                                        image: image,
                                        isSelected: selectedImage?.persistentModelID == image.persistentModelID
                                    ) {
                                        selectedImage = image
                                    }
                                }
                            }
                        }
                    }
                    Button { showingFilePicker = true } label: {
                        Label("Import Image…", systemImage: "plus")
                    }
                    .font(.caption)

                    if let selectedImage {
                        Text(selectedImage.caption.isEmpty ? selectedImage.filename : selectedImage.caption)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .lineLimit(2)
                    }
                }
                .frame(width: 200, alignment: .leading)

                VStack(alignment: .leading, spacing: 8) {
                    if let editorImage {
                        MugshotCropEditor(image: editorImage, crop: $crop)
                            .frame(height: 320)
                    } else {
                        Text("Select or import an image to crop.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(height: 320)
                            .frame(maxWidth: .infinity)
                    }
                    HStack {
                        Text("PREVIEW")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        Spacer()
                        if let preview = livePreview {
                            Image(nsImage: preview)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 72, height: 72)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.secondary.opacity(0.25), lineWidth: 1))
                        }
                    }
                }
            }

            Divider()

            Picker("Identification", selection: $identification) {
                ForEach(Self.identificationOptions, id: \.value) { option in
                    Text(option.label).tag(option.value)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            Text("How do we know this statue is \(figure.name)? Most Mesopotamian statues are anonymous — \"inscribed\" means the statue carries the name.")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            TextField("Source / attribution (photo credit, museum, URL)", text: $sourceNote)
                .textFieldStyle(.roundedBorder)

            HStack {
                if figure.mugshotImage != nil {
                    Button("Remove Mugshot", role: .destructive) { remove() }
                }
                Spacer()
                Button("Cancel") { onClose?() }
                    .keyboardShortcut(.cancelAction)
                Button("Set Mugshot") { save() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(selectedImage == nil)
            }
        }
        .padding(20)
        .frame(width: 580)
        .onAppear { loadEditor() }
        .onChange(of: selectedImage?.persistentModelID) { _, newID in
            loadEditor()
            if newID != figure.mugshotImage?.persistentModelID {
                crop = defaultCrop()
            }
        }
        .fileImporter(isPresented: $showingFilePicker, allowedContentTypes: [.image], allowsMultipleSelection: false) { result in
            handleImport(result)
        }
    }

    private var livePreview: NSImage? {
        guard let editorImage else { return nil }
        return MugshotImageLoader.crop(editorImage, cropRect: crop)
    }

    private func loadEditor() {
        editorImage = MugshotImageLoader.load(url: selectedImage?.fileURL, cropRect: nil, maxPixelSize: 1024)
    }

    private func defaultCrop() -> ImageCropRect {
        let pixelSize = editorImage?.size ?? NSSize(width: 100, height: 100)
        let sidePx = 0.6 * min(pixelSize.width, pixelSize.height)
        let width = sidePx / max(1, pixelSize.width)
        let height = sidePx / max(1, pixelSize.height)
        return ImageCropRect(x: (1 - width) / 2, y: (1 - height) / 2, width: width, height: height)
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        guard let url = try? result.get().first else { return }
        guard url.startAccessingSecurityScopedResource() else { return }
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
            figure.images.append(image)
            selectedImage = image
            try? modelContext.save()
        } catch { }
    }

    private func save() {
        guard let selectedImage else { return }
        if !sourceNote.isEmpty && selectedImage.source.isEmpty {
            selectedImage.source = sourceNote
        }
        figure.mugshotImage = selectedImage
        figure.mugshotCropRect = crop.encoded()
        figure.mugshotIdentification = identification
        try? modelContext.save()
        onClose?()
    }

    private func remove() {
        figure.mugshotImage = nil
        figure.mugshotCropRect = nil
        figure.mugshotIdentification = nil
        try? modelContext.save()
        onClose?()
    }
}

private struct MugshotImageThumb: View {
    let image: ImageAsset
    let isSelected: Bool
    let onSelect: () -> Void

    @State private var thumb: NSImage?

    var body: some View {
        Button(action: onSelect) {
            Group {
                if let thumb {
                    Image(nsImage: thumb)
                        .resizable()
                        .scaledToFill()
                } else {
                    Rectangle().fill(Color.secondary.opacity(0.15))
                }
            }
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .onAppear { thumb = MugshotImageLoader.load(url: image.fileURL, cropRect: nil, maxPixelSize: 160) }
        .onChange(of: image.persistentModelID) { _, _ in thumb = nil }
    }
}

private struct MugshotCropEditor: View {
    let image: NSImage
    @Binding var crop: ImageCropRect

    @State private var moveStart: ImageCropRect?
    @State private var resizeStart: ImageCropRect?

    var body: some View {
        GeometryReader { geo in
            let container = geo.size
            let display = aspectFitRect(image: image.size, in: container)
            let canvasCrop = CGRect(
                x: display.minX + crop.x * display.width,
                y: display.minY + crop.y * display.height,
                width: crop.width * display.width,
                height: crop.height * display.height
            )
            ZStack {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: container.width, height: container.height)

                Color.clear
                    .contentShape(Rectangle())
                    .gesture(moveGesture(display: display))

                Path { path in
                    path.addRect(CGRect(origin: .zero, size: container))
                    path.addEllipse(in: canvasCrop)
                }
                .fill(Color.black.opacity(0.5), style: FillStyle(eoFill: true))
                .allowsHitTesting(false)

                Path(ellipseIn: canvasCrop)
                    .stroke(Color.white, lineWidth: 2)
                    .allowsHitTesting(false)

                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 16, height: 16)
                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
                    .position(x: canvasCrop.maxX, y: canvasCrop.maxY)
                    .gesture(resizeGesture(display: display))
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private func aspectFitRect(image: CGSize, in container: CGSize) -> CGRect {
        let scale = min(container.width / image.width, container.height / image.height)
        let size = CGSize(width: image.width * scale, height: image.height * scale)
        return CGRect(
            x: (container.width - size.width) / 2,
            y: (container.height - size.height) / 2,
            width: size.width,
            height: size.height
        )
    }

    private func moveGesture(display: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if moveStart == nil { moveStart = crop }
                guard let start = moveStart else { return }
                crop = clampRect(ImageCropRect(
                    x: start.x + value.translation.width / display.width,
                    y: start.y + value.translation.height / display.height,
                    width: start.width,
                    height: start.height
                ))
            }
            .onEnded { _ in moveStart = nil }
    }

    private func resizeGesture(display: CGRect) -> some Gesture {
        DragGesture()
            .onChanged { value in
                if resizeStart == nil { resizeStart = crop }
                guard let start = resizeStart else { return }
                let startCanvasDiameter = start.width * display.width
                let delta = max(value.translation.width, value.translation.height)
                let scale = max(0.08, startCanvasDiameter + delta) / startCanvasDiameter
                let centerX = start.x + start.width / 2
                let centerY = start.y + start.height / 2
                var newWidth = start.width * scale
                var newHeight = start.height * scale
                let maxWidth = min(1, 2 * max(centerX, 1 - centerX))
                let maxHeight = min(1, 2 * max(centerY, 1 - centerY))
                newWidth = min(newWidth, maxWidth)
                newHeight = min(newHeight, maxHeight)
                crop = ImageCropRect(
                    x: centerX - newWidth / 2,
                    y: centerY - newHeight / 2,
                    width: newWidth,
                    height: newHeight
                )
            }
            .onEnded { _ in resizeStart = nil }
    }

    private func clampRect(_ rect: ImageCropRect) -> ImageCropRect {
        ImageCropRect(
            x: max(0, min(1 - rect.width, rect.x)),
            y: max(0, min(1 - rect.height, rect.y)),
            width: rect.width,
            height: rect.height
        )
    }
}
