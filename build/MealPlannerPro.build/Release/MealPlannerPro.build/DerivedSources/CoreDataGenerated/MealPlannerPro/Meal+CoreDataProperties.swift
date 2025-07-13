//
//  Meal+CoreDataProperties.swift
//  
//
//  Created by Diego Sierra on 12/07/25.
//
//  This file was automatically generated and should not be edited.
//

public import Foundation
public import CoreData


public typealias MealCoreDataPropertiesSet = NSSet

extension Meal {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Meal> {
        return NSFetchRequest<Meal>(entityName: "Meal")
    }

    @NSManaged public var date: Date?
    @NSManaged public var mealType: String?
    @NSManaged public var name: String?
    @NSManaged public var totalCalories: Double
    @NSManaged public var mealFoods: NSSet?
    @NSManaged public var patient: Patient?

}

// MARK: Generated accessors for mealFoods
extension Meal {

    @objc(addMealFoodsObject:)
    @NSManaged public func addToMealFoods(_ value: MealFood)

    @objc(removeMealFoodsObject:)
    @NSManaged public func removeFromMealFoods(_ value: MealFood)

    @objc(addMealFoods:)
    @NSManaged public func addToMealFoods(_ values: NSSet)

    @objc(removeMealFoods:)
    @NSManaged public func removeFromMealFoods(_ values: NSSet)

}

extension Meal : Identifiable {

}
