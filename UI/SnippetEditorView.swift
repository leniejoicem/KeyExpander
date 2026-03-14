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
    @State private var showDeleteConfirmation = false

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
        VStack(spacing: 18) {
            Image(systemName: "square.and.pencil")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(.secondary)

            Text("Select a snippet to start editing")
                .font(AppTypography.sectionTitle)

            Text("Pick an item from the list to update its trigger, content, and behavior.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(editorBackground)
    }

    private func editor(snippet: Snippet) -> some View {
        VStack(spacing: 0) {
            header(snippet: snippet)

            ScrollView {
                VStack(spacing: 18) {
                    summaryCard(snippet: snippet)

                    Form {
                        Section("Basics") {
                            TextField("Title", text: $draft.title)
                            TextField("Trigger", text: $draft.trigger)
                            Text("Use a short trigger such as ;sig or /addr, then press Space or Return to expand it.")
                                .font(.caption)
                                .foregroundStyle(.secondary)

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

                            Text("Line breaks are preserved. Use this for email replies, addresses, signatures, or templates.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Section("Behavior") {
                            Toggle("Enabled", isOn: $draft.isEnabled)
                            Toggle("Case Sensitive", isOn: $draft.caseSensitive)

                            Text("Turn off a snippet to keep it saved without matching while you type. Case sensitive snippets only expand when the typed capitalization matches exactly.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
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
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                }
                .padding(20)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(editorBackground)
    }

    private func summaryCard(snippet: Snippet) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Trigger")
                    .font(AppTypography.label)
                    .foregroundStyle(.secondary)

                Text(snippet.trigger)
                    .font(.title3.monospaced())
                    .fontWeight(.semibold)
            }

            Spacer()

            statPill(title: "Usage", value: "\(snippet.usageCount)")
            statPill(title: "Updated", value: snippet.updatedAt.formatted(date: .numeric, time: .omitted))
            statPill(title: "Status", value: draft.isEnabled ? "On" : "Off")
        }
        .padding(18)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        )
    }

    private func statPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(AppTypography.label)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.subheadline.weight(.semibold))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func header(snippet: Snippet) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Snippet")
                    .font(AppTypography.label)
                    .foregroundStyle(.secondary)

                Text(snippet.title.isEmpty ? snippet.trigger : snippet.title)
                    .font(AppTypography.sectionTitle)
            }

            Spacer()

            Button("Save") {
                guard let id = vm.selectedSnippetId else { return }
                let d = normalizedDraft()
                guard canSaveSnippet else { return }

                Task { @MainActor in
                    vm.updateSnippet(id: id, draft: d)
                }
            }
            .keyboardShortcut("s", modifiers: [.command])
            .disabled(!canSaveSnippet)

            Button("Delete", role: .destructive) {
                showDeleteConfirmation = true
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .overlay(Divider(), alignment: .bottom)
        .alert("Delete Snippet?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                guard let id = vm.selectedSnippetId else { return }

                Task { @MainActor in
                    vm.deleteSnippet(id: id)
                }
            }
        } message: {
            Text("This will permanently delete \(snippet.title.isEmpty ? snippet.trigger : snippet.title).")
        }
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

    private var canSaveSnippet: Bool {
        let normalized = normalizedDraft()
        return !normalized.trigger.isEmpty && !normalized.content.isEmpty
    }

    private var editorBackground: some View {
        LinearGradient(
            colors: [
                Color(nsColor: .windowBackgroundColor),
                Color.accentColor.opacity(0.04)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
