//
//  AddExerciseView.swift
//  WorkoutTimer
//
//  Form view to add new exercises with name and category selection.
//

import SwiftUI
import CoreData
import UIKit
import Combine

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
    @State private var selectedEquipment = "No Equipment"
    @State private var showingAddCategory = false
    @State private var showingAddEquipment = false
    @State private var showingExerciseDiscovery = false

    private var categoryNames: [String] {
        categories.compactMap { $0.name }
    }

    private var equipmentNames: [String] {
        var names = Equipment.allCases.map { $0.rawValue }
        names.append(contentsOf: CustomEquipmentManager.shared.customEquipment)
        return names.sorted()
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

                    Picker("Equipment", selection: $selectedEquipment) {
                        ForEach(equipmentNames, id: \.self) { equipment in
                            Label(equipment, systemImage: equipmentIcon(for: equipment)).tag(equipment)
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

                    Button(action: { showingAddEquipment = true }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.orange)
                            Text("Add Custom Equipment")
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
            .sheet(isPresented: $showingAddEquipment) {
                AddEquipmentView { newEquipment in
                    selectedEquipment = newEquipment
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
            exercise.equipment = selectedEquipment
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

    private func equipmentIcon(for equipment: String) -> String {
        if let builtIn = Equipment(rawValue: equipment) {
            return builtIn.icon
        }
        return "wrench.and.screwdriver"
    }
}

// MARK: - Custom Equipment Manager

class CustomEquipmentManager: ObservableObject {
    static let shared = CustomEquipmentManager()

    private let key = "customEquipment"

    @Published var customEquipment: [String] = []

    private init() {
        customEquipment = UserDefaults.standard.stringArray(forKey: key) ?? []
    }

    func add(_ equipment: String) {
        let trimmed = equipment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !customEquipment.contains(trimmed) else { return }
        guard Equipment(rawValue: trimmed) == nil else { return } // Don't add if it's a built-in

        customEquipment.append(trimmed)
        customEquipment.sort()
        save()
    }

    func remove(_ equipment: String) {
        customEquipment.removeAll { $0 == equipment }
        save()
    }

    private func save() {
        UserDefaults.standard.set(customEquipment, forKey: key)
    }
}

// MARK: - Add Equipment View

struct AddEquipmentView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var customEquipmentManager = CustomEquipmentManager.shared

    @State private var newEquipmentName = ""
    let onAdd: (String) -> Void

    private var isFormValid: Bool {
        let trimmed = newEquipmentName.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && Equipment(rawValue: trimmed) == nil
    }

    private var allEquipment: [String] {
        var items = Equipment.allCases.map { $0.rawValue }
        items.append(contentsOf: customEquipmentManager.customEquipment)
        return items.sorted()
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Add New Equipment")) {
                    TextField("Equipment Name", text: $newEquipmentName)
                        .textInputAutocapitalization(.words)

                    Button(action: addEquipment) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.green)
                            Text("Add Equipment")
                        }
                    }
                    .disabled(!isFormValid)
                }

                Section(header: Text("Available Equipment")) {
                    ForEach(allEquipment, id: \.self) { equipment in
                        HStack {
                            let isBuiltIn = Equipment(rawValue: equipment) != nil
                            Image(systemName: isBuiltIn ? Equipment(rawValue: equipment)!.icon : "wrench.and.screwdriver")
                                .foregroundColor(.accentColor)
                                .frame(width: 24)

                            Text(equipment)

                            Spacer()

                            if !isBuiltIn {
                                Text("Custom")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            let equipment = allEquipment[index]
                            if Equipment(rawValue: equipment) == nil {
                                customEquipmentManager.remove(equipment)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Equipment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
            }
        }
    }

    private func addEquipment() {
        let trimmed = newEquipmentName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        customEquipmentManager.add(trimmed)
        onAdd(trimmed)
        dismiss()
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
    @State private var selectedCategory: String = "All"
    @State private var selectedEquipment: String = "All"
    @State private var addedExercises: Set<String> = []
    @State private var showingAddedAlert = false
    @State private var lastAddedExercise = ""

    private var existingExerciseNames: Set<String> {
        Set(existingExercises.map { $0.wrappedName })
    }

    private var filteredExercises: [LibraryExercise] {
        let category: String? = selectedCategory == "All" ? nil : selectedCategory
        let equipment: Equipment? = selectedEquipment == "All" ? nil : Equipment.allCases.first { $0.rawValue == selectedEquipment }

        return ExerciseLibrary.filter(category: category, equipment: equipment, search: searchText)
    }

    private var groupedExercises: [String: [LibraryExercise]] {
        Dictionary(grouping: filteredExercises) { $0.category }
    }

    private var sortedCategories: [String] {
        groupedExercises.keys.sorted()
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Filter Section
                VStack(spacing: 12) {
                    // Category Dropdown
                    HStack {
                        Label("Category", systemImage: "folder")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Picker("Category", selection: $selectedCategory) {
                            Text("All Categories").tag("All")
                            ForEach(ExerciseLibrary.categories, id: \.self) { category in
                                Text(category).tag(category)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(.accentColor)
                    }

                    Divider()

                    // Equipment Dropdown
                    HStack {
                        Label("Equipment", systemImage: "dumbbell")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Picker("Equipment", selection: $selectedEquipment) {
                            Text("All Equipment").tag("All")
                            ForEach(Equipment.allCases, id: \.rawValue) { equipment in
                                Label(equipment.rawValue, systemImage: equipment.icon).tag(equipment.rawValue)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(.accentColor)
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))

                Divider()

                // Results count
                HStack {
                    Text("\(filteredExercises.count) exercises")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    if !addedExercises.isEmpty {
                        Text("\(addedExercises.count) added")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.green)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)

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
                        Text("Try different filters")
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
                                        equipment: exercise.equipment,
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
            }
            .alert("Exercise Added", isPresented: $showingAddedAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("\"\(lastAddedExercise)\" has been added to your library.")
            }
        }
    }

    private func addExercise(_ exercise: LibraryExercise) {
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

// MARK: - Discovery Exercise Row

struct DiscoveryExerciseRow: View {
    let name: String
    let category: String
    let equipment: Equipment
    let isInLibrary: Bool
    let onAdd: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.body)
                    .foregroundColor(isInLibrary ? .secondary : .primary)

                if equipment != .none {
                    HStack(spacing: 4) {
                        Image(systemName: equipment.icon)
                            .font(.caption2)
                        Text(equipment.rawValue)
                            .font(.caption)
                    }
                    .foregroundColor(.orange)
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "figure.stand")
                            .font(.caption2)
                        Text("No Equipment")
                            .font(.caption)
                    }
                    .foregroundColor(.green)
                }
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
