//
//  Snippet.swift
//  KeyExpander
//
//  Created by Lenie Joice on 12/27/25.
//


import Foundation

struct Snippet: Identifiable, Equatable {
    let id: Int64
    var title: String
    var trigger: String
    var content: String
    var categoryId: Int64?
    var caseSensitive: Bool
    var isEnabled: Bool
    var usageCount: Int64
    var updatedAt: Date
}

