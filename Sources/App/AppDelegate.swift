import AppKit
import ApplicationServices
import Carbon
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let selectionMonitor = SelectionMonitor()
    private let clipboardMonitor = ClipboardMonitor()
    private let selectionCopyService = SelectionCopyService()
    private let globalShortcutMonitor = GlobalShortcutMonitor()
    private let floatingUI = FloatingUIController()
    private var statusItem: NSStatusItem?

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
        item.button?.title = "RTL"

        let menu = NSMenu()
        menu.delegate = self
        updateMenu(menu)
        item.menu = menu
        statusItem = item
    }

    func menuWillOpen(_ menu: NSMenu) {
        updateMenu(menu)
    }

    private func updateMenu(_ menu: NSMenu) {
        menu.removeAllItems()
        
        if !AccessibilityPermissionHelper.isTrusted() {
            let warningItem = NSMenuItem(title: "⚠️ Accessibility Access Required", action: #selector(requestAccessibility), keyEquivalent: "")
            warningItem.attributedTitle = NSAttributedString(string: "⚠️ Accessibility Access Required", attributes: [.foregroundColor: NSColor.systemRed])
            menu.addItem(warningItem)
            menu.addItem(NSMenuItem(title: "Grant Permission...", action: #selector(requestAccessibility), keyEquivalent: ""))
            menu.addItem(NSMenuItem.separator())
        }

        menu.addItem(NSMenuItem(title: "Shortcut: Ctrl+Option+R (Copy + Open RTL Pad)", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Open RTL Pad", action: #selector(openEmptyPad), keyEquivalent: "o"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Check Accessibility Status", action: #selector(checkPermissionsNow), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))
        
        menu.items.forEach { $0.target = self }
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
