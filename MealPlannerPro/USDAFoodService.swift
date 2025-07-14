import Foundation

class USDAFoodService: ObservableObject {
    private let apiKey = "example"
    private let baseURL = "https://api.nal.usda.gov/fdc/v1"
    
    private lazy var urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30.0
        config.timeoutIntervalForResource = 60.0
        return URLSession(configuration: config)
    }()
    
    func searchFoods(query: String, limit: Int = 10) async throws -> [USDAFood] {
        var components = URLComponents(string: "\(baseURL)/foods/search")!
        components.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "pageSize", value: "10"),
            URLQueryItem(name: "dataType", value: "Foundation,Branded"),
            URLQueryItem(name: "nutrients", value: "203,204,205,208,269,291") // Key nutrients
        ]
        
        guard let url = components.url else {
            throw USDAError.invalidURL
        }
        
        print("🔍 Making request to: \(url.absoluteString)")
        
        do {
            let (data, response) = try await urlSession.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid response type")
                throw USDAError.invalidResponse
            }
            
            print("📡 HTTP Status Code: \(httpResponse.statusCode)")
            
            guard httpResponse.statusCode == 200 else {
                print("❌ HTTP Error: \(httpResponse.statusCode)")
                throw USDAError.serverError(httpResponse.statusCode)
            }
            
            let searchResult = try JSONDecoder().decode(USDASearchResponse.self, from: data)
            print("✅ Successfully decoded \(searchResult.foods.count) foods with portions")
            
            return searchResult.foods
            
        } catch {
            print("❌ Error: \(error)")
            throw error
        }
    }
    
    func getFoodNutrition(fdcId: Int) async throws -> NutritionInfo {
        // For now, return a placeholder since we don't have the specific fdcId lookup endpoint
        // In a real implementation, this would call the USDA API to get detailed nutrition for a specific food
        
        // Mock nutrition data based on fdcId (this should be replaced with actual API call)
        switch fdcId {
        case 171077: // Chicken breast
            return NutritionInfo(calories: 165, protein: 31, carbs: 0, fat: 3.6, fiber: 0, sodium: 74)
        case 168878: // Brown rice
            return NutritionInfo(calories: 111, protein: 2.6, carbs: 23, fat: 0.9, fiber: 1.8, sodium: 5)
        case 170379: // Broccoli
            return NutritionInfo(calories: 34, protein: 2.8, carbs: 7, fat: 0.4, fiber: 2.6, sodium: 33)
        case 171413: // Olive oil
            return NutritionInfo(calories: 884, protein: 0, carbs: 0, fat: 100, fiber: 0, sodium: 2)
        default:
            return NutritionInfo(calories: 100, protein: 5, carbs: 15, fat: 2, fiber: 1, sodium: 50)
        }
    }
}

import Foundation

// MARK: - Enhanced USDA Food Model with Portions
struct USDAFood: Codable, Identifiable {
    let fdcId: Int
    let description: String
    let dataType: String?
    let brandOwner: String?
    let foodNutrients: [USDANutrient]
    let foodPortions: [USDAFoodPortion]? // Added this!
    
    var id: Int { fdcId }
    
    // Base nutrition per 100g (USDA standard)
    var calories: Double {
        return findNutrient(names: ["Energy", "Calories"]) ?? 0
    }
    
    var protein: Double {
        return findNutrient(names: ["Protein"]) ?? 0
    }
    
    var carbs: Double {
        return findNutrient(names: ["Carbohydrate", "Total carbohydrate"]) ?? 0
    }
    
    var fat: Double {
        return findNutrient(names: ["Total lipid", "Fat", "Total fat"]) ?? 0
    }
    
    var fiber: Double {
        return findNutrient(names: ["Fiber", "Dietary fiber"]) ?? 0
    }
    
    var sodium: Double {
        return findNutrient(names: ["Sodium"]) ?? 0
    }
    
    // Get all available portions for this food
    var availablePortions: [FoodPortion] {
        var portions: [FoodPortion] = []
        
        // Always include 100g as default
        portions.append(FoodPortion(
            id: "100g",
            description: "100 grams",
            gramWeight: 100.0,
            modifier: "per 100g",
            isDefault: true
        ))
        
        // Add USDA portions if available
        if let usdaPortions = foodPortions {
            for (index, portion) in usdaPortions.enumerated() {
                portions.append(FoodPortion(
                    id: "usda_\(index)",
                    description: portion.portionDescription ?? "Portion \(index + 1)",
                    gramWeight: portion.gramWeight,
                    modifier: portion.modifier ?? "",
                    isDefault: false
                ))
            }
        }
        
        // Add common portions if none exist
        if portions.count == 1 {
            portions.append(contentsOf: generateCommonPortions())
        }
        
        return portions
    }
    
