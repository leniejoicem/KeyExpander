//
//  SnippetEditorView.swift
//  KeyExpander
//
//  Created by Lenie Joice on 12/27/25.
//


import SwiftUI

struct SnippetEditorView: View {
    @ObservedObject var vm: AppViewModel

    @State private var draft = SnippetDraft()
    @State private var loadedSnippetId: Int64? = nil

    var body: some View {
        Group {
            if let snippet = vm.selectedSnippet() {
                editor(snippet: snippet)
            } else {
                emptyState
            }
        }
        .onAppear {
            DispatchQueue.main.async { syncDraftFromSelection() }
        }
        .onChange(of: vm.selectedSnippetId) {
            DispatchQueue.main.async { syncDraftFromSelection() }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)

            Text("Select a snippet to edit")
                .font(.title3)
                .bold()

            Text("Create snippets that expand instantly as you type.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func editor(snippet: Snippet) -> some View {
        VStack(spacing: 0) {
            header(snippet: snippet)

            Form {
                Section("Basics") {
                    TextField("Title", text: $draft.title)
                    TextField("Trigger", text: $draft.trigger)

                    Picker("Category", selection: Binding(
                        get: { draft.categoryId ?? vm.categories.first?.id },
                        set: { draft.categoryId = $0 }
                    )) {
                        ForEach(vm.categories) { c in
                            Text(c.name).tag(Optional(c.id))
                        }
                    }
                }

                Section("Content") {
                    TextEditor(text: $draft.content)
                        .frame(minHeight: 180)
                        .font(.body)
                        .padding(6)
                        .background(.background)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Section("Behavior") {
                    Toggle("Enabled", isOn: $draft.isEnabled)
                    Toggle("Case Sensitive", isOn: $draft.caseSensitive)
                }

                Section("Stats") {
                    HStack {
                        Text("Usage")
                        Spacer()
                        Text("\(snippet.usageCount)")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Updated")
                        Spacer()
                        Text(snippet.updatedAt.formatted(date: .abbreviated, time: .shortened))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .formStyle(.grouped)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func header(snippet: Snippet) -> some View {
        HStack(spacing: 10) {
            Text("Snippet:")
                .foregroundStyle(.secondary)

            Text(snippet.title.isEmpty ? snippet.trigger : snippet.title)
                .font(.title3)
                .bold()

            Spacer()

            Button("Save") {
                guard let id = vm.selectedSnippetId else { return }
                let d = normalizedDraft()

                Task { @MainActor in
                    vm.updateSnippet(id: id, draft: d)
                }
            }
            .keyboardShortcut("s", modifiers: [.command])

            Button("Delete", role: .destructive) {
                guard let id = vm.selectedSnippetId else { return }

                Task { @MainActor in
                    vm.deleteSnippet(id: id)
                }
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .overlay(Divider(), alignment: .bottom)
    }

    private func syncDraftFromSelection() {
        guard let snippet = vm.selectedSnippet() else {
            draft = SnippetDraft()
            loadedSnippetId = nil
            return
        }

        if loadedSnippetId != snippet.id {
            draft = SnippetDraft(
                title: snippet.title,
                trigger: snippet.trigger,
                content: snippet.content,
                categoryId: snippet.categoryId,
                caseSensitive: snippet.caseSensitive,
                isEnabled: snippet.isEnabled
            )
            loadedSnippetId = snippet.id
        }
    }

    private func normalizedDraft() -> SnippetDraft {
        var d = draft
        d.title = d.title.trimmingCharacters(in: .whitespacesAndNewlines)
        d.trigger = d.trigger.trimmingCharacters(in: .whitespacesAndNewlines)
        d.content = d.content.trimmingCharacters(in: .whitespacesAndNewlines)
        return d
    }
}
