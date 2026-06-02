import SwiftUI
import AppKit

struct TriggerButtonView: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text("RTL")
                .font(.system(size: 11, weight: .semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.white.opacity(0.28), lineWidth: 1)
        )
    }
}

struct RTLTextPanelView: View {
    let onClose: () -> Void
    @State private var text: String

    init(text: String, onClose: @escaping () -> Void) {
        self.onClose = onClose
        _text = State(initialValue: text)
    }

    var body: some View {
        ZStack {
            VisualEffectBlur(material: .hudWindow, blendingMode: .withinWindow)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.22), lineWidth: 1)
                )

            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    Text("RTL Pad")
                        .font(.custom("Vazirmatn-Bold", size: 14))
                        .foregroundStyle(.primary.opacity(0.9))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Button("Paste") {
                        text = NSPasteboard.general.string(forType: .string) ?? text
                    }
                    .buttonStyle(RTLButtonStyle(variant: .secondary))

                    Button("Copy") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(text, forType: .string)
                    }
                    .buttonStyle(RTLButtonStyle(variant: .primary))

                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .bold))
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(RTLButtonStyle(variant: .close))
                }
                .padding(.horizontal, 4)

                BidirectionalTextEditor(text: $text)
                    .padding(10)
                    .background(Color.black.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.white.opacity(0.05), lineWidth: 1)
                    )
            }
            .padding(16)
        }
        .padding(1)
    }
}

struct BidirectionalTextEditor: NSViewRepresentable {
    @Binding var text: String

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder
        scrollView.autohidesScrollers = true
        scrollView.autoresizingMask = [.width, .height]

