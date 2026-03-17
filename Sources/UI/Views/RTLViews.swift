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

                TextEditor(text: $text)
                    .font(.custom("Vazirmatn-Regular", size: 16))
                    .lineSpacing(4)
                    .multilineTextAlignment(.leading)
                    .scrollContentBackground(.hidden)
                    .padding(10)
                    .background(Color.black.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.white.opacity(0.05), lineWidth: 1)
                    )
            }
            .padding(16)
            .environment(\.layoutDirection, .rightToLeft)
        }
        .padding(1)
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
