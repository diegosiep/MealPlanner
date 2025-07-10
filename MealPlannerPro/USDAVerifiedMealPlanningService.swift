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
            
            let verifiedFood = try await verifyFoodWithUSDAEnhanced(aiFood: aiFood)
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
    
    // MARK: - Enhanced Food Verification with Ingredient Separation
    private func verifyFoodWithUSDAEnhanced(aiFood: SuggestedFood) async throws -> VerifiedSuggestedFood {
        // Step 1: Check if this is a compound food that needs separation
        let separatedIngredients = separateCompoundFood(aiFood)
        
        if separatedIngredients.count > 1 {
            // Handle compound foods by verifying each ingredient separately
            return try await verifyCompoundFood(aiFood: aiFood, ingredients: separatedIngredients)
        } else {
            // Handle single ingredient foods with enhanced matching
            return try await verifySingleIngredient(aiFood: aiFood)
        }
    }
    
    // MARK: - Compound Food Verification
    private func verifyCompoundFood(aiFood: SuggestedFood, ingredients: [SuggestedFood]) async throws -> VerifiedSuggestedFood {
        var verifiedIngredients: [VerifiedSuggestedFood] = []
        var totalNutrition = EstimatedNutrition(calories: 0, protein: 0, carbs: 0, fat: 0)
        
        // Verify each separated ingredient
        for ingredient in ingredients {
            let verifiedIngredient = try await verifySingleIngredient(aiFood: ingredient)
            verifiedIngredients.append(verifiedIngredient)
            
            // Accumulate nutrition
            totalNutrition = EstimatedNutrition(
                calories: totalNutrition.calories + verifiedIngredient.verifiedNutrition.calories,
                protein: totalNutrition.protein + verifiedIngredient.verifiedNutrition.protein,
                carbs: totalNutrition.carbs + verifiedIngredient.verifiedNutrition.carbs,
                fat: totalNutrition.fat + verifiedIngredient.verifiedNutrition.fat
            )
        }
        
        // Calculate overall confidence
        let overallConfidence = verifiedIngredients.reduce(0.0) { $0 + $1.matchConfidence } / Double(verifiedIngredients.count)
        let allVerified = verifiedIngredients.allSatisfy { $0.isVerified }
        
        // Create compound verification notes
        let verificationNotes = """
        Compound food separated into \(ingredients.count) ingredients:
        \(verifiedIngredients.map { "• \($0.originalAISuggestion.name): \($0.isVerified ? "Verified" : "Estimated")" }.joined(separator: "\n"))
        """
        
        return VerifiedSuggestedFood(
            originalAISuggestion: aiFood,
            matchedUSDAFood: nil, // Compound foods don't have single USDA match
            verifiedNutrition: totalNutrition,
            matchConfidence: overallConfidence,
            isVerified: allVerified,
            verificationNotes: verificationNotes
        )
    }
    
    // MARK: - Compound Food Separation
    private func separateCompoundFood(_ aiFood: SuggestedFood) -> [SuggestedFood] {
        let foodName = aiFood.name.lowercased()
        
        // Detect compound foods that should be separated
        let compoundPatterns = [
            "sautéed in": ["base", "oil"],
            "cooked with": ["base", "cooking_method"],
            "grilled with": ["base", "seasonings"],
            "mixed with": ["base", "additions"],
            "served with": ["main", "side"]
        ]
        
        for (pattern, components) in compoundPatterns {
            if foodName.contains(pattern) {
                return separateByPattern(aiFood, pattern: pattern, components: components)
            }
        }
        
        // Check for common compound food indicators
        if isCompoundFood(foodName) {
            return separateCompoundFoodIntelligently(aiFood)
        }
        
        return [aiFood] // Return as single ingredient if no separation needed
    }
    
    // MARK: - Pattern-Based Separation
    private func separateByPattern(_ aiFood: SuggestedFood, pattern: String, components: [String]) -> [SuggestedFood] {
        let foodName = aiFood.name.lowercased()
        let parts = foodName.components(separatedBy: pattern)
        
        guard parts.count >= 2 else { return [aiFood] }
        
        var separatedFoods: [SuggestedFood] = []
        
        // Extract base ingredient
        let baseIngredientName = parts[0].trimmingCharacters(in: .whitespaces)
        let baseWeight = aiFood.gramWeight * 0.85 // Base is 85% of weight
        
        separatedFoods.append(SuggestedFood(
            name: baseIngredientName.capitalized,
            portionDescription: "\(Int(baseWeight))g",
            gramWeight: baseWeight,
            estimatedNutrition: EstimatedNutrition(
                calories: aiFood.estimatedNutrition.calories * 0.8,
                protein: aiFood.estimatedNutrition.protein * 0.9,
                carbs: aiFood.estimatedNutrition.carbs * 0.9,
                fat: aiFood.estimatedNutrition.fat * 0.3
            )
        ))
        
        // Add cooking medium (oil, etc.) if appropriate
        if pattern.contains("sautéed") || pattern.contains("cooked") || pattern.contains("grilled") {
            let oilWeight = aiFood.gramWeight * 0.15 // Oil is 15% of weight
            
            separatedFoods.append(SuggestedFood(
                name: "Oil, olive, salad or cooking",
                portionDescription: "\(Int(oilWeight))g",
                gramWeight: oilWeight,
                estimatedNutrition: EstimatedNutrition(
                    calories: aiFood.estimatedNutrition.calories * 0.2,
                    protein: 0,
                    carbs: 0,
                    fat: aiFood.estimatedNutrition.fat * 0.7
                )
            ))
        }
        
        return separatedFoods
    }
    
    private func isCompoundFood(_ foodName: String) -> Bool {
        let compoundIndicators = [
            "sautéed", "grilled", "cooked in", "with oil", "in sauce",
            "mixed", "seasoned", "marinated", "dressed", "topped with"
        ]
        
        return compoundIndicators.contains { foodName.contains($0) }
    }
    
    private func separateCompoundFoodIntelligently(_ aiFood: SuggestedFood) -> [SuggestedFood] {
        let name = aiFood.name.lowercased()
        var separatedFoods: [SuggestedFood] = []
        
        // Extract base ingredient
        let baseIngredient = extractBaseIngredient(from: name)
        let cookingMethod = extractCookingMethod(from: name)
        let additions = extractAdditions(from: name)
        
        // Create base ingredient (80% of weight and calories)
        let baseWeight = aiFood.gramWeight * 0.8
        let baseCalories = aiFood.estimatedNutrition.calories * 0.8
        
        separatedFoods.append(SuggestedFood(
            name: baseIngredient,
            portionDescription: "\(Int(baseWeight))g",
            gramWeight: baseWeight,
            estimatedNutrition: EstimatedNutrition(
                calories: baseCalories,
                protein: aiFood.estimatedNutrition.protein * 0.8,
                carbs: aiFood.estimatedNutrition.carbs * 0.8,
                fat: aiFood.estimatedNutrition.fat * 0.3 // Less fat in base ingredient
            )
        ))
        
        // Add cooking oil if sautéed or fried (20% of weight and calories)
        if cookingMethod.contains("sautéed") || cookingMethod.contains("fried") {
            let oilWeight = aiFood.gramWeight * 0.2
            let oilCalories = aiFood.estimatedNutrition.calories * 0.2
            
            separatedFoods.append(SuggestedFood(
                name: "Oil, olive, salad or cooking",
                portionDescription: "\(Int(oilWeight))g",
                gramWeight: oilWeight,
                estimatedNutrition: EstimatedNutrition(
                    calories: oilCalories,
                    protein: 0,
                    carbs: 0,
                    fat: aiFood.estimatedNutrition.fat * 0.7 // Most fat comes from oil
                )
            ))
        }
        
        // Add other additions if detected
        for addition in additions {
            let additionWeight = aiFood.gramWeight * 0.1
            separatedFoods.append(SuggestedFood(
                name: addition,
                portionDescription: "\(Int(additionWeight))g",
                gramWeight: additionWeight,
                estimatedNutrition: EstimatedNutrition(calories: 10, protein: 0, carbs: 2, fat: 0)
            ))
        }
        
        return separatedFoods
    }
    
    private func extractBaseIngredient(from name: String) -> String {
        // Extract the main ingredient name
        let ingredients = ["chicken", "salmon", "spinach", "broccoli", "rice", "quinoa", "beef", "turkey", "cod", "tuna"]
        
        for ingredient in ingredients {
            if name.contains(ingredient) {
                return "\(ingredient.capitalized), raw" // Format for USDA compatibility
            }
        }
        
        // Fallback: take first part before comma or "in"/"with"
        if let firstPart = name.components(separatedBy: CharacterSet(charactersIn: ",")).first {
            return firstPart.trimmingCharacters(in: .whitespaces).capitalized
        }
        
        return name.capitalized
    }
    
    private func extractCookingMethod(from name: String) -> String {
        let methods = ["sautéed", "grilled", "baked", "fried", "steamed", "boiled", "roasted"]
        
        for method in methods {
            if name.contains(method) {
                return method
            }
        }
        
        return "cooked"
    }
    
    private func extractAdditions(from name: String) -> [String] {
        var additions: [String] = []
        
        if name.contains("olive oil") {
            additions.append("Oil, olive, salad or cooking")
        }
        if name.contains("garlic") {
            additions.append("Garlic, raw")
        }
        if name.contains("herbs") {
            additions.append("Herbs, fresh, mixed")
        }
        if name.contains("lemon") {
            additions.append("Lemon juice, raw")
        }
        
        return additions
    }
    
    // MARK: - Enhanced Single Ingredient Verification
    private func verifySingleIngredient(aiFood: SuggestedFood) async throws -> VerifiedSuggestedFood {
        // Enhanced search with multiple strategies
        var searchResults: [USDAFood] = []
        
        // Strategy 1: Direct name search
        searchResults = try await usdaService.searchFoods(query: aiFood.name)
        
        // Strategy 2: If no results, try simplified name
        if searchResults.isEmpty {
            let simplifiedName = simplifyFoodName(aiFood.name)
            searchResults = try await usdaService.searchFoods(query: simplifiedName)
        }
        
        // Strategy 3: If still no results, try generic category
        if searchResults.isEmpty {
            let category = categorizeFoodForSearch(aiFood.name)
            searchResults = try await usdaService.searchFoods(query: category)
        }
        
        // Find best match using enhanced algorithm
        if let usdaFood = findBestMatchEnhanced(aiFood: aiFood, usdaResults: searchResults) {
            print("✅ Enhanced USDA match: \(usdaFood.description)")
            
            let adjustedPortion = calculateUSDAPortionNutrition(
                usdaFood: usdaFood,
                targetWeight: aiFood.gramWeight
            )
            
            return VerifiedSuggestedFood(
                originalAISuggestion: aiFood,
                matchedUSDAFood: usdaFood,
                verifiedNutrition: adjustedPortion,
                matchConfidence: calculateEnhancedMatchConfidence(aiFood: aiFood, usdaFood: usdaFood),
                isVerified: true,
                verificationNotes: "Enhanced verification: \(usdaFood.description)"
            )
        } else {
            print("⚠️ No enhanced USDA match for: \(aiFood.name)")
            return VerifiedSuggestedFood(
                originalAISuggestion: aiFood,
                matchedUSDAFood: nil,
                verifiedNutrition: aiFood.estimatedNutrition,
                matchConfidence: 0.0,
                isVerified: false,
                verificationNotes: "Could not verify with enhanced USDA search"
            )
        }
    }
    
    private func simplifyFoodName(_ name: String) -> String {
        // Remove cooking methods and preparations
        let unwantedWords = ["grilled", "baked", "sautéed", "cooked", "fresh", "organic", "in", "with", "oil"]
        var simplified = name.lowercased()
        
        for word in unwantedWords {
            simplified = simplified.replacingOccurrences(of: word, with: "")
        }
        
        return simplified.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func categorizeFoodForSearch(_ name: String) -> String {
        let lowerName = name.lowercased()
        
        if lowerName.contains("chicken") { return "chicken breast" }
        if lowerName.contains("salmon") { return "salmon" }
        if lowerName.contains("spinach") { return "spinach" }
        if lowerName.contains("broccoli") { return "broccoli" }
        if lowerName.contains("rice") { return "rice brown" }
        if lowerName.contains("quinoa") { return "quinoa" }
        
        return "food" // Generic fallback
    }
    
    private func findBestMatchEnhanced(aiFood: SuggestedFood, usdaResults: [USDAFood]) -> USDAFood? {
        guard !usdaResults.isEmpty else { return nil }
        
        var bestMatch: USDAFood?
        var bestScore = 0.0
        
        for usdaFood in usdaResults {
            let score = calculateEnhancedSimilarityScore(aiFood: aiFood, usdaFood: usdaFood)
            
            if score > bestScore {
                bestScore = score
                bestMatch = usdaFood
            }
        }
        
        // Higher threshold for enhanced matching
        return bestScore > 0.7 ? bestMatch : nil
    }
    
    private func calculateEnhancedSimilarityScore(aiFood: SuggestedFood, usdaFood: USDAFood) -> Double {
        let nameScore = calculateNameSimilarity(
            aiName: aiFood.name.lowercased(),
            usdaName: usdaFood.description.lowercased()
        )
        
        let calorieScore = calculateNutritionSimilarity(
            aiValue: aiFood.estimatedNutrition.calories,
            usdaValue: usdaFood.calories
        )
        
        let proteinScore = calculateNutritionSimilarity(
            aiValue: aiFood.estimatedNutrition.protein,
            usdaValue: usdaFood.protein
        )
        
        // Weighted combination with name being most important
        return (nameScore * 0.5) + (calorieScore * 0.3) + (proteinScore * 0.2)
    }
    
    private func calculateNutritionSimilarity(aiValue: Double, usdaValue: Double) -> Double {
        guard aiValue > 0 && usdaValue > 0 else { return 0.0 }
        
        let ratio = min(aiValue, usdaValue) / max(aiValue, usdaValue)
        return ratio
    }
    
    private func calculateEnhancedMatchConfidence(aiFood: SuggestedFood, usdaFood: USDAFood) -> Double {
        return calculateEnhancedSimilarityScore(aiFood: aiFood, usdaFood: usdaFood)
    }
    
    // MARK: - Basic Helper Functions
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
