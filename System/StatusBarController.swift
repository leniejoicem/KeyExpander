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
            button.image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "KeyExpander")
        }

        let menu = NSMenu()

        let openItem = NSMenuItem(title: "Open KeyExpander", action: #selector(openApp), keyEquivalent: "o")
        openItem.target = self
        menu.addItem(openItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit KeyExpander", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    @objc private func openApp() {
        NSApp.activate(ignoringOtherApps: true)

        if let window = NSApp.windows.first(where: { $0.canBecomeMain }) {
            window.makeKeyAndOrderFront(nil)
        } else {
            // The main window was closed; reopening the bundle makes SwiftUI create a new one.
            NSWorkspace.shared.openApplication(
                at: Bundle.main.bundleURL,
                configuration: NSWorkspace.OpenConfiguration()
            )
        }
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
