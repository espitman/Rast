import AppKit
import SwiftUI

final class FloatingUIController: NSObject, NSWindowDelegate {
    private var triggerPanel: NSPanel?
    private var textPanel: NSPanel?

    private var globalMouseMonitor: Any?
    private var localKeyMonitor: Any?

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

        let frame = NSRect(x: 0, y: 0, width: 420, height: 260)
        let origin = adjustedOrigin(for: frame, near: point ?? NSEvent.mouseLocation)
        panel.setFrame(NSRect(origin: origin, size: frame.size), display: true)
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
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 260),
            styleMask: [.borderless, .fullSizeContentView],
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
        return panel
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
            return event
        }
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
}
