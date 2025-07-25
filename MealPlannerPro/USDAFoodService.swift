import Foundation

// MARK: - USDA Food Service
// This service handles all interactions with the USDA Food Data Central API

class USDAFoodService: ObservableObject {
    private let baseURL = "https://api.nal.usda.gov/fdc/v1"
    private let secureKeyManager = SecureAPIKeyManager.shared
    
    private var apiKey: String? {
        return secureKeyManager.usdaAPIKey
    }
    
    // MARK: - Search Foods
    func searchFoods(query: String, pageSize: Int = 25) async throws -> [USDAFood] {
        guard let apiKey = apiKey, !secureKeyManager.isInDemoMode else {
            // Return demo data when no API key
            return getDemoFoods(matching: query)
        }
        
        guard let url = URL(string: "\(baseURL)/foods/search") else {
            throw USDAError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let searchRequest = USDASearchRequest(
            query: query,
            pageSize: pageSize,
            pageNumber: 1,
            dataType: ["Foundation", "SR Legacy"],
            api_key: apiKey
        )
        
        request.httpBody = try JSONEncoder().encode(searchRequest)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw USDAError.networkError
        }
        
        guard httpResponse.statusCode == 200 else {
            throw USDAError.serverError(httpResponse.statusCode)
        }
        
        let searchResponse = try JSONDecoder().decode(USDASearchResponse.self, from: data)
        return searchResponse.foods
    }
    
    // MARK: - Get Food Details
    func getFoodDetails(fdcId: Int) async throws -> USDAFoodDetails {
        guard let apiKey = apiKey, !secureKeyManager.isInDemoMode else {
            return getDemoFoodDetails(fdcId: fdcId)
        }
        
        guard let url = URL(string: "\(baseURL)/food/\(fdcId)") else {
            throw USDAError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "nutrients", value: "203,204,205,208,269,291,303,304,305,306")
        ]
        
