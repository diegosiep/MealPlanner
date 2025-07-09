import Foundation
import SwiftUI

// MARK: - Multi-Day Meal Planning Service
class MultiDayMealPlanningService: ObservableObject {
    @Published var isGenerating = false
    @Published var currentProgress = 0
    @Published var totalProgress = 0
    @Published var lastError: String?
    
    private let verifiedMealService = USDAVerifiedMealPlanningService()
    
    // MARK: - Generate Multi-Day Plan
    func generateMultiDayPlan(request: MultiDayPlanRequest) async throws -> MultiDayMealPlan {
        await MainActor.run {
            isGenerating = true
            lastError = nil
            currentProgress = 0
            totalProgress = request.numberOfDays * request.mealsPerDay.count
        }
        
        defer {
            Task { @MainActor in
                isGenerating = false
                currentProgress = 0
                totalProgress = 0
            }
        }
        
        var dailyPlans: [DailyMealPlan] = []
        
        // Generate plan for each day
        for dayIndex in 0..<request.numberOfDays {
            print("📅 Generating day \(dayIndex + 1) of \(request.numberOfDays)")
            
            let dailyPlan = try await generateSingleDayPlan(
                dayNumber: dayIndex + 1,
                request: request,
                previousDays: dailyPlans // For variety
            )
            
            dailyPlans.append(dailyPlan)
        }
        
        return MultiDayMealPlan(
            id: UUID(),
            patientId: request.patientId,
            startDate: request.startDate,
            numberOfDays: request.numberOfDays,
            dailyPlans: dailyPlans,
            totalNutritionSummary: calculateTotalNutrition(dailyPlans: dailyPlans),
            language: request.language,
            generatedDate: Date()
        )
    }
    
    // MARK: - Generate Single Day Plan
    private func generateSingleDayPlan(
        dayNumber: Int,
        request: MultiDayPlanRequest,
        previousDays: [DailyMealPlan]
    ) async throws -> DailyMealPlan {
        
        var meals: [VerifiedMealPlanSuggestion] = []
        let date = Calendar.current.date(byAdding: .day, value: dayNumber - 1, to: request.startDate) ?? request.startDate
        
        // Generate each meal for this day
        for mealType in request.mealsPerDay {
            print("🍽️ Generating \(mealType.displayName) for day \(dayNumber)")
            
            // Create meal request with variety considerations
            let mealRequest = createMealRequest(
                for: mealType,
                baseRequest: request,
                dayNumber: dayNumber,
                previousMeals: getAllPreviousMeals(from: previousDays, meals: meals)
            )
            
            let verifiedMeal = try await verifiedMealService.generateVerifiedMealPlan(request: mealRequest)
            meals.append(verifiedMeal)
            
            // Update progress
            await MainActor.run {
                currentProgress += 1
            }
        }
        
        return DailyMealPlan(
            date: date,
            meals: meals,
            dailyNutritionSummary: calculateDailyNutrition(meals: meals)
        )
    }
    
    // MARK: - Create Meal Request with Variety
    private func createMealRequest(
        for mealType: MealType,
        baseRequest: MultiDayPlanRequest,
        dayNumber: Int,
        previousMeals: [VerifiedMealPlanSuggestion]
    ) -> MealPlanRequest {
        
        // Calculate calories for this meal type
        let mealCalories = calculateMealCalories(
            totalDailyCalories: baseRequest.dailyCalories,
            mealType: mealType
        )
        
        // Get variety considerations
        let usedIngredients = extractUsedIngredients(from: previousMeals)
        let varietyInstructions = createVarietyInstructions(
            usedIngredients: usedIngredients,
            dayNumber: dayNumber,
            mealType: mealType,
            cuisine: baseRequest.cuisineRotation
        )
        
        return MealPlanRequest(targetCalories: mealCalories,
            targetProtein: baseRequest.dailyProtein * Double(mealCalories) / Double(baseRequest.dailyCalories),
            targetCarbs: baseRequest.dailyCarbs * Double(mealCalories) / Double(baseRequest.dailyCalories),
            targetFat: baseRequest.dailyFat * Double(mealCalories) / Double(baseRequest.dailyCalories),
            mealType: mealType,
            cuisinePreference: varietyInstructions.cuisine,
            dietaryRestrictions: baseRequest.dietaryRestrictions,
            medicalConditions: baseRequest.medicalConditions,
            patientId: baseRequest.patientId,
            varietyInstructions: varietyInstructions.instructions, // New field
            language: baseRequest.language)
    }
    
