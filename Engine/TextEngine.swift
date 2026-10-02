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

    private struct PasteboardSnapshotItem {
        let representations: [(type: NSPasteboard.PasteboardType, data: Data)]
    }

    private struct PasteboardSnapshot {
        let string: String?
        let items: [PasteboardSnapshotItem]
    }

    static let shared = TextEngine()

    /// Stamped on every event we post so the key listener can ignore our own keystrokes.
    static let syntheticEventTag: Int64 = 0x4B455850 // "KEXP"

    /// How long the target app gets to read the snippet off the pasteboard before we restore it.
    private let pasteboardRestoreDelay: TimeInterval = 0.5

    private let repo = SnippetRepository()
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

    func handleDelimiter(isNewline: Bool) -> Bool {
        guard isEnabled, !isExpanding else { return false }

        let sortedSnippets = cache.sorted { $0.trigger.count > $1.trigger.count }

        guard let match = sortedSnippets.first(where: matchesCurrentBuffer) else {
            return false
        }

        isExpanding = true

        deleteBackspaces(count: match.trigger.count)

        pasteText(sanitizedExpansionText(match.content))
        reinsertDelimiter(isNewline: isNewline, delay: 0.05)
        recordExpansionUsage(for: match.id)

        buffer = ""

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.isExpanding = false
        }

        return true
    }

    private func matchesCurrentBuffer(_ snippet: CachedSnippet) -> Bool {
        let trigger = snippet.trigger
        guard !trigger.isEmpty, buffer.count >= trigger.count else { return false }

        let start = buffer.index(buffer.endIndex, offsetBy: -trigger.count)
        let typed = buffer[start...]

        let matches = snippet.caseSensitive
            ? typed == trigger
            : typed.caseInsensitiveCompare(trigger) == .orderedSame
        guard matches else { return false }

        // A trigger that starts with a letter or digit must not fire in the middle of a word
        // (e.g. "hi" inside "chi"). Triggers like ";sig" can still fire anywhere.
        guard let first = trigger.first, first.isLetter || first.isNumber,
              start > buffer.startIndex else { return true }

        let previous = buffer[buffer.index(before: start)]
        return !(previous.isLetter || previous.isNumber)
    }

    private func deleteBackspaces(count: Int) {
        guard count > 0 else { return }
        for _ in 0..<count {
            pressKey(keyCode: 51) 
        }
    }

    private func pasteText(_ text: String) {
        let pasteboard = NSPasteboard.general
        let snapshot = makePasteboardSnapshot(from: pasteboard)

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
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
            self.restorePasteboard(snapshot, to: pasteboard)
        }
    }

    private func makePasteboardSnapshot(from pasteboard: NSPasteboard) -> PasteboardSnapshot {
        guard let items = pasteboard.pasteboardItems else {
            return PasteboardSnapshot(
                string: pasteboard.string(forType: .string),
                items: []
            )
        }

        let snapshotItems: [PasteboardSnapshotItem] = items.compactMap { item in
            let representations: [(type: NSPasteboard.PasteboardType, data: Data)] = item.types.compactMap { type in
                guard let data = item.data(forType: type) else { return nil }
                return (type: type, data: data)
            }

            guard !representations.isEmpty else { return nil }
            return PasteboardSnapshotItem(representations: representations)
        }

        return PasteboardSnapshot(
            string: pasteboard.string(forType: .string),
            items: snapshotItems
        )
    }

    private func restorePasteboard(_ snapshot: PasteboardSnapshot, to pasteboard: NSPasteboard) {
        pasteboard.clearContents()

        // Restore every item with all its representations (rich text, images, file URLs, ...).
        // Plain string is only a fallback for when no item data could be captured.
        guard !snapshot.items.isEmpty else {
            if let string = snapshot.string {
                pasteboard.setString(string, forType: .string)
            }
            return
        }

        let restoredItems = snapshot.items.map { snapshotItem -> NSPasteboardItem in
            let item = NSPasteboardItem()
            snapshotItem.representations.forEach { representation in
                item.setData(representation.data, forType: representation.type)
            }
            return item
        }

        pasteboard.writeObjects(restoredItems)
    }

    private func sanitizedExpansionText(_ text: String) -> String {
        // Normalize line endings only; indentation inside the snippet is intentional.
        text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
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
