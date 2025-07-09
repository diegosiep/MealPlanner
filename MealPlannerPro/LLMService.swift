//
//  LLMService.swift
//  MealPlannerPro
//
//  Created by Diego Sierra on 07/07/25.
//

import Foundation
import SwiftUI

// MARK: - AI Meal Planning Service (Updated with Claude)
class LLMService: ObservableObject {
    @Published var isGenerating = false
    @Published var lastError: String?
    
    // Updated provider list with Claude as primary option
    private let providers: [LLMProvider] = [
        ClaudeProvider(),        // ← New! Claude as primary provider
        OpenAIProvider(),        // Backup option (if you have OpenAI key)
        HuggingFaceProvider(),   // Keep as fallback
        MockLLMProvider()        // Always works for testing
    ]
    
    // MARK: - Main Meal Planning Function (Enhanced for Claude)
    func generateMealPlan(request: MealPlanRequest) async throws -> MealPlanSuggestion {
        await MainActor.run {
            isGenerating = true
            lastError = nil
        }
        
        defer {
            Task { @MainActor in
                isGenerating = false
            }
        }
        
        // Create an enhanced prompt specifically optimized for Claude
        let prompt = createClaudeOptimizedPrompt(from: request)
        
        // Try providers in order until one succeeds
        for provider in providers {
            do {
                print("🤖 Trying provider: \(provider.name)")
                let response = try await provider.generateCompletion(prompt: prompt)
                let mealPlan = try parseMealPlanResponse(response, request: request)
                
                print("✅ Successfully generated meal plan using \(provider.name)")
                
                // If we got a good result from Claude, log some success metrics
                if provider.name.contains("Claude") {
                    await MainActor.run {
                        lastError = nil // Clear any previous errors
                    }
                    print("🎯 Claude generated meal plan with \(mealPlan.suggestedFoods.count) foods")
                    print("📊 Accuracy score: \(String(format: "%.1f", mealPlan.nutritionAccuracy.overall * 100))%")
                }
                
                return mealPlan
                
            } catch LLMError.rateLimitExceeded, LLMError.quotaExceeded {
                print("⚠️ Rate limit hit for \(provider.name), trying next provider...")
                continue
            } catch {
                print("❌ Error with \(provider.name): \(error)")
                await MainActor.run {
                    lastError = "Error with \(provider.name): \(error.localizedDescription)"
                }
                continue
            }
        }
        
        await MainActor.run {
            lastError = "All AI providers are currently unavailable. Please try again later."
        }
        throw LLMError.allProvidersUnavailable
    }
    
    // MARK: - Claude-Optimized Prompt Engineering
    private func createClaudeOptimizedPrompt(from request: MealPlanRequest) -> String {
        // First, let's validate and fix the macro targets if they don't add up
        let correctedRequest = validateAndCorrectMacros(request)
        
        // Calculate context for the calorie target
        let calorieContext = getCalorieContext(for: correctedRequest)
        
        var prompt = """
        You are a professional registered dietitian creating a precise meal plan. The calorie target is CRITICAL and must be met within 5%.
        
        STRICT NUTRITIONAL TARGETS (MUST BE MET):
        • CALORIES: \(correctedRequest.targetCalories) kcal (\(calorieContext))
        • PROTEIN: \(String(format: "%.1f", correctedRequest.targetProtein))g (≈\(Int(correctedRequest.targetProtein * 4)) calories)
        • CARBOHYDRATES: \(String(format: "%.1f", correctedRequest.targetCarbs))g (≈\(Int(correctedRequest.targetCarbs * 4)) calories)
        • FAT: \(String(format: "%.1f", correctedRequest.targetFat))g (≈\(Int(correctedRequest.targetFat * 9)) calories)
        • MEAL TYPE: \(correctedRequest.mealType.displayName)
        
        📊 MACRO MATH CHECK: \(Int(correctedRequest.targetProtein * 4 + correctedRequest.targetCarbs * 4 + correctedRequest.targetFat * 9)) calories from macros should ≈ \(correctedRequest.targetCalories) total calories
        
        ⚠️ CRITICAL: The total calories must be between \(Int(Double(correctedRequest.targetCalories) * 0.95)) and \(Int(Double(correctedRequest.targetCalories) * 1.05)) calories. This is NON-NEGOTIABLE.
        """
        
        // Add dietary restrictions with clear formatting
        if !request.dietaryRestrictions.isEmpty {
            prompt += "\n• Dietary Restrictions: \(request.dietaryRestrictions.joined(separator: ", "))"
        }
        
        // Add medical conditions with emphasis on safety
        if !request.medicalConditions.isEmpty {
            prompt += "\n• Medical Conditions: \(request.medicalConditions.joined(separator: ", "))"
            prompt += "\n  ⚠️ These conditions require careful nutritional consideration"
        }
        
        // Add cuisine preference
        if let cuisine = request.cuisinePreference {
            prompt += "\n• Preferred Cuisine Style: \(cuisine)"
        }
        
        prompt += """
        
        CRITICAL REQUIREMENTS:
        1. Suggest exactly 3-5 specific foods with precise, realistic portions
        2. Use standard household measurements (1 cup, 3 oz, 1 medium, etc.)
        3. Foods must be commonly available in grocery stores
        4. Total nutrition should be within 5% of the targets
        5. Consider food preparation methods and cooking
        6. Ensure nutritional balance and variety
        
        SPECIAL CONSIDERATIONS:
        • If medical conditions are present, prioritize foods that support those conditions
        • Balance macro and micronutrients appropriately
        • Consider meal timing and digestibility
        • Suggest foods that work well together flavor-wise
        
        OUTPUT FORMAT:
        Respond with ONLY valid JSON in this exact structure:
        
        {
          "meal_name": "Descriptive, appealing meal name",
          "foods": [
            {
              "food_name": "Exact food description (e.g., 'Salmon fillet, grilled')",
              "portion_description": "Specific portion with measurement (e.g., '4 oz fillet')",
              "gram_weight": estimated_grams_as_number,
              "calories": estimated_calories_as_number,
              "protein": estimated_protein_grams_as_number,
              "carbs": estimated_carbs_grams_as_number,
              "fat": estimated_fat_grams_as_number
            }
          ],
          "total_nutrition": {
            "calories": total_calories_as_number,
            "protein": total_protein_as_number,
            "carbs": total_carbs_as_number,
            "fat": total_fat_as_number
          },
          "preparation_notes": "Clear, concise cooking/preparation instructions",
          "nutritionist_notes": "Professional explanation of why this meal meets the nutritional requirements and supports any medical conditions"
        }
        
        IMPORTANT: Your entire response must be valid JSON only. No additional text before or after the JSON.
        """
        
        return prompt
    }
    
