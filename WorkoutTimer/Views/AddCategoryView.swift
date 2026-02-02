//
//  AddCategoryView.swift
//  WorkoutTimer
//
//  Form view to manage categories - add, edit, and delete.
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

    @FetchRequest(sortDescriptors: [])
    private var exercises: FetchedResults<Exercise>

    @State private var categoryName = ""
    @State private var showingDuplicateAlert = false
    @State private var categoryToEdit: Category?
    @State private var categoryToDelete: Category?
    @State private var editedName = ""
    @State private var showingDeleteConfirmation = false

    var onCategoryAdded: ((String) -> Void)?

    private var isFormValid: Bool {
        !categoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var isDuplicate: Bool {
        let trimmed = categoryName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return existingCategories.contains { $0.name?.lowercased() == trimmed }
    }

    private func exerciseCount(for category: Category) -> Int {
        exercises.filter { $0.category == category.wrappedName }.count
    }

    var body: some View {
        NavigationView {
            Form {
                // Add New Category Section
                Section(header: Text("Add New Category")) {
                    HStack {
                        TextField("Category Name", text: $categoryName)
                            .textInputAutocapitalization(.words)

                        Button(action: saveCategory) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundColor(isFormValid ? .accentColor : .gray)
                        }
                        .disabled(!isFormValid)
                    }
                }

                // Existing Categories Section
                Section(header: Text("Manage Categories")) {
                    if existingCategories.isEmpty {
                        Text("No categories yet")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(existingCategories) { category in
                            CategoryRow(
                                category: category,
                                exerciseCount: exerciseCount(for: category),
                                onEdit: {
                                    categoryToEdit = category
                                    editedName = category.wrappedName
                                },
                                onDelete: {
                                    categoryToDelete = category
                                    showingDeleteConfirmation = true
                                }
                            )
                        }
                    }
                }

                // Info Section
                Section {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                        Text("Deleting a category will move its exercises to 'Unassigned'")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Manage Categories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Duplicate Category", isPresented: $showingDuplicateAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("A category with this name already exists.")
            }
            .alert("Delete Category?", isPresented: $showingDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    if let category = categoryToDelete {
                        deleteCategory(category)
                    }
                }
                Button("Cancel", role: .cancel) {
                    categoryToDelete = nil
                }
            } message: {
                if let category = categoryToDelete {
                    let count = exerciseCount(for: category)
                    if count > 0 {
                        Text("This will delete \"\(category.wrappedName)\" and move \(count) exercise(s) to 'Unassigned'.")
                    } else {
                        Text("Are you sure you want to delete \"\(category.wrappedName)\"?")
                    }
                }
            }
            .sheet(item: $categoryToEdit) { category in
                EditCategorySheet(
                    category: category,
                    initialName: category.wrappedName,
                    existingNames: Set(existingCategories.compactMap { $0.name }),
                    onSave: { newName in
                        renameCategory(category, to: newName)
                    }
                )
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
                categoryName = ""
                onCategoryAdded?(trimmedName)
            } catch {
                let nsError = error as NSError
                print("Error saving category: \(nsError), \(nsError.userInfo)")
            }
        }
    }

    private func deleteCategory(_ category: Category) {
        withAnimation {
            // First, ensure "Unassigned" category exists
            let unassignedCategory = ensureUnassignedCategory()

            // Reassign all exercises from deleted category to "Unassigned"
            let affectedExercises = exercises.filter { $0.category == category.wrappedName }
            for exercise in affectedExercises {
                exercise.category = unassignedCategory.wrappedName
            }

            // Delete the category
            viewContext.delete(category)

            do {
                try viewContext.save()
            } catch {
                print("Error deleting category: \(error)")
            }
        }
        categoryToDelete = nil
    }

    private func renameCategory(_ category: Category, to newName: String) {
        let oldName = category.wrappedName

        withAnimation {
            // Update category name
            category.name = newName

            // Update all exercises with this category
            let affectedExercises = exercises.filter { $0.category == oldName }
            for exercise in affectedExercises {
                exercise.category = newName
            }

            do {
                try viewContext.save()
            } catch {
                print("Error renaming category: \(error)")
            }
        }
    }

    private func ensureUnassignedCategory() -> Category {
        // Check if "Unassigned" category exists
        if let existing = existingCategories.first(where: { $0.wrappedName == "Unassigned" }) {
            return existing
        }

        // Create "Unassigned" category
        let unassigned = Category(context: viewContext)
        unassigned.id = UUID()
        unassigned.name = "Unassigned"
        unassigned.isDefault = false
        unassigned.orderIndex = 999  // Put at the end
        unassigned.createdDate = Date()

        return unassigned
    }
}

// MARK: - Category Row

struct CategoryRow: View {
    let category: Category
    let exerciseCount: Int
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(category.wrappedName)
                    .font(.body)

                Text("\(exerciseCount) exercise\(exerciseCount == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if category.isDefault {
                Text("Default")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.tertiarySystemBackground))
                    .cornerRadius(4)
            }

            // Edit Button
            Button(action: onEdit) {
                Image(systemName: "pencil")
                    .foregroundColor(.accentColor)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 8)

            // Delete Button (disabled for default categories)
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(category.isDefault ? .gray : .red)
            }
            .buttonStyle(.plain)
            .disabled(category.isDefault)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Edit Category Sheet

struct EditCategorySheet: View {
    @Environment(\.dismiss) private var dismiss

    let category: Category
    let initialName: String
    let existingNames: Set<String>
    let onSave: (String) -> Void

    @State private var editedName: String = ""
    @State private var showingDuplicateAlert = false

    private var isValid: Bool {
        let trimmed = editedName.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed != initialName
    }

    private var isDuplicate: Bool {
        let trimmed = editedName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return trimmed != initialName.lowercased() && existingNames.contains { $0.lowercased() == trimmed }
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Category Name")) {
                    TextField("Category Name", text: $editedName)
                        .textInputAutocapitalization(.words)
                }

                Section {
                    Button(action: save) {
                        HStack {
                            Spacer()
                            Text("Save Changes")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(!isValid)
                }
            }
            .navigationTitle("Edit Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                editedName = initialName
            }
            .alert("Duplicate Category", isPresented: $showingDuplicateAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("A category with this name already exists.")
            }
        }
    }

    private func save() {
        if isDuplicate {
            showingDuplicateAlert = true
            return
        }

        let trimmed = editedName.trimmingCharacters(in: .whitespacesAndNewlines)
        onSave(trimmed)
        dismiss()
    }
}

struct AddCategoryView_Previews: PreviewProvider {
    static var previews: some View {
        AddCategoryView()
            .environment(\.managedObjectContext, PersistenceController.preview.viewContext)
    }
}
