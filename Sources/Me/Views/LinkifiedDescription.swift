import SwiftUI
import SwiftData
import AppKit

/// The group page currently being read. Inline links rendered inside a group
/// page preview the linked entity in the group's own detail panel (the main
/// content stays put), so no sidebar navigation or breadcrumbs are involved.
/// Outside a group page, links fall back to sidebar navigation.
struct InlineLinkGroupContext {
    let groupID: PersistentIdentifier
    let groupName: String
    let onOpenEntity: (EntityKind, PersistentIdentifier) -> Void

    init(groupID: PersistentIdentifier, groupName: String, onOpenEntity: @escaping (EntityKind, PersistentIdentifier) -> Void) {
        self.groupID = groupID
        self.groupName = groupName
        self.onOpenEntity = onOpenEntity
    }
}

private struct InlineLinkGroupContextKey: EnvironmentKey {
    static let defaultValue: InlineLinkGroupContext? = nil
}

extension EnvironmentValues {
    var inlineLinkGroupContext: InlineLinkGroupContext? {
        get { self[InlineLinkGroupContextKey.self] }
        set { self[InlineLinkGroupContextKey.self] = newValue }
    }
}

/// Renders a description — RTF when available, otherwise plain text — with
/// entity names auto-linked to their dossier report window.
struct LinkedDescription: View {
    let text: String
    var richData: Data? = nil
    var stripForegroundColor: Bool = false

    var body: some View {
        if let data = richData,
           let nsAttributedString = try? NSAttributedString(
            data: data,
            options: [.documentType: NSAttributedString.DocumentType.rtf],
            documentAttributes: nil
           ) {
            LinkifiedProse(attributed: cleaned(nsAttributedString))
        } else if !text.isEmpty {
            LinkifiedProse(attributed: NSAttributedString(string: text))
        }
    }

    private func cleaned(_ attributedString: NSAttributedString) -> NSAttributedString {
        let mutable = NSMutableAttributedString(attributedString: attributedString)
        let range = NSRange(location: 0, length: mutable.length)
        mutable.removeAttribute(.backgroundColor, range: range)
        if stripForegroundColor {
            mutable.removeAttribute(.foregroundColor, range: range)
        }
        return mutable
    }
}

// MARK: - Tokenizing prose

private struct LinkifiedProse: View {
    let attributed: NSAttributedString
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        let set = CandidateCache.set(in: modelContext)
        let ranges = paragraphNSRanges(of: attributed.string)
        VStack(alignment: .leading, spacing: 4) {
            ForEach(ranges.indices, id: \.self) { index in
                ParagraphView(
                    paragraph: attributed.attributedSubstring(from: ranges[index]),
                    candidates: set.candidates,
                    regex: set.regex
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func paragraphNSRanges(of string: String) -> [NSRange] {
        var result: [NSRange] = []
        var start = string.startIndex
        while start < string.endIndex {
            let lineEnd = string[start...].firstIndex(of: "\n") ?? string.endIndex
            if start < lineEnd, !string[start..<lineEnd].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                result.append(NSRange(start..<lineEnd, in: string))
            }
            if lineEnd == string.endIndex { break }
            start = string.index(after: lineEnd)
        }
        return result
    }
}

// MARK: - Candidate cache

/// The mention vocabulary and its compiled regex are the same for every
/// paragraph and every description view, so they're computed once and reused
/// until the database content changes (entity / alternate-name counts).
private struct CandidateSet {
    let candidates: [MentionCandidate]
    let regex: NSRegularExpression
}

private struct CandidateFingerprint: Equatable {
    let figures: Int
    let places: Int
    let events: Int
    let altNames: Int
}

private enum CandidateCache {
    private static var fingerprint: CandidateFingerprint?
    private static var set: CandidateSet?

    static func set(in context: ModelContext) -> CandidateSet {
        let current = CandidateFingerprint(
            figures: (try? context.fetchCount(FetchDescriptor<Figure>())) ?? 0,
            places: (try? context.fetchCount(FetchDescriptor<Place>())) ?? 0,
            events: (try? context.fetchCount(FetchDescriptor<Event>())) ?? 0,
            altNames: (try? context.fetchCount(FetchDescriptor<AlternateName>())) ?? 0
        )
        if let set, fingerprint == current {
            return set
        }
        let built = build(in: context)
        fingerprint = current
        set = built
        return built
    }

    private static func build(in context: ModelContext) -> CandidateSet {
        var result: [MentionCandidate] = []
        let figures: [Figure] = context.fetchAll()
        let places: [Place] = context.fetchAll()
        let events: [Event] = context.fetchAll()
        for figure in figures {
            appendCandidate(figure.name, kind: .figure, target: figure.name, targetID: figure.persistentModelID, into: &result)
            for alt in figure.alternateNames {
                appendCandidate(alt.name, kind: .figure, target: figure.name, targetID: figure.persistentModelID, into: &result)
            }
        }
        for place in places {
            appendCandidate(place.name, kind: .place, target: place.name, targetID: place.persistentModelID, into: &result)
            for alt in place.alternateNames {
                appendCandidate(alt.name, kind: .place, target: place.name, targetID: place.persistentModelID, into: &result)
            }
        }
        for event in events {
            appendCandidate(event.name, kind: .event, target: event.name, targetID: event.persistentModelID, into: &result)
        }
        let alternatives = result
            .map { NSRegularExpression.escapedPattern(for: $0.matchText) }
            .sorted { $0.count > $1.count }
        let pattern = alternatives.isEmpty
            ? "(?!)"
            : "\\b(?:" + alternatives.map { "(?:\($0))" }.joined(separator: "|") + ")\\b"
        let regex = try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
        return CandidateSet(candidates: result, regex: regex)
    }

    private static func appendCandidate(_ name: String, kind: EntityKind, target: String, targetID: PersistentIdentifier, into result: inout [MentionCandidate]) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return }
        guard !StopwordSet.contains(trimmed.lowercased()) else { return }
        guard trimmed.rangeOfCharacter(from: .letters) != nil else { return }
        guard !result.contains(where: { $0.matchText.caseInsensitiveCompare(trimmed) == .orderedSame }) else { return }
        result.append(MentionCandidate(matchText: trimmed, kind: kind, targetName: target, targetID: targetID))
    }
}

