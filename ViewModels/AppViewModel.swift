//
//  AppViewModel.swift
//  KeyExpander
//
//  Created by Lenie Joice on 12/27/25.
//


import Foundation
import Combine

@MainActor
final class AppViewModel: ObservableObject {
    private let catRepo = CategoryRepository()
    private let snipRepo = SnippetRepository()
    private var reloadTask: Task<Void, Never>?

    @Published var categories: [Category] = []
    @Published var snippets: [Snippet] = []

    @Published var selectedCategoryId: Int64? = nil // nil = All
    @Published var selectedSnippetId: Int64? = nil

    @Published var searchText: String = ""
    @Published var errorMessage: String?


    var filteredSnippets: [Snippet] {
        snippets
            .filter { snip in
                selectedCategoryId == nil || snip.categoryId == selectedCategoryId
            }
            .filter { snip in
                searchText.isEmpty ||
                snip.title.localizedCaseInsensitiveContains(searchText) ||
                snip.content.localizedCaseInsensitiveContains(searchText) ||
                snip.trigger.localizedCaseInsensitiveContains(searchText)
            }
    }


    func loadAll() async {
        do {
            let cats = try catRepo.fetchAll()
            let snips = try snipRepo.fetchAll()

            categories = cats
            snippets = snips
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refresh() {
        reloadTask?.cancel()
        reloadTask = Task { [weak self] in
            await self?.loadAll()
        }
    }


    func categoryName(for id: Int64?) -> String {
        guard let id else { return "All Snippets" }
        return categories.first(where: { $0.id == id })?.name ?? "Unknown"
    }

    func categoryIcon(for id: Int64?) -> String {
        guard let id else { return "tray.full" }
        return categories.first(where: { $0.id == id })?.icon ?? "folder"
    }

    func selectedSnippet() -> Snippet? {
        guard let selectedSnippetId else { return nil }
        return snippets.first(where: { $0.id == selectedSnippetId })
    }

    func addSnippet(_ draft: SnippetDraft) {
        do {
            try snipRepo.add(draft)
            TextEngine.shared.reloadSnippets()
            refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateSnippet(id: Int64, draft: SnippetDraft) {
        do {
            try snipRepo.update(id: id, draft: draft)
            TextEngine.shared.reloadSnippets()
            refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteSnippet(id: Int64) {
        do {
            try snipRepo.delete(id: id)
            TextEngine.shared.reloadSnippets()
            selectedSnippetId = nil
            refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addCategory(name: String) {
        do {
            try catRepo.add(name: name)
            refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateCategory(id: Int64, name: String, icon: String) {
        do {
            try catRepo.update(id: id, name: name, icon: icon)
            refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteCategory(id: Int64) {
        do {
            try catRepo.delete(id: id)
            if selectedCategoryId == id { selectedCategoryId = nil }
            refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
