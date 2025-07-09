// Enhanced Portion Customization System
import Foundation

// MARK: - Advanced Portion Management
struct AdvancedPortionManager {
    
    // MARK: - Portion Size Categories
    enum PortionSize: String, CaseIterable {
        case extraSmall = "extra_small"
        case small = "small"
        case medium = "medium"
        case large = "large"
        case extraLarge = "extra_large"
        
        var displayName: String {
            switch self {
            case .extraSmall: return "Extra Pequeña"
            case .small: return "Pequeña"
            case .medium: return "Media"
            case .large: return "Grande"
            case .extraLarge: return "Extra Grande"
            }
        }
        
        var multiplier: Double {
            switch self {
            case .extraSmall: return 0.5
            case .small: return 0.75
            case .medium: return 1.0
            case .large: return 1.5
            case .extraLarge: return 2.0
            }
        }
    }
    
    // MARK: - Measurement System
    enum MeasurementSystem: String, CaseIterable {
        case metric = "metric"
        case imperial = "imperial"
        case mixed = "mixed"
        
        var displayName: String {
            switch self {
            case .metric: return "Métrico (g, ml)"
            case .imperial: return "Imperial (oz, cups)"
            case .mixed: return "Mixto"
            }
        }
    }
    
    // MARK: - Enhanced Portion Preferences
    struct AdvancedPortionPreferences {
        let measurementSystem: MeasurementSystem
        let defaultPortionSize: PortionSize
        let customMultiplier: Double
        let preferredUnits: [String] // e.g., ["cup", "tablespoon", "piece"]
        let avoidedUnits: [String] // e.g., ["ounce", "pound"]
        let roundingPreference: RoundingPreference
        let culturalContext: CulturalContext
        
        enum RoundingPreference {
            case exact, rounded, simplified
        }
        
        enum CulturalContext {
            case mexican, spanish, american, international
            
            var preferredMeasurements: [String] {
                switch self {
                case .mexican, .spanish:
                    return ["taza", "cucharada", "cucharadita", "pieza", "gramos"]
                case .american:
                    return ["cup", "tablespoon", "teaspoon", "ounce", "piece"]
                case .international:
                    return ["g", "ml", "piece", "serving"]
                }
            }
        }
    }
}

// MARK: - Smart Portion Calculator
struct SmartPortionCalculator {
    let preferences: AdvancedPortionManager.AdvancedPortionPreferences
    
    func calculateOptimalPortion(
        for food: USDAFood,
        targetCalories: Double,
        mealType: MealType,
        patientProfile: PatientProfile?
    ) -> OptimalPortion {
        
        // Step 1: Calculate base portion size from calories
        let baseGrams = calculateBasePortionFromCalories(
            food: food,
            targetCalories: targetCalories
        )
        
        // Step 2: Adjust for meal type
        let mealAdjustedGrams = adjustForMealType(
            baseGrams: baseGrams,
            mealType: mealType
        )
        
        // Step 3: Adjust for patient profile
        let patientAdjustedGrams = adjustForPatient(
            grams: mealAdjustedGrams,
            profile: patientProfile
        )
        
        // Step 4: Convert to user-friendly measurements
        let userFriendlyPortion = convertToUserFriendlyMeasurement(
            food: food,
            grams: patientAdjustedGrams
        )
        
        // Step 5: Calculate nutrition for final portion
        let finalNutrition = calculateNutritionForPortion(
            food: food,
            grams: patientAdjustedGrams
        )
        
        return OptimalPortion(
            gramWeight: patientAdjustedGrams,
            userFriendlyDescription: userFriendlyPortion.description,
            measurementValue: userFriendlyPortion.value,
            measurementUnit: userFriendlyPortion.unit,
            nutrition: finalNutrition,
            accuracyScore: calculateAccuracyScore(
                targetCalories: targetCalories,
                actualCalories: finalNutrition.calories
            )
        )
    }
    
    private func calculateBasePortionFromCalories(food: USDAFood, targetCalories: Double) -> Double {
        guard food.calories > 0 else { return 100 } // Default 100g if no calorie data
        return (targetCalories / food.calories) * 100 // USDA data is per 100g
    }
    
    private func adjustForMealType(baseGrams: Double, mealType: MealType) -> Double {
        let mealMultipliers: [MealType: Double] = [
            .breakfast: 1.0,
            .lunch: 1.2,
            .dinner: 1.1,
            .snack: 0.6
        ]
        
        return baseGrams * (mealMultipliers[mealType] ?? 1.0)
    }
    
