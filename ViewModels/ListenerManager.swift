//
//  ListenerManager.swift
//  KeyExpander
//
//  Created by Lenie Joice on 12/27/25.
//


import Combine
import Foundation
import SwiftUI
 
final class ListenerManager: ObservableObject {
    @Published var isEnabled: Bool = true {
        didSet { apply() }
    }
 
    @Published private(set) var isListening: Bool = false
 
    private var snippetObserver: NSObjectProtocol?
 
    init() {
        GlobalKeyListener.shared.onRunningChanged = { [weak self] running in
            DispatchQueue.main.async {
                self?.isListening = running
            }
        }
 
        snippetObserver = NotificationCenter.default.addObserver(
            forName: .snippetsDidChange,
            object: nil,
            queue: .main
        ) { _ in
            DispatchQueue.main.async {
                TextEngine.shared.reloadSnippets()
            }
        }
 
        apply()
    }
 
    deinit {
        if let snippetObserver {
            NotificationCenter.default.removeObserver(snippetObserver)
        }
    }
 
    private func apply() {
        if isEnabled {
            TextEngine.shared.reloadSnippets()
            GlobalKeyListener.shared.start()
        } else {
            GlobalKeyListener.shared.stop()
        }
    }
}
 
