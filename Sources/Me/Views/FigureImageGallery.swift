import SwiftUI
import SwiftData
import AppKit

/// Image gallery section for the figure detail panel.
struct FigureImageGallery: View {
    @Environment(\.modelContext) private var modelContext
    let figure: Figure
    @State private var showingFilePicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Images")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
                Button(action: { showingFilePicker = true }) {
                    Image(systemName: "plus.circle")
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }

            if figure.images.isEmpty {
                Text("No images attached")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 4)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 8) {
                    ForEach(figure.images) { image in
                        FigureImageThumbnail(image: image, onDelete: {
                            deleteImage(image)
                        })
                    }
                }
            }
        }
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
            let destination = FigureImage.imagesDirectory.appendingPathComponent(filename)

            do {
                try FileManager.default.copyItem(at: url, to: destination)
                let figureImage = FigureImage(
                    figure: figure,
                    filename: filename,
                    caption: url.deletingPathExtension().lastPathComponent,
                    source: ""
                )
                modelContext.insert(figureImage)
            } catch {
                // silently skip failed imports
            }
        }
    }

    private func deleteImage(_ image: FigureImage) {
        // Remove file from disk
        if let fileURL = image.fileURL {
            try? FileManager.default.removeItem(at: fileURL)
        }
        modelContext.delete(image)
    }
}

/// A single image thumbnail with caption.
struct FigureImageThumbnail: View {
    let image: FigureImage
    let onDelete: () -> Void
    @State private var isHovered = false
    @State private var showingDetail = false

    var body: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .topTrailing) {
                if let nsImage = loadImage() {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 100, height: 80)
                        .clipped()
                        .cornerRadius(6)
                        .onTapGesture { showingDetail = true }
                } else {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.secondary.opacity(0.1))
                        .frame(width: 100, height: 80)
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundStyle(.tertiary)
                        )
                }

                if isHovered {
                    Button(action: onDelete) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.white)
                            .background(Circle().fill(Color.red).frame(width: 16, height: 16))
                    }
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
        .sheet(isPresented: $showingDetail) {
            ImageDetailSheet(image: image)
        }
    }

    private func loadImage() -> NSImage? {
        guard let url = image.fileURL else { return nil }
        return NSImage(contentsOf: url)
    }
}

/// Full-size image view in a sheet.
struct ImageDetailSheet: View {
    let image: FigureImage
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 12) {
            if let nsImage = NSImage(contentsOf: image.fileURL ?? URL(fileURLWithPath: "")) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 600, maxHeight: 500)
            }

            if !image.caption.isEmpty {
                Text(image.caption)
                    .font(.headline)
            }
            if !image.source.isEmpty {
                Text(image.source)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button("Close") { dismiss() }
                .keyboardShortcut(.cancelAction)
                .padding(.top, 8)
        }
        .padding(20)
        .frame(minWidth: 400, minHeight: 300)
    }
}