    // MARK: - Helper Functions
    private func calculateMealCalories(totalDailyCalories: Int, mealType: MealType) -> Int {
        let percentage: Double
        switch mealType {
        case .breakfast: percentage = 0.25  // 25%
        case .lunch: percentage = 0.35      // 35%
        case .dinner: percentage = 0.35     // 35%
        case .snack: percentage = 0.05      // 5%
        }
        return Int(Double(totalDailyCalories) * percentage)
    }
    
    private func extractUsedIngredients(from meals: [VerifiedMealPlanSuggestion]) -> Set<String> {
        var ingredients = Set<String>()
        for meal in meals {
            for food in meal.verifiedFoods {
                // Extract base ingredient name (remove preparation methods)
                let baseName = extractBaseIngredientName(food.originalAISuggestion.name)
                ingredients.insert(baseName.lowercased())
            }
        }
        return ingredients
    }
    
    private func extractBaseIngredientName(_ fullName: String) -> String {
        // Extract the main ingredient from USDA-style names
        // "Chicken, broilers or fryers, breast, meat only, cooked, grilled" -> "Chicken"
        let components = fullName.components(separatedBy: ",")
        return components.first?.trimmingCharacters(in: .whitespaces) ?? fullName
    }
    
    private func createVarietyInstructions(
        usedIngredients: Set<String>,
        dayNumber: Int,
        mealType: MealType,
        cuisine: [String]
    ) -> (instructions: String, cuisine: String?) {
        
        var instructions = ""
        var selectedCuisine: String? = nil
        
        // Cuisine rotation
        if !cuisine.isEmpty {
            let cuisineIndex = (dayNumber - 1) % cuisine.count
            selectedCuisine = cuisine[cuisineIndex]
            instructions += "Focus on \(selectedCuisine!) cuisine. "
        }
        
        // Avoid recent ingredients
        if !usedIngredients.isEmpty {
            let recentIngredients = Array(usedIngredients.prefix(8)) // Last 8 ingredients
            instructions += "For variety, avoid these recently used ingredients: \(recentIngredients.joined(separator: ", ")). "
        }
        
        // Day-specific variety
        switch dayNumber % 3 {
        case 1:
            instructions += "Focus on lean proteins and fresh vegetables. "
        case 2:
            instructions += "Include healthy grains and legumes. "
        case 0:
            instructions += "Emphasize omega-3 rich foods and colorful produce. "
        default:
            break
        }
        
        return (instructions, selectedCuisine)
    }
    
    private func getAllPreviousMeals(from dailyPlans: [DailyMealPlan], meals: [VerifiedMealPlanSuggestion]) -> [VerifiedMealPlanSuggestion] {
        var allMeals: [VerifiedMealPlanSuggestion] = []
        
        // Add all meals from previous days
        for dailyPlan in dailyPlans {
            allMeals.append(contentsOf: dailyPlan.meals)
        }
        
        // Add meals from current day
        allMeals.append(contentsOf: meals)
        
        return allMeals
    }
    
    private func calculateDailyNutrition(meals: [VerifiedMealPlanSuggestion]) -> DailyNutritionSummary {
        let totalCalories = meals.reduce(0) { $0 + $1.verifiedTotalNutrition.calories }
        let totalProtein = meals.reduce(0) { $0 + $1.verifiedTotalNutrition.protein }
        let totalCarbs = meals.reduce(0) { $0 + $1.verifiedTotalNutrition.carbs }
        let totalFat = meals.reduce(0) { $0 + $1.verifiedTotalNutrition.fat }
        
        return DailyNutritionSummary(
            calories: totalCalories,
            protein: totalProtein,
            carbs: totalCarbs,
            fat: totalFat,
            averageAccuracy: meals.reduce(0) { $0 + $1.overallAccuracy } / Double(meals.count)
        )
    }
    
    private func calculateTotalNutrition(dailyPlans: [DailyMealPlan]) -> MultiDayNutritionSummary {
        let totalCalories = dailyPlans.reduce(0) { $0 + $1.dailyNutritionSummary.calories }
        let totalProtein = dailyPlans.reduce(0) { $0 + $1.dailyNutritionSummary.protein }
        let totalCarbs = dailyPlans.reduce(0) { $0 + $1.dailyNutritionSummary.carbs }
        let totalFat = dailyPlans.reduce(0) { $0 + $1.dailyNutritionSummary.fat }
        let numberOfDays = Double(dailyPlans.count)
        
        return MultiDayNutritionSummary(
            totalCalories: totalCalories,
            totalProtein: totalProtein,
            totalCarbs: totalCarbs,
            totalFat: totalFat,
            averageDailyCalories: totalCalories / numberOfDays,
            averageDailyProtein: totalProtein / numberOfDays,
            averageDailyCarbs: totalCarbs / numberOfDays,
            averageDailyFat: totalFat / numberOfDays,
            overallAccuracy: dailyPlans.reduce(0) { $0 + $1.dailyNutritionSummary.averageAccuracy } / numberOfDays
        )
    }
}

