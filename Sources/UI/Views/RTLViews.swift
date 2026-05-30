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
            var string: String
            var boldRanges: [NSRange]
            var codeRanges: [NSRange]
            var inlineCodeRanges: [NSRange]
        }

        private static func renderedMarkdownText(from rawText: String) -> RenderedMarkdownText {
            var output = ""
            var boldRanges: [NSRange] = []
            var codeRanges: [NSRange] = []
            var inlineCodeRanges: [NSRange] = []
            var index = rawText.startIndex
            var isInCodeBlock = false
            var codeStart: Int?
            var isInInlineCode = false
            var inlineCodeStart: Int?
            var isInBold = false
            var boldStart: Int?

            while index < rawText.endIndex {
                if rawText[index...].hasPrefix("```") {
                    if isInCodeBlock, let start = codeStart {
                        codeRanges.append(NSRange(location: start, length: (output as NSString).length - start))
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
                codeRanges.append(NSRange(location: start, length: (output as NSString).length - start))
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
                inlineCodeRanges: inlineCodeRanges
            )
        }

        private static func applyMarkdownStyling(to storage: NSTextStorage?, renderedText: RenderedMarkdownText, fullRange: NSRange) {
            guard let storage, fullRange.length > 0 else { return }
            applyBoldStyling(to: storage, ranges: renderedText.boldRanges)
            applyInlineCodeStyling(to: storage, ranges: renderedText.inlineCodeRanges)
            applyCodeBlockStyling(to: storage, text: renderedText.string as NSString, ranges: renderedText.codeRanges)
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
    var codeBlockRanges: [NSRange] = [] {
        didSet {
            needsDisplay = true
        }
    }

    override func drawBackground(in rect: NSRect) {
        drawCodeBlockBackgrounds(in: rect)
        super.drawBackground(in: rect)
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
    @State private var isAccessibilityEnabled: Bool = AccessibilityPermissionHelper.isTrusted()
    
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

            Text("⌃⌥R")
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