    private func adjustForPatient(grams: Double, profile: PatientProfile?) -> Double {
        guard let profile = profile else { return grams }
        
        var adjustedGrams = grams
        
        // Adjust for age
        if profile.age < 18 {
            adjustedGrams *= 0.8 // Smaller portions for children
        } else if profile.age > 65 {
            adjustedGrams *= 0.9 // Slightly smaller for elderly
        }
        
        // Adjust for activity level
        switch profile.activityLevel {
        case .sedentary:
            adjustedGrams *= 0.9
        case .lightlyActive:
            adjustedGrams *= 1.0
        case .moderatelyActive:
            adjustedGrams *= 1.1
        case .veryActive:
            adjustedGrams *= 1.3
        case .extremelyActive:
            adjustedGrams *= 1.5
        }
        
        // Apply user's portion size preference
        adjustedGrams *= preferences.defaultPortionSize.multiplier
        
        // Apply custom multiplier
        adjustedGrams *= preferences.customMultiplier
        
        return adjustedGrams
    }
    
    private func convertToUserFriendlyMeasurement(food: USDAFood, grams: Double) -> UserFriendlyMeasurement {
        let foodName = food.description.lowercased()
        
        // Use food-specific conversions for better user experience
        if foodName.contains("rice") {
            return convertRiceToUserFriendly(grams: grams)
        } else if foodName.contains("chicken") || foodName.contains("salmon") || foodName.contains("beef") {
            return convertProteinToUserFriendly(grams: grams)
        } else if foodName.contains("spinach") || foodName.contains("lettuce") || foodName.contains("kale") {
            return convertLeafyGreensToUserFriendly(grams: grams)
        } else if foodName.contains("oil") {
            return convertOilToUserFriendly(grams: grams)
        } else {
            return convertGenericToUserFriendly(grams: grams)
        }
    }
    
    private func convertRiceToUserFriendly(grams: Double) -> UserFriendlyMeasurement {
        switch preferences.measurementSystem {
        case .metric:
            if grams >= 200 {
                return UserFriendlyMeasurement(value: grams, unit: "g", description: "\(Int(grams))g de arroz")
            } else {
                let cups = grams / 158 // Approximate conversion for cooked rice
                return UserFriendlyMeasurement(value: cups, unit: "taza", description: "\(String(format: "%.1f", cups)) taza de arroz")
            }
        case .imperial, .mixed:
            let cups = grams / 158
            if cups >= 1 {
                return UserFriendlyMeasurement(value: cups, unit: "cups", description: "\(String(format: "%.1f", cups)) cups rice")
            } else {
                return UserFriendlyMeasurement(value: grams, unit: "g", description: "\(Int(grams))g rice")
            }
        }
    }
    
    private func convertProteinToUserFriendly(grams: Double) -> UserFriendlyMeasurement {
        switch preferences.measurementSystem {
        case .metric:
            return UserFriendlyMeasurement(value: grams, unit: "g", description: "\(Int(grams))g")
        case .imperial:
            let ounces = grams / 28.35
            return UserFriendlyMeasurement(value: ounces, unit: "oz", description: "\(String(format: "%.1f", ounces)) oz")
        case .mixed:
            if grams >= 85 { // 3 oz or more
                let ounces = grams / 28.35
                return UserFriendlyMeasurement(value: ounces, unit: "oz", description: "\(String(format: "%.1f", ounces)) oz")
            } else {
                return UserFriendlyMeasurement(value: grams, unit: "g", description: "\(Int(grams))g")
            }
        }
    }
    
    private func convertLeafyGreensToUserFriendly(grams: Double) -> UserFriendlyMeasurement {
        let cups = grams / 30 // Approximate conversion for raw leafy greens
        
        switch preferences.culturalContext {
        case .mexican, .spanish:
            if cups >= 1 {
                return UserFriendlyMeasurement(value: cups, unit: "tazas", description: "\(String(format: "%.1f", cups)) tazas")
            } else {
                return UserFriendlyMeasurement(value: grams, unit: "g", description: "\(Int(grams))g")
            }
        case .american, .international:
            return UserFriendlyMeasurement(value: cups, unit: "cups", description: "\(String(format: "%.1f", cups)) cups")
        }
    }
    
