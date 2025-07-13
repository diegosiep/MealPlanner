//
//  FoodTranslationService.swift
//  MealPlannerPro
//
//  High-accuracy food name translation for USDA database compatibility
//

import Foundation

// MARK: - Food Translation Service for USDA Compatibility
class FoodTranslationService: ObservableObject {
    private let claudeProvider = ClaudeProvider()
    
    // MARK: - Translation with Format Standardization
    func translateFoodNameForUSDA(_ foodName: String, language: PlanLanguage = .spanish) async throws -> USDACompatibleFood {
        guard language != .english else {
            // Already in English, just normalize
            return USDACompatibleFood(
                originalName: foodName,
                translatedName: normalizeFoodName(foodName),
                confidence: 1.0,
                alternativeNames: []
            )
        }
        
        let translationPrompt = createTranslationPrompt(foodName: foodName, sourceLanguage: language)
        
        let response = try await claudeProvider.generateCompletion(prompt: translationPrompt)
        
        return try parseTranslationResponse(response, originalName: foodName)
    }
    
    // MARK: - Specialized Translation Prompt for USDA Format
    private func createTranslationPrompt(foodName: String, sourceLanguage: PlanLanguage) -> String {
        let sourceLanguageName = sourceLanguage == .spanish ? "Spanish" : "English"
        
        return """
        You are a professional nutritionist translating food names for the USDA Food Data Central database. 
        
        CRITICAL REQUIREMENTS:
        1. Translate the food name to standard English USDA format
        2. Use generic, common food names (not brand names)
        3. Include preparation method if relevant (raw, cooked, baked, etc.)
        4. Be specific about food type (e.g., "chicken breast" not just "chicken")
        5. Remove cultural/regional modifiers that don't affect nutrition
        
        Food to translate from \(sourceLanguageName): "\(foodName)"
        
        Respond ONLY with valid JSON in this exact format:
        {
            "primaryTranslation": "exact USDA-compatible food name",
            "confidence": 0.95,
            "alternativeNames": [
                "alternative name 1",
                "alternative name 2"
            ],
            "preparationMethod": "raw|cooked|baked|grilled|etc",
            "foodCategory": "protein|vegetable|grain|fruit|dairy|fat",
            "usdaSearchTerms": [
                "primary search term",
                "secondary search term"
            ]
        }
        
        Examples:
        - "Pollo a la plancha" → "Chicken breast, grilled"
        - "Arroz integral" → "Rice, brown, cooked"
        - "Aceite de oliva" → "Oil, olive, salad or cooking"
        - "Espinacas frescas" → "Spinach, raw"
        """
    }
    
    // MARK: - Parse Claude's Translation Response
    private func parseTranslationResponse(_ response: String, originalName: String) throws -> USDACompatibleFood {
        // Clean response and extract JSON
        let cleanedResponse = response.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let jsonData = cleanedResponse.data(using: .utf8) else {
            throw FoodTranslationError.invalidResponse
        }
        
        do {
            let translationResult = try JSONDecoder().decode(TranslationResult.self, from: jsonData)
            
            // Validate confidence threshold
            guard translationResult.confidence >= 0.8 else {
                throw FoodTranslationError.lowConfidence(translationResult.confidence)
            }
            
            return USDACompatibleFood(
                originalName: originalName,
                translatedName: translationResult.primaryTranslation,
                confidence: translationResult.confidence,
                alternativeNames: translationResult.alternativeNames,
                preparationMethod: translationResult.preparationMethod,
                foodCategory: translationResult.foodCategory,
                usdaSearchTerms: translationResult.usdaSearchTerms
            )
            
        } catch {
            print("❌ Failed to parse translation response: \(error)")
            print("📄 Response was: \(cleanedResponse)")
            
            // Fallback to basic translation
            return USDACompatibleFood(
                originalName: originalName,
                translatedName: normalizeFoodName(originalName),
                confidence: 0.5,
                alternativeNames: []
            )
        }
    }
    
    // MARK: - Food Name Normalization for USDA Compatibility
    private func normalizeFoodName(_ name: String) -> String {
        var normalized = name.lowercased()
        
        // Common Spanish to English replacements
        let replacements = [
            "pollo": "chicken",
            "pescado": "fish",
            "carne": "beef",
            "arroz": "rice",
            "verduras": "vegetables",
            "aceite": "oil",
            "mantequilla": "butter",
            "queso": "cheese",
            "huevo": "egg",
            "leche": "milk"
        ]
        
        for (spanish, english) in replacements {
            normalized = normalized.replacingOccurrences(of: spanish, with: english)
        }
        
        // Remove common preparation words that might interfere
        let wordsToRemove = ["a la", "con", "en", "de", "al", "fresco", "natural"]
        for word in wordsToRemove {
            normalized = normalized.replacingOccurrences(of: word, with: "")
        }
        
        // Clean up extra spaces
        normalized = normalized.components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        
        return normalized.capitalized
    }
}

// MARK: - Translation Data Models
struct USDACompatibleFood {
    let originalName: String
    let translatedName: String
    let confidence: Double
    let alternativeNames: [String]
    let preparationMethod: String?
    let foodCategory: String?
    let usdaSearchTerms: [String]?
    
    init(originalName: String, translatedName: String, confidence: Double, alternativeNames: [String], preparationMethod: String? = nil, foodCategory: String? = nil, usdaSearchTerms: [String]? = nil) {
        self.originalName = originalName
        self.translatedName = translatedName
        self.confidence = confidence
        self.alternativeNames = alternativeNames
        self.preparationMethod = preparationMethod
        self.foodCategory = foodCategory
        self.usdaSearchTerms = usdaSearchTerms
    }
}

struct TranslationResult: Codable {
    let primaryTranslation: String
    let confidence: Double
    let alternativeNames: [String]
    let preparationMethod: String?
    let foodCategory: String
    let usdaSearchTerms: [String]
}

// MARK: - Translation Errors
enum FoodTranslationError: Error, LocalizedError {
    case invalidResponse
    case lowConfidence(Double)
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid translation response format"
        case .lowConfidence(let confidence):
            return "Translation confidence too low: \(String(format: "%.1f", confidence * 100))%"
        case .networkError:
            return "Network error during translation"
        }
    }
}