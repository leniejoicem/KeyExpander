//
//  KeyExpanderApp.swift
//  KeyExpander
//
//  Created by Lenie Joice on 12/26/25.
//

import SwiftUI

@main
struct KeyExpanderApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?
    private let engine = TextEngine()
    private var listener: GlobalKeyListener?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusBarController = StatusBarController()
        listener = GlobalKeyListener(engine: engine)
        listener?.start()
    }
}

