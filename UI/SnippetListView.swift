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

            List {
                ForEach(vm.filteredSnippets) { snippet in
                    SnippetRowButton(vm: vm, snippet: snippet)
                }
            }
        }
        .navigationTitle(vm.categoryName(for: vm.selectedCategoryId))
    }

    private var header: some View {
        HStack {
            TextField("Search", text: $vm.searchText)
                .textFieldStyle(.roundedBorder)
                .padding()

            Button {
                showNewSnippet = true
            } label: {
                Label("New", systemImage: "plus")
            }
            .padding(.trailing, 12)
        }
    }
}

private struct SnippetRowButton: View {
    @ObservedObject var vm: AppViewModel
    let snippet: Snippet

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
                Task { @MainActor in
                    vm.deleteSnippet(id: snippet.id)
                }
            }
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
                    .font(.headline)

                Spacer()

                Text(categoryName)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
            }

            Text(snippet.title.isEmpty ? "Untitled" : snippet.title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text(snippet.content)
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
