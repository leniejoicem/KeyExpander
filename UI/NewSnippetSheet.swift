//
//  NewSnippetSheet.swift
//  KeyExpander
//
//  Created by Lenie Joice on 12/27/25.
//


import SwiftUI

struct NewSnippetSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var vm: AppViewModel

    @State private var draft = SnippetDraft()

    private var defaultCategoryId: Int64? {
        vm.selectedCategoryId ?? vm.categories.first?.id
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("New Snippet").font(.title3).bold()

            Form {
                Section("Basics") {
                    TextField("Title", text: $draft.title)
                    TextField("Trigger (ex: ;hi)", text: $draft.trigger)

                    Picker("Category", selection: Binding(
                        get: { draft.categoryId ?? defaultCategoryId },
                        set: { draft.categoryId = $0 }
                    )) {
                        ForEach(vm.categories) { c in
                            Text(c.name).tag(Optional(c.id))
                        }
                    }
                }

                Section("Content") {
                    TextEditor(text: $draft.content)
                        .frame(minHeight: 140)
                }

                Section("Behavior") {
                    Toggle("Enabled", isOn: $draft.isEnabled)
                    Toggle("Case Sensitive", isOn: $draft.caseSensitive)
                }
            }
            .formStyle(.grouped)

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }

                Button("Create") {
                    var normalized = normalizedDraft(draft)

                    if normalized.categoryId == nil {
                        normalized.categoryId = defaultCategoryId
                    }

                    guard !normalized.trigger.isEmpty, !normalized.content.isEmpty else { return }

                    Task { @MainActor in
                        vm.addSnippet(normalized)
                        dismiss()
                    }
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
        .frame(width: 640, height: 520)
        .onAppear {
            if draft.categoryId == nil {
                draft.categoryId = defaultCategoryId
            }
        }
    }

    private func normalizedDraft(_ d: SnippetDraft) -> SnippetDraft {
        var x = d
        x.title = x.title.trimmingCharacters(in: .whitespacesAndNewlines)
        x.trigger = x.trigger.trimmingCharacters(in: .whitespacesAndNewlines)
        x.content = x.content.trimmingCharacters(in: .whitespacesAndNewlines)
        return x
    }
}