        let textStorage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer(containerSize: NSSize(width: scrollView.contentSize.width, height: CGFloat.greatestFiniteMagnitude))
        textContainer.widthTracksTextView = true
        textContainer.lineFragmentPadding = 0
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)

        let textView = CodeBlockTextView(frame: .zero, textContainer: textContainer)
        textView.minSize = NSSize(width: 0, height: scrollView.contentSize.height)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        scrollView.documentView = textView

        textView.delegate = context.coordinator
        textView.isEditable = true
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.isRichText = false
        textView.importsGraphics = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.allowsUndo = true
        textView.textColor = .labelColor
        textView.insertionPointColor = .white
        textView.font = NSFont(name: "Vazirmatn-Regular", size: 16) ?? .systemFont(ofSize: 16)
        textView.textContainerInset = NSSize(width: 2, height: 6)
        textView.string = text

        context.coordinator.textView = textView
        context.coordinator.applyDirectionStyling(to: textView, text: text, preserveSelection: false)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        guard textView.string != text else {
            context.coordinator.applyDirectionStyling(to: textView, text: text, preserveSelection: true)
            return
        }

        textView.string = text
        context.coordinator.applyDirectionStyling(to: textView, text: text, preserveSelection: false)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        @Binding var text: String
        weak var textView: NSTextView?
        private var isApplyingStyle = false

        init(text: Binding<String>) {
            _text = text
        }

        func textDidChange(_ notification: Notification) {
            guard let textView, !isApplyingStyle else { return }
            let latestText = textView.string
            if text != latestText {
                text = latestText
            }
            applyDirectionStyling(to: textView, text: latestText, preserveSelection: true)
        }

        func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
            guard let url = link as? URL else { return false }
            NSWorkspace.shared.open(url)
            return true
        }

        func applyDirectionStyling(to textView: NSTextView, text: String, preserveSelection: Bool) {
            guard !isApplyingStyle else { return }
            isApplyingStyle = true
            defer { isApplyingStyle = false }

            let selectedRanges = preserveSelection ? textView.selectedRanges : []
            let renderedText = Self.renderedMarkdownText(from: text)
            let fullRange = NSRange(location: 0, length: (renderedText.string as NSString).length)
            let storage = textView.textStorage

            if textView.string != renderedText.string {
                textView.string = renderedText.string
            }
            (textView as? CodeBlockTextView)?.codeBlockRanges = renderedText.codeRanges
            (textView as? CodeBlockTextView)?.mermaidDiagrams = renderedText.mermaidDiagrams.map {
                CodeBlockTextView.MermaidDiagram(range: $0.range, nodes: $0.nodes)
            }

            storage?.beginEditing()
            storage?.setAttributes(Self.baseAttributes(), range: fullRange)

            let nsText = renderedText.string as NSString
            nsText.enumerateSubstrings(in: NSRange(location: 0, length: nsText.length), options: [.byParagraphs, .substringNotRequired]) { _, paragraphRange, _, _ in
                let lineText = nsText.substring(with: paragraphRange)
                let isRTL = Self.shouldRenderRTL(lineText)
                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.alignment = isRTL ? .right : .left
                paragraphStyle.baseWritingDirection = isRTL ? .rightToLeft : .leftToRight
                paragraphStyle.lineSpacing = 4
                paragraphStyle.paragraphSpacing = 6

                storage?.addAttribute(.paragraphStyle, value: paragraphStyle, range: paragraphRange)
            }
            Self.applyMarkdownStyling(to: storage, renderedText: renderedText, fullRange: fullRange)
            storage?.endEditing()

            if preserveSelection, !selectedRanges.isEmpty {
                textView.selectedRanges = selectedRanges
            }
        }

        private static func baseAttributes() -> [NSAttributedString.Key: Any] {
            [
                .font: NSFont(name: "Vazirmatn-Regular", size: 16) ?? .systemFont(ofSize: 16),
                .foregroundColor: NSColor.labelColor
            ]
        }

        private struct RenderedMarkdownText {
            struct LinkRange {
                var range: NSRange
                var target: String
            }

            struct MermaidDiagram {
                var range: NSRange
                var nodes: [String]
            }

            var string: String
            var boldRanges: [NSRange]
            var codeRanges: [NSRange]
            var inlineCodeRanges: [NSRange]
            var linkRanges: [LinkRange]
            var mermaidDiagrams: [MermaidDiagram]
        }

        private static func renderedMarkdownText(from rawText: String) -> RenderedMarkdownText {
            var output = ""
            var boldRanges: [NSRange] = []
            var codeRanges: [NSRange] = []
            var inlineCodeRanges: [NSRange] = []
            var linkRanges: [RenderedMarkdownText.LinkRange] = []
            var mermaidDiagrams: [RenderedMarkdownText.MermaidDiagram] = []
            var index = rawText.startIndex
            var isInCodeBlock = false
            var codeStart: Int?
            var isInInlineCode = false
            var inlineCodeStart: Int?
            var isInBold = false
            var boldStart: Int?

            while index < rawText.endIndex {
                if isInvisibleMarkdownControl(rawText[index]) {
                    let visibleIndex = firstVisibleIndex(startingAt: index, in: rawText)
                    if visibleIndex < rawText.endIndex,
                       rawText[visibleIndex] == "[" || rawText[visibleIndex] == "(" {
                        index = visibleIndex
                        continue
                    }
                }

                if rawText[index...].hasPrefix("```") {
                    if isInCodeBlock, let start = codeStart {
                        let currentLength = (output as NSString).length
                        let blockRange = NSRange(location: start, length: currentLength - start)
                        if let mermaid = mermaidDiagram(in: output, range: blockRange) {
                            output = (output as NSString).replacingCharacters(in: blockRange, with: mermaidPlaceholder)
                            mermaidDiagrams.append(RenderedMarkdownText.MermaidDiagram(
                                range: NSRange(location: start, length: (mermaidPlaceholder as NSString).length),
                                nodes: mermaid
                            ))
                        } else {
                            codeRanges.append(blockRange)
                        }
                        codeStart = nil
                    } else {
                        codeStart = (output as NSString).length
                    }
                    isInCodeBlock.toggle()
                    index = rawText.index(index, offsetBy: 3)

                    if index < rawText.endIndex, rawText[index].isNewline {
                        index = rawText.index(after: index)
                    }
                    continue
                }

                if !isInCodeBlock,
                   !isInInlineCode,
                   let link = markdownLink(at: index, in: rawText) ?? reversedMarkdownLink(at: index, in: rawText) {
                    let start = (output as NSString).length
                    output.append(link.label)
                    let length = (link.label as NSString).length
                    if length > 0 {
                        linkRanges.append(RenderedMarkdownText.LinkRange(
                            range: NSRange(location: start, length: length),
                            target: link.target
                        ))
                    }
                    index = link.nextIndex
                    continue
                }

                if !isInCodeBlock, rawText[index] == "`" {
                    if isInInlineCode, let start = inlineCodeStart {
                        inlineCodeRanges.append(NSRange(location: start, length: (output as NSString).length - start))
                        inlineCodeStart = nil
                    } else {
                        inlineCodeStart = (output as NSString).length
                    }
                    isInInlineCode.toggle()
                    index = rawText.index(after: index)
                    continue
                }

                if !isInCodeBlock, !isInInlineCode, rawText[index...].hasPrefix("**") {
                    if isInBold, let start = boldStart {
                        boldRanges.append(NSRange(location: start, length: (output as NSString).length - start))
                        boldStart = nil
                    } else {
                        boldStart = (output as NSString).length
                    }
                    isInBold.toggle()
                    index = rawText.index(index, offsetBy: 2)
                    continue
                }

                output.append(rawText[index])
                index = rawText.index(after: index)
            }

            if let start = codeStart {
                let blockRange = NSRange(location: start, length: (output as NSString).length - start)
                if let mermaid = mermaidDiagram(in: output, range: blockRange) {
                    output = (output as NSString).replacingCharacters(in: blockRange, with: mermaidPlaceholder)
                    mermaidDiagrams.append(RenderedMarkdownText.MermaidDiagram(
                        range: NSRange(location: start, length: (mermaidPlaceholder as NSString).length),
                        nodes: mermaid
                    ))
                } else {
                    codeRanges.append(blockRange)
                }
            }
            if let start = inlineCodeStart {
                inlineCodeRanges.append(NSRange(location: start, length: (output as NSString).length - start))
            }
            if let start = boldStart {
                boldRanges.append(NSRange(location: start, length: (output as NSString).length - start))
            }

            return RenderedMarkdownText(
                string: output,
                boldRanges: boldRanges,
                codeRanges: codeRanges,
                inlineCodeRanges: inlineCodeRanges,
                linkRanges: linkRanges,
                mermaidDiagrams: mermaidDiagrams
            )
        }

        private static let mermaidPlaceholder = "\u{00A0}\n\u{00A0}\n\u{00A0}\n\u{00A0}\n\u{00A0}\n"

        private static func mermaidDiagram(in output: String, range: NSRange) -> [String]? {
            let block = (output as NSString).substring(with: range)
                .trimmingCharacters(in: .whitespacesAndNewlines)

            let content: String
            if block.lowercased().hasPrefix("mermaid") {
                content = String(block.dropFirst("mermaid".count))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                content = block
            }

            guard content.lowercased().hasPrefix("flowchart lr") else { return nil }

            let pattern = #"[A-Za-z0-9_]+\["([^"]+)"\]"#
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
            let nsContent = content as NSString
            let matches = regex.matches(in: content, range: NSRange(location: 0, length: nsContent.length))

            var seen = Set<String>()
            let nodes = matches.compactMap { match -> String? in
                guard match.numberOfRanges > 1 else { return nil }
                let label = nsContent.substring(with: match.range(at: 1))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                guard !label.isEmpty, !seen.contains(label) else { return nil }
                seen.insert(label)
                return label
            }

            guard nodes.count >= 2 else { return nil }
            return nodes
        }

        private static func markdownLink(at index: String.Index, in text: String) -> (label: String, target: String, nextIndex: String.Index)? {
            guard text[index] == "[" else { return nil }
            guard let labelEnd = text[index...].firstIndex(of: "]") else { return nil }
            let openParen = firstVisibleIndex(after: labelEnd, in: text)
            guard openParen < text.endIndex, text[openParen] == "(" else { return nil }
            guard let targetEnd = text[openParen...].firstIndex(of: ")") else { return nil }

            let labelStart = text.index(after: index)
            let targetStart = text.index(after: openParen)
            let label = String(text[labelStart..<labelEnd])
            let target = String(text[targetStart..<targetEnd])
            return (label, target, text.index(after: targetEnd))
        }

        private static func reversedMarkdownLink(at index: String.Index, in text: String) -> (label: String, target: String, nextIndex: String.Index)? {
            guard text[index] == "(" else { return nil }
            guard let targetEnd = text[index...].firstIndex(of: ")") else { return nil }
            let openBracket = firstVisibleIndex(after: targetEnd, in: text)
            guard openBracket < text.endIndex, text[openBracket] == "[" else { return nil }
            guard let labelEnd = text[openBracket...].firstIndex(of: "]") else { return nil }

            let targetStart = text.index(after: index)
            let labelStart = text.index(after: openBracket)
            let label = String(text[labelStart..<labelEnd])
            let target = String(text[targetStart..<targetEnd])
            return (label, target, text.index(after: labelEnd))
        }

        private static func firstVisibleIndex(after index: String.Index, in text: String) -> String.Index {
            var cursor = text.index(after: index)
            while cursor < text.endIndex, isIgnorableMarkdownSpacer(text[cursor]) {
                cursor = text.index(after: cursor)
            }
            return cursor
        }

        private static func firstVisibleIndex(startingAt index: String.Index, in text: String) -> String.Index {
            var cursor = index
            while cursor < text.endIndex, isInvisibleMarkdownControl(text[cursor]) {
                cursor = text.index(after: cursor)
            }
            return cursor
        }

        private static func isIgnorableMarkdownSpacer(_ character: Character) -> Bool {
            isInvisibleMarkdownControl(character) || character.unicodeScalars.allSatisfy {
                CharacterSet.whitespacesAndNewlines.contains($0)
            }
        }

        private static func isInvisibleMarkdownControl(_ character: Character) -> Bool {
            character.unicodeScalars.allSatisfy { scalar in
                scalar.value == 0x200B
                    || scalar.value == 0x200C
                    || scalar.value == 0x200D
                    || scalar.value == 0xFEFF
                    || scalar.value == 0x061C
                    || scalar.value == 0x200E
                    || scalar.value == 0x200F
                    || (0x202A...0x202E).contains(scalar.value)
                    || (0x2066...0x2069).contains(scalar.value)
            }
        }

        private static func applyMarkdownStyling(to storage: NSTextStorage?, renderedText: RenderedMarkdownText, fullRange: NSRange) {
            guard let storage, fullRange.length > 0 else { return }
            applyBoldStyling(to: storage, ranges: renderedText.boldRanges)
            applyInlineCodeStyling(to: storage, ranges: renderedText.inlineCodeRanges)
            applyLinkStyling(to: storage, links: renderedText.linkRanges)
            applyCodeBlockStyling(to: storage, text: renderedText.string as NSString, ranges: renderedText.codeRanges)
            applyMermaidStyling(to: storage, ranges: renderedText.mermaidDiagrams.map(\.range))
        }

        private static func applyBoldStyling(to storage: NSTextStorage, ranges: [NSRange]) {
            let boldFont = NSFont(name: "Vazirmatn-Bold", size: 16) ?? .boldSystemFont(ofSize: 16)

            ranges.forEach { range in
                guard range.length > 0 else { return }
                storage.addAttribute(.font, value: boldFont, range: range)
            }
        }

        private static func applyInlineCodeStyling(to storage: NSTextStorage, ranges: [NSRange]) {
            let codeFont = NSFont.monospacedSystemFont(ofSize: 15, weight: .regular)
            let codeBackground = NSColor(calibratedWhite: 0.24, alpha: 1)
            let codeColor = NSColor(calibratedWhite: 0.96, alpha: 1)

            ranges.forEach { range in
                guard range.length > 0 else { return }
                storage.addAttributes([
                    .font: codeFont,
                    .foregroundColor: codeColor,
                    .backgroundColor: codeBackground
                ], range: range)
            }
        }

        private static func applyLinkStyling(to storage: NSTextStorage, links: [RenderedMarkdownText.LinkRange]) {
            links.forEach { link in
                guard link.range.length > 0, let url = url(forMarkdownTarget: link.target) else { return }
                storage.addAttributes([
                    .link: url,
                    .foregroundColor: NSColor.systemBlue,
                    .underlineStyle: NSUnderlineStyle.single.rawValue
                ], range: link.range)
            }
        }

        private static func url(forMarkdownTarget target: String) -> URL? {
            if let url = URL(string: target), url.scheme != nil {
                return url
            }

            var fileTarget = target
            if let match = fileTarget.range(of: #":\d+$"#, options: .regularExpression) {
                fileTarget.removeSubrange(match)
            }

            return URL(fileURLWithPath: fileTarget)
        }

        private static func applyCodeBlockStyling(to storage: NSTextStorage, text: NSString, ranges: [NSRange]) {
            let codeFont = NSFont.monospacedSystemFont(ofSize: 15, weight: .regular)
            let codeColor = NSColor(calibratedWhite: 0.92, alpha: 1)

            ranges.forEach { range in
                guard range.length > 0 else { return }
                let paragraphRange = text.paragraphRange(for: range)
                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.alignment = .left
                paragraphStyle.baseWritingDirection = .leftToRight
                paragraphStyle.lineSpacing = 4
                paragraphStyle.paragraphSpacing = 8
                paragraphStyle.headIndent = 12
                paragraphStyle.firstLineHeadIndent = 12
                paragraphStyle.tailIndent = -12

                storage.addAttributes([
                    .font: codeFont,
                    .foregroundColor: codeColor,
                    .paragraphStyle: paragraphStyle
                ], range: range)

                storage.addAttribute(.paragraphStyle, value: paragraphStyle, range: paragraphRange)
            }
        }

        private static func applyMermaidStyling(to storage: NSTextStorage, ranges: [NSRange]) {
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .left
            paragraphStyle.baseWritingDirection = .leftToRight
            paragraphStyle.minimumLineHeight = 24
            paragraphStyle.maximumLineHeight = 24
            paragraphStyle.paragraphSpacing = 10

            ranges.forEach { range in
                guard range.length > 0 else { return }
                storage.addAttributes([
                    .font: NSFont.monospacedSystemFont(ofSize: 18, weight: .regular),
                    .foregroundColor: NSColor.clear,
                    .paragraphStyle: paragraphStyle
                ], range: range)
            }
        }

        private static func shouldRenderRTL(_ text: String) -> Bool {
            text.unicodeScalars.contains { scalar in
                switch scalar.value {
                case 0x0590...0x08FF, 0xFB50...0xFDFF, 0xFE70...0xFEFF:
                    return true
                default:
                    return false
                }
            }
        }
    }
}

