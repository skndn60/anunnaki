import SwiftUI
import SwiftData
import AppKit

struct ImageLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow
    @Query(sort: \ImageAsset.caption) private var allImages: [ImageAsset]
    @State private var showingFilePicker = false
    @State private var previewImage: ImageAsset?

    private let columns = [GridItem(.adaptive(minimum: 140), spacing: 12)]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Gallery       ")
                    .font(.title2.bold())
                Spacer()
                Button(action: { showingFilePicker = true }) {
                    Label("Upload", systemImage: "plus.circle")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()

            if allImages.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 48))
                        .foregroundStyle(.tertiary)
                    Text("No images yet")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    Text("Upload images to attach them to figures, places, and events.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(allImages) { asset in
                            ImageLibraryCell(asset: asset)
                                .onTapGesture {
                                    previewImage = asset
                                }
                        }
                    }
                    .padding()
                }
            }
        }
        .onChange(of: previewImage) { _, newValue in
            if let image = newValue {
                openWindow(id: "image-detail", value: image.persistentModelID)
                previewImage = nil
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
            let destination = ImageAsset.imagesDirectory.appendingPathComponent(filename)

            do {
                try FileManager.default.copyItem(at: url, to: destination)
                let asset = ImageAsset(
                    filename: filename,
                    caption: url.deletingPathExtension().lastPathComponent,
                    source: ""
                )
                modelContext.insert(asset)
            } catch {
                // silently skip failed imports
            }
        }
    }
}

struct ImageLibraryCell: View {
    let asset: ImageAsset
    @State private var isHovered = false
    @State private var thumbnail: NSImage?

    var body: some View {
        VStack(spacing: 4) {
            if let nsImage = thumbnail {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 100)
                    .clipped()
                    .cornerRadius(8)
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.1))
                    .frame(height: 100)
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundStyle(.tertiary)
                    )
            }

            Text(asset.caption)
                .font(.caption)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 4) {
                if !asset.figures.isEmpty {
                    badge(count: asset.figures.count, icon: "person.fill")
                }
                if !asset.places.isEmpty {
                    badge(count: asset.places.count, icon: "mappin")
                }
                if !asset.events.isEmpty {
                    badge(count: asset.events.count, icon: "bolt.fill")
                }
                if !asset.tags.isEmpty {
                    badge(count: asset.tags.count, icon: "tag")
                }
            }

            if !asset.tags.isEmpty {
                let displayTags = Array(asset.tags.prefix(3))
                let overflow = asset.tags.count - displayTags.count
                HStack(spacing: 3) {
                    ForEach(displayTags) { tag in
                        tagToken(tag)
                    }
                    if overflow > 0 {
                        Text("+\(overflow)")
                            .font(.system(size: 8))
                            .foregroundStyle(.tertiary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.textBackgroundColor))
                .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isHovered ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: isHovered ? 2 : 0.5)
        )
        .onHover { isHovered = $0 }
        .onAppear {
            DispatchQueue.main.async {
                DispatchQueue.global(qos: .userInitiated).async { [url = asset.fileURL] in
                    let result = decodeImage(url: url, maxPixelSize: 300)
                    DispatchQueue.main.async {
                        thumbnail = result
                    }
                }
            }
        }
    }

    private func badge(count: Int, icon: String) -> some View {
        HStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: 8))
            Text("\(count)")
                .font(.system(size: 9, weight: .medium))
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .background(Capsule().fill(Color.secondary.opacity(0.1)))
    }

    private func tagToken(_ tag: Tag) -> some View {
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


