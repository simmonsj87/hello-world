//
//  ExerciseListView.swift
//  WorkoutTimer
//
//  List view showing all exercises grouped by category with search, edit, delete, and enable/disable functionality.
//

import SwiftUI
import CoreData

struct ExerciseListView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(keyPath: \Exercise.category, ascending: true),
            NSSortDescriptor(keyPath: \Exercise.name, ascending: true)
        ],
        animation: .default
    )
    private var exercises: FetchedResults<Exercise>

    @State private var searchText = ""
    @State private var showingAddExercise = false
    @State private var exerciseToEdit: Exercise?
    @State private var showDisabled = true

    private var filteredExercises: [Exercise] {
        var result = Array(exercises)

        // Filter by enabled status if not showing disabled
        if !showDisabled {
            result = result.filter { $0.isEnabled }
        }

        // Filter by search text
        if !searchText.isEmpty {
            result = result.filter { exercise in
                exercise.wrappedName.localizedCaseInsensitiveContains(searchText) ||
                exercise.wrappedCategory.localizedCaseInsensitiveContains(searchText)
            }
        }

        return result
    }

    private var groupedExercises: [String: [Exercise]] {
        Dictionary(grouping: filteredExercises) { $0.wrappedCategory }
    }

    private var sortedCategories: [String] {
        groupedExercises.keys.sorted()
    }

    var body: some View {
        NavigationView {
            Group {
                if exercises.isEmpty {
                    emptyStateView
                } else if filteredExercises.isEmpty {
                    noResultsView
                } else {
                    exerciseListContent
                }
            }
            .navigationTitle("Exercises")
            .searchable(text: $searchText, prompt: "Search exercises")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Toggle("Show Disabled", isOn: $showDisabled)
                    } label: {
                        Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddExercise = true }) {
                        Label("Add Exercise", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddExercise) {
                AddExerciseView()
            }
            .sheet(item: $exerciseToEdit) { exercise in
                EditExerciseView(exercise: exercise)
            }
        }
    }

    // MARK: - Empty State View

    private var emptyStateView: some View {
        ScrollView {
            VStack(spacing: 16) {
                Spacer(minLength: 60)
                Image(systemName: "figure.run")
                    .font(.system(size: 60))
                    .foregroundColor(.secondary)
                Text("No Exercises Yet")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Tap the + button to add your first exercise")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - No Results View

    private var noResultsView: some View {
        ScrollView {
            VStack(spacing: 16) {
                Spacer(minLength: 60)
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 60))
                    .foregroundColor(.secondary)
                Text("No Results")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("No exercises match \"\(searchText)\"")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Exercise List Content

    private var exerciseListContent: some View {
        List {
            ForEach(sortedCategories, id: \.self) { category in
                Section(header: CategoryHeader(category: category)) {
                    ForEach(groupedExercises[category] ?? []) { exercise in
                        ExerciseRow(
                            exercise: exercise,
                            onToggleEnabled: { toggleEnabled(exercise) },
                            onEdit: { exerciseToEdit = exercise }
                        )
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                deleteExercise(exercise)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button {
                                toggleEnabled(exercise)
                            } label: {
                                Label(
                                    exercise.isEnabled ? "Disable" : "Enable",
                                    systemImage: exercise.isEnabled ? "eye.slash" : "eye"
                                )
                            }
                            .tint(exercise.isEnabled ? .orange : .green)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Actions

    private func toggleEnabled(_ exercise: Exercise) {
        withAnimation {
            exercise.isEnabled.toggle()
            do {
                try viewContext.save()
            } catch {
                print("Error toggling exercise: \(error)")
            }
        }
    }

    private func deleteExercise(_ exercise: Exercise) {
        withAnimation {
            viewContext.delete(exercise)
            do {
                try viewContext.save()
            } catch {
                print("Error deleting exercise: \(error)")
            }
        }
    }
}

// MARK: - Category Header

struct CategoryHeader: View {
    let category: String

    private var categoryIcon: String {
        switch category {
        case "Upper Body":
            return "figure.arms.open"
        case "Lower Body":
            return "figure.walk"
        case "Core":
            return "figure.core.training"
        case "Cardio":
            return "heart.fill"
        case "Full Body":
            return "figure.mixed.cardio"
        default:
            return "figure.strengthtraining.traditional"
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: categoryIcon)
                .foregroundColor(.accentColor)
            Text(category)
        }
    }
}

// MARK: - Exercise Row

struct ExerciseRow: View {
    @ObservedObject var exercise: Exercise
    let onToggleEnabled: () -> Void
    let onEdit: () -> Void

    var body: some View {
        Button(action: onEdit) {
            HStack(spacing: 12) {
                // Enabled indicator
                Circle()
                    .fill(exercise.isEnabled ? Color.green : Color.gray)
                    .frame(width: 10, height: 10)

                // Exercise info
                VStack(alignment: .leading, spacing: 4) {
                    Text(exercise.wrappedName)
                        .font(.headline)
                        .foregroundColor(exercise.isEnabled ? .primary : .secondary)
                    if let date = exercise.createdDate {
                        Text("Added \(date, formatter: dateFormatter)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // Disabled badge
                if !exercise.isEnabled {
                    Text("Disabled")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.2))
                        .foregroundColor(.secondary)
                        .cornerRadius(4)
                }

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}

private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .none
    return formatter
}()

// MARK: - Preview

struct ExerciseListView_Previews: PreviewProvider {
    static var previews: some View {
        ExerciseListView()
            .environment(\.managedObjectContext, PersistenceController.preview.viewContext)
    }
}
