//
//  AppViewModel.swift
//  KeyExpander
//
//  Created by Lenie Joice on 12/27/25.
//


import SwiftUI

struct SnippetListView: View {
    @ObservedObject var vm: AppViewModel
    @Binding var showNewSnippet: Bool

    var body: some View {
        VStack(spacing: 0) {
            header

            if vm.filteredSnippets.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(vm.filteredSnippets) { snippet in
                        SnippetRowButton(vm: vm, snippet: snippet)
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .padding(.vertical, 2)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(listBackground)
            }
        }
        .navigationTitle(vm.categoryName(for: vm.selectedCategoryId))
        .background(listBackground)
    }

    private var header: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(vm.categoryName(for: vm.selectedCategoryId))
                        .font(AppTypography.hero)

                    Text("\(vm.filteredSnippets.count) snippet\(vm.filteredSnippets.count == 1 ? "" : "s")")
                        .font(AppTypography.label)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    showNewSnippet = true
                } label: {
                    Label("New Snippet", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }

            HStack {
                Label("Search", systemImage: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("Find by title, trigger, or content", text: $vm.searchText)
                    .textFieldStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            )
            .padding(.top, 14)
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 12)
        .background(.ultraThinMaterial)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: vm.searchText.isEmpty ? "text.badge.plus" : "magnifyingglass")
                .font(.system(size: 34))
                .foregroundStyle(.secondary)

            Text(vm.searchText.isEmpty ? "No snippets yet" : "No matching snippets")
                .font(AppTypography.sectionTitle)

            Text(emptyStateMessage)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)

            if vm.searchText.isEmpty {
                Button {
                    showNewSnippet = true
                } label: {
                    Label("Create First Snippet", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(listBackground)
    }

    private var emptyStateMessage: String {
        if vm.searchText.isEmpty {
            return "Start with a trigger like ;sig and a block of text you reuse often."
        }

        return "Try a different keyword or clear the search field."
    }

    private var listBackground: some View {
        LinearGradient(
            colors: [
                Color(nsColor: .windowBackgroundColor),
                Color.accentColor.opacity(0.05)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

private struct SnippetRowButton: View {
    @ObservedObject var vm: AppViewModel
    let snippet: Snippet
    @State private var showDeleteConfirmation = false

    var body: some View {
        Button {
            vm.selectedSnippetId = snippet.id
        } label: {
            SnippetRow(
                snippet: snippet,
                categoryName: vm.categoryName(for: snippet.categoryId),
                isSelected: vm.selectedSnippetId == snippet.id
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Delete", role: .destructive) {
                showDeleteConfirmation = true
            }
        }
        .alert("Delete Snippet?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task { @MainActor in
                    vm.deleteSnippet(id: snippet.id)
                }
            }
        } message: {
            Text("This will permanently delete \(snippet.title.isEmpty ? snippet.trigger : snippet.title).")
        }
    }
}

private struct SnippetRow: View {
    let snippet: Snippet
    let categoryName: String
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(snippet.trigger)
                    .font(.headline.monospaced())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.accentColor.opacity(0.12))
                    .clipShape(Capsule())

                Spacer()

                if !snippet.isEnabled {
                    Text("Off")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.12))
                        .clipShape(Capsule())
                }

                Text(categoryName)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
            }

            Text(snippet.title.isEmpty ? "Untitled" : snippet.title)
                .font(AppTypography.cardTitle)
                .foregroundStyle(.primary)
                .lineLimit(1)

            Text(snippet.content)
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .lineLimit(2)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(isSelected ? Color.accentColor.opacity(0.14) : Color(nsColor: .controlBackgroundColor).opacity(0.7))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isSelected ? Color.accentColor.opacity(0.28) : Color.primary.opacity(0.05), lineWidth: 1)
        )
    }
}
