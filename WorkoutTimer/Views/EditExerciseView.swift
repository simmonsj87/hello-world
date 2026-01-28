//
//  EditExerciseView.swift
//  WorkoutTimer
//
//  Form view to edit existing exercises.
//

import SwiftUI
import CoreData

struct EditExerciseView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Category.orderIndex, ascending: true)],
        animation: .default
    )
    private var categories: FetchedResults<Category>

    @ObservedObject var exercise: Exercise

    @State private var exerciseName: String = ""
    @State private var selectedCategory: String = ""
    @State private var isEnabled: Bool = true
    @State private var showingAddCategory = false
    @State private var showingDeleteConfirmation = false

    private var categoryNames: [String] {
        categories.compactMap { $0.name }
    }

    private var isFormValid: Bool {
        !exerciseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var hasChanges: Bool {
        exerciseName != exercise.wrappedName ||
        selectedCategory != exercise.wrappedCategory ||
        isEnabled != exercise.isEnabled
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Exercise Details")) {
                    TextField("Exercise Name", text: $exerciseName)
                        .textInputAutocapitalization(.words)

                    Picker("Category", selection: $selectedCategory) {
                        ForEach(categoryNames, id: \.self) { category in
                            Text(category).tag(category)
                        }
                    }

                    Toggle("Enabled", isOn: $isEnabled)
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
                            Text("Save Changes")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(!isFormValid || !hasChanges)
                }

                Section {
                    Button(role: .destructive, action: { showingDeleteConfirmation = true }) {
                        HStack {
                            Spacer()
                            Label("Delete Exercise", systemImage: "trash")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Edit Exercise")
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
            .alert("Delete Exercise?", isPresented: $showingDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    deleteExercise()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will permanently delete \"\(exercise.wrappedName)\". This action cannot be undone.")
            }
            .onAppear {
                loadExerciseData()
            }
        }
    }

    private func loadExerciseData() {
        exerciseName = exercise.wrappedName
        selectedCategory = exercise.wrappedCategory
        isEnabled = exercise.isEnabled
    }

    private func saveExercise() {
        let trimmedName = exerciseName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        withAnimation {
            exercise.name = trimmedName
            exercise.category = selectedCategory
            exercise.isEnabled = isEnabled

            do {
                try viewContext.save()
                dismiss()
            } catch {
                let nsError = error as NSError
                print("Error saving exercise: \(nsError), \(nsError.userInfo)")
            }
        }
    }

    private func deleteExercise() {
        withAnimation {
            viewContext.delete(exercise)

            do {
                try viewContext.save()
                dismiss()
            } catch {
                let nsError = error as NSError
                print("Error deleting exercise: \(nsError), \(nsError.userInfo)")
            }
        }
    }
}

// MARK: - Preview

struct EditExerciseView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.viewContext
        let exercise = Exercise(context: context)
        exercise.id = UUID()
        exercise.name = "Push-ups"
        exercise.category = "Upper Body"
        exercise.isEnabled = true
        exercise.createdDate = Date()

        return EditExerciseView(exercise: exercise)
            .environment(\.managedObjectContext, context)
    }
}
