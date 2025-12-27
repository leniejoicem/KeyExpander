//
//  DatabaseManager.swift
//  KeyExpander
//
//  Created by Lenie Joice on 12/27/25.
//


import Foundation
import SQLite

extension Connection {
    func tableColumns(_ tableName: String) throws -> Set<String> {
        var cols: Set<String> = []
        let stmt = try prepare("PRAGMA table_info(\(tableName))")
        for row in stmt {
            if let name = row[1] as? String {
                cols.insert(name)
            }
        }
        return cols
    }
}

final class DatabaseManager {
    static let shared = DatabaseManager()
    let db: Connection

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        try? FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)

        let dbURL = appSupport.appendingPathComponent("keyexpander.sqlite")
        db = try! Connection(dbURL.path)

        createOrMigrate()
    }

    private func createOrMigrate() {
        let categories = Table("categories")
        let catId = Expression<Int64>("id")
        let catName = Expression<String>("name")
        let catIcon = Expression<String>("icon")

        do {
            try db.run(categories.create(ifNotExists: true) { t in
                t.column(catId, primaryKey: .autoincrement)
                t.column(catName, unique: true)
                t.column(catIcon)
            })
        } catch {
            print("❌ categories create:", error)
        }

        let snippets = Table("snippets")
        let id = Expression<Int64>("id")
        let title = Expression<String>("title")
        let trigger = Expression<String>("trigger")
        let content = Expression<String>("content")
        let categoryId = Expression<Int64?>("category_id")
        let caseSensitive = Expression<Bool>("case_sensitive")
        let isEnabled = Expression<Bool>("is_enabled")
        let usageCount = Expression<Int64>("usage_count")
        let updatedAt = Expression<Double>("updated_at") // unix timestamp

        do {
            try db.run(snippets.create(ifNotExists: true) { t in
                t.column(id, primaryKey: .autoincrement)

                t.column(title, defaultValue: "Untitled")
                t.column(trigger, unique: true)
                t.column(content)

                t.column(categoryId)
                t.column(caseSensitive, defaultValue: false)
                t.column(isEnabled, defaultValue: true)
                t.column(usageCount, defaultValue: 0)
                t.column(updatedAt, defaultValue: 0)
            })
        } catch {
            print("❌ snippets create:", error)
        }

        do {
            let cols = try db.tableColumns("snippets")

            if !cols.contains("title") {
                try db.run(snippets.addColumn(title, defaultValue: "Untitled"))
            }
            if !cols.contains("category_id") {
                try db.run(snippets.addColumn(categoryId))
            }
            if !cols.contains("case_sensitive") {
                try db.run(snippets.addColumn(caseSensitive, defaultValue: false))
            }
            if !cols.contains("is_enabled") {
                try db.run(snippets.addColumn(isEnabled, defaultValue: true))
            }
            if !cols.contains("usage_count") {
                try db.run(snippets.addColumn(usageCount, defaultValue: 0))
            }
            if !cols.contains("updated_at") {
                
                try db.run(snippets.addColumn(updatedAt, defaultValue: 0))
            }
        } catch {
            print("❌ snippets migrate:", error)
        }

        do {
            let count = try db.scalar(categories.count)
            if count == 0 {
                let defaults: [(String, String)] = [
                    ("Customer Service", "bubble.left.and.bubble.right"),
                    ("Social Media", "megaphone"),
                    ("Personal", "person"),
                    ("Other", "square.grid.2x2")
                ]
                for (name, icon) in defaults {
                    try db.run(categories.insert(catName <- name, catIcon <- icon))
                }
            }
        } catch {
            print("❌ seed categories:", error)
        }
    }
}