    private func convertOilToUserFriendly(grams: Double) -> UserFriendlyMeasurement {
        let tablespoons = grams / 14 // 1 tablespoon ≈ 14g
        let teaspoons = grams / 4.7 // 1 teaspoon ≈ 4.7g
        
        switch preferences.culturalContext {
        case .mexican, .spanish:
            if tablespoons >= 1 {
                return UserFriendlyMeasurement(value: tablespoons, unit: "cucharadas", description: "\(String(format: "%.1f", tablespoons)) cucharadas")
            } else {
                return UserFriendlyMeasurement(value: teaspoons, unit: "cucharaditas", description: "\(String(format: "%.1f", teaspoons)) cucharaditas")
            }
        case .american, .international:
            if tablespoons >= 1 {
                return UserFriendlyMeasurement(value: tablespoons, unit: "tbsp", description: "\(String(format: "%.1f", tablespoons)) tbsp")
            } else {
                return UserFriendlyMeasurement(value: teaspoons, unit: "tsp", description: "\(String(format: "%.1f", teaspoons)) tsp")
            }
        }
    }
    
    private func convertGenericToUserFriendly(grams: Double) -> UserFriendlyMeasurement {
        return UserFriendlyMeasurement(value: grams, unit: "g", description: "\(Int(grams))g")
    }
    
    private func calculateNutritionForPortion(food: USDAFood, grams: Double) -> EstimatedNutrition {
        let multiplier = grams / 100.0
        
        return EstimatedNutrition(
            calories: food.calories * multiplier,
            protein: food.protein * multiplier,
            carbs: food.carbs * multiplier,
            fat: food.fat * multiplier
        )
    }
    
    private func calculateAccuracyScore(targetCalories: Double, actualCalories: Double) -> Double {
        let difference = abs(targetCalories - actualCalories)
        let percentageDifference = difference / targetCalories
        return max(0, 1.0 - percentageDifference)
    }
}

// MARK: - Supporting Data Models
struct OptimalPortion {
    let gramWeight: Double
    let userFriendlyDescription: String
    let measurementValue: Double
    let measurementUnit: String
    let nutrition: EstimatedNutrition
    let accuracyScore: Double
}

struct UserFriendlyMeasurement {
    let value: Double
    let unit: String
    let description: String
}

struct PatientProfile {
    let age: Int
    let activityLevel: ActivityLevel
    let culturalBackground: AdvancedPortionManager.AdvancedPortionPreferences.CulturalContext
    
    enum ActivityLevel {
        case sedentary, lightlyActive, moderatelyActive, veryActive, extremelyActive
    }
}

// MARK: - Integration with Existing System
extension LLMService {
    
    // Enhanced prompt generation with portion intelligence
    func createPortionAwarePrompt(from request: MealPlanRequest, portionPreferences: AdvancedPortionManager.AdvancedPortionPreferences) -> String {
        let basePrompt = createUSDACompatiblePrompt(from: request)
        
        let portionGuidance = """
        
        🍽️ PORTION INTELLIGENCE REQUIREMENTS:
        
        MEASUREMENT SYSTEM: \(portionPreferences.measurementSystem.displayName)
        PREFERRED PORTION SIZE: \(portionPreferences.defaultPortionSize.displayName)
        CULTURAL CONTEXT: \(portionPreferences.culturalContext.preferredMeasurements.joined(separator: ", "))
        
        PORTION CALCULATION STRATEGY:
        1. Calculate base portions to meet EXACT calorie targets
        2. Use culturally appropriate measurements (\(portionPreferences.culturalContext.preferredMeasurements.joined(separator: ", ")))
        3. Prefer standard serving sizes when possible
        4. Account for portion size preference: \(portionPreferences.defaultPortionSize.displayName)
        5. Round to user-friendly amounts
        
        EXAMPLES OF GOOD PORTION DESCRIPTIONS:
        ✅ "120g de pollo" or "4 oz de pollo"
        ✅ "1 taza de arroz integral" or "1 cup brown rice"
        ✅ "2 cucharadas de aceite de oliva" or "2 tbsp olive oil"
        ✅ "1 pieza mediana" or "1 medium piece"
        
        AVOID THESE PORTION FORMATS:
        ❌ "Some chicken breast"
        ❌ "A handful of rice"
        ❌ "Drizzle of oil"
        ❌ Vague or imprecise measurements
        
        CRITICAL: Each portion must be precise enough for USDA database matching and nutrition calculation.
        """
        
        return basePrompt + portionGuidance
    }
}