    // MARK: - Macro Validation and Correction
    private func validateAndCorrectMacros(_ request: MealPlanRequest) -> MealPlanRequest {
        // Calculate calories from macros
        let caloriesFromMacros = (request.targetProtein * 4) + (request.targetCarbs * 4) + (request.targetFat * 9)
        let targetCalories = Double(request.targetCalories)
        
        // Check if macros are wildly off from calorie target
        let macroToCalorieRatio = caloriesFromMacros / targetCalories
        
        print("🔍 Macro Debug: Target \(request.targetCalories) cal, Macros add up to \(Int(caloriesFromMacros)) cal (ratio: \(String(format: "%.2f", macroToCalorieRatio)))")
        
        // If the macros are way off (more than 50% difference), recalculate them properly
        if macroToCalorieRatio < 0.5 || macroToCalorieRatio > 1.5 {
            print("⚠️ Macro targets don't match calorie target. Recalculating...")
            
            // Use reasonable macro distribution:
            // Protein: 20-30% of calories
            // Carbs: 45-55% of calories
            // Fat: 20-30% of calories
            let correctedProtein = targetCalories * 0.25 / 4  // 25% of calories from protein
            let correctedCarbs = targetCalories * 0.50 / 4   // 50% of calories from carbs
            let correctedFat = targetCalories * 0.25 / 9     // 25% of calories from fat
            
            return MealPlanRequest(
                targetCalories: request.targetCalories,
                targetProtein: correctedProtein,
                targetCarbs: correctedCarbs,
                targetFat: correctedFat,
                mealType: request.mealType,
                cuisinePreference: request.cuisinePreference,
                dietaryRestrictions: request.dietaryRestrictions,
                medicalConditions: request.medicalConditions,
                patientId: request.patientId
            )
        }
        
        // If macros are reasonable, use them as-is
        return request
    }
    
    // MARK: - Helper Functions for Better Claude Context
    private func getCalorieContext(for request: MealPlanRequest) -> String {
        let calories = request.targetCalories
        switch calories {
        case 0..<150:
            return "Very small snack portion"
        case 150..<300:
            return "Light snack or small meal"
        case 300..<500:
            return "Moderate meal or substantial snack"
        case 500..<800:
            return "Full meal portion"
        case 800...:
            return "Large meal or multiple servings"
        default:
            return "Standard portion"
        }
    }
    
    private func getPortionGuidance(for request: MealPlanRequest) -> String {
        let calories = request.targetCalories
        let mealType = request.mealType.displayName.lowercased()
        
        switch calories {
        case 0..<200:
            return """
            • This is a small \(mealType) - focus on 1-2 nutrient-dense foods
            • Think: 1 piece of fruit + small protein, or 1 small grain serving
            • Avoid high-calorie additions like oils, nuts, or large proteins
            • Examples: 1 medium apple (80 cal) + 1 oz cheese (110 cal) = 190 cal
            """
        case 200..<400:
            return """
            • This is a light \(mealType) - you can include 2-3 complementary foods
            • Include one moderate protein source and vegetables/fruits
            • Use minimal added fats (1 tsp oil max)
            • Examples: 3 oz chicken breast (140 cal) + 1 cup vegetables (50 cal) + 1/3 cup rice (70 cal) = 260 cal
            """
        case 400..<600:
            return """
            • This is a substantial \(mealType) - you can build a complete, satisfying meal
            • Include protein, complex carbs, healthy fats, and vegetables
            • Standard restaurant-style portions work here
            • Examples: 4 oz salmon (200 cal) + 1/2 cup quinoa (110 cal) + 1 tbsp olive oil (120 cal) + vegetables (50 cal) = 480 cal
            """
        default:
            return """
            • This is a large \(mealType) - you can include generous portions
            • Build a complete meal with multiple components
            • Include adequate healthy fats and complex carbohydrates
            • Consider this might serve multiple people or be a post-workout meal
            """
        }
    }
    
