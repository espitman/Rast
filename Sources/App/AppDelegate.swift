import AppKit
import ApplicationServices
import Carbon
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let selectionMonitor = SelectionMonitor()
    private let clipboardMonitor = ClipboardMonitor()
    private let selectionCopyService = SelectionCopyService()
    private let globalShortcutMonitor = GlobalShortcutMonitor()
    private let floatingUI = FloatingUIController()
    private var statusItem: NSStatusItem?
    private let popover = NSPopover()
    private var eventMonitor: EventMonitor?

    private var latestDetectedSelection: String = ""
    private var latestClipboardText: String = ""

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        setupStatusItem()

        if !AccessibilityPermissionHelper.isTrusted(prompt: true) {
            print("Accessibility permission is not granted yet.")
        }

        selectionMonitor.onSelectionChanged = { [weak self] selectedText in
            guard let self else { return }
            if let text = selectedText, !text.isEmpty {
                self.latestDetectedSelection = text
                self.floatingUI.showTrigger(for: text)
            } else {
                self.floatingUI.hideTrigger()
            }
        }

        clipboardMonitor.onClipboardTextChanged = { [weak self] text in
            self?.latestClipboardText = text
        }

        selectionMonitor.start()
        clipboardMonitor.start()

        globalShortcutMonitor.onTrigger = { [weak self] in
            self?.copySelectionAndOpenPad()
        }
        globalShortcutMonitor.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        selectionMonitor.stop()
        clipboardMonitor.stop()
        globalShortcutMonitor.stop()
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.title = "RTL"
            button.action = #selector(togglePopover(_:))
            button.target = self
        }
        statusItem = item

        let menuView = MenuBarView(
            onOpenRTLPad: { [weak self] in 
                self?.openEmptyPad()
                self?.closePopover()
            },
            onCheckAccessibility: { [weak self] in 
                self?.checkPermissionsNow()
                self?.closePopover()
            },
            onQuit: { [weak self] in 
                self?.quitApp()
            }
        )

        popover.contentViewController = NSHostingController(rootView: menuView)
        popover.behavior = .transient
        
        eventMonitor = EventMonitor(mask: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            if let self = self, self.popover.isShown {
                self.closePopover()
            }
        }
    }

    @objc private func togglePopover(_ sender: AnyObject?) {
        if popover.isShown {
            closePopover(sender)
        } else {
            showPopover(sender)
        }
    }

    private func showPopover(_ sender: AnyObject?) {
        if let button = statusItem?.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            eventMonitor?.start()
        }
    }

    private func closePopover(_ sender: AnyObject? = nil) {
        popover.performClose(sender)
        eventMonitor?.stop()
    }


    @objc private func openFromCurrentSelection() {
        let direct = selectionMonitor.readCurrentSelection()?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let cached = latestDetectedSelection.trimmingCharacters(in: .whitespacesAndNewlines)
        let text = direct.isEmpty ? cached : direct

        floatingUI.showTextPanel(with: text.isEmpty ? "متنی انتخاب نشده یا این برنامه اجازه خواندن Selection نمی‌دهد." : text)
    }

    @objc private func openFromClipboard() {
        let pasted = NSPasteboard.general.string(forType: .string)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let text = pasted.isEmpty ? latestClipboardText : pasted
        floatingUI.showTextPanel(with: text.isEmpty ? "متنی در Clipboard نیست." : text)
    }

    @objc private func openEmptyPad() {
        floatingUI.showTextPanel(with: "")
    }

    @objc private func checkPermissionsNow() {
        let ax = AccessibilityPermissionHelper.isTrusted()
        let msg = "Accessibility: \(ax ? "✅ Allowed" : "❌ Denied")"
        floatingUI.showTextPanel(with: msg + "\n\nاگر علامت ❌ می‌بینید، یعنی اجازه صادر نشده است.")
    }

    @objc private func requestAccessibility() {
        _ = AccessibilityPermissionHelper.isTrusted(prompt: true)
        AccessibilityPermissionHelper.openAccessibilitySettings()
    }

    private func copySelectionAndOpenPad() {
        if let directText = selectionMonitor.readCurrentSelection(), !directText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            self.floatingUI.showTextPanel(with: directText.trimmingCharacters(in: .whitespacesAndNewlines))
            return
        }
        
        selectionCopyService.captureSelectedText { [weak self] text in
            guard let self else { return }
            let finalText = text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            
            DispatchQueue.main.async {
                if finalText.isEmpty {
                    self.floatingUI.showTextPanel(with: "متنی پیدا نشد. مطمئن شوید برنامه Rast در لیست Accessibility فعال است.")
                } else {
                    self.floatingUI.showTextPanel(with: finalText)
                }
            }
        }
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
