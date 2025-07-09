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
    var preferMetric: Bool // grams vs ounces
    let preferLargePortion: Bool
    let customPortionMultiplier: Double // 0.5 to 2.0
    let avoidedFoodSizes: [String] // e.g., ["large", "jumbo"]
    let preferredMeasurements: [String] // e.g., ["cup", "tablespoon", "piece"]
}

// MARK: - Enhanced Multi-Day Planning Service
extension MultiDayMealPlanningService {
    
    // MARK: - Intelligent Variety Management
    struct VarietyManager {
        private let maxRepeatDays: Int = 3 // Don't repeat same ingredient within 3 days
        private let cuisineRotationStrength: Double = 0.8 // How strongly to enforce cuisine rotation
        private let nutritionVarietyBonus: Double = 0.2 // Bonus for nutritional variety
        
        func createVarietyConstraints(
            for dayNumber: Int,
            request: MultiDayPlanRequest,
            previousDays: [DailyMealPlan]
        ) -> VarietyConstraints {
            
            let recentIngredients = extractRecentIngredients(from: previousDays, dayNumber: dayNumber)
            let recentCuisines = extractRecentCuisines(from: previousDays, dayNumber: dayNumber)
            let nutritionGaps = identifyNutritionGaps(from: previousDays, targetGoals: request)
            
            return VarietyConstraints(
                avoidIngredients: recentIngredients,
                preferredCuisine: selectOptimalCuisine(
                    dayNumber: dayNumber,
                    availableCuisines: request.cuisineRotation,
                    recentCuisines: recentCuisines
                ),
                nutritionPriorities: nutritionGaps,
                varietyInstructions: generateVarietyInstructions(
                    dayNumber: dayNumber,
                    recentIngredients: recentIngredients,
                    nutritionGaps: nutritionGaps
                )
            )
        }
        
        private func extractBaseIngredientName(_ fullName: String) -> String {
              // Extract the main ingredient from USDA-style names
              // "Chicken, broilers or fryers, breast, meat only, cooked, grilled" -> "Chicken"
              let components = fullName.components(separatedBy: ",")
              return components.first?.trimmingCharacters(in: .whitespaces) ?? fullName
          }
        
        private func extractRecentIngredients(from previousDays: [DailyMealPlan], dayNumber: Int) -> Set<String> {
            var ingredients = Set<String>()
            
            // Look at last few days (up to maxRepeatDays)
            let startIndex = max(0, previousDays.count - maxRepeatDays)
            let recentDays = Array(previousDays[startIndex...])
            
            for day in recentDays {
                for meal in day.meals {
                    for food in meal.verifiedFoods {
                        let baseIngredient = extractBaseIngredientName(food.originalAISuggestion.name)
                        ingredients.insert(baseIngredient.lowercased())
                    }
                }
            }
            
            return ingredients
        }
        
        private func extractRecentCuisines(from previousDays: [DailyMealPlan], dayNumber: Int) -> [String] {
            var cuisines: [String] = []
            
            let startIndex = max(0, previousDays.count - 2) // Last 2 days
            let recentDays = Array(previousDays[startIndex...])
            
            for day in recentDays {
                for meal in day.meals {
                    if let cuisine = identifyCuisineFromMeal(meal) {
                        cuisines.append(cuisine)
                    }
                }
            }
            
            return cuisines
        }
        
        private func identifyNutritionGaps(from previousDays: [DailyMealPlan], targetGoals: MultiDayPlanRequest) -> [NutritionPriority] {
            guard !previousDays.isEmpty else { return [] }
            
            var priorities: [NutritionPriority] = []
            
            // Calculate average nutrition from previous days
            let avgCalories = previousDays.reduce(0) { $0 + $1.dailyNutritionSummary.calories } / Double(previousDays.count)
            let avgProtein = previousDays.reduce(0) { $0 + $1.dailyNutritionSummary.protein } / Double(previousDays.count)
            let avgCarbs = previousDays.reduce(0) { $0 + $1.dailyNutritionSummary.carbs } / Double(previousDays.count)
            let avgFat = previousDays.reduce(0) { $0 + $1.dailyNutritionSummary.fat } / Double(previousDays.count)
            
            // Identify gaps compared to targets
            if avgProtein < targetGoals.dailyProtein * 0.9 {
                priorities.append(.increaseProtein)
            }
            if avgCarbs < targetGoals.dailyCarbs * 0.9 {
                priorities.append(.increaseCarbs)
            }
            if avgFat < targetGoals.dailyFat * 0.9 {
                priorities.append(.increaseFat)
            }
            
            // Add micronutrient priorities based on food variety
            if hasLowVegetableVariety(previousDays) {
                priorities.append(.increaseVegetableVariety)
            }
            if hasLowProteinVariety(previousDays) {
                priorities.append(.increaseProteinVariety)
            }
            
            return priorities
        }
        