    // MARK: - Enhanced Response Parsing with Better Error Handling
    private func parseMealPlanResponse(_ response: String, request: MealPlanRequest) throws -> MealPlanSuggestion {
        // Clean the response string to ensure it's valid JSON
        let cleanedResponse = cleanJSONResponse(response)
        
        guard let jsonData = cleanedResponse.data(using: .utf8) else {
            print("❌ Could not convert response to data")
            print("Raw response: \(response)")
            throw LLMError.invalidResponse
        }
        
        do {
            let aiResponse = try JSONDecoder().decode(AIMealPlanResponse.self, from: jsonData)
            
            // Validate the response has all required fields
            guard !aiResponse.meal_name.isEmpty,
                  !aiResponse.foods.isEmpty,
                  aiResponse.foods.allSatisfy({ $0.calories > 0 && $0.gram_weight > 0 }) else {
                print("❌ Invalid meal plan data structure")
                throw LLMError.invalidResponse
            }
            
            // Convert to our internal model with enhanced validation
            let suggestedFoods = aiResponse.foods.map { aiFood in
                SuggestedFood(
                    name: aiFood.food_name,
                    portionDescription: aiFood.portion_description,
                    gramWeight: max(aiFood.gram_weight, 1), // Ensure positive weight
                    estimatedNutrition: EstimatedNutrition(
                        calories: max(aiFood.calories, 0),
                        protein: max(aiFood.protein, 0),
                        carbs: max(aiFood.carbs, 0),
                        fat: max(aiFood.fat, 0)
                    )
                )
            }
            
            let mealPlan = MealPlanSuggestion(
                id: UUID(),
                mealName: aiResponse.meal_name,
                mealType: request.mealType,
                suggestedFoods: suggestedFoods,
                totalNutrition: EstimatedNutrition(
                    calories: max(aiResponse.total_nutrition.calories, 0),
                    protein: max(aiResponse.total_nutrition.protein, 0),
                    carbs: max(aiResponse.total_nutrition.carbs, 0),
                    fat: max(aiResponse.total_nutrition.fat, 0)
                ),
                preparationNotes: aiResponse.preparation_notes,
                nutritionistNotes: aiResponse.nutritionist_notes,
                targetRequest: request
            )
            
            // Log success metrics for debugging
            print("✅ Parsed meal plan: '\(mealPlan.mealName)'")
            print("📊 Foods: \(mealPlan.suggestedFoods.count)")
            print("🎯 Accuracy: \(String(format: "%.1f", mealPlan.nutritionAccuracy.overall * 100))%")
            
            return mealPlan
            
        } catch {
            print("❌ Failed to parse AI response: \(error)")
            print("Cleaned response was: \(cleanedResponse)")
            throw LLMError.invalidResponse
        }
    }
    
    // MARK: - JSON Response Cleaning Utility
    private func cleanJSONResponse(_ response: String) -> String {
        // Remove any markdown code blocks
        var cleaned = response
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Find the actual JSON content between the first { and last }
        if let startIndex = cleaned.firstIndex(of: "{"),
           let endIndex = cleaned.lastIndex(of: "}") {
            cleaned = String(cleaned[startIndex...endIndex])
        }
        
        return cleaned
    }
}

// MARK: - Data Models for AI Meal Planning
struct MealPlanRequest {
    let targetCalories: Int
    let targetProtein: Double
    let targetCarbs: Double
    let targetFat: Double
    let mealType: MealType
    let cuisinePreference: String?
    let dietaryRestrictions: [String]
    let medicalConditions: [String]
    let patientId: UUID?
}

struct MealPlanSuggestion: Identifiable {
    let id: UUID
    let mealName: String
    let mealType: MealType
    let suggestedFoods: [SuggestedFood]
    let totalNutrition: EstimatedNutrition
    let preparationNotes: String
    let nutritionistNotes: String
    let targetRequest: MealPlanRequest
    
    // Calculate accuracy of the AI suggestion
    var nutritionAccuracy: NutritionAccuracy {
        let calorieAccuracy = 1.0 - abs(totalNutrition.calories - Double(targetRequest.targetCalories)) / Double(targetRequest.targetCalories)
        let proteinAccuracy = 1.0 - abs(totalNutrition.protein - targetRequest.targetProtein) / targetRequest.targetProtein
        let carbAccuracy = 1.0 - abs(totalNutrition.carbs - targetRequest.targetCarbs) / targetRequest.targetCarbs
        let fatAccuracy = 1.0 - abs(totalNutrition.fat - targetRequest.targetFat) / targetRequest.targetFat
        
        return NutritionAccuracy(
            overall: (calorieAccuracy + proteinAccuracy + carbAccuracy + fatAccuracy) / 4.0,
            calories: calorieAccuracy,
            protein: proteinAccuracy,
            carbs: carbAccuracy,
            fat: fatAccuracy
        )
    }
}

struct SuggestedFood: Identifiable {
    let id = UUID()
    let name: String
    let portionDescription: String
    let gramWeight: Double
    let estimatedNutrition: EstimatedNutrition
    var matchedUSDAFood: USDAFood? // Will be populated when we match to database
    var isVerified: Bool { matchedUSDAFood != nil }
}

struct EstimatedNutrition {
    let calories: Double
    let protein: Double
    let carbs: Double
    let fat: Double
}

struct NutritionAccuracy {
    let overall: Double
    let calories: Double
    let protein: Double
    let carbs: Double
    let fat: Double
    
    var grade: String {
        switch overall {
        case 0.95...: return "A+"
        case 0.90...: return "A"
        case 0.85...: return "B+"
        case 0.80...: return "B"
        case 0.75...: return "C+"
        default: return "C"
        }
    }
    
    var color: Color {
        switch overall {
        case 0.90...: return .green
        case 0.80...: return .orange
        default: return .red
        }
    }
}

// MARK: - AI Response Models
private struct AIMealPlanResponse: Codable {
    let meal_name: String
    let foods: [AIFood]
    let total_nutrition: AINutrition
    let preparation_notes: String
    let nutritionist_notes: String
}

private struct AIFood: Codable {
    let food_name: String
    let portion_description: String
    let gram_weight: Double
    let calories: Double
    let protein: Double
    let carbs: Double
    let fat: Double
}

