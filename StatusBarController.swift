//
//  StatusBarController.swift
//  KeyExpander
//
//  Created by Lenie Joice on 12/26/25.
//


import Cocoa

final class StatusBarController {
    private var statusItem: NSStatusItem

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "Keyspand")
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Quit Keyspand", action: #selector(quitApp), keyEquivalent: "q"))
        menu.items.first?.target = self
        statusItem.menu = menu
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
