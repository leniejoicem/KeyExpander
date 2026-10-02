//
//  GlobalKeyListener.swift
//  KeyExpander
//
//  Created by Lenie Joice on 12/26/25.
//


import Cocoa

final class GlobalKeyListener {
    static let shared = GlobalKeyListener(engine: TextEngine.shared)
 
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let engine: TextEngine
 
    private(set) var isRunning = false {
        didSet { onRunningChanged?(isRunning) }
    }
 
    var onRunningChanged: ((Bool) -> Void)?
 
    private init(engine: TextEngine) {
        self.engine = engine
    }
 
    func start() {
        guard !isRunning else { return }
 
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        print("AX trusted:", trusted)
 
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
            | CGEventMask(1 << CGEventType.leftMouseDown.rawValue)
            | CGEventMask(1 << CGEventType.rightMouseDown.rawValue)
            | CGEventMask(1 << CGEventType.otherMouseDown.rawValue)
 
        let callback: CGEventTapCallBack = { _, type, event, userInfo in
            guard let userInfo else { return Unmanaged.passUnretained(event) }
            let listener = Unmanaged<GlobalKeyListener>.fromOpaque(userInfo).takeUnretainedValue()
 
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                print("⚠️ Event tap disabled by macOS. Re-enabling…")
                if let tap = listener.eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
                return Unmanaged.passUnretained(event)
            }
 
            if type == .leftMouseDown || type == .rightMouseDown || type == .otherMouseDown {
                // A click can move the caret, so whatever was typed before no longer sits behind it.
                listener.engine.resetBuffer()
                return Unmanaged.passUnretained(event)
            }

            guard type == .keyDown else { return Unmanaged.passUnretained(event) }
 
            let consumed = listener.handleKeyDown(event)
            if consumed { return nil }
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
            print("   Privacy & Security → Accessibility → KeyExpander = ON")
            print("   Privacy & Security → Input Monitoring → KeyExpander = ON")
            return
        }
 
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        if let runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
 
        CGEvent.tapEnable(tap: eventTap, enable: true)
 
        isRunning = true
        print("✅ GlobalKeyListener started (event tap enabled)")
    }
 
    func stop() {
        guard isRunning else { return }
 
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        if let eventTap {
            CFMachPortInvalidate(eventTap)
        }
 
        runLoopSource = nil
        eventTap = nil
 
        isRunning = false
        print("⏸️ GlobalKeyListener stopped")
    }
 
    var running: Bool { isRunning }
 
 
    /// Arrows, Home/End, Page Up/Down, forward delete, Tab and Escape move the caret or change
    /// text in ways the buffer can't follow.
    private static let bufferResettingKeyCodes: Set<Int64> = [
        123, 124, 125, 126, // arrows
        115, 119, 116, 121, // home, end, page up, page down
        117, 48, 53         // forward delete, tab, escape
    ]

    private func handleKeyDown(_ event: CGEvent) -> Bool {
        // Ignore the backspaces / paste / delimiter we post ourselves during an expansion.
        if event.getIntegerValueField(.eventSourceUserData) == TextEngine.syntheticEventTag {
            return false
        }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags

        // Shortcuts (Cmd+V, Cmd+Z, Ctrl+A, ...) edit text or move the caret unpredictably.
        if flags.contains(.maskCommand) || flags.contains(.maskControl) {
            engine.resetBuffer()
            return false
        }

        if Self.bufferResettingKeyCodes.contains(keyCode) {
            engine.resetBuffer()
            return false
        }

        if keyCode == 51 {
            // Option+Backspace deletes a whole word; we can't mirror that, so start over.
            if flags.contains(.maskAlternate) {
                engine.resetBuffer()
            } else {
                engine.handleTyped(character: "\u{8}")
            }
            return false
        }
 
        if keyCode == 49 {
            if engine.handleDelimiter(isNewline: false) { return true }
            engine.handleTyped(character: " ")
            return false
        }
 
        if keyCode == 36 || keyCode == 76 {
            if engine.handleDelimiter(isNewline: true) { return true }
            engine.handleTyped(character: "\n")
            return false
        }
 
        if let s = event.unicodeString, !s.isEmpty {
            // Function keys report characters in the private use area (U+F700...); they aren't text.
            if s.unicodeScalars.contains(where: { (0xF700...0xF8FF).contains($0.value) }) {
                engine.resetBuffer()
            } else {
                engine.handleTyped(character: s)
            }
        }
 
        return false
    }
}
 
private extension CGEvent {
    var unicodeString: String? {
        var length = 0
        var buffer = [UniChar](repeating: 0, count: 32)
        self.keyboardGetUnicodeString(
            maxStringLength: buffer.count,
            actualStringLength: &length,
            unicodeString: &buffer
        )
        guard length > 0 else { return nil }
        return String(utf16CodeUnits: buffer, count: length)
    }
}
 
