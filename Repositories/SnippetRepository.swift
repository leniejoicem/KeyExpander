//
//  SnippetRepository.swift
//  KeyExpander
//
//  Created by Lenie Joice on 12/27/25.
//


import SQLite
import Foundation

final class SnippetRepository {
    private let db = DatabaseManager.shared.db

    private let snippets = Table("snippets")
    private let id = Expression<Int64>("id")
    private let title = Expression<String>("title")
    private let trigger = Expression<String>("trigger")
    private let content = Expression<String>("content")
    private let categoryId = Expression<Int64?>("category_id")
    private let caseSensitive = Expression<Bool>("case_sensitive")
    private let isEnabled = Expression<Bool>("is_enabled")
    private let usageCount = Expression<Int64>("usage_count")
    private let updatedAt = Expression<Double>("updated_at")

    func fetchAll() throws -> [Snippet] {
        try db.prepare(snippets.order(updatedAt.desc)).map { row in
            Snippet(
                id: row[id],
                title: row[title],
                trigger: row[trigger],
                content: row[content],
                categoryId: row[categoryId],
                caseSensitive: row[caseSensitive],
                isEnabled: row[isEnabled],
                usageCount: row[usageCount],
                updatedAt: Date(timeIntervalSince1970: row[updatedAt])
            )
        }
    }

    func add(_ s: SnippetDraft) throws {
        let now = Date().timeIntervalSince1970
        try db.run(snippets.insert(
            title <- s.title,
            trigger <- s.trigger,
            content <- s.content,
            categoryId <- s.categoryId,
            caseSensitive <- s.caseSensitive,
            isEnabled <- s.isEnabled,
            usageCount <- 0,
            updatedAt <- now
        ))
    }

    func update(id: Int64, draft: SnippetDraft) throws {
        let row = snippets.filter(self.id == id)
        try db.run(row.update(
            title <- draft.title,
            trigger <- draft.trigger,
            content <- draft.content,
            categoryId <- draft.categoryId,
            caseSensitive <- draft.caseSensitive,
            isEnabled <- draft.isEnabled,
            updatedAt <- Date().timeIntervalSince1970
        ))
    }

    func delete(id: Int64) throws {
        let row = snippets.filter(self.id == id)
        try db.run(row.delete())
    }

    func incrementUsage(id: Int64) throws {
        let row = snippets.filter(self.id == id)
        try db.run(row.update(
            usageCount <- usageCount + 1,
            updatedAt <- Date().timeIntervalSince1970
        ))
    }
}

struct SnippetDraft: Equatable {
    var title: String = ""
    var trigger: String = ""
    var content: String = ""
    var categoryId: Int64? = nil
    var caseSensitive: Bool = false
    var isEnabled: Bool = true
}


