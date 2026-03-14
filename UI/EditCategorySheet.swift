//
//  EditCategorySheet.swift
//  KeyExpander
//
//  Created by Lenie Joice on 3/14/26.
//


import SwiftUI
 
struct EditCategorySheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var vm: AppViewModel
 
    let category: Category
 
    @State private var name: String = ""
 
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Edit Category")
                .font(.title3)
                .bold()
 
            VStack(alignment: .leading, spacing: 6) {
                Text("Name")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("Category name", text: $name)
                    .textFieldStyle(.roundedBorder)
            }
 
            Spacer()
 
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
 
                Button("Save") {
                    let n = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !n.isEmpty else { return }
                    Task { @MainActor in
                        vm.updateCategory(id: category.id, name: n, icon: category.icon)
                        dismiss()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 320, height: 180)
        .onAppear {
            name = category.name
        }
    }
}
 
