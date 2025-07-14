
import Foundation
import CoreData


// MARK: - DataModelExtensions.swift
// Purpose: This file safely extends your existing Core Data models to provide missing properties
// Why needed: Your code is trying to access properties that don't exist in your actual models

// ==========================================
// ESTIMATED NUTRITION EXTENSIONS
// ==========================================

extension EstimatedNutrition {
    // Problem: Code tries to access .carbohydrates but your model might use .carbs
    // Solution: Provide safe accessors that check for different property names
    
    var safeCarbohydrates: Double {
        // First, try the property as written in the original code
        if let value = self.value(forKey: "carbohydrates") as? Double {
            return value
        }
        // Fallback to common alternative names
        if let value = self.value(forKey: "carbs") as? Double {
            return value
        }
        // Last resort: return 0 to prevent crashes
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
        if let value = self.value(forKey: "protein") as? Double {
            return value
        }
        return 0.0
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

// ==========================================
// SUGGESTED FOOD EXTENSIONS
// ==========================================

extension SuggestedFood {
    // Problem: Code tries to access .estimatedCalories but property might not exist
    // Solution: Provide safe calculated properties
    
    var safeEstimatedCalories: Int {
        // Try to get from the model property first
        if let calories = self.value(forKey: "estimatedCalories") as? Int {
            return calories
        }
        
        // Calculate from nutrition if available
        if let nutrition = self.estimatedNutrition {
            return Int(nutrition.safeCalories)
        }
        
        // Estimate based on weight and food type (very rough estimate)
        let caloriesPerGram: Double
        let foodName = self.name.lowercased()
        
        if foodName.contains("oil") || foodName.contains("butter") {
            caloriesPerGram = 9.0 // Fats are calorie-dense
        } else if foodName.contains("meat") || foodName.contains("fish") {
            caloriesPerGram = 2.0 // Protein-rich foods
        } else if foodName.contains("vegetable") || foodName.contains("fruit") {
            caloriesPerGram = 0.5 // Lower calorie foods
        } else {
            caloriesPerGram = 1.5 // Default estimate
        }
        
        return Int(Double(self.gramWeight) * caloriesPerGram)
    }
    
    var safeCookingInstructions: String? {
        // Try different possible property names
        if let instructions = self.value(forKey: "cookingInstructions") as? String {
            return instructions
        }
        if let instructions = self.value(forKey: "instructions") as? String {
            return instructions
        }
        if let instructions = self.value(forKey: "preparationMethod") as? String {
            return instructions
        }
        
        // Generate basic instructions if none exist
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

// ==========================================
// MEAL PLAN SUGGESTION EXTENSIONS
// ==========================================

extension VerifiedMealPlanSuggestion {
    // Problem: Code assumes certain properties exist on the original suggestion
    // Solution: Provide safe accessors that calculate or estimate values
    
    var safeEstimatedCalories: Int {
        // Try the original suggestion first
        if let originalCalories = self.originalAISuggestion.value(forKey: "estimatedCalories") as? Int {
            return originalCalories
        }
        
        // Calculate from verified foods
        let totalCalories = self.verifiedFoods.reduce(0.0) { sum, verifiedFood in
            return sum + verifiedFood.verifiedNutrition.safeCalories
        }
        
        return Int(totalCalories)
    }
    
    var safeCookingInstructions: String? {
        // Check if original suggestion has instructions
        if let instructions = self.originalAISuggestion.safeCookingInstructions {
            return instructions
        }
        
        // Generate combined instructions from all foods
        return generateCombinedInstructions()
    }
    
    private func generateCombinedInstructions() -> String {
        var instructions: [String] = []
        
        // Add preparation step
        instructions.append("1. Preparar todos los ingredientes:")
        
        // List each verified food
        for (index, verifiedFood) in self.verifiedFoods.enumerated() {
            let foodName = verifiedFood.originalAISuggestion.name
            let weight = verifiedFood.originalAISuggestion.gramWeight
            instructions.append("   - \(foodName): \(weight)g")
        }
        
        // Add cooking steps based on food types
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
    // Safe accessors for patient information
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
// SAVED FOOD EXTENSIONS
// ==========================================

extension SavedFood {
    // Safe category handling
    var safeCategory: String {
        return self.categoryRaw ?? "custom"
    }
    
    var isUSDAVerified: Bool {
        if let usdaId = self.usdaFoodId {
            return !usdaId.isEmpty
        }
        return false
    }
    
    // Safe nutrition accessors
    var safeCaloriesPer100g: Double {
        return self.value(forKey: "caloriesPer100g") as? Double ?? 0.0
    }
    
    var safeProteinPer100g: Double {
        return self.value(forKey: "proteinPer100g") as? Double ?? 0.0
    }
    
    var safeCarbsPer100g: Double {
        return self.value(forKey: "carbsPer100g") as? Double ?? 0.0
    }
    
    var safeFatPer100g: Double {
        return self.value(forKey: "fatPer100g") as? Double ?? 0.0
    }
}

// ==========================================
// PLANNED MEAL EXTENSIONS
// ==========================================

extension PlannedMeal {
    // Safe meal type handling
    var safeMealType: MealType {
        if let typeRaw = self.mealTypeRaw,
           let mealType = MealType(rawValue: typeRaw) {
            return mealType
        }
        return .breakfast // Default fallback
    }
    
    // Safe nutrition accessors
    var safeEstimatedCalories: Double {
        return self.value(forKey: "estimatedCalories") as? Double ?? 0.0
    }
    
    var safeEstimatedProtein: Double {
        return self.value(forKey: "estimatedProtein") as? Double ?? 0.0
    }
    
    var safeEstimatedCarbs: Double {
        return self.value(forKey: "estimatedCarbs") as? Double ?? 0.0
    }
    
    var safeEstimatedFat: Double {
        return self.value(forKey: "estimatedFat") as? Double ?? 0.0
    }
}
