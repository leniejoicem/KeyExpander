//
//  CategoryRepository.swift
//  KeyExpander
//
//  Created by Lenie Joice on 12/27/25.
//


import SQLite

final class CategoryRepository {
    private let db = DatabaseManager.shared.db

    private let categories = Table("categories")
    private let id = Expression<Int64>("id")
    private let name = Expression<String>("name")
    private let icon = Expression<String>("icon")

    func fetchAll() throws -> [Category] {
        try db.prepare(categories.order(name.asc)).map {
            Category(id: $0[id], name: $0[name], icon: $0[icon])
        }
    }

    func add(name: String) throws {
        try db.run(categories.insert(self.name <- name))
    }

    func update(id: Int64, name: String, icon: String) throws {
        let row = categories.filter(self.id == id)
        try db.run(row.update(self.name <- name))
    }

    func delete(id: Int64) throws {
        let row = categories.filter(self.id == id)
        try db.run(row.delete())
    }
}
