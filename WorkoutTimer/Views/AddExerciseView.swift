//
//  AddExerciseView.swift
//  WorkoutTimer
//
//  Form view to add new exercises with name and category selection.
//

import SwiftUI
import CoreData
import UIKit

struct AddExerciseView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Category.orderIndex, ascending: true)],
        animation: .default
    )
    private var categories: FetchedResults<Category>

    @FetchRequest(sortDescriptors: [])
    private var existingExercises: FetchedResults<Exercise>

    @State private var exerciseName = ""
    @State private var selectedCategory = "Upper Body"
    @State private var showingAddCategory = false
    @State private var showingExerciseDiscovery = false

    private var categoryNames: [String] {
        categories.compactMap { $0.name }
    }

    private var isFormValid: Bool {
        !exerciseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationView {
            Form {
                // Discover Exercises Section
                Section {
                    Button(action: { showingExerciseDiscovery = true }) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 36, height: 36)
                                .background(Color.blue)
                                .cornerRadius(8)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Explore Exercises")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text("Browse 100+ exercises to add to your library")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("Find New Exercises")
                }

                // Manual Entry Section
                Section(header: Text("Or Add Manually")) {
                    TextField("Exercise Name", text: $exerciseName)
                        .textInputAutocapitalization(.words)

                    Picker("Category", selection: $selectedCategory) {
                        ForEach(categoryNames, id: \.self) { category in
                            Text(category).tag(category)
                        }
                    }
                }

                Section {
                    Button(action: { showingAddCategory = true }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.green)
                            Text("Add Custom Category")
                        }
                    }
                }

                Section {
                    Button(action: saveExercise) {
                        HStack {
                            Spacer()
                            Text("Save Exercise")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(!isFormValid)
                }
            }
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingAddCategory) {
                AddCategoryView { newCategory in
                    selectedCategory = newCategory
                }
            }
            .sheet(isPresented: $showingExerciseDiscovery) {
                ExerciseDiscoveryView(existingExercises: Array(existingExercises))
                    .environment(\.managedObjectContext, viewContext)
            }
            .onAppear {
                ensureDefaultCategories()
                if let firstCategory = categoryNames.first {
                    selectedCategory = firstCategory
                }
            }
        }
    }

    private func ensureDefaultCategories() {
        Category.createDefaultCategories(in: viewContext)
    }

    private func saveExercise() {
        let trimmedName = exerciseName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        withAnimation {
            let exercise = Exercise(context: viewContext)
            exercise.id = UUID()
            exercise.name = trimmedName
            exercise.category = selectedCategory
            exercise.createdDate = Date()
            exercise.isEnabled = true

            do {
                try viewContext.save()
                dismiss()
            } catch {
                let nsError = error as NSError
                print("Error saving exercise: \(nsError), \(nsError.userInfo)")
            }
        }
    }
}

struct AddExerciseView_Previews: PreviewProvider {
    static var previews: some View {
        AddExerciseView()
            .environment(\.managedObjectContext, PersistenceController.preview.viewContext)
    }
}

// MARK: - Exercise Discovery View

struct ExerciseDiscoveryView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    let existingExercises: [Exercise]

    @State private var searchText = ""
    @State private var selectedCategory: String? = nil
    @State private var addedExercises: Set<String> = []
    @State private var showingAddedAlert = false
    @State private var lastAddedExercise = ""

    private var existingExerciseNames: Set<String> {
        Set(existingExercises.map { $0.wrappedName })
    }

    private var filteredExercises: [(name: String, category: String)] {
        var results = ExerciseLibrary.exercises

        // Filter by category if selected
        if let category = selectedCategory {
            results = results.filter { $0.category == category }
        }

        // Filter by search text
        if !searchText.isEmpty {
            results = results.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.category.localizedCaseInsensitiveContains(searchText)
            }
        }

        return results
    }

    private var groupedExercises: [String: [(name: String, category: String)]] {
        Dictionary(grouping: filteredExercises) { $0.category }
    }

    private var sortedCategories: [String] {
        groupedExercises.keys.sorted()
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Category filter chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        CategoryChip(
                            title: "All",
                            isSelected: selectedCategory == nil,
                            action: { selectedCategory = nil }
                        )

                        ForEach(ExerciseLibrary.categories, id: \.self) { category in
                            CategoryChip(
                                title: category,
                                isSelected: selectedCategory == category,
                                action: { selectedCategory = category }
                            )
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                .background(Color(.systemBackground))

                Divider()

                // Exercise list
                if filteredExercises.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("No exercises found")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("Try a different search or category")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                } else {
                    List {
                        ForEach(sortedCategories, id: \.self) { category in
                            Section(header: Text(category)) {
                                ForEach(groupedExercises[category] ?? [], id: \.name) { exercise in
                                    DiscoveryExerciseRow(
                                        name: exercise.name,
                                        category: exercise.category,
                                        isInLibrary: existingExerciseNames.contains(exercise.name) || addedExercises.contains(exercise.name),
                                        onAdd: { addExercise(exercise) }
                                    )
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Explore Exercises")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search exercises")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    if !addedExercises.isEmpty {
                        Text("\(addedExercises.count) added")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .alert("Exercise Added", isPresented: $showingAddedAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("\"\(lastAddedExercise)\" has been added to your library.")
            }
        }
    }

    private func addExercise(_ exercise: (name: String, category: String)) {
        // Check if already exists
        guard !existingExerciseNames.contains(exercise.name),
              !addedExercises.contains(exercise.name) else {
            return
        }

        let newExercise = Exercise(context: viewContext)
        newExercise.id = UUID()
        newExercise.name = exercise.name
        newExercise.category = exercise.category
        newExercise.createdDate = Date()
        newExercise.isEnabled = true

        do {
            try viewContext.save()
            addedExercises.insert(exercise.name)
            lastAddedExercise = exercise.name
            showingAddedAlert = true

            // Haptic feedback
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        } catch {
            print("Error adding exercise: \(error)")
        }
    }
}

// MARK: - Category Chip

struct CategoryChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isSelected ? Color.accentColor : Color(.tertiarySystemBackground))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(20)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Discovery Exercise Row

struct DiscoveryExerciseRow: View {
    let name: String
    let category: String
    let isInLibrary: Bool
    let onAdd: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.body)
                    .foregroundColor(isInLibrary ? .secondary : .primary)
            }

            Spacer()

            if isInLibrary {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("In Library")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                Button(action: onAdd) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                        Text("Add")
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }
}
