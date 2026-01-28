//
//  ExercisePickerSheet.swift
//  WorkoutTimer
//
//  Sheet view for selecting exercises with multi-selection and category filtering.
//

import SwiftUI
import CoreData

struct ExercisePickerSheet: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @Binding var selectedExercises: [SelectedExercise]

    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(keyPath: \Exercise.category, ascending: true),
            NSSortDescriptor(keyPath: \Exercise.name, ascending: true)
        ],
        animation: .default
    )
    private var exercises: FetchedResults<Exercise>

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Category.orderIndex, ascending: true)],
        animation: .default
    )
    private var categories: FetchedResults<Category>

    @State private var selectedCategory: String? = nil
    @State private var searchText = ""
    @State private var pendingSelections: Set<UUID> = []

    private var filteredExercises: [Exercise] {
        var result = Array(exercises)

        // Only show enabled exercises
        result = result.filter { $0.isEnabled }

        // Filter by category
        if let category = selectedCategory {
            result = result.filter { $0.category == category }
        }

        // Filter by search text
        if !searchText.isEmpty {
            result = result.filter {
                $0.wrappedName.localizedCaseInsensitiveContains(searchText) ||
                $0.wrappedCategory.localizedCaseInsensitiveContains(searchText)
            }
        }

        return result
    }

    private var groupedExercises: [(String, [Exercise])] {
        let grouped = Dictionary(grouping: filteredExercises) { $0.wrappedCategory }
        return grouped.sorted { $0.key < $1.key }
    }

    private var categoryNames: [String] {
        let names = Set(exercises.compactMap { $0.category })
        return names.sorted()
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Category Filter
                categoryFilterView

                // Exercise List
                if filteredExercises.isEmpty {
                    emptyStateView
                } else {
                    exerciseListView
                }
            }
            .navigationTitle("Select Exercises")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done (\(pendingSelections.count))") {
                        addSelectedExercises()
                    }
                    .disabled(pendingSelections.isEmpty)
                    .fontWeight(.semibold)
                }
            }
            .searchable(text: $searchText, prompt: "Search exercises")
            .onAppear {
                // Pre-select already added exercises
                let existingIds = Set(selectedExercises.compactMap { $0.exercise.id })
                pendingSelections = existingIds
            }
        }
    }

    // MARK: - Category Filter View

    private var categoryFilterView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // All Categories Button
                CategoryChip(
                    title: "All",
                    isSelected: selectedCategory == nil,
                    action: { selectedCategory = nil }
                )

                // Category Buttons
                ForEach(categoryNames, id: \.self) { category in
                    CategoryChip(
                        title: category,
                        isSelected: selectedCategory == category,
                        action: { selectedCategory = category }
                    )
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Empty State View

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No Exercises Found")
                .font(.headline)

            Text("Try adjusting your search or category filter")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Exercise List View

    private var exerciseListView: some View {
        List {
            ForEach(groupedExercises, id: \.0) { category, categoryExercises in
                Section(header: Text(category)) {
                    ForEach(categoryExercises) { exercise in
                        ExerciseSelectionRow(
                            exercise: exercise,
                            isSelected: isSelected(exercise),
                            isAlreadyAdded: isAlreadyAdded(exercise),
                            onToggle: { toggleSelection(exercise) }
                        )
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Helper Methods

    private func isSelected(_ exercise: Exercise) -> Bool {
        guard let id = exercise.id else { return false }
        return pendingSelections.contains(id)
    }

    private func isAlreadyAdded(_ exercise: Exercise) -> Bool {
        guard let id = exercise.id else { return false }
        return selectedExercises.contains { $0.exercise.id == id }
    }

    private func toggleSelection(_ exercise: Exercise) {
        guard let id = exercise.id else { return }

        if pendingSelections.contains(id) {
            pendingSelections.remove(id)
        } else {
            pendingSelections.insert(id)
        }
    }

    private func addSelectedExercises() {
        // Get IDs of already added exercises
        let existingIds = Set(selectedExercises.compactMap { $0.exercise.id })

        // Add only newly selected exercises
        for exercise in exercises {
            guard let id = exercise.id else { continue }

            if pendingSelections.contains(id) && !existingIds.contains(id) {
                selectedExercises.append(SelectedExercise(exercise: exercise))
            }
        }

        // Remove deselected exercises
        selectedExercises.removeAll { selectedExercise in
            guard let id = selectedExercise.exercise.id else { return false }
            return !pendingSelections.contains(id)
        }

        dismiss()
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
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.accentColor : Color(.systemBackground))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.accentColor, lineWidth: isSelected ? 0 : 1)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Exercise Selection Row

struct ExerciseSelectionRow: View {
    let exercise: Exercise
    let isSelected: Bool
    let isAlreadyAdded: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(exercise.wrappedName)
                        .font(.headline)
                        .foregroundColor(.primary)

                    if isAlreadyAdded && isSelected {
                        Text("Already in workout")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(isSelected ? .accentColor : .gray)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

struct ExercisePickerSheet_Previews: PreviewProvider {
    @State static var selectedExercises: [SelectedExercise] = []

    static var previews: some View {
        ExercisePickerSheet(selectedExercises: $selectedExercises)
            .environment(\.managedObjectContext, PersistenceController.preview.viewContext)
    }
}
