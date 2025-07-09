//
//  FoodDataManager.swift
//  MealPlannerPro
//
//  Created by Diego Sierra on 03/07/25.
//

import Foundation
import CoreData

class FoodDataManager: ObservableObject {
    let container: NSPersistentContainer
    
    init(container: NSPersistentContainer) {
        self.container = container
    }
    
    // Save a USDA food to local database
    func saveFood(from usdaFood: USDAFood) {
        let context = container.viewContext
        
        // Check if food already exists
        let request: NSFetchRequest<Food> = Food.fetchRequest()
        request.predicate = NSPredicate(format: "fdcId == %d", usdaFood.fdcId)
        
        do {
            let existingFoods = try context.fetch(request)
            if !existingFoods.isEmpty {
                print("Food already saved!")
                return
            }
        } catch {
            print("Error checking for existing food: \(error)")
        }
        
        // Create new food entity
        let food = Food(context: context)
        food.fdcId = Int32(usdaFood.fdcId)
        food.name = usdaFood.description
        food.calories = usdaFood.calories
        food.protein = usdaFood.protein
        food.carbs = usdaFood.carbs
        food.fat = usdaFood.fat
        food.fiber = usdaFood.fiber
        food.sodium = usdaFood.sodium
        food.servingSize = 100 // Default to 100g
        food.servingSizeUnit = "g"
        food.dataType = usdaFood.dataType
        food.brandOwner = usdaFood.brandOwner
        food.dateAdded = Date()
        
        // Save to Core Data
        do {
            try context.save()
            print("✅ Food saved successfully!")
        } catch {
            print("❌ Error saving food: \(error)")
        }
    }
    
    // Get all saved foods
    func getSavedFoods() -> [Food] {
        let request: NSFetchRequest<Food> = Food.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Food.dateAdded, ascending: false)]
        
        do {
            return try container.viewContext.fetch(request)
        } catch {
            print("Error fetching saved foods: \(error)")
            return []
        }
    }
}

