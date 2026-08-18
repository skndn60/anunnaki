import SwiftUI

/// Plain-value mugshot data, pre-resolved off the render path so a list row can
/// never fault a live model mid-layout. Nil data renders the content unchanged.
struct MugshotHoverData {
    let imageURL: URL?
    let cropRect: ImageCropRect?
    let identification: String?
    let fallbackColor: Color
    let fallbackIcon: String
}

struct MugshotHoverModifier: ViewModifier {
    let figure: Figure
    var size: CGFloat
    var arrowEdge: Edge
    var onHover: ((Bool) -> Void)?

    @State private var isHovering = false

    func body(content: Content) -> some View {
        if figure.mugshotImage != nil {
            content
                .onHover { hovering in
                    isHovering = hovering
                    onHover?(hovering)
                }
                .onDisappear { isHovering = false }
                .popover(isPresented: $isHovering, arrowEdge: arrowEdge) {
                    MugshotView(
                        image: figure.mugshotImage,
                        cropRect: ImageCropRect(encoded: figure.mugshotCropRect),
                        size: size,
                        figureType: figure.figureType,
                        identification: figure.mugshotIdentification
                    )
                    .padding(8)
                }
        } else {
            content
        }
    }
}

struct MugshotHoverValueModifier: ViewModifier {
    let data: MugshotHoverData?
    var size: CGFloat
    var arrowEdge: Edge
    var onHover: ((Bool) -> Void)?

    @State private var isHovering = false

    func body(content: Content) -> some View {
        if let data {
            content
                .onHover { hovering in
                    isHovering = hovering
                    onHover?(hovering)
                }
                .onDisappear { isHovering = false }
                .popover(isPresented: $isHovering, arrowEdge: arrowEdge) {
                    MugshotView(
                        imageURL: data.imageURL,
                        cropRect: data.cropRect,
                        size: size,
                        fallbackColor: data.fallbackColor,
                        fallbackIcon: data.fallbackIcon,
                        identification: data.identification
                    )
                    .padding(8)
                }
        } else {
            content
        }
    }
}

extension View {
    func mugshotHover(_ figure: Figure, size: CGFloat = 140, arrowEdge: Edge = .trailing, onHover: ((Bool) -> Void)? = nil) -> some View {
        modifier(MugshotHoverModifier(figure: figure, size: size, arrowEdge: arrowEdge, onHover: onHover))
    }

    func mugshotHover(_ data: MugshotHoverData?, size: CGFloat = 140, arrowEdge: Edge = .trailing, onHover: ((Bool) -> Void)? = nil) -> some View {
        modifier(MugshotHoverValueModifier(data: data, size: size, arrowEdge: arrowEdge, onHover: onHover))
    }
}
