//
//  ListenerManager.swift
//  KeyExpander
//
//  Created by Lenie Joice on 12/27/25.
//


import Foundation
import SwiftUI
import Combine

@MainActor
final class ListenerManager: ObservableObject {
    @Published var isEnabled: Bool = true {
        didSet { apply() }
    }

    @Published private(set) var isListening: Bool = false

    init() {
        apply()
    }

    private func apply() {
        if isEnabled {
            TextEngine.shared.reloadSnippets() 
            GlobalKeyListener.shared.start()
        } else {
            GlobalKeyListener.shared.stop()
        }
        isListening = GlobalKeyListener.shared.running
    }
}