private struct AINutrition: Codable {
    let calories: Double
    let protein: Double
    let carbs: Double
    let fat: Double
}

// MARK: - LLM Provider Protocol
protocol LLMProvider {
    var name: String { get }
    func generateCompletion(prompt: String) async throws -> String
}

// MARK: - OpenAI Provider (Free Tier)
class OpenAIProvider: LLMProvider {
    let name = "OpenAI GPT-3.5"
    private let apiKey = "your-openai-api-key" // Replace with your key
    
    func generateCompletion(prompt: String) async throws -> String {
        guard !apiKey.isEmpty && apiKey != "your-openai-api-key" else {
            throw LLMError.invalidAPIKey
        }
        
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = [
            "model": "gpt-3.5-turbo",
            "messages": [
                ["role": "user", "content": prompt]
            ],
            "max_tokens": 1000,
            "temperature": 0.3
        ] as [String: Any]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.networkError
        }
        
        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 429 {
                throw LLMError.rateLimitExceeded
            }
            throw LLMError.serverError(httpResponse.statusCode)
        }
        
        let openAIResponse = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        return openAIResponse.choices.first?.message.content ?? ""
    }
}

// MARK: - Correct Free Hugging Face Provider
class HuggingFaceProvider: LLMProvider {
    let name = "Hugging Face Free API"
    private let apiKey = "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" // ← Your token here
    