        request.url = components.url
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw USDAError.networkError
        }
        
        guard httpResponse.statusCode == 200 else {
            throw USDAError.serverError(httpResponse.statusCode)
        }
        
        return try JSONDecoder().decode(USDAFoodDetails.self, from: data)
    }
    
    // MARK: - Get Food Nutrition
    func getFoodNutrition(fdcId: Int) async throws -> NutritionInfo {
        let foodDetails = try await getFoodDetails(fdcId: fdcId)
        return extractNutritionInfo(from: foodDetails)
    }
    
    // MARK: - Demo Data
    private func getDemoFoods(matching query: String) -> [USDAFood] {
        let demoFoods = [
            USDAFood(
                fdcId: 171077,
                description: "Chicken, broilers or fryers, breast, meat only, cooked, grilled",
                dataType: "Foundation",
                brandOwner: nil,
                calories: 165,
                protein: 31.02,
                carbs: 0,
                fat: 3.57,
                fiber: 0,
                sodium: 74
            ),
            USDAFood(
                fdcId: 168876,
                description: "Rice, brown, long-grain, cooked",
                dataType: "Foundation",
                brandOwner: nil,
                calories: 111,
                protein: 2.58,
                carbs: 23,
                fat: 0.9,
                fiber: 1.8,
                sodium: 5
            ),
            USDAFood(
                fdcId: 170379,
                description: "Broccoli, cooked, boiled, drained, without salt",
                dataType: "Foundation",
                brandOwner: nil,
                calories: 34,
                protein: 2.38,
                carbs: 7.18,
                fat: 0.41,
                fiber: 2.6,
                sodium: 41
            ),
            USDAFood(
                fdcId: 175167,
                description: "Salmon, Atlantic, farmed, cooked, dry heat",
                dataType: "Foundation",
                brandOwner: nil,
                calories: 206,
                protein: 25.44,
                carbs: 0,
                fat: 12.35,
                fiber: 0,
                sodium: 59
            ),
            USDAFood(
                fdcId: 168482,
                description: "Sweet potato, cooked, baked in skin, without salt",
                dataType: "Foundation",
                brandOwner: nil,
                calories: 90,
                protein: 2.01,
                carbs: 20.71,
                fat: 0.15,
                fiber: 3.3,
                sodium: 6
            ),
            USDAFood(
                fdcId: 168462,
                description: "Spinach, cooked, boiled, drained, without salt",
                dataType: "Foundation",
                brandOwner: nil,
                calories: 23,
                protein: 2.97,
                carbs: 3.75,
                fat: 0.26,
                fiber: 2.4,
                sodium: 24
            ),
            USDAFood(
                fdcId: 169414,
                description: "Oil, olive, salad or cooking",
                dataType: "Foundation",
                brandOwner: nil,
                calories: 884,
                protein: 0,
                carbs: 0,
                fat: 100,
                fiber: 0,
                sodium: 2
            ),
            USDAFood(
                fdcId: 169057,
                description: "Egg, whole, cooked, hard-boiled",
                dataType: "Foundation",
                brandOwner: nil,
                calories: 155,
                protein: 12.58,
                carbs: 1.12,
                fat: 10.61,
                fiber: 0,
                sodium: 124
            )
        ]
        
        return demoFoods.filter { food in
            food.description.localizedCaseInsensitiveContains(query)
        }
    }
    
    private func getDemoFoodDetails(fdcId: Int) -> USDAFoodDetails {
        let demoFood = getDemoFoods(matching: "").first { $0.fdcId == fdcId }
        
        return USDAFoodDetails(
            fdcId: fdcId,
            description: demoFood?.description ?? "Demo Food",
            dataType: "Demo",
            brandOwner: nil,
            foodNutrients: [
                USDANutrient(
                    nutrientId: 1008,
                    nutrientName: "Energy",
                    value: demoFood?.calories ?? 100,
                    unitName: "kcal"
                ),
                USDANutrient(
                    nutrientId: 1003,
                    nutrientName: "Protein",
                    value: demoFood?.protein ?? 10,
                    unitName: "g"
                ),
                USDANutrient(
                    nutrientId: 1005,
                    nutrientName: "Carbohydrate, by difference",
                    value: demoFood?.carbs ?? 15,
                    unitName: "g"
                ),
                USDANutrient(
                    nutrientId: 1004,
                    nutrientName: "Total lipid (fat)",
                    value: demoFood?.fat ?? 5,
                    unitName: "g"
                ),
                USDANutrient(
                    nutrientId: 1079,
                    nutrientName: "Fiber, total dietary",
                    value: demoFood?.fiber ?? 2,
                    unitName: "g"
                ),
                USDANutrient(
                    nutrientId: 1093,
                    nutrientName: "Sodium, Na",
                    value: demoFood?.sodium ?? 50,
                    unitName: "mg"
                )
            ],
            foodPortions: [
                FoodPortion(
                    id: 1,
                    description: "100 g",
                    gramWeight: 100,
                    modifier: "",
                    isDefault: true
                ),
                FoodPortion(
                    id: 2,
                    description: "1 serving",
                    gramWeight: 85,
                    modifier: "",
                    isDefault: false
                )
            ]
        )
    }
    
    private func extractNutritionInfo(from foodDetails: USDAFoodDetails) -> NutritionInfo {
        var calories: Double = 0
        var protein: Double = 0
        var carbs: Double = 0
        var fat: Double = 0
        var fiber: Double = 0
        var sodium: Double = 0
        
        for nutrient in foodDetails.foodNutrients {
            guard let value = nutrient.value else { continue }
            
            switch nutrient.nutrientId {
            case 1008: calories = value
            case 1003: protein = value
            case 1005: carbs = value
            case 1004: fat = value
            case 1079: fiber = value
            case 1093: sodium = value
            default: break
            }
        }
        
        return NutritionInfo(
            calories: calories,
            protein: protein,
            carbs: carbs,
            fat: fat,
            fiber: fiber,
            sodium: sodium
        )
    }
}

// MARK: - USDA Data Models

struct USDAFood: Codable, Identifiable {
    let fdcId: Int
    let description: String
    let dataType: String?
    let brandOwner: String?
    let calories: Double
    let protein: Double
    let carbs: Double
    let fat: Double
    let fiber: Double
    let sodium: Double
    
    var id: Int { fdcId }
    
