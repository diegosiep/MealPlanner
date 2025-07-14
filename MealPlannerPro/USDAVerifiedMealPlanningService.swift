import SwiftUI
import Foundation
import CoreData

// MARK: - USDAVerifiedMealPlanningService.swift
// Fixed: PendingFoodSelection ambiguity and missing arguments for onSelection/onSkip

// ==========================================
// USDA VERIFIED MEAL PLANNING SERVICE
// ==========================================

class USDAVerifiedMealPlanningService: ObservableObject {
    @Published var isGenerating = false
    @Published var generationProgress: Double = 0.0
    @Published var lastError: String?
    @Published var currentMealSuggestion: MealSuggestion?
    @Published var pendingVerifications: [FoodVerificationItem] = []
    
    private let foodSelectionManager = ManualFoodSelectionManager.shared
    private let usdaService = USDAFoodService()
    private let aiService = AIFoodSuggestionService.shared
    
    static let shared = USDAVerifiedMealPlanningService()
    
    init() {}
    
    // MARK: - Main Meal Generation Method
    
    func generateVerifiedMeal(
        for patient: Patient?,
        targetCalories: Int,
        mealType: MealType,
        dietaryRestrictions: [String] = [],
        medicalConditions: [String] = [],
        cuisinePreference: String? = nil
    ) async throws -> VerifiedMealPlanSuggestion {
        
        await MainActor.run {
            isGenerating = true
            generationProgress = 0.0
            lastError = nil
        }
        
        defer {
            Task { @MainActor in
                isGenerating = false
                generationProgress = 1.0
            }
        }
        
        do {
            // Step 1: Generate AI meal suggestion
            await updateProgress(0.1, "Generando sugerencia de comida...")
            
            let aiSuggestion = try await generateAIMealSuggestion(
                targetCalories: targetCalories,
                mealType: mealType,
                dietaryRestrictions: dietaryRestrictions,
                medicalConditions: medicalConditions,
                cuisinePreference: cuisinePreference
            )
            
            await MainActor.run {
                currentMealSuggestion = aiSuggestion
            }
            
            // Step 2: Verify each food item with USDA database
            await updateProgress(0.3, "Verificando alimentos con base de datos USDA...")
            
            let verifiedFoods = try await verifyFoodsWithUSDA(aiSuggestion.suggestedFoods)
            
            // Step 3: Calculate final nutrition
            await updateProgress(0.8, "Calculando información nutricional...")
            
            let finalNutrition = calculateFinalNutrition(from: verifiedFoods)
            
            // Step 4: Create verified meal suggestion
            await updateProgress(0.9, "Finalizando comida verificada...")
            
            let verifiedMeal = VerifiedMealPlanSuggestion(
                originalAISuggestion: convertMealSuggestionToSuggestedFood(aiSuggestion),
                verifiedFoods: verifiedFoods.map { convertToVerifiedFood($0) },
                verifiedTotalNutrition: finalNutrition,
                overallAccuracy: calculateVerificationAccuracy(verifiedFoods)
            )
            
            await updateProgress(1.0, "¡Comida verificada generada exitosamente!")
            
            return verifiedMeal
            
        } catch {
            await MainActor.run {
                lastError = error.localizedDescription
            }
            throw error
        }
    }
    
    // MARK: - AI Meal Suggestion Generation
    
    private func generateAIMealSuggestion(
        targetCalories: Int,
        mealType: MealType,
        dietaryRestrictions: [String],
        medicalConditions: [String],
        cuisinePreference: String?
    ) async throws -> MealSuggestion {
        
        let prompt = buildMealPrompt(
            targetCalories: targetCalories,
            mealType: mealType,
            dietaryRestrictions: dietaryRestrictions,
            medicalConditions: medicalConditions,
            cuisinePreference: cuisinePreference
        )
        
        // Simulate AI response (replace with actual AI service call)
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
        
        return MealSuggestion(
            name: generateMealName(mealType: mealType, cuisine: cuisinePreference),
            description: "Una comida balanceada y nutritiva",
            targetCalories: targetCalories,
            mealType: mealType,
            suggestedFoods: generateSampleFoods(targetCalories: targetCalories),
            preparationInstructions: generatePreparationInstructions(),
            estimatedPrepTime: 30,
            difficulty: .medium
        )
    }
    
