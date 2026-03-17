import AppKit
import ApplicationServices

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