    func generateCompletion(prompt: String) async throws -> String {
        guard !apiKey.isEmpty && apiKey != "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" else {
            throw LLMError.invalidAPIKey
        }
        
        // Use a reliable free model that supports text generation
        let modelId = "microsoft/DialoGPT-large"
        let url = URL(string: "https://api-inference.huggingface.co/models/\(modelId)")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Format the prompt specifically for this model
        let formattedPrompt = formatPromptForNutrition(prompt)
        
        let requestBody = [
            "inputs": formattedPrompt,
            "parameters": [
                "max_new_tokens": 800,
                "temperature": 0.3,
                "do_sample": true,
                "return_full_text": false
            ],
            "options": [
                "wait_for_model": true,
                "use_cache": false
            ]
        ] as [String: Any]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        print("🤗 Making request to Hugging Face model: \(modelId)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.networkError
        }
        
        print("🤗 Response Status: \(httpResponse.statusCode)")
        
        // Handle the different status codes appropriately
        switch httpResponse.statusCode {
        case 200:
            break // Success
        case 401:
            print("🤗 Invalid API key")
            throw LLMError.invalidAPIKey
        case 429:
            print("🤗 Rate limit exceeded")
            throw LLMError.rateLimitExceeded
        case 503:
            print("🤗 Model is loading, this is normal for free tier")
            try await Task.sleep(nanoseconds: 20_000_000_000) // Wait 20 seconds
            throw LLMError.rateLimitExceeded // This will trigger a retry
        default:
            if let responseText = String(data: data, encoding: .utf8) {
                print("🤗 Error response: \(responseText)")
            }
            throw LLMError.serverError(httpResponse.statusCode)
        }
        
        // Parse the response from the free API
        do {
            if let responseArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]],
               let firstResponse = responseArray.first,
               let generatedText = firstResponse["generated_text"] as? String {
                
                print("🤗 Raw generated text: \(generatedText)")
                
                // The free models often don't generate perfect JSON, so we'll need to
                // either extract JSON or fall back to creating a structured response
                return createMealPlanFromText(generatedText, originalPrompt: prompt)
                
            } else {
                print("🤗 Unexpected response format")
                throw LLMError.invalidResponse
            }
        } catch {
            print("🤗 Failed to parse response: \(error)")
            throw LLMError.invalidResponse
        }
    }
    
    // Helper function to format prompts for better nutrition responses
    private func formatPromptForNutrition(_ prompt: String) -> String {
        // Extract key information from the detailed prompt
        let calories = extractCalories(from: prompt)
        let mealType = extractMealType(from: prompt)
        let restrictions = extractRestrictions(from: prompt)
        
        // Create a simpler, more direct prompt that free models can handle better
        var simplifiedPrompt = "Create a \(mealType.lowercased()) meal plan with \(calories) calories."
        
        if !restrictions.isEmpty {
            simplifiedPrompt += " Dietary requirements: \(restrictions.joined(separator: ", "))."
        }
        
        simplifiedPrompt += " List specific foods with portions and approximate nutrition."
        
        return simplifiedPrompt
    }
    
    // Helper function to create structured meal plan from free-form text
    private func createMealPlanFromText(_ text: String, originalPrompt: String) -> String {
        // Since free models might not generate perfect JSON, we'll create a valid response
        // based on the text they do generate, combined with nutritional knowledge
        
        let calories = extractCalories(from: originalPrompt)
        let mealType = extractMealType(from: originalPrompt)
        
        // For now, we'll return a nutritionally appropriate meal plan
        // In a real implementation, you could use NLP to parse the generated text
        return generateNutritionallyBalancedMeal(targetCalories: calories, mealType: mealType, inspirationText: text)
    }
    
    // Helper functions to extract information from prompts
    private func extractCalories(from prompt: String) -> Int {
        let lines = prompt.components(separatedBy: "\n")
        for line in lines {
            if line.contains("Calories:") {
                let calString = line.replacingOccurrences(of: "- Calories: ", with: "")
                    .replacingOccurrences(of: " kcal", with: "")
                return Int(calString) ?? 500
            }
        }
        return 500
    }
    
    private func extractMealType(from prompt: String) -> String {
        if prompt.contains("MEAL TYPE:") {
            let lines = prompt.components(separatedBy: "\n")
            for line in lines {
                if line.contains("MEAL TYPE:") {
                    return line.replacingOccurrences(of: "MEAL TYPE: ", with: "")
                }
            }
        }
        return "Lunch"
    }
    
    private func extractRestrictions(from prompt: String) -> [String] {
        var restrictions: [String] = []
        let lines = prompt.components(separatedBy: "\n")
        
        for line in lines {
            if line.contains("Dietary Restrictions:") {
                let restrictionText = line.replacingOccurrences(of: "- Dietary Restrictions: ", with: "")
                restrictions = restrictionText.components(separatedBy: ", ")
                break
            }
        }
        
        return restrictions.filter { !$0.isEmpty }
    }
    
    // Generate a nutritionally balanced meal plan when AI text isn't perfect
    private func generateNutritionallyBalancedMeal(targetCalories: Int, mealType: String, inspirationText: String) -> String {
        // Use the inspiration text to influence food choices, but ensure nutritional balance
        let isVegetarian = inspirationText.lowercased().contains("vegetarian") || inspirationText.lowercased().contains("plant")
        let isMediterranean = inspirationText.lowercased().contains("mediterranean")
        let isAsian = inspirationText.lowercased().contains("asian")
        
        // Create a balanced meal based on the target calories and detected preferences
        return createBalancedMealJSON(
            calories: targetCalories,
            mealType: mealType,
            isVegetarian: isVegetarian,
            isMediterranean: isMediterranean,
            isAsian: isAsian
        )
    }
    
    private func createBalancedMealJSON(calories: Int, mealType: String, isVegetarian: Bool, isMediterranean: Bool, isAsian: Bool) -> String {
        let protein: (String, String, Double, Double) // name, portion, grams, calories
        let carb: (String, String, Double, Double)
        let fat: (String, String, Double, Double)
        let vegetable: (String, String, Double, Double)
        
        // Choose foods based on dietary preferences
        if isVegetarian {
            protein = ("Tofu, firm", "4 oz (113g)", 113, 180)
            carb = ("Quinoa, cooked", "3/4 cup", 138, 166)
            fat = ("Avocado", "1/2 medium", 100, 160)
            vegetable = ("Spinach, sautéed", "1 cup", 180, 41)
        } else if isMediterranean {
            protein = ("Salmon, grilled", "4 oz fillet", 113, 206)
            carb = ("Quinoa, cooked", "1/2 cup", 92, 111)
            fat = ("Olive oil", "1 tbsp", 14, 120)
            vegetable = ("Cherry tomatoes", "1 cup", 149, 27)
        } else if isAsian {
            protein = ("Chicken breast, grilled", "3 oz", 85, 140)
            carb = ("Brown rice, cooked", "2/3 cup", 130, 150)
            fat = ("Sesame oil", "2 tsp", 9, 80)
            vegetable = ("Bok choy, steamed", "1 cup", 70, 9)
        } else {
            protein = ("Chicken breast, grilled", "4 oz", 113, 185)
            carb = ("Sweet potato, baked", "1 medium", 128, 112)
            fat = ("Almonds, raw", "1 oz (28g)", 28, 164)
            vegetable = ("Broccoli, steamed", "1 cup", 156, 55)
        }
        
        let totalCalories = protein.3 + carb.3 + fat.3 + vegetable.3
        let proteinGrams = protein.2 * 0.23 // Approximate protein content
        let carbGrams = carb.2 * 0.20 // Approximate carb content
        let fatGrams = fat.2 * 0.15 // Approximate fat content
        
        return """
        {
          "meal_name": "\(mealType) Power Bowl",
          "foods": [
            {
              "food_name": "\(protein.0)",
              "portion_description": "\(protein.1)",
              "gram_weight": \(protein.2),
              "calories": \(protein.3),
              "protein": \(proteinGrams),
              "carbs": 0,
              "fat": 4
            },
            {
              "food_name": "\(carb.0)",
              "portion_description": "\(carb.1)",
              "gram_weight": \(carb.2),
              "calories": \(carb.3),
              "protein": 3,
              "carbs": \(carbGrams),
              "fat": 2
            },
            {
              "food_name": "\(fat.0)",
              "portion_description": "\(fat.1)",
              "gram_weight": \(fat.2),
              "calories": \(fat.3),
              "protein": 2,
              "carbs": 2,
              "fat": \(fatGrams)
            },
            {
              "food_name": "\(vegetable.0)",
              "portion_description": "\(vegetable.1)",
              "gram_weight": \(vegetable.2),
              "calories": \(vegetable.3),
              "protein": 3,
              "carbs": 8,
              "fat": 0
            }
          ],
          "total_nutrition": {
            "calories": \(Int(totalCalories)),
            "protein": \(Int(proteinGrams + 8)),
            "carbs": \(Int(carbGrams + 10)),
            "fat": \(Int(fatGrams + 6))
          },
          "preparation_notes": "Prepare all components fresh. Season with herbs and spices for optimal flavor.",
          "nutritionist_notes": "This meal provides balanced macronutrients with high-quality protein, complex carbohydrates, and healthy fats."
        }
        """
    }
}

// MARK: - Hugging Face Chat Response Models (OpenAI-compatible)
private struct HuggingFaceChatResponse: Codable {
    let choices: [HuggingFaceChoice]
    let created: Int?
    let id: String?
    let model: String?
    let object: String?
}

private struct HuggingFaceChoice: Codable {
    let message: HuggingFaceMessage
    let finish_reason: String?
    let index: Int?
}

private struct HuggingFaceMessage: Codable {
    let role: String
    let content: String
}