final class CodeBlockTextView: NSTextView {
    struct MermaidDiagram {
        var range: NSRange
        var nodes: [String]
    }

    var codeBlockRanges: [NSRange] = [] {
        didSet {
            needsDisplay = true
        }
    }

    var mermaidDiagrams: [MermaidDiagram] = [] {
        didSet {
            needsDisplay = true
        }
    }
    private var mermaidScrollOffsets: [Int: CGFloat] = [:]

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        drawMermaidDiagrams(in: dirtyRect)
    }

    override func drawBackground(in rect: NSRect) {
        drawCodeBlockBackgrounds(in: rect)
        super.drawBackground(in: rect)
    }

    override func keyDown(with event: NSEvent) {
        let isCopyShortcut = event.keyCode == 8
            && (event.modifierFlags.contains(.command) || event.modifierFlags.contains(.control))

        if isCopyShortcut {
            copy(nil)
            return
        }

        super.keyDown(with: event)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let isCommandCopy = event.keyCode == 8 && event.modifierFlags.contains(.command)
        if isCommandCopy {
            copy(nil)
            return true
        }

        return super.performKeyEquivalent(with: event)
    }

    override func mouseDown(with event: NSEvent) {
        if openLink(at: event.locationInWindow) {
            return
        }

        super.mouseDown(with: event)
    }

    override func scrollWheel(with event: NSEvent) {
        if scrollMermaidDiagram(with: event) {
            return
        }

        super.scrollWheel(with: event)
    }

    override func copy(_ sender: Any?) {
        copySelectedTextToPasteboard()
    }

    private func copySelectedTextToPasteboard() {
        let selectedText = selectedRanges
            .compactMap { $0.rangeValue }
            .filter { $0.length > 0 }
            .map { (string as NSString).substring(with: $0) }
            .joined(separator: "\n")

        guard !selectedText.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(selectedText, forType: .string)
    }

    private func openLink(at windowPoint: NSPoint) -> Bool {
        guard
            let layoutManager,
            let textContainer,
            let textStorage
        else { return false }

        let point = convert(windowPoint, from: nil)
        let containerPoint = NSPoint(
            x: point.x - textContainerOrigin.x,
            y: point.y - textContainerOrigin.y
        )
        guard textContainer.containerSize.width > 0, textContainer.containerSize.height > 0 else {
            return false
        }

        layoutManager.ensureLayout(for: textContainer)
        let glyphIndex = layoutManager.glyphIndex(for: containerPoint, in: textContainer)
        let characterIndex = layoutManager.characterIndexForGlyph(at: glyphIndex)
        guard characterIndex >= 0, characterIndex < textStorage.length else { return false }
        guard let url = textStorage.attribute(.link, at: characterIndex, effectiveRange: nil) as? URL else {
            return false
        }

        NSWorkspace.shared.open(url)
        return true
    }

    private func drawCodeBlockBackgrounds(in dirtyRect: NSRect) {
        guard
            !codeBlockRanges.isEmpty,
            let layoutManager,
            let textContainer
        else { return }

        let textOrigin = textContainerOrigin
        let horizontalInset: CGFloat = 8
        let verticalInset: CGFloat = 10
        let blockColor = NSColor(calibratedWhite: 0.16, alpha: 1)

        for characterRange in codeBlockRanges where characterRange.length > 0 {
            let glyphRange = layoutManager.glyphRange(forCharacterRange: characterRange, actualCharacterRange: nil)
            guard glyphRange.length > 0 else { continue }

            layoutManager.ensureLayout(for: textContainer)
            let usedRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
            let blockRect = NSRect(
                x: horizontalInset,
                y: textOrigin.y + usedRect.minY - verticalInset,
                width: bounds.width - (horizontalInset * 2),
                height: usedRect.height + (verticalInset * 2)
            )

            guard blockRect.intersects(dirtyRect) else { continue }

            blockColor.setFill()
            NSBezierPath(roundedRect: blockRect, xRadius: 12, yRadius: 12).fill()
        }
    }

    private func drawMermaidDiagrams(in dirtyRect: NSRect) {
        guard
            !mermaidDiagrams.isEmpty,
            let layoutManager,
            let textContainer
        else { return }

        layoutManager.ensureLayout(for: textContainer)

        for diagram in mermaidDiagrams where diagram.range.length > 0 && diagram.nodes.count >= 2 {
            guard let containerRect = mermaidContainerRect(for: diagram, layoutManager: layoutManager, textContainer: textContainer) else {
                continue
            }

            guard containerRect.intersects(dirtyRect) else { continue }
            drawMermaidContainer(in: containerRect)
            drawMermaidNodes(
                diagram.nodes,
                in: containerRect,
                scrollOffset: mermaidScrollOffsets[diagram.range.location] ?? 0
            )
        }
    }

    private func mermaidContainerRect(
        for diagram: MermaidDiagram,
        layoutManager: NSLayoutManager,
        textContainer: NSTextContainer
    ) -> NSRect? {
        let glyphRange = layoutManager.glyphRange(forCharacterRange: diagram.range, actualCharacterRange: nil)
        guard glyphRange.length > 0 else { return nil }

        let usedRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
        let textOrigin = textContainerOrigin
        return NSRect(
            x: 8,
            y: textOrigin.y + usedRect.minY - 8,
            width: max(120, bounds.width - 16),
            height: max(116, usedRect.height + 16)
        )
    }

    private func drawMermaidContainer(in rect: NSRect) {
        let path = NSBezierPath(roundedRect: rect, xRadius: 14, yRadius: 14)
        NSColor(calibratedWhite: 0.10, alpha: 0.72).setFill()
        path.fill()
        NSColor(calibratedWhite: 0.24, alpha: 0.9).setStroke()
        path.lineWidth = 1
        path.stroke()
    }

    private func drawMermaidNodes(_ nodes: [String], in containerRect: NSRect, scrollOffset: CGFloat) {
        let gap: CGFloat = 28
        let nodeWidth: CGFloat = 170
        let contentWidth = preferredMermaidWidth(forNodeCount: nodes.count)
        let startX = containerRect.minX + 40 - scrollOffset
        let nodeHeight: CGFloat = 62
        let nodeY = containerRect.midY - nodeHeight / 2

        NSGraphicsContext.current?.saveGraphicsState()
        NSBezierPath(roundedRect: containerRect.insetBy(dx: 1, dy: 1), xRadius: 13, yRadius: 13).setClip()

        var nodeRects: [NSRect] = []
        for (index, label) in nodes.enumerated() {
            let rect = NSRect(
                x: startX + CGFloat(index) * (nodeWidth + gap),
                y: nodeY,
                width: nodeWidth,
                height: nodeHeight
            )
            nodeRects.append(rect)
            drawMermaidNode(label, in: rect)
        }

        for index in 0..<(nodeRects.count - 1) {
            drawMermaidArrow(from: nodeRects[index], to: nodeRects[index + 1])
        }

        if contentWidth > containerRect.width {
            drawMermaidScrollHint(in: containerRect, contentWidth: contentWidth, scrollOffset: scrollOffset)
        }

        NSGraphicsContext.current?.restoreGraphicsState()
    }

    private func preferredMermaidWidth(forNodeCount count: Int) -> CGFloat {
        guard count > 0 else { return 0 }
        let nodeWidth: CGFloat = 170
        let gap: CGFloat = 28
        let padding: CGFloat = 80
        return CGFloat(count) * nodeWidth + CGFloat(max(0, count - 1)) * gap + padding
    }

    private func scrollMermaidDiagram(with event: NSEvent) -> Bool {
        guard
            !mermaidDiagrams.isEmpty,
            let layoutManager,
            let textContainer
        else { return false }

        layoutManager.ensureLayout(for: textContainer)

        let point = convert(event.locationInWindow, from: nil)
        guard let diagram = mermaidDiagrams.first(where: { diagram in
            guard let rect = mermaidContainerRect(for: diagram, layoutManager: layoutManager, textContainer: textContainer) else {
                return false
            }
            return rect.contains(point)
        }) else { return false }

        let contentWidth = preferredMermaidWidth(forNodeCount: diagram.nodes.count)
        guard
            let containerRect = mermaidContainerRect(for: diagram, layoutManager: layoutManager, textContainer: textContainer),
            contentWidth > containerRect.width
        else { return false }

        let horizontalDelta = event.scrollingDeltaX != 0
            ? event.scrollingDeltaX
            : (event.modifierFlags.contains(.shift) ? event.scrollingDeltaY : 0)
        guard abs(horizontalDelta) > 0 else { return false }

        let key = diagram.range.location
        let maxOffset = max(0, contentWidth - containerRect.width)
        let currentOffset = mermaidScrollOffsets[key] ?? 0
        let nextOffset = min(maxOffset, max(0, currentOffset + horizontalDelta))
        mermaidScrollOffsets[key] = nextOffset
        needsDisplay = true
        return true
    }

    private func drawMermaidScrollHint(in rect: NSRect, contentWidth: CGFloat, scrollOffset: CGFloat) {
        let trackWidth = max(40, rect.width - 56)
        let trackRect = NSRect(x: rect.minX + 28, y: rect.minY + 10, width: trackWidth, height: 3)
        let thumbWidth = max(24, trackWidth * min(1, rect.width / contentWidth))
        let maxOffset = max(1, contentWidth - rect.width)
        let thumbX = trackRect.minX + (trackWidth - thumbWidth) * min(1, max(0, scrollOffset / maxOffset))

        NSColor(calibratedWhite: 1, alpha: 0.08).setFill()
        NSBezierPath(roundedRect: trackRect, xRadius: 1.5, yRadius: 1.5).fill()

        NSColor(calibratedWhite: 1, alpha: 0.28).setFill()
        NSBezierPath(
            roundedRect: NSRect(x: thumbX, y: trackRect.minY, width: thumbWidth, height: trackRect.height),
            xRadius: 1.5,
            yRadius: 1.5
        ).fill()
    }

    private func drawMermaidNode(_ label: String, in rect: NSRect) {
        let path = NSBezierPath(rect: rect)
        NSColor(calibratedWhite: 0.20, alpha: 1).setFill()
        path.fill()

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.baseWritingDirection = containsRTL(label) ? .rightToLeft : .leftToRight
        paragraph.lineBreakMode = .byWordWrapping

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont(name: "Vazirmatn-Regular", size: 14) ?? NSFont.systemFont(ofSize: 14),
            .foregroundColor: NSColor(calibratedWhite: 0.92, alpha: 1),
            .paragraphStyle: paragraph
        ]
        let insetRect = rect.insetBy(dx: 10, dy: 8)
        (label as NSString).draw(with: insetRect, options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attributes)
    }

    private func drawMermaidArrow(from startRect: NSRect, to endRect: NSRect) {
        let start = NSPoint(x: startRect.maxX, y: startRect.midY)
        let end = NSPoint(x: endRect.minX - 2, y: endRect.midY)
        let line = NSBezierPath()
        line.move(to: start)
        line.line(to: end)
        NSColor(calibratedWhite: 0.72, alpha: 0.86).setStroke()
        line.lineWidth = 1
        line.stroke()

        let arrow = NSBezierPath()
        arrow.move(to: end)
        arrow.line(to: NSPoint(x: end.x - 7, y: end.y + 4))
        arrow.move(to: end)
        arrow.line(to: NSPoint(x: end.x - 7, y: end.y - 4))
        arrow.lineWidth = 1
        arrow.stroke()
    }

    private func containsRTL(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            switch scalar.value {
            case 0x0590...0x08FF, 0xFB50...0xFDFF, 0xFE70...0xFEFF:
                return true
            default:
                return false
            }
        }
    }
}

