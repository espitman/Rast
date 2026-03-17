import AppKit

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
}
