//
//  TextEngine.swift
//  KeyExpander
//
//  Created by Lenie Joice on 12/26/25.
//


import Cocoa

final class TextEngine {
    private struct CachedSnippet {
        let id: Int64
        let trigger: String
        let content: String
        let caseSensitive: Bool
    }

    static let shared = TextEngine()

    /// Stamped on every event we post so the key listener can ignore our own keystrokes.
    static let syntheticEventTag: Int64 = 0x4B455850 // "KEXP"

    /// How long the target app gets to read the snippet off the pasteboard before we restore it.
    private let pasteboardRestoreDelay: TimeInterval = 0.5

    private let repo = SnippetRepository()
    /// Longest trigger first, so ";sig2" wins over ";sig".
    private var cache: [CachedSnippet] = []

    private var buffer = ""
    private var isExpanding = false

    var isEnabled = true

    private init() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.buffer = ""
        }
    }

    func reloadSnippets() {
        do {
            let items = try repo.fetchAll()
            cache = items
                .filter { $0.isEnabled }
                .map {
                    CachedSnippet(
                        id: $0.id,
                        trigger: $0.trigger,
                        content: $0.content,
                        caseSensitive: $0.caseSensitive
                    )
                }
                .sorted { $0.trigger.count > $1.trigger.count }
            print("✅ Loaded \(cache.count) enabled snippets into cache")
        } catch {
            print("❌ Failed to load snippets:", error)
        }
    }

    func handleTyped(character: String) {
        guard isEnabled else { return }

        if character == "\u{8}" {
            if !buffer.isEmpty { buffer.removeLast() }
            return
        }

        buffer.append(character)
        if buffer.count > 300 {
            buffer.removeFirst(buffer.count - 300)
        }
    }

    /// Forget what was typed, e.g. after a click or cursor movement puts the caret somewhere else.
    func resetBuffer() {
        buffer = ""
    }

    /// Called from the event tap for Space/Return. Returns true when the delimiter was consumed
    /// because an expansion is starting.
    func handleDelimiter(isNewline: Bool) -> Bool {
        guard isEnabled, !isExpanding else { return false }

        guard let match = cache.first(where: {
            Self.triggerMatches($0.trigger, buffer: buffer, caseSensitive: $0.caseSensitive)
        }) else {
            return false
        }

        isExpanding = true
        buffer = ""

        // Do the slow part (pasteboard snapshot, posting events, DB write) outside the event tap
        // callback; macOS disables taps whose callbacks take too long.
        DispatchQueue.main.async { [weak self] in
            self?.expand(match, isNewline: isNewline)
        }

        return true
    }

    private func expand(_ match: CachedSnippet, isNewline: Bool) {
        deleteBackspaces(count: match.trigger.count)
        pasteText(Self.sanitizedExpansionText(match.content))
        reinsertDelimiter(isNewline: isNewline, delay: 0.05)
        recordExpansionUsage(for: match.id)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.isExpanding = false
        }
    }

    /// True when `buffer` ends with `trigger`. A trigger that starts with a letter or digit must
    /// also start a word, so "hi" doesn't fire inside "chi"; triggers like ";sig" fire anywhere.
    static func triggerMatches(_ trigger: String, buffer: String, caseSensitive: Bool) -> Bool {
        guard !trigger.isEmpty, buffer.count >= trigger.count else { return false }

        let start = buffer.index(buffer.endIndex, offsetBy: -trigger.count)
        let typed = buffer[start...]

        let matches = caseSensitive
            ? typed == trigger
            : typed.caseInsensitiveCompare(trigger) == .orderedSame
        guard matches else { return false }

        guard let first = trigger.first, first.isLetter || first.isNumber,
              start > buffer.startIndex else { return true }

        let previous = buffer[buffer.index(before: start)]
        return !(previous.isLetter || previous.isNumber)
    }

    static func sanitizedExpansionText(_ text: String) -> String {
        // Normalize line endings only; indentation inside the snippet is intentional.
        text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
    }

    private func deleteBackspaces(count: Int) {
        guard count > 0 else { return }
        for _ in 0..<count {
            pressKey(keyCode: 51)
        }
    }

    private func pasteText(_ text: String) {
        let pasteboard = NSPasteboard.general
        let snapshot = PasteboardSnapshot.capture(from: pasteboard)

        pasteboard.clearContents()
        let item = NSPasteboardItem()
        item.setString(text, forType: .string)
        // Ask clipboard managers (Maccy, Raycast, Paste, ...) not to record the expansion.
        item.setString("", forType: .transient)
        item.setString("", forType: .autoGenerated)
        pasteboard.writeObjects([item])
        let snippetChangeCount = pasteboard.changeCount

        let src = CGEventSource(stateID: .combinedSessionState)

        let cmdDown = CGEvent(keyboardEventSource: src, virtualKey: 55, keyDown: true) // command
        let vDown = CGEvent(keyboardEventSource: src, virtualKey: 9, keyDown: true)     // v
        vDown?.flags = .maskCommand

        let vUp = CGEvent(keyboardEventSource: src, virtualKey: 9, keyDown: false)
        vUp?.flags = .maskCommand

        let cmdUp = CGEvent(keyboardEventSource: src, virtualKey: 55, keyDown: false)

        [cmdDown, vDown, vUp, cmdUp].forEach { postSynthetic($0) }

        DispatchQueue.main.asyncAfter(deadline: .now() + pasteboardRestoreDelay) {
            // If something else was copied in the meantime, leave it alone.
            guard pasteboard.changeCount == snippetChangeCount else { return }
            snapshot.restore(to: pasteboard)
        }
    }

    private func reinsertDelimiter(isNewline: Bool, delay: TimeInterval = 0) {
        let keyCode: CGKeyCode = isNewline ? 36 : 49
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.pressKey(keyCode: keyCode)
        }
    }

    private func recordExpansionUsage(for id: Int64) {
        do {
            try repo.incrementUsage(id: id)
            NotificationCenter.default.post(name: .snippetsDidChange, object: nil)
        } catch {
            print("❌ Failed to increment usage:", error)
        }
    }

    private func pressKey(keyCode: CGKeyCode) {
        let src = CGEventSource(stateID: .combinedSessionState)
        let down = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: true)
        let up = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: false)
        postSynthetic(down)
        postSynthetic(up)
    }

    private func postSynthetic(_ event: CGEvent?) {
        guard let event else { return }
        event.setIntegerValueField(.eventSourceUserData, value: Self.syntheticEventTag)
        event.post(tap: .cghidEventTap)
    }
}

