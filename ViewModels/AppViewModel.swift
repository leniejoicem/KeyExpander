//
//  AppViewModel.swift
//  KeyExpander
//
//  Created by Lenie Joice on 12/27/25.
//


import Foundation
import Combine
 
extension Notification.Name {
    static let snippetsDidChange = Notification.Name("snippetsDidChange")
}
 
@MainActor
final class AppViewModel: ObservableObject {
    private let catRepo  = CategoryRepository()
    private let snipRepo = SnippetRepository()
 
    private var reloadTask: Task<Void, Never>?
    private var snippetObserver: NSObjectProtocol?
    private let debounceInterval: Duration = .milliseconds(150)
 
    @Published var categories: [Category] = []
    @Published var snippets:   [Snippet]  = []
 
    @Published var selectedCategoryId: Int64? = nil
    @Published var selectedSnippetId:  Int64? = nil
 
    @Published var searchText:    String = ""
    @Published var errorMessage:  String?
    @Published var bannerMessage: String?

    init() {
        snippetObserver = NotificationCenter.default.addObserver(
            forName: .snippetsDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refresh()
            }
        }
    }

    deinit {
        if let snippetObserver {
            NotificationCenter.default.removeObserver(snippetObserver)
        }
    }
 
    var filteredSnippets: [Snippet] {
        snippets
            .filter { selectedCategoryId == nil || $0.categoryId == selectedCategoryId }
            .filter {
                searchText.isEmpty ||
                $0.title.localizedCaseInsensitiveContains(searchText)   ||
                $0.content.localizedCaseInsensitiveContains(searchText) ||
                $0.trigger.localizedCaseInsensitiveContains(searchText)
            }
    }
 
 
    func loadAll() async {
        do {
            categories    = try catRepo.fetchAll()
            snippets      = try snipRepo.fetchAll()
            errorMessage  = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
 
    func refresh() {
        reloadTask?.cancel()
        reloadTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: debounceInterval)
            guard !Task.isCancelled else { return }
            await self.loadAll()
        }
    }
 
 
    func categoryName(for id: Int64?) -> String {
        guard let id else { return "All Snippets" }
        return categories.first(where: { $0.id == id })?.name ?? "Unknown"
    }
 
    /// Category label for a snippet row; nil or deleted categories read as "Uncategorized".
    func snippetCategoryName(for id: Int64?) -> String {
        guard let id, let category = categories.first(where: { $0.id == id }) else {
            return "Uncategorized"
        }
        return category.name
    }

    func categoryIcon(for id: Int64?) -> String {
        guard let id else { return "tray.full" }
        return categories.first(where: { $0.id == id })?.icon ?? "folder"
    }
 
    func selectedSnippet() -> Snippet? {
        guard let selectedSnippetId else { return nil }
        return snippets.first(where: { $0.id == selectedSnippetId })
    }
 
 
    @discardableResult
    func addSnippet(_ draft: SnippetDraft) -> Bool {
        if let message = triggerConflictMessage(for: draft.trigger, excluding: nil) {
            errorMessage = message
            return false
        }
        do {
            try snipRepo.add(draft)
            notifySnippetsChanged()
            bannerMessage = "Snippet created."
            refresh()
            return true
        } catch {
            errorMessage = presentableMessage(for: error)
            return false
        }
    }
 
    func updateSnippet(id: Int64, draft: SnippetDraft) {
        if let message = triggerConflictMessage(for: draft.trigger, excluding: id) {
            errorMessage = message
            return
        }
        do {
            try snipRepo.update(id: id, draft: draft)
            notifySnippetsChanged()   // FIX #8
            bannerMessage = "Snippet saved."
            refresh()
        } catch {
            errorMessage = presentableMessage(for: error)
        }
    }
 
    func deleteSnippet(id: Int64) {
        do {
            try snipRepo.delete(id: id)
            notifySnippetsChanged()   // FIX #8
            selectedSnippetId = nil
            bannerMessage = "Snippet deleted."
            refresh()
        } catch {
            errorMessage = presentableMessage(for: error)
        }
    }
 
 
    func addCategory(name: String) {
        do {
            try catRepo.add(name: name)
            bannerMessage = "Category created."
            refresh()
        } catch {
            errorMessage = presentableMessage(for: error)
        }
    }
 
    func updateCategory(id: Int64, name: String, icon: String) {
        do {
            try catRepo.update(id: id, name: name, icon: icon)
            bannerMessage = "Category updated."
            refresh()
        } catch {
            errorMessage = presentableMessage(for: error)
        }
    }
 
    func deleteCategory(id: Int64) {
        do {
            try catRepo.delete(id: id)
            if selectedCategoryId == id { selectedCategoryId = nil }
            bannerMessage = "Category deleted."
            refresh()
        } catch {
            errorMessage = presentableMessage(for: error)
        }
    }
 
    /// The DB's UNIQUE constraint is case-sensitive, but case-insensitive snippets would make
    /// ";sig" and ";SIG" ambiguous, so reject triggers that differ only by case.
    private func triggerConflictMessage(for trigger: String, excluding id: Int64?) -> String? {
        let clash = snippets.contains {
            $0.id != id && $0.trigger.caseInsensitiveCompare(trigger) == .orderedSame
        }
        return clash ? "That trigger is already in use. Choose a different one." : nil
    }

    private func notifySnippetsChanged() {
        NotificationCenter.default.post(name: .snippetsDidChange, object: nil)
    }

    private func presentableMessage(for error: Error) -> String {
        let message = error.localizedDescription.lowercased()

        if message.contains("unique") && message.contains("trigger") {
            return "That trigger is already in use. Choose a different one."
        }

        if message.contains("unique") && message.contains("name") {
            return "That category name already exists."
        }

        return "Something went wrong. Please try again."
    }
}
 
