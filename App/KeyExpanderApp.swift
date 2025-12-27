//
//  KeyExpanderApp.swift
//  KeyExpander
//
//  Created by Lenie Joice on 12/26/25.
//

import SwiftUI

@main
struct KeyExpanderApp: App {
    @StateObject private var listenerManager = ListenerManager()
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(listenerManager)
        }
    }

}


final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?
    private let engine = TextEngine.shared
    private var listener: GlobalKeyListener?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusBarController = StatusBarController()

        engine.reloadSnippets()

        GlobalKeyListener.shared.start()

    }
}


