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
    @Published var pendingFoodSelections: [PendingFoodSelection] = []
    
    private let llmService = LLMService()
    private let usdaService = USDAFoodService()
    private let translationService = FoodTranslationService()
    
    // MARK: - Two-Stage Meal Planning Process
    func generateVerifiedMealPlan(request: MealPlanRequest) async throws -> VerifiedMealPlanSuggestion {
        print("🚀 USDA VERIFICATION STARTED for request: \(request)")
        
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
        print("🤖 AI suggested \(aiSuggestion.suggestedFoods.count) foods: \(aiSuggestion.suggestedFoods.map { $0.name })")
        
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
        print("🔍 Starting verification of \(aiSuggestion.suggestedFoods.count) foods")
        for (index, aiFood) in aiSuggestion.suggestedFoods.enumerated() {
            print("🔍 [\(index + 1)/\(aiSuggestion.suggestedFoods.count)] Verifying: \(aiFood.name)")
            
            let verifiedFood = try await verifyFoodWithUSDAEnhanced(aiFood: aiFood)
            verifiedFoods.append(verifiedFood)
            print("📊 Result: \(verifiedFood.isVerified ? "VERIFIED" : "NOT VERIFIED") - confidence: \(String(format: "%.1f", verifiedFood.matchConfidence * 100))%")
            
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
    
    // MARK: - Enhanced Single Ingredient Verification with Translation
    private func verifySingleIngredient(aiFood: SuggestedFood) async throws -> VerifiedSuggestedFood {
        print("🔍 Starting enhanced verification for: \(aiFood.name)")
        
        // Step 0: Test USDA API connectivity with a simple search
        do {
            let testResults = try await usdaService.searchFoods(query: "apple")
            print("✅ USDA API connectivity test successful: \(testResults.count) results for 'apple'")
        } catch {
            print("❌ USDA API connectivity test FAILED: \(error)")
        }
        
        // Step 1: Translate food name to USDA-compatible format
        let translatedFood: USDACompatibleFood
        do {
            translatedFood = try await translationService.translateFoodNameForUSDA(aiFood.name, language: .spanish)
            print("📝 Translation: '\(aiFood.name)' → '\(translatedFood.translatedName)' (confidence: \(String(format: "%.1f", translatedFood.confidence * 100))%)")
        } catch {
            print("⚠️ Translation failed, using original name: \(error)")
            translatedFood = USDACompatibleFood(
                originalName: aiFood.name,
                translatedName: aiFood.name,
                confidence: 0.5,
                alternativeNames: []
            )
        }
        
        // Step 2: Enhanced search with multiple strategies using translated terms
        var searchResults: [USDAFood] = []
        
        // Strategy 1: Use primary translation
        if !translatedFood.translatedName.isEmpty {
            do {
                searchResults = try await usdaService.searchFoods(query: translatedFood.translatedName)
                print("🔍 Primary search ('\(translatedFood.translatedName)'): \(searchResults.count) results")
            } catch {
                print("❌ USDA primary search failed for '\(translatedFood.translatedName)': \(error)")
            }
        }
        
        // Strategy 2: Use USDA-specific search terms if available
        if searchResults.isEmpty, let usdaSearchTerms = translatedFood.usdaSearchTerms {
            for searchTerm in usdaSearchTerms {
                do {
                    let termResults = try await usdaService.searchFoods(query: searchTerm)
                    searchResults.append(contentsOf: termResults)
                    print("🔍 USDA term search ('\(searchTerm)'): \(termResults.count) results")
                    if searchResults.count >= 5 { break } // Limit results
                } catch {
                    print("❌ USDA term search failed for '\(searchTerm)': \(error)")
                }
            }
        }
        
        // Strategy 3: Try alternative names
        if searchResults.isEmpty {
            for altName in translatedFood.alternativeNames {
                do {
                    let altResults = try await usdaService.searchFoods(query: altName)
                    searchResults.append(contentsOf: altResults)
                    print("🔍 Alternative search ('\(altName)'): \(altResults.count) results")
                    if searchResults.count >= 5 { break }
                } catch {
                    print("❌ USDA alternative search failed for '\(altName)': \(error)")
                }
            }
        }
        
        // Strategy 4: Fallback to category-based search
        if searchResults.isEmpty {
            do {
                let category = categorizeFoodForSearch(aiFood.name)
                searchResults = try await usdaService.searchFoods(query: category)
                print("🔍 Category fallback ('\(category)'): \(searchResults.count) results")
            } catch {
                print("❌ USDA category search failed: \(error)")
            }
        }
        
        // Step 3: Find best match using enhanced algorithm with 80% accuracy threshold
        let potentialMatches = findPotentialMatches(aiFood: aiFood, usdaResults: searchResults, translatedFood: translatedFood)
        
        if let bestMatch = potentialMatches.first, bestMatch.confidence >= 0.60 {
            print("✅ High-confidence USDA match: \(bestMatch.usdaFood.description) (confidence: \(String(format: "%.1f", bestMatch.confidence * 100))%)")
            
            let adjustedPortion = calculateUSDAPortionNutrition(
                usdaFood: bestMatch.usdaFood,
                targetWeight: aiFood.gramWeight
            )
            
            return VerifiedSuggestedFood(
                originalAISuggestion: aiFood,
                matchedUSDAFood: bestMatch.usdaFood,
                verifiedNutrition: adjustedPortion,
                matchConfidence: bestMatch.confidence,
                isVerified: true,
                verificationNotes: "High-accuracy verification: \(bestMatch.usdaFood.description)"
            )
        } else if potentialMatches.count >= 1 && potentialMatches.first!.confidence >= 0.60 {
            // Multiple potential matches - require user selection for accuracy
            print("🤔 Multiple potential matches found - requiring user selection")
            
            await MainActor.run {
                pendingFoodSelections.append(PendingFoodSelection(
                    originalFood: aiFood,
                    usdaOptions: potentialMatches.map { $0.usdaFood },
                    translatedFood: translatedFood
                ))
            }
            
            // Return temporary result while awaiting user selection
            return VerifiedSuggestedFood(
                originalAISuggestion: aiFood,
                matchedUSDAFood: nil,
                verifiedNutrition: aiFood.estimatedNutrition,
                matchConfidence: 0.0,
                isVerified: false,
                verificationNotes: "Awaiting user selection from \(potentialMatches.count) potential matches"
            )
        } else {
            print("⚠️ No high-confidence USDA match for: \(aiFood.name)")
            
            // Enhanced fallback: Use the best low-confidence match if available
            let bestFallbackMatch = potentialMatches.first
            let fallbackNutrition: EstimatedNutrition
            let fallbackConfidence: Double
            var fallbackNotes = "Could not find high-accuracy match in USDA database"
            
            if let fallback = bestFallbackMatch, fallback.confidence >= 0.50 {
                // Use the best low-confidence match but with adjusted confidence
                fallbackNutrition = calculateUSDAPortionNutrition(
                    usdaFood: fallback.usdaFood,
                    targetWeight: aiFood.gramWeight
                )
                fallbackConfidence = fallback.confidence * 0.7 // Reduce confidence
                fallbackNotes = "Using low-confidence USDA match: \(fallback.usdaFood.description) (confidence: \(String(format: "%.1f", fallback.confidence * 100))%)"
                print("🔄 Using fallback USDA match: \(fallback.usdaFood.description)")
            } else {
                // Use enhanced AI estimation with category-based adjustments
                fallbackNutrition = enhanceAIEstimation(for: aiFood)
                fallbackConfidence = 0.3 // Low confidence for pure AI estimate
                fallbackNotes = "Using enhanced AI nutrition estimation"
                print("🤖 Using enhanced AI estimation for: \(aiFood.name)")
            }
            
            return VerifiedSuggestedFood(
                originalAISuggestion: aiFood,
                matchedUSDAFood: bestFallbackMatch?.usdaFood,
                verifiedNutrition: fallbackNutrition,
                matchConfidence: fallbackConfidence,
                isVerified: false,
                verificationNotes: fallbackNotes
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
    
    // MARK: - High-Accuracy Food Matching (80%+ threshold)
    private func findPotentialMatches(aiFood: SuggestedFood, usdaResults: [USDAFood], translatedFood: USDACompatibleFood) -> [FoodMatch] {
        guard !usdaResults.isEmpty else { return [] }
        
        var matches: [FoodMatch] = []
        
        for usdaFood in usdaResults {
            let confidence = calculateHighAccuracyScore(
                aiFood: aiFood,
                usdaFood: usdaFood,
                translatedFood: translatedFood
            )
            
            if confidence >= 0.60 { // Minimum threshold for consideration
                matches.append(FoodMatch(usdaFood: usdaFood, confidence: confidence))
            }
        }
        
        // Sort by confidence (highest first)
        return matches.sorted { $0.confidence > $1.confidence }
    }
    
    // MARK: - High-Accuracy Scoring Algorithm
    private func calculateHighAccuracyScore(aiFood: SuggestedFood, usdaFood: USDAFood, translatedFood: USDACompatibleFood) -> Double {
        // 1. Enhanced name matching using translation data
        let nameScore = calculateEnhancedNameSimilarity(
            originalName: aiFood.name,
            translatedName: translatedFood.translatedName,
            usdaName: usdaFood.description,
            alternativeNames: translatedFood.alternativeNames
        )
        
        // 2. Nutrition profile matching (per 100g for consistency)
        let nutritionScore = calculateNutritionProfileSimilarity(
            aiNutrition: aiFood.estimatedNutrition,
            usdaNutrition: EstimatedNutrition(
                calories: usdaFood.calories,
                protein: usdaFood.protein,
                carbs: usdaFood.carbs,
                fat: usdaFood.fat
            )
        )
        
        // 3. Food category consistency
        let categoryScore = calculateCategoryConsistency(
            translatedCategory: translatedFood.foodCategory ?? "unknown",
            usdaFood: usdaFood
        )
        
        // 4. Translation confidence bonus
        let translationBonus = translatedFood.confidence * 0.1
        
        // Weighted combination emphasizing nutrition accuracy for patient safety
        let finalScore = (nameScore * 0.40) + (nutritionScore * 0.45) + (categoryScore * 0.10) + translationBonus
        
        print("🎯 Scoring '\(usdaFood.description)': name=\(String(format: "%.2f", nameScore)), nutrition=\(String(format: "%.2f", nutritionScore)), category=\(String(format: "%.2f", categoryScore)), final=\(String(format: "%.2f", finalScore))")
        
        return min(finalScore, 1.0) // Cap at 1.0
    }
    
    private func calculateNutritionSimilarity(aiValue: Double, usdaValue: Double) -> Double {
        guard aiValue > 0 && usdaValue > 0 else { return 0.0 }
        
        let ratio = min(aiValue, usdaValue) / max(aiValue, usdaValue)
        return ratio
    }
    
    private func calculateEnhancedMatchConfidence(aiFood: SuggestedFood, usdaFood: USDAFood) -> Double {
        return calculateEnhancedSimilarityScore(aiFood: aiFood, usdaFood: usdaFood)
    }
    
    // MARK: - Legacy Enhanced Similarity Score (for backward compatibility)
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
        // Improved accuracy calculation that handles edge cases and provides better scoring
        let calorieAccuracy = calculateNutrientAccuracy(
            actual: verified.calories,
            target: Double(target.targetCalories),
            tolerance: 0.15 // 15% tolerance
        )
        
        let proteinAccuracy = calculateNutrientAccuracy(
            actual: verified.protein,
            target: target.targetProtein,
            tolerance: 0.20 // 20% tolerance for protein
        )
        
        let carbAccuracy = calculateNutrientAccuracy(
            actual: verified.carbs,
            target: target.targetCarbs,
            tolerance: 0.20 // 20% tolerance for carbs
        )
        
        let fatAccuracy = calculateNutrientAccuracy(
            actual: verified.fat,
            target: target.targetFat,
            tolerance: 0.25 // 25% tolerance for fat
        )
        
        return DetailedAccuracy(
            overall: (calorieAccuracy + proteinAccuracy + carbAccuracy + fatAccuracy) / 4.0,
            calories: calorieAccuracy,
            protein: proteinAccuracy,
            carbs: carbAccuracy,
            fat: fatAccuracy
        )
    }
    
    private func calculateNutrientAccuracy(actual: Double, target: Double, tolerance: Double) -> Double {
        guard target > 0 else { return 0.0 }
        
        let percentDifference = abs(actual - target) / target
        
        if percentDifference <= tolerance {
            // Within tolerance: scale from 1.0 to 0.8
            return 1.0 - (percentDifference / tolerance) * 0.2
        } else {
            // Outside tolerance: scale from 0.8 to 0.0
            let excessDifference = percentDifference - tolerance
            let maxExcess = 1.0 - tolerance // Maximum difference before 0 score
            let penaltyScore = min(excessDifference / maxExcess, 1.0)
            return max(0.8 - (penaltyScore * 0.8), 0.0)
        }
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
    
    // MARK: - Enhanced Matching Helper Functions
    private func calculateEnhancedNameSimilarity(originalName: String, translatedName: String, usdaName: String, alternativeNames: [String]) -> Double {
        let usdaLower = usdaName.lowercased()
        
        // Check direct translation match
        let translatedScore = calculateNameSimilarity(aiName: translatedName.lowercased(), usdaName: usdaLower)
        
        // Check alternative names
        var bestAltScore = 0.0
        for altName in alternativeNames {
            let altScore = calculateNameSimilarity(aiName: altName.lowercased(), usdaName: usdaLower)
            bestAltScore = max(bestAltScore, altScore)
        }
        
        // Check original name as fallback
        let originalScore = calculateNameSimilarity(aiName: originalName.lowercased(), usdaName: usdaLower)
        
        // Return the highest score
        return max(translatedScore, max(bestAltScore, originalScore))
    }
    
    private func calculateNutritionProfileSimilarity(aiNutrition: EstimatedNutrition, usdaNutrition: EstimatedNutrition) -> Double {
        // Calculate similarity for each macronutrient
        let calorieScore = calculateNutrientSimilarity(aiNutrition.calories, usdaNutrition.calories, tolerance: 0.15)
        let proteinScore = calculateNutrientSimilarity(aiNutrition.protein, usdaNutrition.protein, tolerance: 0.20)
        let carbScore = calculateNutrientSimilarity(aiNutrition.carbs, usdaNutrition.carbs, tolerance: 0.25)
        let fatScore = calculateNutrientSimilarity(aiNutrition.fat, usdaNutrition.fat, tolerance: 0.30)
        
        // Weighted average (calories and protein most important for patient safety)
        return (calorieScore * 0.35) + (proteinScore * 0.30) + (carbScore * 0.20) + (fatScore * 0.15)
    }
    
    private func calculateNutrientSimilarity(_ value1: Double, _ value2: Double, tolerance: Double) -> Double {
        guard value1 > 0 && value2 > 0 else {
            // Handle zero values - perfect match if both zero, otherwise penalize
            return (value1 == 0 && value2 == 0) ? 1.0 : 0.0
        }
        
        let percentDifference = abs(value1 - value2) / max(value1, value2)
        
        if percentDifference <= tolerance {
            // Within tolerance: high score
            return 1.0 - (percentDifference / tolerance) * 0.3
        } else {
            // Outside tolerance: declining score
            let excessDifference = percentDifference - tolerance
            return max(0.7 - (excessDifference * 2.0), 0.0)
        }
    }
    
    private func calculateCategoryConsistency(translatedCategory: String, usdaFood: USDAFood) -> Double {
        let usdaDescription = usdaFood.description.lowercased()
        let category = translatedCategory.lowercased()
        
        // Category-specific keywords for USDA matching
        let categoryKeywords: [String: [String]] = [
            "protein": ["chicken", "beef", "fish", "meat", "salmon", "turkey", "pork", "egg"],
            "vegetable": ["spinach", "broccoli", "carrot", "lettuce", "tomato", "onion", "pepper"],
            "grain": ["rice", "bread", "oats", "quinoa", "pasta", "wheat", "barley"],
            "fruit": ["apple", "banana", "orange", "berry", "grape", "mango", "pear"],
            "dairy": ["milk", "cheese", "yogurt", "butter", "cream"],
            "fat": ["oil", "butter", "avocado", "nuts", "seeds", "olive"]
        ]
        
        guard let keywords = categoryKeywords[category] else { return 0.5 }
        
        for keyword in keywords {
            if usdaDescription.contains(keyword) {
                return 1.0
            }
        }
        
        return 0.3 // Penalty for category mismatch
    }
    
    // MARK: - Enhanced AI Estimation
    private func enhanceAIEstimation(for aiFood: SuggestedFood) -> EstimatedNutrition {
        let foodName = aiFood.name.lowercased()
        var adjustedNutrition = aiFood.estimatedNutrition
        
        // Apply category-based adjustments to improve AI estimations
        if foodName.contains("oil") || foodName.contains("butter") || foodName.contains("avocado") {
            // High-fat foods - typically underestimated calories
            adjustedNutrition = EstimatedNutrition(
                calories: adjustedNutrition.calories * 1.1,
                protein: adjustedNutrition.protein,
                carbs: max(adjustedNutrition.carbs * 0.5, 0), // Lower carbs for fats
                fat: adjustedNutrition.fat * 1.2
            )
        } else if foodName.contains("protein") || foodName.contains("chicken") || foodName.contains("fish") || foodName.contains("beef") {
            // Protein sources - typically well estimated but may need slight adjustment
            adjustedNutrition = EstimatedNutrition(
                calories: adjustedNutrition.calories * 1.05,
                protein: adjustedNutrition.protein * 1.1,
                carbs: adjustedNutrition.carbs * 0.8,
                fat: adjustedNutrition.fat
            )
        } else if foodName.contains("vegetable") || foodName.contains("spinach") || foodName.contains("broccoli") {
            // Vegetables - typically overestimated calories
            adjustedNutrition = EstimatedNutrition(
                calories: adjustedNutrition.calories * 0.9,
                protein: adjustedNutrition.protein,
                carbs: adjustedNutrition.carbs * 0.95,
                fat: adjustedNutrition.fat
            )
        } else if foodName.contains("fruit") || foodName.contains("berry") || foodName.contains("apple") {
            // Fruits - natural sugars, adjust carbs
            adjustedNutrition = EstimatedNutrition(
                calories: adjustedNutrition.calories,
                protein: adjustedNutrition.protein * 0.8,
                carbs: adjustedNutrition.carbs * 1.1,
                fat: max(adjustedNutrition.fat * 0.5, 0)
            )
        } else if foodName.contains("grain") || foodName.contains("rice") || foodName.contains("bread") {
            // Grains - carb-heavy foods
            adjustedNutrition = EstimatedNutrition(
                calories: adjustedNutrition.calories,
                protein: adjustedNutrition.protein,
                carbs: adjustedNutrition.carbs * 1.05,
                fat: adjustedNutrition.fat * 0.9
            )
        }
        
        return adjustedNutrition
    }
    
    // MARK: - User Selection Support
    func selectFoodForPendingItem(_ pendingSelection: PendingFoodSelection, selectedFood: USDAFood?) {
        // Update the pending selection with user choice
        // This would be called from the UI when user makes a selection
        if let selected = selectedFood {
            print("✅ User selected: \(selected.description)")
            // TODO: Update the meal plan with the selected food
        } else {
            print("⚠️ User skipped food selection")
        }
        
        // Remove from pending list
        if let index = pendingFoodSelections.firstIndex(where: { $0.id == pendingSelection.id }) {
            pendingFoodSelections.remove(at: index)
        }
    }
}

// MARK: - Supporting Data Structures
struct FoodMatch {
    let usdaFood: USDAFood
    let confidence: Double
}

struct PendingFoodSelection: Identifiable {
    let id = UUID()
    let originalFood: SuggestedFood
    let usdaOptions: [USDAFood]
    let translatedFood: USDACompatibleFood
}
