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

    private let repo = SnippetRepository()
    private var cache: [CachedSnippet] = []

    private var buffer = ""
    private var isExpanding = false

    var isEnabled = true
    var isCurrentlyExpanding: Bool { isExpanding }

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
        guard isEnabled, !isExpanding else { return }

        if character == "\u{8}" {
            if !buffer.isEmpty { buffer.removeLast() }
            return
        }

        buffer.append(character)
        if buffer.count > 300 {
            buffer.removeFirst(buffer.count - 300)
        }
    }

    func handleDelimiter(isNewline: Bool) -> Bool {
        guard isEnabled, !isExpanding else { return false }

        print("🔎 buffer:", buffer)
        print("🔎 keys:", cache.map(\.trigger))

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
        if snippet.caseSensitive {
            return buffer.hasSuffix(snippet.trigger)
        }

        return buffer.lowercased().hasSuffix(snippet.trigger.lowercased())
    }

    private func deleteBackspaces(count: Int) {
        guard count > 0 else { return }
        for _ in 0..<count {
            pressKey(keyCode: 51) 
        }
    }

    private func pasteText(_ text: String) {
        let pasteboard = NSPasteboard.general
        let previousItems = pasteboard.pasteboardItems

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        let src = CGEventSource(stateID: .combinedSessionState)

        let cmdDown = CGEvent(keyboardEventSource: src, virtualKey: 55, keyDown: true) // command
        let vDown = CGEvent(keyboardEventSource: src, virtualKey: 9, keyDown: true)     // v
        vDown?.flags = .maskCommand

        let vUp = CGEvent(keyboardEventSource: src, virtualKey: 9, keyDown: false)
        vUp?.flags = .maskCommand

        let cmdUp = CGEvent(keyboardEventSource: src, virtualKey: 55, keyDown: false)

        cmdDown?.post(tap: .cghidEventTap)
        vDown?.post(tap: .cghidEventTap)
        vUp?.post(tap: .cghidEventTap)
        cmdUp?.post(tap: .cghidEventTap)


        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            pasteboard.clearContents()
            previousItems?.forEach { item in
                for type in item.types {
                    if let value = item.data(forType: type) {
                        pasteboard.setData(value, forType: type)
                    }
                }
            }
        }
    }

    private func sanitizedExpansionText(_ text: String) -> String {
        text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .joined(separator: "\n")
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
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }
}
