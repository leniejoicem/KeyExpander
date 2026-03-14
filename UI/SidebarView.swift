//
//  SidebarView.swift
//  KeyExpander
//
//  Created by Lenie Joice on 12/27/25.
//


import SwiftUI

struct SidebarView: View {
    @ObservedObject var vm: AppViewModel
    @EnvironmentObject var listenerManager: ListenerManager
 
    private enum SidebarSelection: Hashable {
        case all
        case category(Int64)
    }
 
    @State private var selection: SidebarSelection = .all
 
    @State private var categoryToEdit: Category? = nil
    @State private var categoryToDelete: Category? = nil
 
    var body: some View {
        List(selection: $selection) {
 
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Library")
                            .font(AppTypography.label)
                            .foregroundStyle(.secondary)
                        Text("All Snippets")
                            .font(AppTypography.cardTitle)
                    }
                    Spacer()
                }
                .contentShape(Rectangle())
                .tag(SidebarSelection.all)
            }
 
            Section("Categories") {
                ForEach(vm.categories) { cat in
                    HStack {
                        Text(cat.name)
                        Spacer()
                    }
                    .contentShape(Rectangle())
                    .tag(SidebarSelection.category(cat.id))
                    .contextMenu {

                        Button {
                            categoryToEdit = cat
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
 
                        Divider()
 
                        Button("Delete", role: .destructive) {
                            categoryToDelete = cat
                        }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(sidebarBackground)
 
        .onChange(of: selection) { _, newValue in
            Task { @MainActor in
                switch newValue {
                case .all:
                    vm.selectedCategoryId = nil
                case .category(let id):
                    vm.selectedCategoryId = id
                }
            }
        }
 
        .onAppear { syncFromVM() }
        .onChange(of: vm.selectedCategoryId) { _, _ in syncFromVM() }
 
        .sheet(item: $categoryToEdit) { cat in
            EditCategorySheet(vm: vm, category: cat)
        }
        .alert("Delete Category?", isPresented: Binding(
            get: { categoryToDelete != nil },
            set: { if !$0 { categoryToDelete = nil } }
        )) {
            Button("Cancel", role: .cancel) {
                categoryToDelete = nil
            }
            Button("Delete", role: .destructive) {
                guard let category = categoryToDelete else { return }
                Task { @MainActor in
                    vm.deleteCategory(id: category.id)
                    categoryToDelete = nil
                }
            }
        } message: {
            Text("This will permanently delete \(categoryToDelete?.name ?? "this category").")
        }
 
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 10) {
                Divider()
 
                HStack {
                    Text("\(vm.filteredSnippets.count) snippets")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
 
                HStack(spacing: 10) {
                    Circle()
                        .fill(listenerManager.isListening ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
 
                    Text(listenerManager.isListening ? "ON" : "OFF")
                        .font(.caption)
                        .foregroundStyle(.secondary)
 
                    Spacer()
 
                    Toggle("", isOn: $listenerManager.isEnabled)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
            }
            .background(.ultraThinMaterial)
        }
    }
 
    private func syncFromVM() {
        if let id = vm.selectedCategoryId {
            selection = .category(id)
        } else {
            selection = .all
        }
    }

    private var sidebarBackground: some View {
        LinearGradient(
            colors: [
                Color.accentColor.opacity(0.07),
                Color(nsColor: .windowBackgroundColor)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
 