// Helper to extract JSON from Llama response
private func extractJSON(from text: String) -> String {
    // Look for JSON content between { and }
    if let startIndex = text.firstIndex(of: "{"),
       let endIndex = text.lastIndex(of: "}") {
        let jsonPart = String(text[startIndex...endIndex])
        return jsonPart
    }
    
    // If no JSON found, return the whole text
    return text
}

// MARK: - Hugging Face Response Model
private struct HuggingFaceResponse: Codable {
    let generated_text: String
}

// MARK: - OpenRouter Provider (Free Tier)
class OpenRouterProvider: LLMProvider {
    let name = "OpenRouter"
    
    func generateCompletion(prompt: String) async throws -> String {
        // Implement OpenRouter API call
        // For now, throw not available
        throw LLMError.providerNotAvailable
    }
}

// MARK: - Improved Mock Provider
class MockLLMProvider: LLMProvider {
    let name = "Mock AI (Testing)"
    
    func generateCompletion(prompt: String) async throws -> String {
        // Simulate realistic API delay
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        let calories = extractTargetCalories(from: prompt)
        let mealType = extractMealType(from: prompt)
        let cuisine = extractCuisine(from: prompt)
        
        return generateMealPlan(calories: calories, mealType: mealType, cuisine: cuisine)
    }
    
    private func extractTargetCalories(from prompt: String) -> Int {
        if prompt.contains("Calories:") {
            let lines = prompt.components(separatedBy: "\n")
            for line in lines {
                if line.contains("Calories:") {
                    let calString = line.replacingOccurrences(of: "- Calories: ", with: "").replacingOccurrences(of: " kcal", with: "")
                    return Int(calString) ?? 500
                }
            }
        }
        return 500
    }
    
    private func extractMealType(from prompt: String) -> String {
        if prompt.contains("MEAL TYPE:") {
            let lines = prompt.components(separatedBy: "\n")
            for line in lines {
                if line.contains("MEAL TYPE:") {
                    return line.replacingOccurrences(of: "MEAL TYPE: ", with: "")
                }
            }
        }
        return "Lunch"
    }
    
    private func extractCuisine(from prompt: String) -> String {
        if prompt.contains("Cuisine Style:") {
            let lines = prompt.components(separatedBy: "\n")
            for line in lines {
                if line.contains("Cuisine Style:") {
                    return line.replacingOccurrences(of: "- Cuisine Style: ", with: "")
                }
            }
        }
        return "American"
    }
    
    private func generateMealPlan(calories: Int, mealType: String, cuisine: String) -> String {
        // Generate different meals based on parameters
        let mealPlans = getMealPlans(for: cuisine, calories: calories)
        let selectedPlan = mealPlans.randomElement() ?? mealPlans[0]
        
        return selectedPlan
    }
    
    private func getMealPlans(for cuisine: String, calories: Int) -> [String] {
        let adjustedCalories = max(300, min(800, calories)) // Keep realistic
        
        switch cuisine.lowercased() {
        case "mediterranean":
            return [generateMediterraneanMeal(calories: adjustedCalories)]
        case "mexican":
            return [generateMexicanMeal(calories: adjustedCalories)]
            
        default:
            return [generateAmericanMeal(calories: adjustedCalories)]
        }
    }
    
    private func generateMediterraneanMeal(calories: Int) -> String {
        return """
        {
          "meal_name": "Mediterranean Bowl",
          "foods": [
            {
              "food_name": "Salmon, grilled",
              "portion_description": "4 oz fillet",
              "gram_weight": 113,
              "calories": 206,
              "protein": 28,
              "carbs": 0,
              "fat": 9
            },
            {
              "food_name": "Quinoa, cooked",
              "portion_description": "1/2 cup",
              "gram_weight": 92,
              "calories": 111,
              "protein": 4,
              "carbs": 20,
              "fat": 2
            },
            {
              "food_name": "Greek olives",
              "portion_description": "8 olives",
              "gram_weight": 32,
              "calories": 40,
              "protein": 0,
              "carbs": 1,
              "fat": 4
            },
            {
              "food_name": "Cherry tomatoes",
              "portion_description": "1/2 cup",
              "gram_weight": 75,
              "calories": 13,
              "protein": 1,
              "carbs": 3,
              "fat": 0
            }
          ],
          "total_nutrition": {
            "calories": 370,
            "protein": 33,
            "carbs": 24,
            "fat": 15
          },
          "preparation_notes": "Grill salmon with lemon and herbs. Serve over quinoa with olives and fresh tomatoes.",
          "nutritionist_notes": "Rich in omega-3 fatty acids, complete protein, and antioxidants. Perfect Mediterranean-style nutrition."
        }
        """
    }
    
    private func generateAmericanMeal(calories: Int) -> String {
        return """
        {
          "meal_name": "Classic American Bowl",
          "foods": [
            {
              "food_name": "Chicken breast, grilled",
              "portion_description": "4 oz",
              "gram_weight": 113,
              "calories": 185,
              "protein": 35,
              "carbs": 0,
              "fat": 4
            },
            {
              "food_name": "Sweet potato, baked",
              "portion_description": "1 medium",
              "gram_weight": 128,
              "calories": 112,
              "protein": 2,
              "carbs": 26,
              "fat": 0
            },
            {
              "food_name": "Green beans, steamed",
              "portion_description": "1 cup",
              "gram_weight": 125,
              "calories": 35,
              "protein": 2,
              "carbs": 8,
              "fat": 0
            }
          ],
          "total_nutrition": {
            "calories": 332,
            "protein": 39,
            "carbs": 34,
            "fat": 4
          },
          "preparation_notes": "Grill chicken with seasonings. Bake sweet potato until tender. Steam green beans until crisp-tender.",
          "nutritionist_notes": "High protein, complex carbohydrates, and plenty of vitamins. Great for muscle building and sustained energy."
        }
        """
    }
    