    // Available portions for this food
    var availablePortions: [FoodPortion] {
        return [
            FoodPortion(id: 1, description: "100 g", gramWeight: 100, modifier: "", isDefault: true),
            FoodPortion(id: 2, description: "1 serving", gramWeight: 85, modifier: "typical", isDefault: false),
            FoodPortion(id: 3, description: "1 portion", gramWeight: 75, modifier: "small", isDefault: false)
        ]
    }
}

struct USDAFoodDetails: Codable {
    let fdcId: Int
    let description: String
    let dataType: String?
    let brandOwner: String?
    let foodNutrients: [USDANutrient]
    let foodPortions: [FoodPortion]?
}

struct USDANutrient: Codable {
    let nutrientId: Int?
    let nutrientName: String?
    let value: Double?
    let unitName: String?
}

struct FoodPortion: Codable, Identifiable {
    let id: Int
    let description: String
    let gramWeight: Double
    let modifier: String
    let isDefault: Bool
    
    // Calculate nutrition for this portion
    func calculateNutrients(from food: USDAFood) -> PortionNutrients {
        let multiplier = gramWeight / 100.0
        
        return PortionNutrients(
            portion: self,
            calories: food.calories * multiplier,
            protein: food.protein * multiplier,
            carbs: food.carbs * multiplier,
            fat: food.fat * multiplier,
            fiber: food.fiber * multiplier,
            sodium: food.sodium * multiplier
        )
    }
}

struct PortionNutrients {
    let portion: FoodPortion
    let calories: Double
    let protein: Double
    let carbs: Double
    let fat: Double
    let fiber: Double
    let sodium: Double
}

// MARK: - USDA API Request Models

struct USDASearchRequest: Codable {
    let query: String
    let pageSize: Int
    let pageNumber: Int
    let dataType: [String]
    let api_key: String
}

struct USDASearchResponse: Codable {
    let foods: [USDAFood]
    let totalHits: Int
    let currentPage: Int
    let totalPages: Int
}

// MARK: - USDA Errors

enum USDAError: Error, LocalizedError {
    case invalidURL
    case networkError
    case serverError(Int)
    case invalidResponse
    case noAPIKey
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL for USDA API"
        case .networkError:
            return "Network error connecting to USDA API"
        case .serverError(let code):
            return "USDA API server error: \(code)"
        case .invalidResponse:
            return "Invalid response from USDA API"
        case .noAPIKey:
            return "USDA API key not configured"
        }
    }
}

// MARK: - Extension for Food Conversions

extension USDAFood {
    func toNutritionInfo() -> NutritionInfo {
        return NutritionInfo(
            calories: calories,
            protein: protein,
            carbs: carbs,
            fat: fat,
            fiber: fiber,
            sodium: sodium
        )
    }
}

// MARK: - Additional Supporting Types

struct USDANutritionSearchResult {
    let food: USDAFood
    let confidence: Double
    let nutritionInfo: NutritionInfo
}

// MARK: - Food Matching Utilities

extension USDAFoodService {
    
    // Find best matches for a food name
    func findBestMatches(for foodName: String, limit: Int = 5) async throws -> [USDANutritionSearchResult] {
        let foods = try await searchFoods(query: foodName, pageSize: limit)
        
        return foods.map { food in
            let confidence = calculateMatchConfidence(searchTerm: foodName, foodDescription: food.description)
            return USDANutritionSearchResult(
                food: food,
                confidence: confidence,
                nutritionInfo: food.toNutritionInfo()
            )
        }.sorted { $0.confidence > $1.confidence }
    }
    
    private func calculateMatchConfidence(searchTerm: String, foodDescription: String) -> Double {
        let searchWords = searchTerm.lowercased().components(separatedBy: .whitespaces)
        let descriptionWords = foodDescription.lowercased().components(separatedBy: .whitespaces)
        
        let commonWords = Set(searchWords).intersection(Set(descriptionWords))
        let totalWords = Set(searchWords).union(Set(descriptionWords))
        
        return Double(commonWords.count) / Double(totalWords.count)
    }
}

// Note: NutritionInfo is defined in USDAVerifiedMealPlanningService.swift