private struct MentionCandidate {
    let matchText: String
    let kind: EntityKind
    let targetName: String
    let targetID: PersistentIdentifier
}

/// Renders one paragraph: plain `Text` when it has no links (max SwiftUI
/// fidelity, including RTF formatting), otherwise a word-wrapping flow with
/// link spans.
private struct ParagraphView: View {
    let paragraph: NSAttributedString
    let candidates: [MentionCandidate]
    let regex: NSRegularExpression

    var body: some View {
        if paragraph.string.isEmpty {
            EmptyView()
        } else {
            WrappingTextFlow(spacing: 0) {
                ForEach(Array(runs.enumerated()), id: \.offset) { _, run in
                    switch run {
                    case .text(let attributed):
                        Text(attributed)
                    case .link(let attributed, let candidate, let request):
                        InlineEntityLink(attributed: attributed, candidate: candidate, request: request)
                    }
                }
            }
        }
    }

    private var runs: [Run] {
        let plain = paragraph.string
        guard !candidates.isEmpty, !plain.isEmpty else { return [] }
        let matches = regex.matches(in: plain, range: NSRange(plain.startIndex..., in: plain))
        guard !matches.isEmpty else { return [] }

        var runs: [Run] = []
        var location = 0
        for match in matches {
            let range = match.range
            if location < range.location {
                Self.appendWordRuns(paragraph.attributedSubstring(from: NSRange(location: location, length: range.location - location)), into: &runs)
            }
            let matchedPlain = (plain as NSString).substring(with: range)
            let matchedAttributed = paragraph.attributedSubstring(from: range)
            if let candidate = candidates.first(where: { $0.matchText.caseInsensitiveCompare(matchedPlain) == .orderedSame }) {
                runs.append(.link(
                    attributed: styledLink(matchedAttributed),
                    candidate: candidate,
                    request: EntityReportRequest(name: candidate.targetName, kind: candidate.kind.rawValue)
                ))
            } else {
                Self.appendWordRuns(matchedAttributed, into: &runs)
            }
            location = range.location + range.length
        }
        if location < plain.utf16.count {
            Self.appendWordRuns(paragraph.attributedSubstring(from: NSRange(location: location, length: plain.utf16.count - location)), into: &runs)
        }
        return runs
    }

    /// Splits a plain-text segment into word runs, preserving all whitespace so
    /// inter-word spacing survives the wrapping layout. Each word keeps the gap
    /// that precedes it (" word"); the segment's trailing gap — the space before
    /// a following link — is attached to the last word. Reconstruction is
    /// lossless. Attributes (font, color) from the source are preserved per word.
    private static func appendWordRuns(_ segment: NSAttributedString, into runs: inout [Run]) {
        let plain = segment.string
        guard let regex = try? NSRegularExpression(pattern: "\\s*\\S+") else {
            runs.append(.text(AttributedString(segment)))
            return
        }
        let matches = regex.matches(in: plain, range: NSRange(plain.startIndex..., in: plain))
        guard !matches.isEmpty else {
            runs.append(.text(AttributedString(segment)))
            return
        }
        for (index, match) in matches.enumerated() {
            var range = match.range
            if index == matches.count - 1 {
                range.length = plain.utf16.count - range.location
            }
            runs.append(.text(AttributedString(segment.attributedSubstring(from: range))))
        }
    }

