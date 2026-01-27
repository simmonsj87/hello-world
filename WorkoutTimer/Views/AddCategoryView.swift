//
//  AddCategoryView.swift
//  WorkoutTimer
//
//  Form view to add custom categories.
//

import SwiftUI
import CoreData

struct AddCategoryView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Category.orderIndex, ascending: true)],
        animation: .default
    )
    private var existingCategories: FetchedResults<Category>

    @State private var categoryName = ""
    @State private var showingDuplicateAlert = false

    var onCategoryAdded: ((String) -> Void)?

    private var isFormValid: Bool {
        !categoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var isDuplicate: Bool {
        let trimmed = categoryName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return existingCategories.contains { $0.name?.lowercased() == trimmed }
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("New Category")) {
                    TextField("Category Name", text: $categoryName)
                        .textInputAutocapitalization(.words)
                }

                Section(header: Text("Existing Categories")) {
                    ForEach(existingCategories) { category in
                        HStack {
                            Text(category.wrappedName)
                            Spacer()
                            if category.isDefault {
                                Text("Default")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                Section {
                    Button(action: saveCategory) {
                        HStack {
                            Spacer()
                            Text("Add Category")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(!isFormValid)
                }
            }
            .navigationTitle("Add Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Duplicate Category", isPresented: $showingDuplicateAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("A category with this name already exists.")
            }
        }
    }

    private func saveCategory() {
        let trimmedName = categoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        if isDuplicate {
            showingDuplicateAlert = true
            return
        }

        withAnimation {
            let maxOrderIndex = existingCategories.map { $0.orderIndex }.max() ?? 0

            let category = Category(context: viewContext)
            category.id = UUID()
            category.name = trimmedName
            category.isDefault = false
            category.orderIndex = maxOrderIndex + 1
            category.createdDate = Date()

            do {
                try viewContext.save()
                onCategoryAdded?(trimmedName)
                dismiss()
            } catch {
                let nsError = error as NSError
                print("Error saving category: \(nsError), \(nsError.userInfo)")
            }
        }
    }
}

struct AddCategoryView_Previews: PreviewProvider {
    static var previews: some View {
        AddCategoryView()
            .environment(\.managedObjectContext, PersistenceController.preview.viewContext)
    }
}
