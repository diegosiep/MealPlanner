//
//  USDAVerifiedMealPlanningService.swift
//  MealPlannerPro
//
//  Created by Diego Sierra on [current date]
//

import Foundation

// MARK: - Enhanced Meal Planning Service with USDA Verification
class USDAVerifiedMealPlanningService: ObservableObject {
    @Published var isGenerating = false
    @Published var isVerifying = false
    @Published var lastError: String?
    
    private let llmService = LLMService()
    private let usdaService = USDAFoodService()
    
    // MARK: - Two-Stage Meal Planning Process
    func generateVerifiedMealPlan(request: MealPlanRequest) async throws -> VerifiedMealPlanSuggestion {
        await MainActor.run {
            isGenerating = true
            lastError = nil
        }
        
        defer {
            Task { @MainActor in
                isGenerating = false
                isVerifying = false
            }
        }
        
        // Stage 1: Get AI meal plan suggestion
        print("🤖 Stage 1: Getting AI meal plan suggestion...")
        let aiSuggestion = try await llmService.generateMealPlan(request: request)
        
        // Stage 2: Verify and correct using USDA data
        await MainActor.run { isVerifying = true }
        print("🔍 Stage 2: Verifying with USDA database...")
        let verifiedSuggestion = try await verifyWithUSDA(aiSuggestion: aiSuggestion, originalRequest: request)
        
        print("✅ Generated verified meal plan with \(String(format: "%.1f", verifiedSuggestion.overallAccuracy * 100))% accuracy")
        
        return verifiedSuggestion
    }
    
    // MARK: - USDA Verification Process
    private func verifyWithUSDA(aiSuggestion: MealPlanSuggestion, originalRequest: MealPlanRequest) async throws -> VerifiedMealPlanSuggestion {
        var verifiedFoods: [VerifiedSuggestedFood] = []
        var totalVerifiedNutrition = EstimatedNutrition(calories: 0, protein: 0, carbs: 0, fat: 0)
        
        // Process each AI-suggested food
        for aiFood in aiSuggestion.suggestedFoods {
            print("🔍 Verifying: \(aiFood.name)")
            
            let verifiedFood = try await verifyFoodWithUSDA(aiFood: aiFood)
            verifiedFoods.append(verifiedFood)
            
            // Add to totals (create new instance instead of mutating)
            totalVerifiedNutrition = EstimatedNutrition(
                calories: totalVerifiedNutrition.calories + verifiedFood.verifiedNutrition.calories,
                protein: totalVerifiedNutrition.protein + verifiedFood.verifiedNutrition.protein,
                carbs: totalVerifiedNutrition.carbs + verifiedFood.verifiedNutrition.carbs,
                fat: totalVerifiedNutrition.fat + verifiedFood.verifiedNutrition.fat
            )
        }
        
        // Calculate accuracy scores
        let accuracyScore = calculateAccuracy(
            verified: totalVerifiedNutrition,
            target: originalRequest
        )
        
        return VerifiedMealPlanSuggestion(
            originalAISuggestion: aiSuggestion,
            verifiedFoods: verifiedFoods,
            verifiedTotalNutrition: totalVerifiedNutrition,
            overallAccuracy: accuracyScore.overall,
            detailedAccuracy: accuracyScore,
            verificationNotes: generateVerificationNotes(verifiedFoods: verifiedFoods, accuracy: accuracyScore)
        )
    }
    
    // MARK: - Individual Food Verification
    private func verifyFoodWithUSDA(aiFood: SuggestedFood) async throws -> VerifiedSuggestedFood {
        // Search USDA database for the suggested food
        let searchResults = try await usdaService.searchFoods(query: aiFood.name)
        
        // Find the best matching food
        let bestMatch = findBestMatch(aiFood: aiFood, usdaResults: searchResults)
        
        if let usdaFood = bestMatch {
            print("✅ Found USDA match: \(usdaFood.description)")
            
            // Calculate nutrition for the AI-suggested portion using USDA data
            let adjustedPortion = calculateUSDAPortionNutrition(
                usdaFood: usdaFood,
                targetWeight: aiFood.gramWeight
            )
            
            return VerifiedSuggestedFood(
                originalAISuggestion: aiFood,
                matchedUSDAFood: usdaFood,
                verifiedNutrition: adjustedPortion,
                matchConfidence: calculateMatchConfidence(aiFood: aiFood, usdaFood: usdaFood),
                isVerified: true,
                verificationNotes: "Verified with USDA database: \(usdaFood.description)"
            )
            
        } else {
            print("⚠️ No USDA match found for: \(aiFood.name)")
            
            // Use AI estimate but mark as unverified
            return VerifiedSuggestedFood(
                originalAISuggestion: aiFood,
                matchedUSDAFood: nil,
                verifiedNutrition: aiFood.estimatedNutrition,
                matchConfidence: 0.0,
                isVerified: false,
                verificationNotes: "Could not verify with USDA database. Using AI estimate."
            )
        }
    }
    
