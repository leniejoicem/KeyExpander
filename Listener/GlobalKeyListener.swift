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
    private var mouseMonitors: [Any] = []
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
        startMouseMonitors()

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
        mouseMonitors.forEach { NSEvent.removeMonitor($0) }
        mouseMonitors = []

        runLoopSource = nil
        eventTap = nil

        isRunning = false
        print("⏸️ GlobalKeyListener stopped")
    }

    var running: Bool { isRunning }

    /// A click can move the caret, so whatever was typed before no longer sits behind it.
    /// Passive monitors observe clicks without ever being able to delay them.
    private func startMouseMonitors() {
        let clicks: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]

        if let global = NSEvent.addGlobalMonitorForEvents(matching: clicks, handler: { [weak self] _ in
            self?.engine.resetBuffer()
        }) {
            mouseMonitors.append(global)
        }

        // Global monitors don't see clicks in our own windows.
        if let local = NSEvent.addLocalMonitorForEvents(matching: clicks, handler: { [weak self] event in
            self?.engine.resetBuffer()
            return event
        }) {
            mouseMonitors.append(local)
        }
    }

    enum KeyAction: Equatable {
        /// Our own synthetic event, or something irrelevant: let it through untouched.
        case ignore
        /// The caret moved or text changed in a way the buffer can't follow.
        case resetBuffer
        case backspace
        case delimiter(isNewline: Bool)
        case character(String)
    }

    /// Arrows, Home/End, Page Up/Down, forward delete, Tab and Escape move the caret or change
    /// text in ways the buffer can't follow.
    private static let bufferResettingKeyCodes: Set<Int64> = [
        123, 124, 125, 126, // arrows
        115, 119, 116, 121, // home, end, page up, page down
        117, 48, 53         // forward delete, tab, escape
    ]

    static func action(
        keyCode: Int64,
        flags: CGEventFlags,
        characters: String?,
        isSynthetic: Bool
    ) -> KeyAction {
        // The backspaces / paste / delimiter we post ourselves during an expansion.
        if isSynthetic { return .ignore }

        // Shortcuts (Cmd+V, Cmd+Z, Ctrl+A, ...) edit text or move the caret unpredictably.
        if flags.contains(.maskCommand) || flags.contains(.maskControl) { return .resetBuffer }

        if bufferResettingKeyCodes.contains(keyCode) { return .resetBuffer }

        switch keyCode {
        case 51:
            // Option+Backspace deletes a whole word; we can't mirror that, so start over.
            return flags.contains(.maskAlternate) ? .resetBuffer : .backspace
        case 49:
            return .delimiter(isNewline: false)
        case 36, 76:
            return .delimiter(isNewline: true)
        default:
            break
        }

        guard let characters, !characters.isEmpty else { return .ignore }

        // Function keys report characters in the private use area (U+F700...); they aren't text.
        if characters.unicodeScalars.contains(where: { (0xF700...0xF8FF).contains($0.value) }) {
            return .resetBuffer
        }

        return .character(characters)
    }

    private func handleKeyDown(_ event: CGEvent) -> Bool {
        let action = Self.action(
            keyCode: event.getIntegerValueField(.keyboardEventKeycode),
            flags: event.flags,
            characters: event.unicodeString,
            isSynthetic: event.getIntegerValueField(.eventSourceUserData) == TextEngine.syntheticEventTag
        )

        switch action {
        case .ignore:
            return false
        case .resetBuffer:
            engine.resetBuffer()
            return false
        case .backspace:
            engine.handleTyped(character: "\u{8}")
            return false
        case .delimiter(let isNewline):
            if engine.handleDelimiter(isNewline: isNewline) { return true }
            engine.handleTyped(character: isNewline ? "\n" : " ")
            return false
        case .character(let s):
            engine.handleTyped(character: s)
            return false
        }
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

