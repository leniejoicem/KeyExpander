//
//  SidebarView.swift
//  KeyExpander
//
//  Created by Lenie Joice on 12/27/25.
//


import SwiftUI

struct SidebarView: View {
    @ObservedObject var vm: AppViewModel
    @Binding var showNewCategory: Bool
    @EnvironmentObject var listenerManager: ListenerManager

    private enum SidebarSelection: Hashable {
        case all
        case category(Int64)
    }

    @State private var selection: SidebarSelection = .all

    var body: some View {
        List(selection: $selection) {

            HStack {
                Text("All Snippets")
                Spacer()
            }
            .contentShape(Rectangle())
            .tag(SidebarSelection.all)

            Section("Categories") {
                ForEach(vm.categories) { cat in
                    HStack {
                        Text(cat.name)
                        Spacer()
                    }
                    .contentShape(Rectangle())
                    .tag(SidebarSelection.category(cat.id))
                    .contextMenu {
                        Button("Delete", role: .destructive) {
                            Task { @MainActor in
                                vm.deleteCategory(id: cat.id)
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.sidebar)

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

        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 10) {
                Divider()

                HStack {
                    Text("\(vm.filteredSnippets.count) snippets")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button { showNewCategory = true } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.plain)
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
}
