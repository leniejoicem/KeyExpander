//
//  ContentView.swift
//  KeyExpander
//
//  Created by Lenie Joice on 12/26/25.
//


import SwiftUI
import ApplicationServices

private enum AppTheme: String, CaseIterable, Identifiable {
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .light:
            return "Light"
        case .dark:
            return "Dark"
        }
    }

    var colorScheme: ColorScheme {
        switch self {
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}

struct ContentView: View {
    @StateObject private var vm = AppViewModel()
    @State private var didLoad = false
    @State private var permissionsGranted = false
    @AppStorage("appTheme") private var appTheme = AppTheme.light.rawValue

    @State private var showNewCategoryPrompt = false
    @State private var newCategoryName = ""
    @State private var showNewSnippet  = false
    @State private var bannerDismissTask: Task<Void, Never>?

    var body: some View {
        Group {
            if permissionsGranted {
                mainView
            } else {
                PermissionGateView {
                    GlobalKeyListener.shared.start()
                    TextEngine.shared.reloadSnippets()
                    permissionsGranted = true
                }
            }
        }
        .onAppear {
            let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
                as CFDictionary
            permissionsGranted = AXIsProcessTrustedWithOptions(opts)
        }
        .onChange(of: vm.bannerMessage) { _, newValue in
            bannerDismissTask?.cancel()
            guard newValue != nil else { return }

            bannerDismissTask = Task {
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    vm.bannerMessage = nil
                }
            }
        }
        .preferredColorScheme(selectedTheme.colorScheme)
    }

    private var mainView: some View {
        NavigationSplitView {
            SidebarView(vm: vm)
                .navigationSplitViewColumnWidth(min: 220, ideal: 240, max: 280)
        } content: {
            SnippetListView(vm: vm, showNewSnippet: $showNewSnippet)
                .navigationSplitViewColumnWidth(min: 420, ideal: 520, max: 620)
        } detail: {
            SnippetEditorView(vm: vm)
        }
        .task {
            guard !didLoad else { return }
            didLoad = true
            await vm.loadAll()
        }
        .sheet(isPresented: $showNewSnippet)  { NewSnippetSheet(vm: vm) }
        .alert("New Category", isPresented: $showNewCategoryPrompt) {
            TextField("Category name", text: $newCategoryName)
            Button("Cancel", role: .cancel) {
                newCategoryName = ""
            }
            Button("Create") {
                createCategory()
            }
            .disabled(newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        } message: {
            Text("Add a category without leaving the current screen.")
        }
        .alert("Error", isPresented: Binding(
            get: { vm.errorMessage != nil },
            set: { if !$0 { vm.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { vm.errorMessage = nil }
        } message: {
            Text(vm.errorMessage ?? "")
        }
        .safeAreaInset(edge: .top) {
            if let bannerMessage = vm.bannerMessage {
                BannerView(message: bannerMessage)
                    .padding(.top, 8)
                    .padding(.horizontal, 12)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .toolbar {
            ToolbarItemGroup {
                Button { showNewSnippet = true } label: {
                    Label("New Snippet", systemImage: "plus")
                }
                Button {
                    newCategoryName = ""
                    showNewCategoryPrompt = true
                } label: {
                    Label("New Category", systemImage: "folder.badge.plus")
                }

                Menu {
                    Picker("Theme", selection: $appTheme) {
                        ForEach(AppTheme.allCases) { theme in
                            Text(theme.title).tag(theme.rawValue)
                        }
                    }
                } label: {
                    Label("Theme", systemImage: "paintbrush")
                }
            }
        }
    }

    private func createCategory() {
        let trimmedName = newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        vm.addCategory(name: trimmedName)
        newCategoryName = ""
    }

    private var selectedTheme: AppTheme {
        AppTheme(rawValue: appTheme) ?? .light
    }
}

private struct BannerView: View {
    let message: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)

            Text(message)
                .font(.subheadline)
                .fontWeight(.medium)

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.green.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
    }
}
