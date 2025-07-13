//
//  MealFood+CoreDataProperties.swift
//  
//
//  Created by Diego Sierra on 12/07/25.
//
//  This file was automatically generated and should not be edited.
//

public import Foundation
public import CoreData


public typealias MealFoodCoreDataPropertiesSet = NSSet

extension MealFood {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<MealFood> {
        return NSFetchRequest<MealFood>(entityName: "MealFood")
    }

    @NSManaged public var quantity: Double
    @NSManaged public var unit: String?
    @NSManaged public var food: Food?
    @NSManaged public var meal: Meal?

}

extension MealFood : Identifiable {

}