        private func selectOptimalCuisine(
            dayNumber: Int,
            availableCuisines: [String],
            recentCuisines: [String]
        ) -> String? {
            guard !availableCuisines.isEmpty else { return nil }
            
            // Simple rotation if no recent cuisine history
            if recentCuisines.isEmpty {
                let index = (dayNumber - 1) % availableCuisines.count
                return availableCuisines[index]
            }
            
            // Find cuisine that hasn't been used recently
            let unusedCuisines = availableCuisines.filter { cuisine in
                !recentCuisines.contains(cuisine)
            }
            
            if !unusedCuisines.isEmpty {
                let index = (dayNumber - 1) % unusedCuisines.count
                return unusedCuisines[index]
            }
            
            // If all cuisines have been used, pick the least recent one
            return availableCuisines.randomElement()
        }
        
        private func generateVarietyInstructions(
            dayNumber: Int,
            recentIngredients: Set<String>,
            nutritionGaps: [NutritionPriority]
        ) -> String {
            var instructions: [String] = []
            
            // Variety instructions
            if !recentIngredients.isEmpty {
                let ingredientsList = Array(recentIngredients.prefix(5)).joined(separator: ", ")
                instructions.append("Para variar, evita estos ingredientes usados recientemente: \(ingredientsList)")
            }
            
            // Nutrition priority instructions
            for priority in nutritionGaps {
                switch priority {
                case .increaseProtein:
                    instructions.append("Prioriza fuentes de proteína de alta calidad")
                case .increaseCarbs:
                    instructions.append("Incluye carbohidratos complejos saludables")
                case .increaseFat:
                    instructions.append("Agrega grasas saludables como aceite de oliva, aguacate o nueces")
                case .increaseVegetableVariety:
                    instructions.append("Incluye una amplia variedad de vegetales coloridos")
                case .increaseProteinVariety:
                    instructions.append("Varía las fuentes de proteína (pescado, pollo, legumbres, etc.)")
                }
            }
            
            // Day-specific instructions for meal timing
            switch dayNumber % 7 {
            case 1: // Monday
                instructions.append("Comienza la semana con comidas energizantes y nutritivas")
            case 3: // Wednesday
                instructions.append("A mitad de semana, enfócate en comidas que mantengan la energía estable")
            case 5: // Friday
                instructions.append("Termina la semana con comidas satisfactorias pero ligeras")
            case 0, 6: // Weekend
                instructions.append("Fin de semana: permite comidas más elaboradas y sabrosas")
            default:
                break
            }
            
            return instructions.joined(separator: ". ")
        }
        
        private func hasLowVegetableVariety(_ days: [DailyMealPlan]) -> Bool {
            var vegetables = Set<String>()
            
            for day in days {
                for meal in day.meals {
                    for food in meal.verifiedFoods {
                        if isVegetable(food.originalAISuggestion.name) {
                            vegetables.insert(extractBaseIngredientName(food.originalAISuggestion.name))
                        }
                    }
                }
            }
            
            return vegetables.count < 3 // Less than 3 different vegetables
        }
        
        private func hasLowProteinVariety(_ days: [DailyMealPlan]) -> Bool {
            var proteins = Set<String>()
            
            for day in days {
                for meal in day.meals {
                    for food in meal.verifiedFoods {
                        if isProtein(food.originalAISuggestion.name) {
                            proteins.insert(extractBaseIngredientName(food.originalAISuggestion.name))
                        }
                    }
                }
            }
            
            return proteins.count < 2 // Less than 2 different protein sources
        }
        
        private func isVegetable(_ foodName: String) -> Bool {
            let vegetables = ["spinach", "broccoli", "lettuce", "tomato", "carrot", "pepper", "onion", "zucchini"]
            return vegetables.contains { foodName.lowercased().contains($0) }
        }
        
        private func isProtein(_ foodName: String) -> Bool {
            let proteins = ["chicken", "salmon", "beef", "turkey", "cod", "tuna", "eggs", "tofu"]
            return proteins.contains { foodName.lowercased().contains($0) }
        }
        
        private func identifyCuisineFromMeal(_ meal: VerifiedMealPlanSuggestion) -> String? {
            let mealName = meal.originalAISuggestion.mealName.lowercased()
            
            let cuisineKeywords: [String: [String]] = [
                "Mexicano": ["taco", "burrito", "salsa", "avocado", "lime", "cilantro"],
                "Mediterráneo": ["olive", "lemon", "herb", "tomato", "feta", "mediterranean"],
                "Asiático": ["soy", "ginger", "sesame", "rice", "stir", "asian"],
                "Italiano": ["pasta", "parmesan", "basil", "marinara", "italian"],
                "Americano": ["burger", "bbq", "american", "classic"]
            ]
            
            for (cuisine, keywords) in cuisineKeywords {
                if keywords.contains(where: { mealName.contains($0) }) {
                    return cuisine
                }
            }
            
            return nil
        }
    }
    
