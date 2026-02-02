//
//  ExerciseListView.swift
//  WorkoutTimer
//
//  List view showing all exercises grouped by category with search, edit, delete, and enable/disable functionality.
//

import SwiftUI
import CoreData
import UniformTypeIdentifiers

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
    @State private var selectedCategoryFilter = "All"
    @State private var selectedEquipmentFilter = "All"
    @State private var showingAddExercise = false
    @State private var exerciseToEdit: Exercise?
    @State private var showDisabled = true
    @State private var showingExportSheet = false
    @State private var exportURL: URL?
    @State private var showingImportPicker = false
    @State private var showingImportSuccess = false
    @State private var showingImportError = false
    @State private var importErrorMessage = ""

    private var availableCategories: [String] {
        let categories = Set(exercises.compactMap { $0.category })
        return ["All"] + categories.sorted()
    }

    private var availableEquipment: [String] {
        var equipment = Set(exercises.compactMap { $0.equipment })
        equipment.insert("No Equipment")
        return ["All"] + equipment.sorted()
    }

    private var filteredExercises: [Exercise] {
        var result = Array(exercises)

        // Filter by enabled status if not showing disabled
        if !showDisabled {
            result = result.filter { $0.isEnabled }
        }

        // Filter by category
        if selectedCategoryFilter != "All" {
            result = result.filter { $0.wrappedCategory == selectedCategoryFilter }
        }

        // Filter by equipment
        if selectedEquipmentFilter != "All" {
            result = result.filter { $0.wrappedEquipment == selectedEquipmentFilter }
        }

        // Filter by search text
        if !searchText.isEmpty {
            result = result.filter { exercise in
                exercise.wrappedName.localizedCaseInsensitiveContains(searchText) ||
                exercise.wrappedCategory.localizedCaseInsensitiveContains(searchText) ||
                exercise.wrappedEquipment.localizedCaseInsensitiveContains(searchText)
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

    private var hasActiveFilters: Bool {
        selectedCategoryFilter != "All" || selectedEquipmentFilter != "All"
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
                        // Category Filter
                        Menu {
                            ForEach(availableCategories, id: \.self) { category in
                                Button(action: { selectedCategoryFilter = category }) {
                                    if selectedCategoryFilter == category {
                                        Label(category, systemImage: "checkmark")
                                    } else {
                                        Text(category)
                                    }
                                }
                            }
                        } label: {
                            Label("Category: \(selectedCategoryFilter)", systemImage: "folder")
                        }

                        // Equipment Filter
                        Menu {
                            ForEach(availableEquipment, id: \.self) { equipment in
                                Button(action: { selectedEquipmentFilter = equipment }) {
                                    if selectedEquipmentFilter == equipment {
                                        Label(equipment, systemImage: "checkmark")
                                    } else {
                                        Text(equipment)
                                    }
                                }
                            }
                        } label: {
                            Label("Equipment: \(selectedEquipmentFilter)", systemImage: "dumbbell")
                        }

                        Divider()

                        Toggle("Show Disabled", isOn: $showDisabled)

                        Divider()

                        Button(action: { showingImportPicker = true }) {
                            Label("Import Exercises", systemImage: "square.and.arrow.down")
                        }

                        if selectedCategoryFilter != "All" || selectedEquipmentFilter != "All" {
                            Divider()

                            Button(action: {
                                selectedCategoryFilter = "All"
                                selectedEquipmentFilter = "All"
                            }) {
                                Label("Clear Filters", systemImage: "xmark.circle")
                            }
                        }
                    } label: {
                        Label("Filter", systemImage: hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
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
            .sheet(isPresented: $showingExportSheet) {
                if let url = exportURL {
                    ShareSheet(items: [url])
                }
            }
            .sheet(isPresented: $showingImportPicker) {
                DocumentPicker(onDocumentPicked: importFromFile)
            }
            .alert("Import Successful", isPresented: $showingImportSuccess) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Exercise(s) imported successfully.")
            }
            .alert("Import Failed", isPresented: $showingImportError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(importErrorMessage)
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
                        .contextMenu {
                            Button(action: { exportExercise(exercise) }) {
                                Label("Share Exercise", systemImage: "square.and.arrow.up")
                            }

                            Button(action: { exerciseToEdit = exercise }) {
                                Label("Edit", systemImage: "pencil")
                            }

                            Button(action: { toggleEnabled(exercise) }) {
                                Label(
                                    exercise.isEnabled ? "Disable" : "Enable",
                                    systemImage: exercise.isEnabled ? "eye.slash" : "eye"
                                )
                            }

                            Divider()

                            Button(role: .destructive, action: { deleteExercise(exercise) }) {
                                Label("Delete", systemImage: "trash")
                            }
                        }
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

    private func exportExercise(_ exercise: Exercise) {
        guard let id = exercise.id else { return }

        let exportData = SingleExerciseExport(
            exportDate: Date(),
            appVersion: "1.0.0",
            exercise: ExerciseExport(
                id: id,
                name: exercise.wrappedName,
                category: exercise.wrappedCategory,
                createdDate: exercise.wrappedCreatedDate
            )
        )

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(exportData)

            let tempDir = FileManager.default.temporaryDirectory
            let sanitizedName = exercise.wrappedName.replacingOccurrences(of: " ", with: "_")
            let fileName = "Exercise_\(sanitizedName).json"
            let fileURL = tempDir.appendingPathComponent(fileName)

            try data.write(to: fileURL)
            exportURL = fileURL
            showingExportSheet = true
        } catch {
            print("Export error: \(error)")
        }
    }

    private func importFromFile(_ url: URL) {
        do {
            guard url.startAccessingSecurityScopedResource() else {
                importErrorMessage = "Could not access the selected file."
                showingImportError = true
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }

            let data = try Data(contentsOf: url)

            // Try to decode as single exercise first
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            if let singleExport = try? decoder.decode(SingleExerciseExport.self, from: data) {
                importSingleExercise(singleExport.exercise)
                showingImportSuccess = true
            } else if let workoutExport = try? decoder.decode(SingleWorkoutExport.self, from: data) {
                // If it's a workout export, import the exercises from it
                for exerciseExport in workoutExport.exercises {
                    importSingleExercise(exerciseExport)
                }
                showingImportSuccess = true
            } else if let fullExport = try? decoder.decode(AppDataExport.self, from: data) {
                // Full app export - import all exercises
                for exerciseExport in fullExport.exercises {
                    importSingleExercise(exerciseExport)
                }
                showingImportSuccess = true
            } else {
                importErrorMessage = "Invalid file format. Please select a valid exercise export file."
                showingImportError = true
            }
        } catch {
            importErrorMessage = "Failed to import: \(error.localizedDescription)"
            showingImportError = true
        }
    }

    private func importSingleExercise(_ exerciseExport: ExerciseExport) {
        // Check if exercise already exists by name
        let existingExercise = exercises.first { $0.wrappedName == exerciseExport.name }
        guard existingExercise == nil else { return }

        let exercise = Exercise(context: viewContext)
        exercise.id = UUID()
        exercise.name = exerciseExport.name
        exercise.category = exerciseExport.category
        exercise.createdDate = exerciseExport.createdDate
        exercise.isEnabled = true

        do {
            try viewContext.save()
        } catch {
            print("Error importing exercise: \(error)")
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

    private var equipmentIcon: String {
        if let builtIn = Equipment(rawValue: exercise.wrappedEquipment) {
            return builtIn.icon
        }
        return "wrench.and.screwdriver"
    }

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

                    HStack(spacing: 8) {
                        if exercise.wrappedEquipment != "No Equipment" {
                            HStack(spacing: 4) {
                                Image(systemName: equipmentIcon)
                                    .font(.caption2)
                                Text(exercise.wrappedEquipment)
                                    .font(.caption)
                            }
                            .foregroundColor(.orange)
                        }

                        if let date = exercise.createdDate {
                            Text("Added \(date, formatter: dateFormatter)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
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