    private func buildMealPrompt(
        targetCalories: Int,
        mealType: MealType,
        dietaryRestrictions: [String],
        medicalConditions: [String],
        cuisinePreference: String?
    ) -> String {
        var prompt = "Genera una comida de \(mealType.localizedName) con \(targetCalories) calorías."
        
        if !dietaryRestrictions.isEmpty {
            prompt += " Restricciones dietéticas: \(dietaryRestrictions.joined(separator: ", "))."
        }
        
        if !medicalConditions.isEmpty {
            prompt += " Condiciones médicas: \(medicalConditions.joined(separator: ", "))."
        }
        
        if let cuisine = cuisinePreference {
            prompt += " Preferencia de cocina: \(cuisine)."
        }
        
        prompt += " Incluye alimentos específicos con pesos en gramos y valores nutricionales estimados."
        
        return prompt
    }
    
    private func generateMealName(mealType: MealType, cuisine: String?) -> String {
        let cuisinePrefix = cuisine ?? "Mediterránea"
        
        switch mealType {
        case .breakfast:
            return "\(cuisinePrefix) - Desayuno Balanceado"
        case .lunch:
            return "\(cuisinePrefix) - Almuerzo Nutritivo"
        case .dinner:
            return "\(cuisinePrefix) - Cena Saludable"
        case .snack:
            return "\(cuisinePrefix) - Merienda Energética"
        }
    }
    
    private func generateSampleFoods(targetCalories: Int) -> [AIFoodSuggestion] {
        let caloriesPerFood = targetCalories / 4 // Distribute across 4 foods
        
        return [
            AIFoodSuggestion(
                name: "Pechuga de pollo a la parrilla",
                gramWeight: 120,
                estimatedCalories: caloriesPerFood,
                estimatedProtein: 25.0,
                estimatedCarbs: 0.0,
                estimatedFat: 3.0,
                category: "Proteína"
            ),
            AIFoodSuggestion(
                name: "Arroz integral cocido",
                gramWeight: 80,
                estimatedCalories: caloriesPerFood,
                estimatedProtein: 3.0,
                estimatedCarbs: 35.0,
                estimatedFat: 1.0,
                category: "Carbohidratos"
            ),
            AIFoodSuggestion(
                name: "Brócoli al vapor",
                gramWeight: 100,
                estimatedCalories: caloriesPerFood / 2,
                estimatedProtein: 3.0,
                estimatedCarbs: 7.0,
                estimatedFat: 0.5,
                category: "Vegetales"
            ),
            AIFoodSuggestion(
                name: "Aceite de oliva extra virgen",
                gramWeight: 10,
                estimatedCalories: caloriesPerFood / 2,
                estimatedProtein: 0.0,
                estimatedCarbs: 0.0,
                estimatedFat: 10.0,
                category: "Grasas"
            )
        ]
    }
    
    private func generatePreparationInstructions() -> String {
        return """
        1. Precalentar la parrilla a fuego medio-alto.
        2. Sazonar la pechuga de pollo con sal, pimienta y hierbas.
        3. Cocinar el arroz integral según las instrucciones del paquete.
        4. Cocinar al vapor el brócoli hasta que esté tierno.
        5. Asar la pechuga de pollo 6-8 minutos por lado.
        6. Servir todo junto, rociar con aceite de oliva.
        """
    }
    
    // MARK: - USDA Food Verification
    
    private func verifyFoodsWithUSDA(_ aiSuggestions: [AIFoodSuggestion]) async throws -> [VerifiedFoodItem] {
        var verifiedFoods: [VerifiedFoodItem] = []
        
        for (index, aiFood) in aiSuggestions.enumerated() {
            await updateProgress(0.3 + (Double(index) / Double(aiSuggestions.count)) * 0.4,
                                 "Verificando \(aiFood.name)...")
            
            let verifiedFood = try await verifyIndividualFood(aiFood)
            verifiedFoods.append(verifiedFood)
        }
        
        return verifiedFoods
    }
    
