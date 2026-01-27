//
//  ExerciseListView.swift
//  WorkoutTimer
//
//  List view showing all exercises grouped by category with search functionality.
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

    private var filteredExercises: [Exercise] {
        if searchText.isEmpty {
            return Array(exercises)
        } else {
            return exercises.filter { exercise in
                exercise.wrappedName.localizedCaseInsensitiveContains(searchText) ||
                exercise.wrappedCategory.localizedCaseInsensitiveContains(searchText)
            }
        }
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
                    VStack(spacing: 16) {
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
                    }
                    .padding()
                } else if filteredExercises.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        Text("No Results")
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text("No exercises match \"\(searchText)\"")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                } else {
                    List {
                        ForEach(sortedCategories, id: \.self) { category in
                            Section(header: CategoryHeader(category: category)) {
                                ForEach(groupedExercises[category] ?? []) { exercise in
                                    ExerciseRow(exercise: exercise)
                                }
                                .onDelete { indexSet in
                                    deleteExercises(at: indexSet, in: category)
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Exercises")
            .searchable(text: $searchText, prompt: "Search exercises")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddExercise = true }) {
                        Label("Add Exercise", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddExercise) {
                AddExerciseView()
            }
        }
    }

    private func deleteExercises(at offsets: IndexSet, in category: String) {
        withAnimation {
            let exercisesInCategory = groupedExercises[category] ?? []
            offsets.map { exercisesInCategory[$0] }.forEach(viewContext.delete)

            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                print("Error deleting exercise: \(nsError), \(nsError.userInfo)")
            }
        }
    }
}

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

struct ExerciseRow: View {
    let exercise: Exercise

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(exercise.wrappedName)
                .font(.headline)
            if let date = exercise.createdDate {
                Text("Added \(date, formatter: dateFormatter)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .none
    return formatter
}()

struct ExerciseListView_Previews: PreviewProvider {
    static var previews: some View {
        ExerciseListView()
            .environment(\.managedObjectContext, PersistenceController.preview.viewContext)
    }
}