    private func generateMexicanMeal(calories: Int) -> String {
        return """
        {
          "meal_name": "Mexican Protein Bowl",
          "foods": [
            {
              "food_name": "Ground turkey, lean",
              "portion_description": "3 oz cooked",
              "gram_weight": 85,
              "calories": 120,
              "protein": 22,
              "carbs": 0,
              "fat": 3
            },
            {
              "food_name": "Black beans",
              "portion_description": "1/2 cup",
              "gram_weight": 86,
              "calories": 114,
              "protein": 8,
              "carbs": 20,
              "fat": 0
            },
            {
              "food_name": "Brown rice",
              "portion_description": "1/3 cup cooked",
              "gram_weight": 65,
              "calories": 73,
              "protein": 2,
              "carbs": 15,
              "fat": 1
            },
            {
              "food_name": "Avocado",
              "portion_description": "1/4 medium",
              "gram_weight": 50,
              "calories": 80,
              "protein": 1,
              "carbs": 4,
              "fat": 7
            }
          ],
          "total_nutrition": {
            "calories": 387,
            "protein": 33,
            "carbs": 39,
            "fat": 11
          },
          "preparation_notes": "Season turkey with cumin, chili powder, and garlic. Serve over rice with beans and fresh avocado.",
          "nutritionist_notes": "Complete amino acid profile with healthy fats and fiber. Traditional Mexican flavors with modern nutrition balance."
        }
        """
    }
}

// MARK: - OpenAI Response Models
private struct OpenAIResponse: Codable {
    let choices: [Choice]
}

private struct Choice: Codable {
    let message: Message
}

private struct Message: Codable {
    let content: String
}

// MARK: - LLM Errors
enum LLMError: Error, LocalizedError {
    case invalidAPIKey
    case rateLimitExceeded
    case quotaExceeded
    case networkError
    case serverError(Int)
    case invalidResponse
    case providerNotAvailable
    case allProvidersUnavailable
    
    var errorDescription: String? {
        switch self {
        case .invalidAPIKey:
            return "Invalid API key. Please check your LLM service configuration."
        case .rateLimitExceeded:
            return "Rate limit exceeded. Please wait before trying again."
        case .quotaExceeded:
            return "API quota exceeded. Consider upgrading your plan."
        case .networkError:
            return "Network error. Please check your internet connection."
        case .serverError(let code):
            return "Server error (\(code)). Please try again later."
        case .invalidResponse:
            return "Invalid response from AI service. Please try again."
        case .providerNotAvailable:
            return "This AI provider is not available."
        case .allProvidersUnavailable:
            return "All AI providers are currently unavailable. Please try again later."
        }
    }
}


// MARK: - USDA Verification Data Models
// ADD THESE TO THE BOTTOM OF YOUR EXISTING LLMService.swift FILE

struct VerifiedMealPlanSuggestion {
    let originalAISuggestion: MealPlanSuggestion
    let verifiedFoods: [VerifiedSuggestedFood]
    let verifiedTotalNutrition: EstimatedNutrition
    let overallAccuracy: Double
    let detailedAccuracy: DetailedAccuracy
    let verificationNotes: String
}

struct VerifiedSuggestedFood {
    let originalAISuggestion: SuggestedFood
    let matchedUSDAFood: USDAFood?
    let verifiedNutrition: EstimatedNutrition
    let matchConfidence: Double
    let isVerified: Bool
    let verificationNotes: String
}

struct DetailedAccuracy {
    let overall: Double
    let calories: Double
    let protein: Double
    let carbs: Double
    let fat: Double
    
    var grade: String {
        switch overall {
        case 0.95...: return "A+"
        case 0.90...: return "A"
        case 0.85...: return "B+"
        case 0.80...: return "B"
        case 0.75...: return "C+"
        default: return "C"
        }
    }
    
    var color: Color {
        switch overall {
        case 0.90...: return .green
        case 0.80...: return .orange
        default: return .red
        }
    }
}


// MARK: - Enhanced Claude Prompting for USDA Compatibility
extension LLMService {
    