    private func verifyIndividualFood(_ aiFood: AIFoodSuggestion) async throws -> VerifiedFoodItem {
        // Search for potential USDA matches
        let searchResults = try await usdaService.searchFoods(query: aiFood.name)
        
        if searchResults.isEmpty {
            // No USDA match found, use AI estimation
            return VerifiedFoodItem(
                originalAISuggestion: aiFood,
                usdaFood: nil,
                finalNutrition: NutritionInfo(
                    calories: Double(aiFood.estimatedCalories),
                    protein: aiFood.estimatedProtein,
                    carbs: aiFood.estimatedCarbs,
                    fat: aiFood.estimatedFat,
                    fiber: 0.0,
                    sodium: 0.0
                ),
                verificationStatus: .aiEstimated,
                confidence: 0.6
            )
        }
        
        // Find best automatic match
        let bestMatch = findBestAutomaticMatch(for: aiFood, in: searchResults)
        
        if let autoMatch = bestMatch, autoMatch.confidence > 0.8 {
            // High confidence automatic match
            let nutrition = try await usdaService.getFoodNutrition(fdcId: autoMatch.food.fdcId)
            let scaledNutrition = scaleNutritionToWeight(nutrition, targetWeight: aiFood.gramWeight)
            
            return VerifiedFoodItem(
                originalAISuggestion: aiFood,
                usdaFood: autoMatch.food,
                finalNutrition: scaledNutrition,
                verificationStatus: .usdaVerified,
                confidence: autoMatch.confidence
            )
        } else {
            // Require manual selection
            return try await requestManualFoodSelection(aiFood: aiFood, options: searchResults)
        }
    }
    
    private func findBestAutomaticMatch(for aiFood: AIFoodSuggestion, in results: [USDAFood]) -> (food: USDAFood, confidence: Double)? {
        var bestMatch: (food: USDAFood, confidence: Double)?
        
        for usdaFood in results {
            let confidence = calculateMatchConfidence(aiFood: aiFood, usdaFood: usdaFood)
            
            if confidence > (bestMatch?.confidence ?? 0) {
                bestMatch = (usdaFood, confidence)
            }
        }
        
        return bestMatch
    }
    
    private func calculateMatchConfidence(aiFood: AIFoodSuggestion, usdaFood: USDAFood) -> Double {
        let nameWords = aiFood.name.lowercased().components(separatedBy: .whitespaces)
        let usdaWords = usdaFood.description.lowercased().components(separatedBy: .whitespaces)
        
        let commonWords = Set(nameWords).intersection(Set(usdaWords))
        let totalWords = Set(nameWords).union(Set(usdaWords))
        
        let wordSimilarity = Double(commonWords.count) / Double(totalWords.count)
        
        // Boost confidence for certain food types
        var confidence = wordSimilarity
        
        if usdaFood.dataType == "Foundation" || usdaFood.dataType == "SR Legacy" {
            confidence += 0.1 // Prefer high-quality USDA data
        }
        
        return min(confidence, 1.0)
    }
    
    private func requestManualFoodSelection(aiFood: AIFoodSuggestion, options: [USDAFood]) async throws -> VerifiedFoodItem {
        return try await withCheckedThrowingContinuation { continuation in
            let selection = ManualFoodSelection(
                originalFood: convertToSuggestedFood(aiFood),
                usdaOptions: options,
                translationInfo: nil,
                confidenceScores: options.map { calculateMatchConfidence(aiFood: aiFood, usdaFood: $0) },
                onSelection: { selectedUSDAFood in
                    Task {
                        do {
                            let verifiedFood: VerifiedFoodItem
                            
                            if let selectedFood = selectedUSDAFood {
                                let nutrition = try await self.usdaService.getFoodNutrition(fdcId: selectedFood.fdcId)
                                let scaledNutrition = self.scaleNutritionToWeight(nutrition, targetWeight: aiFood.gramWeight)
                                
                                verifiedFood = VerifiedFoodItem(
                                    originalAISuggestion: aiFood,
                                    usdaFood: selectedFood,
                                    finalNutrition: scaledNutrition,
                                    verificationStatus: .manuallyVerified,
                                    confidence: 0.9
                                )
                            } else {
                                // User chose to use AI estimation
                                verifiedFood = VerifiedFoodItem(
                                    originalAISuggestion: aiFood,
                                    usdaFood: nil,
                                    finalNutrition: NutritionInfo(
                                        calories: Double(aiFood.estimatedCalories),
                                        protein: aiFood.estimatedProtein,
                                        carbs: aiFood.estimatedCarbs,
                                        fat: aiFood.estimatedFat,
                                        fiber: 0.0,
                                        sodium: 0.0
                                    ),
                                    verificationStatus: .aiEstimated,
                                    confidence: 0.6
                                )
                            }
                            
                            continuation.resume(returning: verifiedFood)
                        } catch {
                            continuation.resume(throwing: error)
                        }
                    }
                },
                onSkip: {
                    // User skipped, use AI estimation
                    let verifiedFood = VerifiedFoodItem(
                        originalAISuggestion: aiFood,
                        usdaFood: nil,
                        finalNutrition: NutritionInfo(
                            calories: Double(aiFood.estimatedCalories),
                            protein: aiFood.estimatedProtein,
                            carbs: aiFood.estimatedCarbs,
                            fat: aiFood.estimatedFat,
                            fiber: 0.0,
                            sodium: 0.0
                        ),
                        verificationStatus: .skipped,
                        confidence: 0.5
                    )
                    
                    continuation.resume(returning: verifiedFood)
                }
            )
            
            DispatchQueue.main.async {
                self.foodSelectionManager.addFoodForSelection(selection)
            }
        }
    }
    
