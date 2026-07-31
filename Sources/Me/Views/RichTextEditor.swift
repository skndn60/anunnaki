import SwiftUI
import AppKit

struct RichTextEditor: NSViewRepresentable {
    @Binding var richData: Data?
    @Binding var plainText: String

    func makeNSView(context: Context) -> NSView {
        let container = NSView()
        container.wantsLayer = true

        let toolbar = RichTextToolbar(target: context.coordinator)
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView
        textView.isRichText = true
        textView.allowsUndo = true
        textView.isEditable = true
        textView.isSelectable = true
        textView.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        textView.drawsBackground = true
        textView.backgroundColor = NSColor.controlBackgroundColor
        scrollView.drawsBackground = true
        scrollView.backgroundColor = NSColor.controlBackgroundColor
        textView.delegate = context.coordinator
        context.coordinator.textView = textView

        toolbar.translatesAutoresizingMaskIntoConstraints = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(toolbar)
        container.addSubview(scrollView)

        NSLayoutConstraint.activate([
            toolbar.topAnchor.constraint(equalTo: container.topAnchor),
            toolbar.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            toolbar.heightAnchor.constraint(equalToConstant: 38),

            scrollView.topAnchor.constraint(equalTo: toolbar.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        return container
    }

    func updateNSView(_ container: NSView, context: Context) {
        guard let scrollView = container.subviews.compactMap({ $0 as? NSScrollView }).first,
              let textView = scrollView.documentView as? NSTextView else { return }
        if let data = richData,
           let loadedString = try? NSAttributedString(
            data: data,
            options: [.documentType: NSAttributedString.DocumentType.rtf],
            documentAttributes: nil
           ) {
            let mutable = NSMutableAttributedString(attributedString: loadedString)
            mutable.removeAttribute(.backgroundColor, range: NSRange(location: 0, length: mutable.length))
            let attributedString = mutable
            if !textView.attributedString().isEqual(attributedString) {
                context.coordinator.isUpdating = true
                textView.textStorage?.setAttributedString(attributedString)
                context.coordinator.isUpdating = false
            }
        } else {
            if textView.string != plainText {
                context.coordinator.isUpdating = true
                textView.string = plainText
                context.coordinator.isUpdating = false
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(richData: $richData, plainText: $plainText)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var richData: Binding<Data?>
        var plainText: Binding<String>
        var isUpdating = false
        weak var textView: NSTextView?

        init(richData: Binding<Data?>, plainText: Binding<String>) {
            self.richData = richData
            self.plainText = plainText
        }

        func textDidChange(_ notification: Notification) {
            guard !isUpdating else { return }
            guard let textView = notification.object as? NSTextView else { return }
            plainText.wrappedValue = textView.string
            let range = NSRange(location: 0, length: textView.attributedString().length)
            if range.length > 0,
               let rtfData = try? textView.attributedString().data(
                from: range,
                documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
               ) {
                richData.wrappedValue = rtfData
            } else {
                richData.wrappedValue = nil
            }
        }

        @objc func toggleBold(_ sender: Any?) {
            toggleFontTrait(.boldFontMask)
            syncRichData()
        }

        @objc func toggleItalic(_ sender: Any?) {
            toggleFontTrait(.italicFontMask)
            syncRichData()
        }

        private func toggleFontTrait(_ trait: NSFontTraitMask) {
            guard let tv = textView, let storage = tv.textStorage else { return }
            let range = tv.selectedRange()
            if range.length == 0 { return }
            let fontManager = NSFontManager.shared
            storage.enumerateAttribute(.font, in: range, options: []) { value, subrange, _ in
                guard let font = value as? NSFont else { return }
                let newFont = fontManager.convert(font, toHaveTrait: trait)
                storage.addAttribute(.font, value: newFont, range: subrange)
            }
        }

        @objc func toggleUnderline(_ sender: Any?) {
            guard let tv = textView, let storage = tv.textStorage else { return }
            let range = tv.selectedRange()
            if range.length == 0 { return }
            storage.enumerateAttribute(.underlineStyle, in: range, options: []) { value, subrange, _ in
                let isUnderlined = (value as? Int) == NSUnderlineStyle.single.rawValue
                if isUnderlined {
                    storage.removeAttribute(.underlineStyle, range: subrange)
                } else {
                    storage.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: subrange)
                }
            }
            syncRichData()
        }

        private func syncRichData() {
            guard let tv = textView else { return }
            plainText.wrappedValue = tv.string
            let range = NSRange(location: 0, length: tv.attributedString().length)
            if range.length > 0,
               let rtfData = try? tv.attributedString().data(
                from: range,
                documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
               ) {
                richData.wrappedValue = rtfData
            } else {
                richData.wrappedValue = nil
            }
        }

        @objc func stripFormatting(_ sender: Any?) {
            guard let tv = textView, let storage = tv.textStorage else { return }
            let range = tv.selectedRange()
            let effectiveRange = range.length == 0 ? NSRange(location: 0, length: storage.length) : range

            let plainText = storage.attributedSubstring(from: effectiveRange).string
            let defaultFont = NSFont.systemFont(ofSize: NSFont.systemFontSize)
            let defaultColor = NSColor.textColor

            let replacement = NSAttributedString(string: plainText, attributes: [
                .font: defaultFont,
                .foregroundColor: defaultColor,
            ])
            storage.replaceCharacters(in: effectiveRange, with: replacement)

            tv.typingAttributes = [
                .font: defaultFont,
                .foregroundColor: defaultColor,
            ]
            tv.needsDisplay = true

            syncRichData()
        }

        @objc func orderFrontFontPanel(_ sender: Any?) {
            NSFontManager.shared.orderFrontFontPanel(sender)
        }
    }
}

// MARK: - Native AppKit Toolbar

private class RichTextToolbar: NSView {
    init(target: AnyObject) {
        super.init(frame: .zero)
        wantsLayer = true

        let stack = NSStackView(views: [
            makeButton(title: "B", action: #selector(RichTextEditor.Coordinator.toggleBold), target: target, tooltip: "Bold (Cmd+B)"),
            makeButton(title: "I", action: #selector(RichTextEditor.Coordinator.toggleItalic), target: target, tooltip: "Italic (Cmd+I)"),
            makeButton(title: "U", action: #selector(RichTextEditor.Coordinator.toggleUnderline), target: target, tooltip: "Underline (Cmd+U)"),

            makeDivider(),

            makeButton(title: "Aa", action: #selector(RichTextEditor.Coordinator.orderFrontFontPanel), target: target, tooltip: "Font Panel (Cmd+T)"),

            makeDivider(),

            makeButton(title: "T", action: #selector(RichTextEditor.Coordinator.stripFormatting), target: target, tooltip: "Strip Formatting (remove fonts, sizes, colors)"),
        ])
        stack.orientation = .horizontal
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -6),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            stack.heightAnchor.constraint(equalToConstant: 30),
        ])
    }

    required init?(coder: NSCoder) { nil }

    private func makeButton(title: String, action: Selector, target: AnyObject, tooltip: String) -> NSButton {
        let btn = NSButton(title: title, target: target, action: action)
        btn.bezelStyle = .regularSquare
        btn.isBordered = true
        btn.setContentHuggingPriority(.required, for: .horizontal)
        btn.toolTip = tooltip
        btn.font = NSFont.systemFont(ofSize: 15, weight: .semibold)
        btn.contentTintColor = .labelColor
        return btn
    }

    private func makeDivider() -> NSBox {
        let box = NSBox()
        box.boxType = .separator
        box.setContentHuggingPriority(.required, for: .horizontal)
        return box
    }
}

// MARK: - SwiftUI Wrapper with border

struct RichTextEditorSection: View {
    @Binding var richData: Data?
    @Binding var plainText: String

    var body: some View {
        RichTextEditor(richData: $richData, plainText: $plainText)
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(.separator, lineWidth: 1)
            )
    }
}
