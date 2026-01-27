//
//  Category+CoreDataProperties.swift
//  WorkoutTimer
//
//  Properties and fetch request for Category entity.
//

import Foundation
import CoreData

extension Category {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Category> {
        return NSFetchRequest<Category>(entityName: "Category")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var isDefault: Bool
    @NSManaged public var orderIndex: Int16
    @NSManaged public var createdDate: Date?

}

// MARK: - Identifiable Conformance

extension Category: Identifiable {

}

// MARK: - Convenience Properties

extension Category {

    /// Unwrapped name with a default value.
    public var wrappedName: String {
        name ?? "Unknown Category"
    }

    /// Unwrapped created date with a default value.
    public var wrappedCreatedDate: Date {
        createdDate ?? Date()
    }

    /// Default category names for the app.
    public static let defaultCategoryNames: [String] = [
        "Upper Body",
        "Lower Body",
        "Core",
        "Cardio",
        "Full Body"
    ]

    /// Creates default categories if they don't exist.
    public static func createDefaultCategories(in context: NSManagedObjectContext) {
        let fetchRequest: NSFetchRequest<Category> = Category.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "isDefault == YES")

        do {
            let existingDefaults = try context.fetch(fetchRequest)
            let existingNames = Set(existingDefaults.compactMap { $0.name })

            for (index, categoryName) in defaultCategoryNames.enumerated() {
                if !existingNames.contains(categoryName) {
                    let category = Category(context: context)
                    category.id = UUID()
                    category.name = categoryName
                    category.isDefault = true
                    category.orderIndex = Int16(index)
                    category.createdDate = Date()
                }
            }

            if context.hasChanges {
                try context.save()
            }
        } catch {
            print("Error creating default categories: \(error)")
        }
    }
}