/// A copy of everything on a pasteboard, so it can be put back after we borrow it for a paste.
struct PasteboardSnapshot {
    let string: String?
    let items: [[(type: NSPasteboard.PasteboardType, data: Data)]]

    static func capture(from pasteboard: NSPasteboard) -> PasteboardSnapshot {
        let items = (pasteboard.pasteboardItems ?? []).compactMap { item -> [(type: NSPasteboard.PasteboardType, data: Data)]? in
            let representations = item.types.compactMap { type -> (type: NSPasteboard.PasteboardType, data: Data)? in
                guard let data = item.data(forType: type) else { return nil }
                return (type: type, data: data)
            }
            return representations.isEmpty ? nil : representations
        }

        return PasteboardSnapshot(string: pasteboard.string(forType: .string), items: items)
    }

    func restore(to pasteboard: NSPasteboard) {
        pasteboard.clearContents()

        // Restore every item with all its representations (rich text, images, file URLs, ...).
        // Plain string is only a fallback for when no item data could be captured.
        guard !items.isEmpty else {
            if let string {
                pasteboard.setString(string, forType: .string)
            }
            return
        }

        let restoredItems = items.map { representations -> NSPasteboardItem in
            let item = NSPasteboardItem()
            representations.forEach { item.setData($0.data, forType: $0.type) }
            return item
        }

        pasteboard.writeObjects(restoredItems)
    }
}

extension NSPasteboard.PasteboardType {
    /// nspasteboard.org markers that clipboard managers honor.
    static let transient = NSPasteboard.PasteboardType("org.nspasteboard.TransientType")
    static let autoGenerated = NSPasteboard.PasteboardType("org.nspasteboard.AutoGeneratedType")
}
