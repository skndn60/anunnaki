import SwiftUI
import AppKit
import ImageIO
import CoreGraphics

/// Decodes an `ImageAsset` file and crops it to a normalized rectangle. The crop
/// is metadata — the original statue photo stays whole on disk and the mugshot is
/// derived at render time.
enum MugshotImageLoader {
    static func load(url: URL?, cropRect: ImageCropRect?, maxPixelSize: Int = 2048) -> NSImage? {
        guard let url else { return nil }
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceCreateThumbnailWithTransform: true,
        ]
        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        let rect = cropRect ?? .full
        // The thumbnail preserves aspect ratio, so the normalized rect maps directly
        // onto thumbnail pixels.
        let pixelRect = CGRect(
            x: rect.x * CGFloat(thumbnail.width),
            y: rect.y * CGFloat(thumbnail.height),
            width: rect.width * CGFloat(thumbnail.width),
            height: rect.height * CGFloat(thumbnail.height)
        )        .integral
        guard let cropped = thumbnail.cropping(to: pixelRect) else { return nil }
        return NSImage(cgImage: cropped, size: NSSize(width: cropped.width, height: cropped.height))
    }

    /// Crops an already-loaded image (used for the live preview in the crop sheet).
    static func crop(_ image: NSImage, cropRect: ImageCropRect?) -> NSImage? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let rect = cropRect ?? .full
        let pixelRect = CGRect(
            x: rect.x * CGFloat(cgImage.width),
            y: rect.y * CGFloat(cgImage.height),
            width: rect.width * CGFloat(cgImage.width),
            height: rect.height * CGFloat(cgImage.height)
        ).integral
        guard let cropped = cgImage.cropping(to: pixelRect) else { return nil }
        return NSImage(cgImage: cropped, size: NSSize(width: cropped.width, height: cropped.height))
    }
}

/// A figure's designated portrait: the `mugshotImage` cropped to `mugshotCropRect`
/// and masked in a circle. Falls back to the type-icon circle when there is none.
struct MugshotView: View {
    private let imageURL: URL?
    private let cropRect: ImageCropRect?
    private let size: CGFloat
    private let fallbackColor: Color
    private let fallbackIcon: String
    private let identification: String?

    @State private var loaded: NSImage?

    init(image: ImageAsset?, cropRect: ImageCropRect?, size: CGFloat, figureType: FigureType? = nil, identification: String? = nil) {
        self.imageURL = image?.fileURL
        self.cropRect = cropRect
        self.size = size
        self.fallbackColor = figureType?.color ?? .gray
        self.fallbackIcon = figureType?.icon ?? "questionmark"
        self.identification = identification
    }

    init(imageURL: URL?, cropRect: ImageCropRect?, size: CGFloat, fallbackColor: Color, fallbackIcon: String, identification: String? = nil) {
        self.imageURL = imageURL
        self.cropRect = cropRect
        self.size = size
        self.fallbackColor = fallbackColor
        self.fallbackIcon = fallbackIcon
        self.identification = identification
    }

    var body: some View {
        Group {
            if let loaded {
                Image(nsImage: loaded)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.secondary.opacity(0.25), lineWidth: 1))
            } else {
                FigureIconCircle(color: fallbackColor, icon: fallbackIcon, size: size)
            }
        }
        .help(helpText)
        .onAppear { reload() }
        .onChange(of: loadKey) { _, _ in reload() }
    }

    private var loadKey: String? {
        guard let imageURL else { return nil }
        return "\(imageURL.absoluteString)|\(cropRect.map { $0.encoded() } ?? "")"
    }

    private var helpText: String {
        var parts: [String] = []
        if imageURL != nil { parts.append("Mugshot") }
        if let identification, !identification.isEmpty {
            parts.append("identified by \(identification)")
        }
        return parts.joined(separator: " · ")
    }

    private func reload() {
        loaded = MugshotImageLoader.load(url: imageURL, cropRect: cropRect)
    }
}