struct RTLButtonStyle: ButtonStyle {
    enum Variant {
        case primary, secondary, close
    }
    
    let variant: Variant
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .padding(.horizontal, variant == .close ? 0 : 12)
            .padding(.vertical, variant == .close ? 0 : 6)
            .background(backgroundColor(configuration.isPressed))
            .foregroundStyle(foregroundColor())
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
            .animation(.easeOut(duration: 0.15), value: isHovered)
            .onHover { isHovered = $0 }
    }

    private func backgroundColor(_ isPressed: Bool) -> Color {
        switch variant {
        case .primary:
            return .blue.opacity(isPressed ? 0.8 : (isHovered ? 0.7 : 0.6))
        case .secondary:
            return .white.opacity(isPressed ? 0.15 : (isHovered ? 0.1 : 0.05))
        case .close:
            return isHovered ? .red.opacity(0.8) : .white.opacity(0.05)
        }
    }

    private func foregroundColor() -> Color {
        switch variant {
        case .primary:
            return .white
        case .secondary:
            return .primary.opacity(0.9)
        case .close:
            return isHovered ? .white : .secondary
        }
    }
}

struct VisualEffectBlur: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = .active
    }
}

struct MenuBarView: View {
    private enum DefaultsKey {
        static let autoOpenCopiedText = "rast.autoOpenCopiedText"
    }

