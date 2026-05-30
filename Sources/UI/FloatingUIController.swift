import AppKit
import SwiftUI

final class FloatingUIController: NSObject, NSWindowDelegate {
    private enum DefaultsKey {
        static let panelWidth = "rast.rtlPad.width"
        static let panelHeight = "rast.rtlPad.height"
    }

    private let defaultPanelSize = NSSize(width: 420, height: 260)
    private let minPanelSize = NSSize(width: 320, height: 200)
    private var triggerPanel: NSPanel?
    private var textPanel: NSPanel?

    private var globalMouseMonitor: Any?
    private var localKeyMonitor: Any?

    var isTextPanelVisible: Bool {
        textPanel?.isVisible == true
    }

    func showTrigger(for text: String) {
        let panel = triggerPanel ?? makeTriggerPanel()
        triggerPanel = panel

        panel.contentView = NSHostingView(rootView: TriggerButtonView { [weak self] in
            self?.showTextPanel(with: text, near: NSEvent.mouseLocation)
        })

        let origin = adjustedOrigin(
            for: NSRect(x: 0, y: 0, width: 46, height: 30),
            near: NSEvent.mouseLocation
        )
        panel.setFrameOrigin(origin)
        panel.orderFrontRegardless()
    }

    func hideTrigger() {
        triggerPanel?.orderOut(nil)
    }

    func showTextPanel(with text: String, near point: NSPoint? = nil) {
        hideTrigger()
        NSApp.activate(ignoringOtherApps: true)

        let panel = textPanel ?? makeTextPanel()
        textPanel = panel

        panel.contentView = NSHostingView(rootView: RTLTextPanelView(
            text: text,
            onClose: { [weak self] in self?.closeTextPanel() }
        ))

        let currentSize = panel.isVisible ? panel.frame.size : restoredPanelSize()
        let targetFrame = NSRect(origin: .zero, size: currentSize)
        let origin = adjustedOrigin(for: targetFrame, near: point ?? NSEvent.mouseLocation)
        panel.setFrame(NSRect(origin: origin, size: currentSize), display: true)
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()

        installDismissMonitors()
    }

    private func closeTextPanel() {
        textPanel?.orderOut(nil)
        removeDismissMonitors()
    }

    private func makeTriggerPanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 46, height: 30),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.isMovableByWindowBackground = true
        return panel
    }

    private func makeTextPanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: restoredPanelSize()),
            styleMask: [.borderless, .fullSizeContentView, .resizable],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.delegate = self
        panel.isMovableByWindowBackground = true
        panel.minSize = minPanelSize
        return panel
    }

    func windowDidResize(_ notification: Notification) {
        guard let panel = notification.object as? NSPanel, panel == textPanel else { return }
        persistPanelSize(panel.frame.size)
    }

    func windowDidEndLiveResize(_ notification: Notification) {
        guard let panel = notification.object as? NSPanel, panel == textPanel else { return }
        persistPanelSize(panel.frame.size)
    }

    private func installDismissMonitors() {
        removeDismissMonitors()

        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self, let textPanel = self.textPanel else { return }
            let clickPoint = NSEvent.mouseLocation
            if !textPanel.frame.contains(clickPoint) {
                self.closeTextPanel()
            }
        }

        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard let self else { return event }
            if event.keyCode == 53 {
                self.closeTextPanel()
                return nil
            }
            if event.keyCode == 8, event.modifierFlags.contains(.command) {
                if self.copyFromVisibleTextPanel() {
                    return nil
                }
                return nil
            }
            return event
        }
    }

    private func copyFromVisibleTextPanel() -> Bool {
        guard
            let textPanel,
            textPanel.isVisible,
            let contentView = textPanel.contentView,
            let textView = firstTextView(in: contentView)
        else { return false }

        textView.copy(nil)
        return true
    }

    private func firstTextView(in view: NSView) -> NSTextView? {
        if let textView = view as? NSTextView {
            return textView
        }

        for subview in view.subviews {
            if let textView = firstTextView(in: subview) {
                return textView
            }
        }

        return nil
    }

    private func removeDismissMonitors() {
        if let monitor = globalMouseMonitor {
            NSEvent.removeMonitor(monitor)
            globalMouseMonitor = nil
        }
        if let monitor = localKeyMonitor {
            NSEvent.removeMonitor(monitor)
            localKeyMonitor = nil
        }
    }

    private func adjustedOrigin(for frame: NSRect, near point: NSPoint) -> NSPoint {
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(point) }) ?? NSScreen.main else {
            return point
        }
        let visible = screen.visibleFrame
        var x = point.x + 12
        var y = point.y - frame.height - 12

        x = max(visible.minX + 8, min(x, visible.maxX - frame.width - 8))
        y = max(visible.minY + 8, min(y, visible.maxY - frame.height - 8))
        return NSPoint(x: x, y: y)
    }

    private func restoredPanelSize() -> NSSize {
        let defaults = UserDefaults.standard
        let width = defaults.double(forKey: DefaultsKey.panelWidth)
        let height = defaults.double(forKey: DefaultsKey.panelHeight)

        guard width > 0, height > 0 else {
            return defaultPanelSize
        }

        return NSSize(
            width: max(minPanelSize.width, width),
            height: max(minPanelSize.height, height)
        )
    }

    private func persistPanelSize(_ size: NSSize) {
        let defaults = UserDefaults.standard
        defaults.set(size.width, forKey: DefaultsKey.panelWidth)
        defaults.set(size.height, forKey: DefaultsKey.panelHeight)
    }
}