    // Generate common portions based on food type
    private func generateCommonPortions() -> [FoodPortion] {
        let foodDesc = description.lowercased()
        var portions: [FoodPortion] = []
        
        // Fruits
        if foodDesc.contains("apple") {
            portions.append(FoodPortion(id: "medium", description: "1 medium apple", gramWeight: 182, modifier: "medium", isDefault: false))
            portions.append(FoodPortion(id: "large", description: "1 large apple", gramWeight: 223, modifier: "large", isDefault: false))
            portions.append(FoodPortion(id: "cup_sliced", description: "1 cup, sliced", gramWeight: 125, modifier: "cup sliced", isDefault: false))
        }
        else if foodDesc.contains("banana") {
            portions.append(FoodPortion(id: "medium", description: "1 medium banana", gramWeight: 118, modifier: "medium", isDefault: false))
            portions.append(FoodPortion(id: "large", description: "1 large banana", gramWeight: 136, modifier: "large", isDefault: false))
            portions.append(FoodPortion(id: "cup_sliced", description: "1 cup, sliced", gramWeight: 150, modifier: "cup sliced", isDefault: false))
        }
        // Vegetables
        else if foodDesc.contains("broccoli") {
            portions.append(FoodPortion(id: "cup_chopped", description: "1 cup, chopped", gramWeight: 91, modifier: "cup chopped", isDefault: false))
            portions.append(FoodPortion(id: "spear", description: "1 spear", gramWeight: 31, modifier: "spear", isDefault: false))
        }
        // Grains
        else if foodDesc.contains("rice") {
            portions.append(FoodPortion(id: "cup_cooked", description: "1 cup, cooked", gramWeight: 158, modifier: "cup cooked", isDefault: false))
            portions.append(FoodPortion(id: "half_cup", description: "1/2 cup, cooked", gramWeight: 79, modifier: "1/2 cup cooked", isDefault: false))
        }
        // Proteins
        else if foodDesc.contains("chicken") && foodDesc.contains("breast") {
            portions.append(FoodPortion(id: "piece", description: "1 piece (172g)", gramWeight: 172, modifier: "piece", isDefault: false))
            portions.append(FoodPortion(id: "3oz", description: "3 oz", gramWeight: 85, modifier: "3 oz", isDefault: false))
            portions.append(FoodPortion(id: "cup_diced", description: "1 cup, diced", gramWeight: 140, modifier: "cup diced", isDefault: false))
        }
        // Dairy
        else if foodDesc.contains("milk") {
            portions.append(FoodPortion(id: "cup", description: "1 cup", gramWeight: 244, modifier: "cup", isDefault: false))
            portions.append(FoodPortion(id: "half_cup", description: "1/2 cup", gramWeight: 122, modifier: "1/2 cup", isDefault: false))
        }
        // Generic portions
        else {
            portions.append(FoodPortion(id: "serving", description: "1 serving", gramWeight: 85, modifier: "serving", isDefault: false))
            portions.append(FoodPortion(id: "cup", description: "1 cup", gramWeight: 125, modifier: "cup", isDefault: false))
            portions.append(FoodPortion(id: "oz", description: "1 oz", gramWeight: 28, modifier: "oz", isDefault: false))
        }
        
        return portions
    }
    
    // Helper function to find nutrients by name
    private func findNutrient(names: [String]) -> Double? {
        for nutrient in foodNutrients {
            for name in names {
                if nutrient.nutrientName.lowercased().contains(name.lowercased()) {
                    return nutrient.value
                }
            }
        }
        return nil
    }
}

// MARK: - USDA Food Portion Model
struct USDAFoodPortion: Codable {
    let id: Int?
    let portionDescription: String?
    let modifier: String?
    let gramWeight: Double
    let sequenceNumber: Int?
    let minYearAcquired: Int?
}

// MARK: - Standardized Food Portion Model
struct FoodPortion: Identifiable, Hashable {
    let id: String
    let description: String
    let gramWeight: Double
    let modifier: String
    let isDefault: Bool
    
    // Calculate nutrition values for this portion
    func calculateNutrients(from baseFood: USDAFood) -> PortionNutrients {
        let multiplier = gramWeight / 100.0 // Convert from per-100g base
        
        return PortionNutrients(
            portion: self,
            calories: baseFood.calories * multiplier,
            protein: baseFood.protein * multiplier,
            carbs: baseFood.carbs * multiplier,
            fat: baseFood.fat * multiplier,
            fiber: baseFood.fiber * multiplier,
            sodium: baseFood.sodium * multiplier,
            // Calculate all other nutrients
            allNutrients: baseFood.foodNutrients.compactMap { nutrient in
                guard let value = nutrient.value else { return nil }
                return CalculatedNutrient(
                    name: nutrient.nutrientName,
                    value: value * multiplier,
                    unit: nutrient.unitName,
                    originalValue: value
                )
            }
        )
    }
}

// MARK: - Calculated Nutrients for Specific Portion
struct PortionNutrients {
    let portion: FoodPortion
    let calories: Double
    let protein: Double
    let carbs: Double
    let fat: Double
    let fiber: Double
    let sodium: Double
    let allNutrients: [CalculatedNutrient]
}

struct CalculatedNutrient {
    let name: String
    let value: Double
    let unit: String
    let originalValue: Double // Original per-100g value
}

struct USDANutrient: Codable {
    let nutrientId: Int?
    let nutrientName: String
    let value: Double?
    let unitName: String
}

struct USDASearchResponse: Codable {
    let foods: [USDAFood]
    let totalHits: Int?
    let currentPage: Int?
    let totalPages: Int?
}

enum USDAError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case networkError
    case dataParsingError
    case rateLimitExceeded
    case serverError(Int)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL created"
        case .invalidResponse:
            return "Invalid response from server"
        case .networkError:
            return "Network connection error"
        case .dataParsingError:
            return "Could not parse response data"
        case .rateLimitExceeded:
            return "API rate limit exceeded. Please wait before trying again."
        case .serverError(let code):
            return "Server error with code: \(code)"
        }
    }
}
