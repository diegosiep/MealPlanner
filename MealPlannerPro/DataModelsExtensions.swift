import Foundation
import CoreData

// MARK: - DataModelsExtensions.swift
// Purpose: Safe extensions for Core Data models that handle missing properties gracefully
// Fixed: Cannot find type 'SavedFood' and 'PlannedMeal' in scope

// ==========================================
// ESTIMATED NUTRITION EXTENSIONS
// ==========================================
// Note: These extensions are disabled because EstimatedNutrition is now a struct, not a Core Data entity
/*
extension EstimatedNutrition {
    var safeCarbohydrates: Double {
        if let value = self.value(forKey: "carbohydrates") as? Double {
            return value
        }
        if let value = self.value(forKey: "carbs") as? Double {
            return value
        }
        return 0.0
    }
    
    var safeFat: Double {
        if let value = self.value(forKey: "fat") as? Double {
            return value
        }
        if let value = self.value(forKey: "totalFat") as? Double {
            return value
        }
        return 0.0
    }
    
    var safeProtein: Double {
        return self.value(forKey: "protein") as? Double ?? 0.0
    }
    
    var safeCalories: Double {
        if let value = self.value(forKey: "calories") as? Double {
            return value
        }
        if let value = self.value(forKey: "energy") as? Double {
            return value
        }
        return 0.0
    }
    
    var safeFiber: Double {
        if let value = self.value(forKey: "fiber") as? Double {
            return value
        }
        if let value = self.value(forKey: "dietaryFiber") as? Double {
            return value
        }
        return 0.0
    }
    
    var safeSugar: Double {
        if let value = self.value(forKey: "sugar") as? Double {
            return value
        }
        if let value = self.value(forKey: "sugars") as? Double {
            return value
        }
        return 0.0
    }
}
*/

// ==========================================
// SUGGESTED FOOD EXTENSIONS
// ==========================================
// Note: These extensions are disabled because SuggestedFood is now a struct, not a Core Data entity
/*
extension SuggestedFood {
    var safeEstimatedCalories: Int {
        if let calories = self.value(forKey: "estimatedCalories") as? Int {
            return calories
        }
        
        if let nutrition = self.estimatedNutrition {
            return Int(nutrition.safeCalories)
        }
        
        // Estimate based on weight and food type
        let caloriesPerGram: Double
        let foodName = self.name.lowercased()
        
        if foodName.contains("oil") || foodName.contains("butter") {
            caloriesPerGram = 9.0
        } else if foodName.contains("meat") || foodName.contains("fish") {
            caloriesPerGram = 2.0
        } else if foodName.contains("vegetable") || foodName.contains("fruit") {
            caloriesPerGram = 0.5
        } else {
            caloriesPerGram = 1.5
        }
        
        return Int(Double(self.gramWeight) * caloriesPerGram)
    }
    
    var safeCookingInstructions: String? {
        if let instructions = self.value(forKey: "cookingInstructions") as? String {
            return instructions
        }
        if let instructions = self.value(forKey: "instructions") as? String {
            return instructions
        }
        if let instructions = self.value(forKey: "preparationMethod") as? String {
            return instructions
        }
        
        return generateBasicInstructions()
    }
    
    private func generateBasicInstructions() -> String {
        let foodName = self.name.lowercased()
        
        if foodName.contains("raw") || foodName.contains("fresh") {
            return "Servir fresco. Lavar antes de consumir si es necesario."
        } else if foodName.contains("oil") {
            return "Usar para cocinar o como aderezo según sea necesario."
        } else if foodName.contains("meat") || foodName.contains("chicken") {
            return "Cocinar completamente hasta que alcance la temperatura interna segura. Sazonar al gusto."
        } else if foodName.contains("vegetable") {
            return "Lavar y cocinar al vapor, salteado o hervido hasta que esté tierno."
        } else {
            return "Preparar según las instrucciones del paquete o preferencia personal."
        }
    }
}
*/