    private func convertToSuggestedFood(_ aiFood: AIFoodSuggestion) -> SuggestedFood {
        let nutrition = EstimatedNutrition(
            calories: Double(aiFood.estimatedCalories),
            protein: aiFood.estimatedProtein,
            carbs: aiFood.estimatedCarbs,
            fat: aiFood.estimatedFat
        )
        
        return SuggestedFood(
            name: aiFood.name,
            portionDescription: "\(aiFood.gramWeight)g serving",
            gramWeight: Double(aiFood.gramWeight),
            estimatedNutrition: nutrition
        )
    }
    
    private func scaleNutritionToWeight(_ nutrition: NutritionInfo, targetWeight: Int) -> NutritionInfo {
        let scaleFactor = Double(targetWeight) / 100.0 // USDA data is per 100g
        
        return NutritionInfo(
            calories: nutrition.calories * scaleFactor,
            protein: nutrition.protein * scaleFactor,
            carbs: nutrition.carbs * scaleFactor,
            fat: nutrition.fat * scaleFactor,
            fiber: nutrition.fiber * scaleFactor,
            sodium: nutrition.sodium * scaleFactor
        )
    }
    
    // MARK: - Nutrition Calculations
    
    private func calculateFinalNutrition(from verifiedFoods: [VerifiedFoodItem]) -> NutritionInfo {
        let totalCalories = verifiedFoods.reduce(0) { $0 + $1.finalNutrition.calories }
        let totalProtein = verifiedFoods.reduce(0) { $0 + $1.finalNutrition.protein }
        let totalCarbs = verifiedFoods.reduce(0) { $0 + $1.finalNutrition.carbs }
        let totalFat = verifiedFoods.reduce(0) { $0 + $1.finalNutrition.fat }
        let totalFiber = verifiedFoods.reduce(0) { $0 + $1.finalNutrition.fiber }
        let totalSodium = verifiedFoods.reduce(0) { $0 + $1.finalNutrition.sodium }
        
        return NutritionInfo(
            calories: totalCalories,
            protein: totalProtein,
            carbs: totalCarbs,
            fat: totalFat,
            fiber: totalFiber,
            sodium: totalSodium
        )
    }
    
    private func calculateVerificationAccuracy(_ verifiedFoods: [VerifiedFoodItem]) -> Double {
        guard !verifiedFoods.isEmpty else { return 0.0 }
        
        let totalConfidence = verifiedFoods.reduce(0) { $0 + $1.confidence }
        return totalConfidence / Double(verifiedFoods.count)
    }
    
    @MainActor
    private func updateProgress(_ progress: Double, _ status: String) {
        generationProgress = progress
        print("Meal Generation: \(status) (\(Int(progress * 100))%)")
    }
    
    // MARK: - Type Conversion Functions
    
