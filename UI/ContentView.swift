//
//  ContentView.swift
//  KeyExpander
//
//  Created by Lenie Joice on 12/26/25.
//


import SwiftUI

struct ContentView: View {
    @StateObject private var vm = AppViewModel()
    @State private var didLoad = false

    @State private var showNewCategory = false
    @State private var showNewSnippet = false

    var body: some View {
        NavigationSplitView {
            SidebarView(vm: vm, showNewCategory: $showNewCategory)
        } content: {
            SnippetListView(vm: vm, showNewSnippet: $showNewSnippet)
        } detail: {
            SnippetEditorView(vm: vm)
        }
        .task {
            guard !didLoad else { return }
            didLoad = true
            await vm.loadAll()
            TextEngine.shared.reloadSnippets() 
        }
        .sheet(isPresented: $showNewCategory) { NewCategorySheet(vm: vm) }
        .sheet(isPresented: $showNewSnippet) { NewSnippetSheet(vm: vm) }
        .alert("Error", isPresented: Binding(
            get: { vm.errorMessage != nil },
            set: { if !$0 { vm.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { vm.errorMessage = nil }
        } message: {
            Text(vm.errorMessage ?? "")
        }

        .toolbar {
            ToolbarItemGroup {
                Button {
                    showNewSnippet = true
                } label: {
                    Label("New Snippet", systemImage: "plus")
                }

                Button {
                    showNewCategory = true
                } label: {
                    Label("New Category", systemImage: "folder.badge.plus")
                }
        
            }
        }
    }
}