// ==========================================
// VERIFIED MEAL PLAN SUGGESTION EXTENSIONS
// ==========================================
// Note: These extensions are disabled because VerifiedMealPlanSuggestion is now a struct, not a Core Data entity
/*
extension VerifiedMealPlanSuggestion {
    var safeEstimatedCalories: Int {
        if let originalCalories = self.originalAISuggestion.value(forKey: "estimatedCalories") as? Int {
            return originalCalories
        }
        
        let totalCalories = self.verifiedFoods.reduce(0.0) { sum, verifiedFood in
            return sum + verifiedFood.verifiedNutrition.safeCalories
        }
        
        return Int(totalCalories)
    }
    
    var safeCookingInstructions: String? {
        if let instructions = self.originalAISuggestion.safeCookingInstructions {
            return instructions
        }
        
        return generateCombinedInstructions()
    }
    
    private func generateCombinedInstructions() -> String {
        var instructions: [String] = []
        
        instructions.append("1. Preparar todos los ingredientes:")
        
        for (index, verifiedFood) in self.verifiedFoods.enumerated() {
            let foodName = verifiedFood.originalAISuggestion.name
            let weight = verifiedFood.originalAISuggestion.gramWeight
            instructions.append("   - \(foodName): \(weight)g")
        }
        
        instructions.append("2. Cocinar los ingredientes según sea necesario:")
        
        let hasProtein = self.verifiedFoods.contains { food in
            let name = food.originalAISuggestion.name.lowercased()
            return name.contains("meat") || name.contains("chicken") || name.contains("fish")
        }
        
        if hasProtein {
            instructions.append("   - Cocinar las proteínas hasta que estén completamente cocidas")
        }
        
        let hasVegetables = self.verifiedFoods.contains { food in
            let name = food.originalAISuggestion.name.lowercased()
            return name.contains("vegetable") || name.contains("broccoli") || name.contains("spinach")
        }
        
        if hasVegetables {
            instructions.append("   - Cocinar las verduras hasta que estén tiernas pero crujientes")
        }
        
        instructions.append("3. Combinar todos los ingredientes y servir caliente.")
        
        return instructions.joined(separator: "\n")
    }
}

// ==========================================
// PATIENT EXTENSIONS
// ==========================================

extension Patient {
    var safeFullName: String {
        let first = self.firstName ?? ""
        let last = self.lastName ?? ""
        let fullName = "\(first) \(last)".trimmingCharacters(in: .whitespaces)
        return fullName.isEmpty ? "Paciente" : fullName
    }
    
    var safeInitials: String {
        let firstInitial = self.firstName?.first?.uppercased() ?? "P"
        let lastInitial = self.lastName?.first?.uppercased() ?? ""
        return "\(firstInitial)\(lastInitial)"
    }
}

// ==========================================
// FOOD EXTENSIONS (Core Data Model)
// ==========================================

extension Food {
    var safeCategory: String {
        return self.value(forKey: "categoryRaw") as? String ?? "custom"
    }
    
    var isUSDAVerified: Bool {
        if let fdcId = self.value(forKey: "fdcId") as? Int32 {
            return fdcId > 0
        }
        return false
    }
    
    var safeCaloriesPer100g: Double {
        return self.calories
    }
    
    var safeProteinPer100g: Double {
        return self.protein
    }
    
    var safeCarbsPer100g: Double {
        return self.carbs
    }
    
    var safeFatPer100g: Double {
        return self.fat
    }
}

// ==========================================
// PLANNED MEAL EXTENSIONS (if the type exists)
// ==========================================

// Note: Since PlannedMeal type wasn't found, creating a placeholder extension
// If you have a different meal planning entity, replace this with the correct name
extension NSManagedObject {
    func safeMealTypeForPlannedMeal() -> MealType {
        if let typeRaw = self.value(forKey: "mealTypeRaw") as? String,
           let mealType = MealType(rawValue: typeRaw) {
            return mealType
        }
        return .breakfast // Default fallback
    }
    
    func safeEstimatedCaloriesForPlannedMeal() -> Double {
        return self.value(forKey: "estimatedCalories") as? Double ?? 0.0
    }
    
    func safeEstimatedProteinForPlannedMeal() -> Double {
        return self.value(forKey: "estimatedProtein") as? Double ?? 0.0
    }
    
    func safeEstimatedCarbsForPlannedMeal() -> Double {
        return self.value(forKey: "estimatedCarbs") as? Double ?? 0.0
    }
    
    func safeEstimatedFatForPlannedMeal() -> Double {
        return self.value(forKey: "estimatedFat") as? Double ?? 0.0
    }
}
*/
