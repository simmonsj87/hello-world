//
//  AddExerciseView.swift
//  WorkoutTimer
//
//  Form view to add new exercises with name and category selection.
//

import SwiftUI
import CoreData

struct AddExerciseView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Category.orderIndex, ascending: true)],
        animation: .default
    )
    private var categories: FetchedResults<Category>

    @State private var exerciseName = ""
    @State private var selectedCategory = "Upper Body"
    @State private var showingAddCategory = false

    private var categoryNames: [String] {
        categories.compactMap { $0.name }
    }

    private var isFormValid: Bool {
        !exerciseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