// MARK: - Multi-Day Data Models
struct MultiDayPlanRequest {
    let patientId: UUID?
    let numberOfDays: Int
    let startDate: Date
    let dailyCalories: Int
    let dailyProtein: Double
    let dailyCarbs: Double
    let dailyFat: Double
    let mealsPerDay: [MealType] // e.g., [.breakfast, .lunch, .dinner, .snack]
    let cuisineRotation: [String] // e.g., ["Mediterranean", "Mexican", "Asian"]
    let dietaryRestrictions: [String]
    let medicalConditions: [String]
    let language: PlanLanguage
    let customPortionPreferences: PortionPreferences?
}

struct MultiDayMealPlan: Identifiable {
    let id: UUID
    let patientId: UUID?
    let startDate: Date
    let numberOfDays: Int
    let dailyPlans: [DailyMealPlan]
    let totalNutritionSummary: MultiDayNutritionSummary
    let language: PlanLanguage
    let generatedDate: Date
    
    var endDate: Date {
        Calendar.current.date(byAdding: .day, value: numberOfDays - 1, to: startDate) ?? startDate
    }
}

struct DailyMealPlan {
    let date: Date
    let meals: [VerifiedMealPlanSuggestion]
    let dailyNutritionSummary: DailyNutritionSummary
}

struct DailyNutritionSummary {
    let calories: Double
    let protein: Double
    let carbs: Double
    let fat: Double
    let averageAccuracy: Double
}

struct MultiDayNutritionSummary {
    let totalCalories: Double
    let totalProtein: Double
    let totalCarbs: Double
    let totalFat: Double
    let averageDailyCalories: Double
    let averageDailyProtein: Double
    let averageDailyCarbs: Double
    let averageDailyFat: Double
    let overallAccuracy: Double
}

// MARK: - Language Support
enum PlanLanguage: String, CaseIterable {
    case english = "en"
    case spanish = "es"
    
    var displayName: String {
        switch self {
        case .english: return "English"
        case .spanish: return "Español"
        }
    }
    
    var localized: LocalizedStrings {
        switch self {
        case .english: return EnglishStrings()
        case .spanish: return SpanishStrings()
        }
    }
}

// MARK: - Localization Protocol
protocol LocalizedStrings {
    var mealPlan: String { get }
    var breakfast: String { get }
    var lunch: String { get }
    var dinner: String { get }
    var snack: String { get }
    var calories: String { get }
    var protein: String { get }
    var carbohydrates: String { get }
    var fat: String { get }
    var preparationNotes: String { get }
    var nutritionistNotes: String { get }
    var shoppingList: String { get }
    var recipes: String { get }
}

struct EnglishStrings: LocalizedStrings {
    let mealPlan = "Meal Plan"
    let breakfast = "Breakfast"
    let lunch = "Lunch"
    let dinner = "Dinner"
    let snack = "Snack"
    let calories = "Calories"
    let protein = "Protein"
    let carbohydrates = "Carbohydrates"
    let fat = "Fat"
    let preparationNotes = "Preparation Notes"
    let nutritionistNotes = "Nutritionist Notes"
    let shoppingList = "Shopping List"
    let recipes = "Recipes"
}

struct SpanishStrings: LocalizedStrings {
    let mealPlan = "Plan de Comidas"
    let breakfast = "Desayuno"
    let lunch = "Almuerzo"
    let dinner = "Cena"
    let snack = "Merienda"
    let calories = "Calorías"
    let protein = "Proteína"
    let carbohydrates = "Carbohidratos"
    let fat = "Grasa"
    let preparationNotes = "Notas de Preparación"
    let nutritionistNotes = "Notas del Nutricionista"
    let shoppingList = "Lista de Compras"
    let recipes = "Recetas"
}

// MARK: - Portion Preferences
struct PortionPreferences {
    let preferMetric: Bool // grams vs ounces
    let preferLargePortion: Bool
    let customPortionMultiplier: Double // 0.5 to 2.0
    let avoidedFoodSizes: [String] // e.g., ["large", "jumbo"]
    let preferredMeasurements: [String] // e.g., ["cup", "tablespoon", "piece"]
}
