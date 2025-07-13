//
//  Food+CoreDataProperties.swift
//  
//
//  Created by Diego Sierra on 12/07/25.
//
//  This file was automatically generated and should not be edited.
//

public import Foundation
public import CoreData


public typealias FoodCoreDataPropertiesSet = NSSet

extension Food {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Food> {
        return NSFetchRequest<Food>(entityName: "Food")
    }

    @NSManaged public var brandOwner: String?
    @NSManaged public var calories: Double
    @NSManaged public var carbs: Double
    @NSManaged public var dataType: String?
    @NSManaged public var dateAdded: Date?
    @NSManaged public var fat: Double
    @NSManaged public var fdcId: Int32
    @NSManaged public var fiber: Double
    @NSManaged public var name: String?
    @NSManaged public var protein: Double
    @NSManaged public var servingSize: Double
    @NSManaged public var servingSizeUnit: String?
    @NSManaged public var sodium: Double
    @NSManaged public var mealFoods: NSSet?

}

// MARK: Generated accessors for mealFoods
extension Food {

    @objc(addMealFoodsObject:)
    @NSManaged public func addToMealFoods(_ value: MealFood)

    @objc(removeMealFoodsObject:)
    @NSManaged public func removeFromMealFoods(_ value: MealFood)

    @objc(addMealFoods:)
    @NSManaged public func addToMealFoods(_ values: NSSet)

    @objc(removeMealFoods:)
    @NSManaged public func removeFromMealFoods(_ values: NSSet)

}

extension Food : Identifiable {

}