    // MARK: - Food Matching Algorithm
    private func findBestMatch(aiFood: SuggestedFood, usdaResults: [USDAFood]) -> USDAFood? {
        guard !usdaResults.isEmpty else { return nil }
        
        let aiName = aiFood.name.lowercased()
        var bestMatch: USDAFood?
        var bestScore = 0.0
        
        for usdaFood in usdaResults {
            let usdaName = usdaFood.description.lowercased()
            let score = calculateNameSimilarity(aiName: aiName, usdaName: usdaName)
            
            // Boost score for foods with similar calories
            let calorieRatio = abs(usdaFood.calories - aiFood.estimatedNutrition.calories) / max(usdaFood.calories, aiFood.estimatedNutrition.calories)
            let calorieBoost = max(0, 1.0 - calorieRatio) * 0.3
            
            let totalScore = score + calorieBoost
            
            if totalScore > bestScore {
                bestScore = totalScore
                bestMatch = usdaFood
            }
        }
        
        // Only return matches with reasonable confidence
        return bestScore > 0.6 ? bestMatch : nil
    }
    
    // MARK: - Helper Functions
    private func calculateNameSimilarity(aiName: String, usdaName: String) -> Double {
        // Create a character set with whitespaces and common punctuation
        let separators = CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ".,!?;:()[]{}\"'-"))
        
        let aiWords = Set(aiName.components(separatedBy: separators).filter { !$0.isEmpty })
        let usdaWords = Set(usdaName.components(separatedBy: separators).filter { !$0.isEmpty })
        
        let intersection = aiWords.intersection(usdaWords)
        let union = aiWords.union(usdaWords)
        
        return union.isEmpty ? 0.0 : Double(intersection.count) / Double(union.count)
    }
    
    private func calculateUSDAPortionNutrition(usdaFood: USDAFood, targetWeight: Double) -> EstimatedNutrition {
        let multiplier = targetWeight / 100.0 // USDA data is per 100g
        
        return EstimatedNutrition(
            calories: usdaFood.calories * multiplier,
            protein: usdaFood.protein * multiplier,
            carbs: usdaFood.carbs * multiplier,
            fat: usdaFood.fat * multiplier
        )
    }
    
    private func calculateMatchConfidence(aiFood: SuggestedFood, usdaFood: USDAFood) -> Double {
        let nameSimilarity = calculateNameSimilarity(
            aiName: aiFood.name.lowercased(),
            usdaName: usdaFood.description.lowercased()
        )
        
        let calorieAccuracy = 1.0 - abs(usdaFood.calories - aiFood.estimatedNutrition.calories) / max(usdaFood.calories, aiFood.estimatedNutrition.calories)
        
        return (nameSimilarity + calorieAccuracy) / 2.0
    }
    
    private func calculateAccuracy(verified: EstimatedNutrition, target: MealPlanRequest) -> DetailedAccuracy {
        let calorieAccuracy = 1.0 - abs(verified.calories - Double(target.targetCalories)) / Double(target.targetCalories)
        let proteinAccuracy = 1.0 - abs(verified.protein - target.targetProtein) / target.targetProtein
        let carbAccuracy = 1.0 - abs(verified.carbs - target.targetCarbs) / target.targetCarbs
        let fatAccuracy = 1.0 - abs(verified.fat - target.targetFat) / target.targetFat
        
        return DetailedAccuracy(
            overall: (calorieAccuracy + proteinAccuracy + carbAccuracy + fatAccuracy) / 4.0,
            calories: calorieAccuracy,
            protein: proteinAccuracy,
            carbs: carbAccuracy,
            fat: fatAccuracy
        )
    }
    
    private func generateVerificationNotes(verifiedFoods: [VerifiedSuggestedFood], accuracy: DetailedAccuracy) -> String {
        let verifiedCount = verifiedFoods.filter { $0.isVerified }.count
        let totalCount = verifiedFoods.count
        
        var notes = "USDA Verification Results:\n"
        notes += "• \(verifiedCount)/\(totalCount) foods verified with USDA database\n"
        notes += "• Overall accuracy: \(String(format: "%.1f", accuracy.overall * 100))%\n"
        
        if accuracy.overall < 0.8 {
            notes += "• ⚠️ Consider adjusting portions for better target matching\n"
        }
        
        for food in verifiedFoods where !food.isVerified {
            notes += "• ⚠️ Could not verify: \(food.originalAISuggestion.name)\n"
        }
        
        return notes
    }
}
