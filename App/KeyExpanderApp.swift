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
 
    func applicationDidFinishLaunching(_ notification: Notification) {
        statusBarController = StatusBarController()

    }
}