    // MARK: - Enhanced Day Generation with Variety Constraints
    func generateSingleDayPlanWithVariety(
        dayNumber: Int,
        request: MultiDayPlanRequest,
        previousDays: [DailyMealPlan]
    ) async throws -> DailyMealPlan {
        
        let varietyManager = VarietyManager()
        let varietyConstraints = varietyManager.createVarietyConstraints(
            for: dayNumber,
            request: request,
            previousDays: previousDays
        )
        
        var meals: [VerifiedMealPlanSuggestion] = []
        let date = Calendar.current.date(byAdding: .day, value: dayNumber - 1, to: request.startDate) ?? request.startDate
        
        print("📅 Generating day \(dayNumber) with variety constraints:")
        print("  - Preferred cuisine: \(varietyConstraints.preferredCuisine ?? "Any")")
        print("  - Avoiding ingredients: \(varietyConstraints.avoidIngredients.count) items")
        
        for mealType in request.mealsPerDay {
            let mealRequest = createVarietyAwareMealRequest(
                for: mealType,
                baseRequest: request,
                varietyConstraints: varietyConstraints,
                existingMealsToday: meals
            )
            
            let verifiedMeal = try await verifiedMealService.generateVerifiedMealPlan(request: mealRequest)
            meals.append(verifiedMeal)
            
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
    
    private func createVarietyAwareMealRequest(
        for mealType: MealType,
        baseRequest: MultiDayPlanRequest,
        varietyConstraints: VarietyConstraints,
        existingMealsToday: [VerifiedMealPlanSuggestion]
    ) -> MealPlanRequest {
        
        let mealCalories = calculateMealCalories(
            totalDailyCalories: baseRequest.dailyCalories,
            mealType: mealType
        )
        
        // Enhanced variety instructions combining all constraints
        var varietyInstructions = varietyConstraints.varietyInstructions
        
        if let preferredCuisine = varietyConstraints.preferredCuisine {
            varietyInstructions += ". Estilo de cocina preferido: \(preferredCuisine)"
        }
        
        // Add daily meal coordination
        if !existingMealsToday.isEmpty {
            let todaysIngredients = existingMealsToday.flatMap { meal in
                meal.verifiedFoods.map { $0.originalAISuggestion.name }
            }
            if !todaysIngredients.isEmpty {
                varietyInstructions += ". Ya se usaron hoy: \(todaysIngredients.joined(separator: ", "))"
            }
        }
        
        return MealPlanRequest(
            targetCalories: mealCalories,
            targetProtein: baseRequest.dailyProtein * Double(mealCalories) / Double(baseRequest.dailyCalories),
            targetCarbs: baseRequest.dailyCarbs * Double(mealCalories) / Double(baseRequest.dailyCalories),
            targetFat: baseRequest.dailyFat * Double(mealCalories) / Double(baseRequest.dailyCalories),
            mealType: mealType,
            cuisinePreference: varietyConstraints.preferredCuisine,
            dietaryRestrictions: baseRequest.dietaryRestrictions,
            medicalConditions: baseRequest.medicalConditions,
            patientId: baseRequest.patientId,
            varietyInstructions: varietyInstructions,
            language: baseRequest.language
        )
    }
}

// MARK: - Supporting Data Models for Variety Management
struct VarietyConstraints {
    let avoidIngredients: Set<String>
    let preferredCuisine: String?
    let nutritionPriorities: [NutritionPriority]
    let varietyInstructions: String
}

enum NutritionPriority {
    case increaseProtein
    case increaseCarbs
    case increaseFat
    case increaseVegetableVariety
    case increaseProteinVariety
}

// MARK: - Enhanced MealPlanRequest with Variety Support
extension MealPlanRequest {
    init(
        targetCalories: Int,
        targetProtein: Double,
        targetCarbs: Double,
        targetFat: Double,
        mealType: MealType,
        cuisinePreference: String?,
        dietaryRestrictions: [String],
        medicalConditions: [String],
        patientId: UUID?,
        varietyInstructions: String?,
        language: PlanLanguage
    ) {
        self.init(
            targetCalories: targetCalories,
            targetProtein: targetProtein,
            targetCarbs: targetCarbs,
            targetFat: targetFat,
            mealType: mealType,
            cuisinePreference: cuisinePreference,
            dietaryRestrictions: dietaryRestrictions,
            medicalConditions: medicalConditions,
            patientId: patientId
        )
        // Note: We'll need to add these properties to the base struct
    }
}
