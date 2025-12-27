//
//  TextEngine.swift
//  KeyExpander
//
//  Created by Lenie Joice on 12/26/25.
//


import Cocoa

final class TextEngine {
    static let shared = TextEngine()

    private let repo = SnippetRepository()
    private var cache: [String: String] = [:]

    private var buffer = ""
    private var isExpanding = false
    var isEnabled = true
    var isCurrentlyExpanding: Bool { isExpanding }

    func reloadSnippets() {
        do {
            let items = try repo.fetchAll()
            cache = Dictionary(uniqueKeysWithValues: items.map { ($0.trigger, $0.content) })
            print("✅ Loaded \(cache.count) snippets into cache")
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
        if buffer.count > 300 { buffer.removeFirst(buffer.count - 300) }
    }

    func handleDelimiter(isNewline: Bool) -> Bool {
        guard isEnabled, !isExpanding else { return false }

        let lowered = buffer.lowercased()

        let keys = cache.keys
            .filter { $0.hasPrefix(";") }
            .sorted { $0.count > $1.count }
        print("🔎 buffer:", buffer)
        print("🔎 keys:", cache.keys)


        guard let matchKey = keys.first(where: { lowered.hasSuffix($0.lowercased()) }) else {
            return false
        }

        guard let expansion = cache[matchKey] else {
            return false
        }

        isExpanding = true

        deleteBackspaces(count: matchKey.count)

        typeText(expansion)

        if isNewline {
            pressKey(keyCode: 36)
        } else {
            pressKey(keyCode: 49)
        }

        buffer = ""
        isExpanding = false
        return true
    }

    private func deleteBackspaces(count: Int) {
        guard count > 0 else { return }
        for _ in 0..<count {
            pressKey(keyCode: 51) 
        }
    }

    private func typeText(_ text: String) {
        let src = CGEventSource(stateID: .combinedSessionState)

        for scalar in text.unicodeScalars {
            var chars = [UniChar(scalar.value)]

            if let down = CGEvent(keyboardEventSource: src, virtualKey: 0, keyDown: true) {
                down.keyboardSetUnicodeString(stringLength: chars.count, unicodeString: &chars)
                down.post(tap: .cghidEventTap)
            }
            if let up = CGEvent(keyboardEventSource: src, virtualKey: 0, keyDown: false) {
                up.keyboardSetUnicodeString(stringLength: chars.count, unicodeString: &chars)
                up.post(tap: .cghidEventTap)
            }
        }
    }

    private func pressKey(keyCode: CGKeyCode) {
        let src = CGEventSource(stateID: .combinedSessionState)
        let down = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: true)
        let up   = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: false)
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }
}
