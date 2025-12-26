//
//  GlobalKeyListener.swift
//  KeyExpander
//
//  Created by Lenie Joice on 12/26/25.
//


import Cocoa

final class GlobalKeyListener {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let engine: TextEngine

    init(engine: TextEngine) {
        self.engine = engine
    }

    func start() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        print("AX trusted:", trusted)

        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)

        let callback: CGEventTapCallBack = { _, type, event, userInfo in
            guard let userInfo else { return Unmanaged.passUnretained(event) }
            let listener = Unmanaged<GlobalKeyListener>.fromOpaque(userInfo).takeUnretainedValue()

            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                print("⚠️ Event tap disabled by macOS. Re-enabling…")
                if let tap = listener.eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
                return Unmanaged.passUnretained(event)
            }

            guard type == .keyDown else { return Unmanaged.passUnretained(event) }

            let consumed = listener.handleKeyDown(event)
            if consumed {
                return nil
            }
            return Unmanaged.passUnretained(event)
        }

        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        )

        guard let eventTap else {
            print("❌ Failed to create event tap.")
            print("✅ Enable BOTH permissions:")
            print("   Privacy & Security → Accessibility → Keyspand = ON")
            print("   Privacy & Security → Input Monitoring → Keyspand = ON")
            return
        }

        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        if let runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }

        CGEvent.tapEnable(tap: eventTap, enable: true)
        print("✅ GlobalKeyListener started (event tap enabled)")
    }

    func stop() {
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        runLoopSource = nil
        eventTap = nil
    }

    private func handleKeyDown(_ event: CGEvent) -> Bool {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

        if keyCode == 49 {
            let expanded = engine.handleDelimiter(isNewline: false)
            return expanded
        }

        if keyCode == 36 {
            let expanded = engine.handleDelimiter(isNewline: true)
            return expanded
        }

        if let s = event.unicodeString, !s.isEmpty {
            engine.handle(typed: s)
        }

        return false
    }
}

private extension CGEvent {
    var unicodeString: String? {
        var length = 0
        var buffer = [UniChar](repeating: 0, count: 32)
        self.keyboardGetUnicodeString(maxStringLength: buffer.count, actualStringLength: &length, unicodeString: &buffer)
        guard length > 0 else { return nil }
        return String(utf16CodeUnits: buffer, count: length)
    }
}
