import AppKit
import Carbon

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