    private func convertMealSuggestionToSuggestedFood(_ mealSuggestion: MealSuggestion) -> SuggestedFood {
        // Take the first food item as the representative suggestion
        guard let firstFood = mealSuggestion.suggestedFoods.first else {
            return SuggestedFood(
                name: mealSuggestion.name,
                portionDescription: "100g serving",
                gramWeight: 100.0,
                estimatedNutrition: EstimatedNutrition(
                    calories: Double(mealSuggestion.targetCalories),
                    protein: 0,
                    carbs: 0,
                    fat: 0
                )
            )
        }
        
        return SuggestedFood(
            name: mealSuggestion.name,
            portionDescription: "\(firstFood.gramWeight)g serving",
            gramWeight: Double(firstFood.gramWeight),
            estimatedNutrition: EstimatedNutrition(
                calories: Double(firstFood.estimatedCalories),
                protein: firstFood.estimatedProtein,
                carbs: firstFood.estimatedCarbs,
                fat: firstFood.estimatedFat
            )
        )
    }
    
    private func convertToVerifiedFood(_ verifiedItem: VerifiedFoodItem) -> VerifiedFood {
        return VerifiedFood(
            originalAISuggestion: SuggestedFood(
                name: verifiedItem.originalAISuggestion.name,
                portionDescription: "\(verifiedItem.originalAISuggestion.gramWeight)g serving",
                gramWeight: Double(verifiedItem.originalAISuggestion.gramWeight),
                estimatedNutrition: EstimatedNutrition(
                    calories: Double(verifiedItem.originalAISuggestion.estimatedCalories),
                    protein: verifiedItem.originalAISuggestion.estimatedProtein,
                    carbs: verifiedItem.originalAISuggestion.estimatedCarbs,
                    fat: verifiedItem.originalAISuggestion.estimatedFat
                )
            ),
            verifiedNutrition: EstimatedNutrition(
                calories: verifiedItem.finalNutrition.calories,
                protein: verifiedItem.finalNutrition.protein,
                carbs: verifiedItem.finalNutrition.carbs,
                fat: verifiedItem.finalNutrition.fat
            )
        )
    }
    
    // Add missing function that MultiDayMealPlanningService is trying to call
    func generateVerifiedMealPlan(request: MealPlanRequest) async throws -> VerifiedMealPlanSuggestion {
        return try await generateVerifiedMeal(
            for: nil,
            targetCalories: request.targetCalories,
            mealType: request.mealType,
            dietaryRestrictions: request.dietaryRestrictions,
            medicalConditions: request.medicalConditions,
            cuisinePreference: request.cuisinePreference
        )
    }
}

// ==========================================
// SUPPORTING DATA STRUCTURES
// ==========================================

struct MealSuggestion {
    let name: String
    let description: String
    let targetCalories: Int
    let mealType: MealType
    let suggestedFoods: [AIFoodSuggestion]
    let preparationInstructions: String
    let estimatedPrepTime: Int // minutes
    let difficulty: MealDifficulty
}

struct AIFoodSuggestion {
    let name: String
    let gramWeight: Int
    let estimatedCalories: Int
    let estimatedProtein: Double
    let estimatedCarbs: Double
    let estimatedFat: Double
    let category: String
}

struct VerifiedMealPlanSuggestion {
    let originalAISuggestion: SuggestedFood
    let verifiedFoods: [VerifiedFood]
    let verifiedTotalNutrition: NutritionInfo
    let overallAccuracy: Double
}

struct VerifiedFood {
    let originalAISuggestion: SuggestedFood
    let verifiedNutrition: EstimatedNutrition
}

struct VerifiedFoodItem {
    let originalAISuggestion: AIFoodSuggestion
    let usdaFood: USDAFood?
    let finalNutrition: NutritionInfo
    let verificationStatus: FoodVerificationStatus
    let confidence: Double
}

struct FoodVerificationItem: Identifiable {
    let id = UUID()
    let aiSuggestion: AIFoodSuggestion
    let usdaOptions: [USDAFood]
    let onSelection: (USDAFood?) -> Void
    let onSkip: () -> Void
}

struct NutritionInfo {
    let calories: Double
    let protein: Double
    let carbs: Double
    let fat: Double
    let fiber: Double
    let sodium: Double
}

// Note: USDAFood is defined in USDAFoodService.swift to avoid conflicts

enum FoodVerificationStatus {
    case usdaVerified
    case manuallyVerified
    case aiEstimated
    case skipped
}

enum MealDifficulty {
    case easy, medium, hard
}

// ==========================================
// MOCK SERVICES
// ==========================================
// Note: USDAFoodService is defined in USDAFoodService.swift to avoid conflicts

class AIFoodSuggestionService {
    static let shared = AIFoodSuggestionService()
    
    private init() {}
    
    // Mock AI service methods would go here
}