    @State private var isAccessibilityEnabled: Bool = AccessibilityPermissionHelper.isTrusted()
    @AppStorage(DefaultsKey.autoOpenCopiedText) private var autoOpenCopiedText = false
    
    var onOpenRTLPad: () -> Void
    var onCheckAccessibility: () -> Void
    var onQuit: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.145, green: 0.152, blue: 0.19),
                    Color(red: 0.118, green: 0.124, blue: 0.155)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.22),
                                Color.white.opacity(0.05)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            )
            .overlay(alignment: .topLeading) {
                Circle()
                    .fill(Color(red: 0.34, green: 0.56, blue: 1.0).opacity(0.18))
                    .frame(width: 180, height: 180)
                    .blur(radius: 42)
                    .offset(x: -28, y: -70)
            }

            VStack(spacing: 0) {
                headerSection
                shortcutPill

                VStack(spacing: 14) {
                    autoOpenCard

                    actionCard(
                        title: "Open RTL Pad",
                        subtitle: "Compose, clean up, and copy bidirectional text.",
                        trailingLabel: "⌘O",
                        accent: Color(red: 0.37, green: 0.67, blue: 1.0),
                        iconSystemName: "arrow.up.left.and.arrow.down.right"
                    ) {
                        onOpenRTLPad()
                    }

                    actionCard(
                        title: "Accessibility",
                        subtitle: isAccessibilityEnabled ? "Everything is ready for selection capture." : "Grant access to read text from other apps.",
                        trailingLabel: isAccessibilityEnabled ? "Ready" : "Fix",
                        accent: isAccessibilityEnabled ? Color(red: 0.26, green: 0.84, blue: 0.42) : Color(red: 1.0, green: 0.67, blue: 0.21),
                        iconSystemName: isAccessibilityEnabled ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
                    ) {
                        onCheckAccessibility()
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 16)
                .padding(.bottom, 18)

                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 1)
                    .padding(.horizontal, 18)

                Button(action: onQuit) {
                    HStack(spacing: 10) {
                        Image(systemName: "power")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.5))

                        Text("Quit")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.92))

                        Spacer()

                        Text("⌘Q")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.36))
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
                .buttonStyle(SimpleHoverButtonStyle(opacityDelta: 0.08, scale: 0.99))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.34), radius: 20, x: 0, y: 10)
        .frame(width: 348)
        .onAppear {
            isAccessibilityEnabled = AccessibilityPermissionHelper.isTrusted()
        }
    }

    private var headerSection: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.14),
                                Color.white.opacity(0.04)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.white.opacity(0.14), lineWidth: 1)
                    )

                if let appIcon = NSApp.applicationIconImage {
                    Image(nsImage: appIcon)
                        .resizable()
                        .scaledToFit()
                        .padding(4)
                }
            }
            .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 4) {
                Text("Rast")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("Bidirectional writing companion")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.42))
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 18)
    }

    private var shortcutPill: some View {
        HStack(spacing: 10) {
            Text("Global Shortcut")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.45))

            Spacer(minLength: 0)

            Text("⌘⌥R")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.78))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.055))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
        .padding(.horizontal, 18)
    }

    private var autoOpenCard: some View {
        Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                autoOpenCopiedText.toggle()
            }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(red: 0.55, green: 0.42, blue: 1.0).opacity(0.16))
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color(red: 0.65, green: 0.78, blue: 1.0))
                }
                .frame(width: 42, height: 42)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Auto-open copied text")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)

                    Text(autoOpenCopiedText ? "Copied text opens in RTL Pad instantly." : "Keep copied text in clipboard only.")
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.42))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 8)

                toggleSwitch(isOn: autoOpenCopiedText)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(autoOpenCopiedText ? Color.white.opacity(0.07) : Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(
                                autoOpenCopiedText
                                    ? Color(red: 0.45, green: 0.66, blue: 1.0).opacity(0.34)
                                    : Color.white.opacity(0.08),
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(SimpleHoverButtonStyle(opacityDelta: 0.04, scale: 0.992))
    }

    private func toggleSwitch(isOn: Bool) -> some View {
        ZStack(alignment: isOn ? .trailing : .leading) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    isOn
                        ? Color(red: 0.24, green: 0.48, blue: 1.0)
                        : Color.white.opacity(0.13)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(isOn ? 0.18 : 0.1), lineWidth: 1)
                )

            Circle()
                .fill(.white)
                .frame(width: 20, height: 20)
                .shadow(color: .black.opacity(0.18), radius: 4, x: 0, y: 2)
                .padding(3)
        }
        .frame(width: 46, height: 26)
        .accessibilityLabel("Auto-open copied text")
        .accessibilityValue(isOn ? "On" : "Off")
    }

    private func actionCard(
        title: String,
        subtitle: String,
        trailingLabel: String,
        accent: Color,
        iconSystemName: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(accent.opacity(0.14))
                    Image(systemName: iconSystemName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(accent)
                }
                .frame(width: 42, height: 42)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)

                    Text(subtitle)
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.42))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 8)

                HStack(spacing: 7) {
                    if title == "Accessibility" {
                        Circle()
                            .fill(accent)
                            .frame(width: 8, height: 8)
                    }

                    Text(trailingLabel)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(accent)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(SimpleHoverButtonStyle(opacityDelta: 0.04, scale: 0.992))
    }
}

struct SimpleHoverButtonStyle: ButtonStyle {
    var opacityDelta: Double = 0.1
    var scale: CGFloat = 0.985
    @State private var isHovered = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            .opacity(isHovered ? (1.0 - opacityDelta) : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHovered)
            .animation(.spring(response: 0.24, dampingFraction: 0.72), value: configuration.isPressed)
            .onHover { isHovered = $0 }
    }
}
