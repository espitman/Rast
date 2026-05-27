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
                        .frame(maxWidth: .infinity, alignment: .trailing)

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
        let scrollView = NSTextView.scrollableTextView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder
        scrollView.autohidesScrollers = true

        guard let textView = scrollView.documentView as? NSTextView else {
            return scrollView
        }

        textView.delegate = context.coordinator
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
            let fullRange = NSRange(location: 0, length: (text as NSString).length)
            let storage = textView.textStorage

            storage?.beginEditing()
            storage?.removeAttribute(.paragraphStyle, range: fullRange)

            let nsText = text as NSString
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
            storage?.endEditing()

            if preserveSelection, !selectedRanges.isEmpty {
                textView.selectedRanges = selectedRanges
            }

            let dominantRTL = Self.shouldRenderRTL(text)
            textView.alignment = dominantRTL ? .right : .left
            textView.baseWritingDirection = dominantRTL ? .rightToLeft : .leftToRight
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