    // MARK: - USDA-Compatible Prompt Engineering
    private func createUSDACompatiblePrompt(from request: MealPlanRequest) -> String {
        // First, let's validate and fix the macro targets if they don't add up
        let correctedRequest = validateAndCorrectMacros(request)
        
        // Calculate context for the calorie target
        let calorieContext = getCalorieContext(for: correctedRequest)
        
        var prompt = """
        You are a professional registered dietitian creating a precise meal plan. You must think in terms of INDIVIDUAL INGREDIENTS that exist in the USDA food database.
        
        CRITICAL: Break down meals into separate, basic ingredients rather than compound dishes.
        
        STRICT NUTRITIONAL TARGETS (MUST BE MET):
        • CALORIES: \(correctedRequest.targetCalories) kcal (\(calorieContext))
        • PROTEIN: \(String(format: "%.1f", correctedRequest.targetProtein))g (≈\(Int(correctedRequest.targetProtein * 4)) calories)
        • CARBOHYDRATES: \(String(format: "%.1f", correctedRequest.targetCarbs))g (≈\(Int(correctedRequest.targetCarbs * 4)) calories)
        • FAT: \(String(format: "%.1f", correctedRequest.targetFat))g (≈\(Int(correctedRequest.targetFat * 9)) calories)
        • MEAL TYPE: \(correctedRequest.mealType.displayName)
        
        📊 MACRO MATH CHECK: \(Int(correctedRequest.targetProtein * 4 + correctedRequest.targetCarbs * 4 + correctedRequest.targetFat * 9)) calories from macros should ≈ \(correctedRequest.targetCalories) total calories
        
        ⚠️ CRITICAL: The total calories must be between \(Int(Double(correctedRequest.targetCalories) * 0.95)) and \(Int(Double(correctedRequest.targetCalories) * 1.05)) calories. This is NON-NEGOTIABLE.
        """
        
        // Add dietary restrictions with clear formatting
        if !correctedRequest.dietaryRestrictions.isEmpty {
            prompt += "\n• DIETARY RESTRICTIONS: \(correctedRequest.dietaryRestrictions.joined(separator: ", "))"
        }
        
        // Add medical conditions with emphasis on safety
        if !correctedRequest.medicalConditions.isEmpty {
            prompt += "\n• MEDICAL CONDITIONS: \(correctedRequest.medicalConditions.joined(separator: ", "))"
            prompt += "\n  ⚠️ Adapt portions and food choices to support these conditions while meeting calorie targets"
        }
        
        // Add cuisine preference
        if let cuisine = correctedRequest.cuisinePreference {
            prompt += "\n• CUISINE STYLE: \(cuisine)"
        }
        
        prompt += """
        
        🔍 USDA DATABASE COMPATIBILITY RULES:
        
        WRONG WAY (Compound dishes that won't match USDA):
        ❌ "Grilled chicken breast with herbs" 
        ❌ "Spinach, sautéed in olive oil"
        ❌ "Rice pilaf with vegetables"
        ❌ "Mixed green salad with dressing"
        
        RIGHT WAY (Individual ingredients that WILL match USDA):
        ✅ "Chicken, broilers or fryers, breast, meat only, cooked, grilled" + "Herbs, fresh mixed"
        ✅ "Spinach, raw" + "Oil, olive, salad or cooking"
        ✅ "Rice, brown, long-grain, cooked" + "Vegetables, mixed, frozen, cooked"
        ✅ "Lettuce, cos or romaine, raw" + "Salad dressing, ranch"
        
        INGREDIENT SEPARATION STRATEGY:
        1. Think of the base ingredient (chicken, spinach, rice)
        2. Think of cooking method (grilled, sautéed, steamed)
        3. Think of additions (oil, herbs, seasonings) as SEPARATE ingredients
        4. Use USDA-style naming: "Food, type, preparation method"
        
        USDA NAMING PATTERNS:
        • Proteins: "Chicken, broilers or fryers, [part], [preparation]"
        • Vegetables: "[Vegetable name], [raw/cooked], [method if cooked]"
        • Grains: "Rice, [type], [preparation]", "Bread, [type]"
        • Oils: "Oil, [type], salad or cooking"
        • Dairy: "Milk, [fat content]", "Cheese, [type]"
        
        PORTION STRATEGY FOR \(correctedRequest.targetCalories) CALORIES:
        \(getPortionGuidance(for: correctedRequest))
        
        CRITICAL SUCCESS CRITERIA:
        1. Total meal calories: \(Int(Double(correctedRequest.targetCalories) * 0.95))-\(Int(Double(correctedRequest.targetCalories) * 1.05)) kcal (95-105% of target)
        2. Suggest 3-6 INDIVIDUAL ingredients (not compound dishes)
        3. Each ingredient must be something that exists in USDA database
        4. Use precise portions that achieve exact targets
        5. All ingredients must be commonly available
        6. Calculate nutrition values carefully and double-check totals
        
        MATHEMATICAL APPROACH:
        1. Start with target calories: \(correctedRequest.targetCalories)
        2. Select your primary ingredient (highest calorie contributor)
        3. Add cooking oil/fat if needed (calculate exactly)
        4. Add vegetables or grains to balance macros
        5. Add smaller ingredients to fine-tune totals
        6. Verify totals before finalizing
        
        RESPONSE FORMAT - Use individual ingredients:
        {
          "meal_name": "Descriptive meal name (like 'Grilled Chicken Power Bowl')",
          "foods": [
            {
              "food_name": "Chicken, broilers or fryers, breast, meat only, cooked, grilled",
              "portion_description": "4 oz (113g)",
              "gram_weight": 113,
              "calories": 185,
              "protein": 35,
              "carbs": 0,
              "fat": 4
            },
            {
              "food_name": "Oil, olive, salad or cooking",
              "portion_description": "1 tablespoon (14g)",
              "gram_weight": 14,
              "calories": 120,
              "protein": 0,
              "carbs": 0,
              "fat": 14
            },
            {
              "food_name": "Spinach, raw",
              "portion_description": "2 cups (60g)",
              "gram_weight": 60,
              "calories": 14,
              "protein": 2,
              "carbs": 2,
              "fat": 0
            }
          ],
          "total_nutrition": {
            "calories": 319,
            "protein": 37,
            "carbs": 2,
            "fat": 18
          },
          "preparation_notes": "Grill chicken breast until internal temperature reaches 165°F. Heat olive oil in pan and quickly sauté spinach until wilted. Serve together.",
          "nutritionist_notes": "This meal provides high-quality complete protein, healthy monounsaturated fats, and essential vitamins from leafy greens. Perfect for muscle building and heart health."
        }
        
        IMPORTANT: Your entire response must be valid JSON only. No additional text before or after the JSON. Each food item must be a single, basic ingredient that would exist in the USDA database.
        """
        
        return prompt
    }
}


// MARK: - Enhanced MealPlanRequest for Multi-Day Planning
extension MealPlanRequest {
    var varietyInstructions: String? { nil }
    var language: PlanLanguage { .spanish }
}
