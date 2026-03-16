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

    private var latestDetectedSelection: String = ""
    private var latestClipboardText: String = ""

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        setupStatusItem()

        if !AccessibilityPermissionHelper.isTrusted(prompt: true) {
            print("Accessibility permission is not granted yet.")
        }
        if !InputMonitoringPermissionHelper.isTrusted(prompt: true) {
            print("Input Monitoring permission is not granted yet.")
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
        menu.addItem(NSMenuItem(title: "RTL from Current Selection", action: #selector(openFromCurrentSelection), keyEquivalent: "s"))
        menu.addItem(NSMenuItem(title: "Shortcut: Ctrl+Option+R (Copy + Open RTL Pad)", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Test Shortcut Action Now", action: #selector(testShortcutActionNow), keyEquivalent: "t"))
        menu.addItem(NSMenuItem(title: "RTL from Clipboard", action: #selector(openFromClipboard), keyEquivalent: "v"))
        menu.addItem(NSMenuItem(title: "Open RTL Pad", action: #selector(openEmptyPad), keyEquivalent: "o"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Check Accessibility Status", action: #selector(checkPermissionsNow), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))

        menu.items.forEach { $0.target = self }
        item.menu = menu
        statusItem = item
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
        let im = InputMonitoringPermissionHelper.isTrusted()
        
        let msg = "Accessibility: \(ax ? "✅ Allowed" : "❌ Denied")\nInput Monitoring: \(im ? "✅ Allowed" : "❌ Denied")"
        floatingUI.showTextPanel(with: msg + "\n\nاگر علامت ❌ می‌بینید، یعنی اجازه صادر نشده است.")
    }

    @objc private func requestAccessibility() {
        _ = AccessibilityPermissionHelper.isTrusted(prompt: true)
        AccessibilityPermissionHelper.openAccessibilitySettings()
    }

    @objc private func testShortcutActionNow() {
        copySelectionAndOpenPad()
    }

    private func copySelectionAndOpenPad() {
        print("DEBUG: copySelectionAndOpenPad triggered!")
        
        // Step 1: Try reading directly from the active application's UI elements (Best way)
        if let directText = selectionMonitor.readCurrentSelection(), !directText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            print("DEBUG: Direct selection read successful.")
            self.floatingUI.showTextPanel(with: directText.trimmingCharacters(in: .whitespacesAndNewlines))
            return
        }
        
        // Step 2: Fallback to Cmd+C simulation
        print("DEBUG: Direct read failed, falling back to Cmd+C...")
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

enum AccessibilityPermissionHelper {
    static func isTrusted(prompt: Bool = false) -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeRetainedValue() as String
        let options = [key: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    static func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}

enum InputMonitoringPermissionHelper {
    static func isTrusted(prompt: Bool = false) -> Bool {
        if prompt {
            return CGRequestListenEventAccess()
        }
        return CGPreflightListenEventAccess()
    }

    static func openInputMonitoringSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            NSWorkspace.shared.open(url)
        }
    }
}

final class GlobalShortcutMonitor {
    var onTrigger: (() -> Void)?
    private var globalMonitor: Any?
    private var eventHandlerRef: EventHandlerRef?
    private var hotKeyRefs: [EventHotKeyRef?] = []
    private let signature = OSType(0x52544C31) // 'RTL1'

    func start() {
        stop()

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let userData else { return noErr }
                let monitor = Unmanaged<GlobalShortcutMonitor>.fromOpaque(userData).takeUnretainedValue()
                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                if status == noErr, hotKeyID.signature == monitor.signature {
                    print("DEBUG: Carbon HotKey event received! (id: \(hotKeyID.id))")
                    DispatchQueue.main.async {
                        monitor.onTrigger?()
                    }
                }
                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandlerRef
        )

        hotKeyRefs.removeAll()
        hotKeyRefs.append(registerHotKey(keyCode: UInt32(kVK_ANSI_R), modifiers: UInt32(controlKey | optionKey), id: 1))
        hotKeyRefs.append(registerHotKey(keyCode: UInt32(kVK_ANSI_R), modifiers: UInt32(cmdKey | optionKey), id: 2))
        hotKeyRefs.append(registerHotKey(keyCode: UInt32(kVK_ANSI_C), modifiers: UInt32(controlKey | optionKey), id: 3))

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return }
            guard self.matchesFallbackShortcut(event) else { return }
            print("DEBUG: Fallback NSEvent Shortcut triggered!")
            DispatchQueue.main.async {
                self.onTrigger?()
            }
        }
    }

    func stop() {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
            self.eventHandlerRef = nil
        }
        for ref in hotKeyRefs {
            if let ref {
                UnregisterEventHotKey(ref)
            }
        }
        hotKeyRefs.removeAll()
    }

    private func registerHotKey(keyCode: UInt32, modifiers: UInt32, id: UInt32) -> EventHotKeyRef? {
        var ref: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: signature, id: id)
        let status = RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &ref)
        if status == noErr {
            print("DEBUG: HotKey registered successfully (id: \(id))")
        } else {
            print("ERROR: Failed to register HotKey (id: \(id)), status: \(status)")
        }
        return status == noErr ? ref : nil
    }

    private func matchesFallbackShortcut(_ event: NSEvent) -> Bool {
        guard !event.isARepeat else { return false }
        guard event.keyCode == 15 else { return false } // R
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        return flags.contains(.control) && flags.contains(.option)
    }
}

final class SelectionCopyService {
    func captureSelectedText(completion: @escaping (String?) -> Void) {
        let changeBefore = NSPasteboard.general.changeCount
        
        sendCommandC {
            self.waitForClipboardChange(previousChangeCount: changeBefore, retries: 15) { text in
                completion(text)
            }
        }
    }

    private func sendCommandC(completion: @escaping () -> Void) {
        print("DEBUG: Sending Cmd+C...")
        guard let source = CGEventSource(stateID: .combinedSessionState) else { 
            print("ERROR: Could not create CGEventSource")
            completion()
            return 
        }
        
        // Wait 0.4s for user to release shortcut keys (IMPORTANT)
        // If user is still holding Ctrl/Option, the Cmd+C will fail.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            guard
                let down = CGEvent(keyboardEventSource: source, virtualKey: 8, keyDown: true),
                let up = CGEvent(keyboardEventSource: source, virtualKey: 8, keyDown: false)
            else { 
                print("ERROR: Could not create CGEvent")
                completion()
                return 
            }
            
            // Explicitly clear flags of previous modifiers
            down.flags = .maskCommand
            up.flags = .maskCommand
            
            down.post(tap: .cghidEventTap)
            up.post(tap: .cghidEventTap)
            
            print("DEBUG: Cmd+C posted after delay.")
            completion()
        }
    }

    private func waitForClipboardChange(previousChangeCount: Int, retries: Int, completion: @escaping (String?) -> Void) {
        let pasteboard = NSPasteboard.general
        if pasteboard.changeCount != previousChangeCount {
            completion(pasteboard.string(forType: .string))
            return
        }
        guard retries > 0 else {
            completion(nil)
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            self.waitForClipboardChange(previousChangeCount: previousChangeCount, retries: retries - 1, completion: completion)
        }
    }

    private func restorePasteboard(_ snapshot: [NSPasteboardItem]?) {
        // Disabled snapshot/restore as it might be causing crashes
        /*
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        guard let snapshot, !snapshot.isEmpty else { return }
        _ = pasteboard.writeObjects(snapshot)
        */
    }
}