    private func styledLink(_ nsAttributedString: NSAttributedString) -> AttributedString {
        var attributed = AttributedString(nsAttributedString)
        attributed.foregroundColor = .accentColor
        return attributed
    }
}

private enum Run {
    case text(AttributedString)
    case link(attributed: AttributedString, candidate: MentionCandidate, request: EntityReportRequest)
}

/// Common English words and generic mythological nouns that must never be
/// misread as entity names.
private let StopwordSet: Set<String> = [
    "a", "an", "as", "at", "by", "for", "from", "in", "of", "on", "or", "to", "the", "and",
    "be", "is", "am", "are", "was", "were", "it", "this", "that", "these", "those", "with",
    "he", "she", "they", "we", "you", "me", "us", "him", "her", "them", "his", "hers", "its",
    "our", "their", "my", "your", "do", "does", "did", "not", "no", "so", "up", "if", "then",
    "than", "but", "also", "into", "king", "god", "gods", "goddess", "goddesses", "city",
    "town", "temple", "event", "story", "myth", "son", "daughter", "father", "mother",
    "brother", "sister", "wife", "husband", "consort", "child", "children", "world", "land",
]

// MARK: - Inline entity link token

private struct InlineEntityLink: View {
    let attributed: AttributedString
    let candidate: MentionCandidate
    let request: EntityReportRequest
    @Environment(\.openWindow) private var openWindow
    @Environment(\.navigationCoordinator) private var navigationCoordinator
    @Environment(\.inlineLinkGroupContext) private var inlineLinkGroupContext
    @Environment(\.modelContext) private var modelContext
    @State private var isHovered = false
    @State private var showMugshot = false

    private var displayName: String { request.name }

    private var mugshotFigure: Figure? {
        guard candidate.kind == .figure else { return nil }
        guard let figure = try? modelContext.model(for: candidate.targetID) as? Figure else { return nil }
        return figure.mugshotImage != nil ? figure : nil
    }

    var body: some View {
        Button {
            if let coordinator = navigationCoordinator {
                navigateInSidebar(coordinator)
            } else {
                openWindow(id: "entity-report", value: request)
            }
        } label: {
            Text(attributed)
                .underline(isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
            showMugshot = hovering && mugshotFigure != nil
        }
        .pointingHand()
        .help("View \(request.kind.lowercased()) \"\(displayName)\"")
        .popover(isPresented: $showMugshot, arrowEdge: .bottom) {
            if let figure = mugshotFigure {
                MugshotView(
                    image: figure.mugshotImage,
                    cropRect: ImageCropRect(encoded: figure.mugshotCropRect),
                    size: 120,
                    figureType: figure.figureType,
                    identification: figure.mugshotIdentification
                )
                .padding(8)
            }
        }
    }

    private func navigateInSidebar(_ coordinator: NavigationCoordinator) {
        if let context = inlineLinkGroupContext {
            context.onOpenEntity(candidate.kind, candidate.targetID)
            return
        }
        switch candidate.kind {
        case .figure:
            coordinator.navigateToFigure(candidate.targetID, name: candidate.targetName)
        case .place:
            coordinator.navigateToPlace(candidate.targetID, name: candidate.targetName)
        case .event:
            coordinator.navigateToEvent(candidate.targetID, name: candidate.targetName)
        }
    }
}

// MARK: - Wrapping text flow layout

/// A paragraph-flavoured layout: wraps its children like wrapped text lines,
/// left-aligned, honoring each child's intrinsic size.
private struct WrappingTextFlow: Layout {
    var spacing: CGFloat = 0
    var lineSpacing: CGFloat = 3
    private let fallbackWidth: CGFloat = 400

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? fallbackWidth
        let frames = flowFrames(subviews: subviews, maxWidth: maxWidth)
        let width = frames.map { $0.maxX }.max() ?? 0
        let height = frames.map { $0.maxY }.max() ?? 0
        return CGSize(width: min(width, maxWidth), height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let frames = flowFrames(subviews: subviews, maxWidth: bounds.width)
        for (index, frame) in frames.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                proposal: .unspecified
            )
        }
    }

    private func flowFrames(subviews: Subviews, maxWidth: CGFloat) -> [CGRect] {
        var frames: [CGRect] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                x = 0
                y += lineHeight + lineSpacing
                lineHeight = 0
            }
            frames.append(CGRect(x: x, y: y, width: size.width, height: size.height))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
        return frames
    }
}