final class ClipboardMonitor {
    var onClipboardTextChanged: ((String) -> Void)?

    private var timer: Timer?
    private var lastChangeCount: Int = NSPasteboard.general.changeCount
    private var lastText: String = ""

    func start() {
        stop()
        timer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { [weak self] _ in
            self?.poll()
        }
        if let timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func poll() {
        let pasteboard = NSPasteboard.general
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount

        let text = pasteboard.string(forType: .string)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !text.isEmpty, text != lastText else { return }

        lastText = text
        onClipboardTextChanged?(text)
    }
}

final class SelectionMonitor {
    var onSelectionChanged: ((String?) -> Void)?

    private var timer: Timer?
    private var lastSelection: String = ""

    func start() {
        stop()
        timer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: true) { [weak self] _ in
            self?.pollSelection()
        }
        if let timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func readCurrentSelection() -> String? {
        guard AccessibilityPermissionHelper.isTrusted() else { return nil }
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }

        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        var focusedObject: CFTypeRef?
        let focusedResult = AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedObject
        )

        guard focusedResult == .success, let focused = focusedObject else { return nil }
        return selectedText(from: focused as! AXUIElement)
    }

    private func pollSelection() {
        guard let text = readCurrentSelection() else {
            publishIfChanged(nil)
            return
        }
        publishIfChanged(text)
    }

    private func publishIfChanged(_ value: String?) {
        let normalized = (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized != lastSelection else { return }
        lastSelection = normalized
        onSelectionChanged?(normalized.isEmpty ? nil : normalized)
    }

    private func selectedText(from element: AXUIElement) -> String? {
        if let direct = stringAttribute(element, attribute: kAXSelectedTextAttribute as CFString), !direct.isEmpty {
            return direct
        }

        if let range = selectedRange(from: element) {
            if let valueText = stringAttribute(element, attribute: kAXValueAttribute as CFString),
               let sliced = substring(valueText, nsRange: range),
               !sliced.isEmpty {
                return sliced
            }
            if let parameterized = stringForRange(element: element, range: range), !parameterized.isEmpty {
                return parameterized
            }
        }

        return nil
    }

    private func stringAttribute(_ element: AXUIElement, attribute: CFString) -> String? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute, &value)
        guard result == .success, let value else { return nil }
        if let str = value as? String { return str }
        if let attributed = value as? NSAttributedString { return attributed.string }
        return nil
    }

    private func selectedRange(from element: AXUIElement) -> NSRange? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &value)
        guard result == .success, let axValue = value else { return nil }
        return nsRange(fromAXValue: axValue)
    }

    private func nsRange(fromAXValue value: CFTypeRef) -> NSRange? {
        guard CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        let axValue = value as! AXValue
        guard AXValueGetType(axValue) == .cfRange else { return nil }
        var range = CFRange(location: 0, length: 0)
        guard AXValueGetValue(axValue, .cfRange, &range) else { return nil }
        guard range.location >= 0, range.length > 0 else { return nil }
        return NSRange(location: range.location, length: range.length)
    }

    private func stringForRange(element: AXUIElement, range: NSRange) -> String? {
        var cfRange = CFRange(location: range.location, length: range.length)
        guard let rangeValue = AXValueCreate(.cfRange, &cfRange) else { return nil }
        var value: CFTypeRef?
        let result = AXUIElementCopyParameterizedAttributeValue(
            element,
            kAXStringForRangeParameterizedAttribute as CFString,
            rangeValue,
            &value
        )
        guard result == .success, let value else { return nil }
        if let str = value as? String { return str }
        if let attributed = value as? NSAttributedString { return attributed.string }
        return nil
    }

    private func substring(_ text: String, nsRange: NSRange) -> String? {
        guard let range = Range(nsRange, in: text) else { return nil }
        return String(text[range])
    }
}

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
        print("DEBUG: Closing text panel...")
        textPanel?.orderOut(nil)
        removeDismissMonitors()
    }

    func windowDidResignKey(_ notification: Notification) {
        print("DEBUG: windowDidResignKey triggered.")
        // Don't close immediately to see if it's the cause
        // closeTextPanel()
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
