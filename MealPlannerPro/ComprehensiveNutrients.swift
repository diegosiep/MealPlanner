//
//  ComprehensiveNutrients.swift
//  MealPlannerPro
//
//  Created by Diego Sierra on 03/07/25.
//

import Foundation


import Foundation

// MARK: - Complete Nutrient Model (Based on USDA FoodData Central)
struct ComprehensiveNutrients: Codable {
    // MARK: - Macronutrients & Energy
    var energy: Double = 0 // kcal
    var protein: Double = 0 // g
    var totalFat: Double = 0 // g
    var carbohydrate: Double = 0 // g
    var fiber: Double = 0 // g
    var sugars: Double = 0 // g
    var addedSugars: Double = 0 // g
    
    // MARK: - Fats (Detailed)
    var saturatedFat: Double = 0 // g
    var monounsaturatedFat: Double = 0 // g
    var polyunsaturatedFat: Double = 0 // g
    var transFat: Double = 0 // g
    var cholesterol: Double = 0 // mg
    
    // MARK: - Water Soluble Vitamins
    var vitaminC: Double = 0 // mg (Ascorbic acid)
    var thiamin: Double = 0 // mg (B1)
    var riboflavin: Double = 0 // mg (B2)
    var niacin: Double = 0 // mg (B3)
    var pantothenicAcid: Double = 0 // mg (B5)
    var vitaminB6: Double = 0 // mg
    var biotin: Double = 0 // mcg (B7)
    var folate: Double = 0 // mcg DFE
    var vitaminB12: Double = 0 // mcg
    var choline: Double = 0 // mg
    
    // MARK: - Fat Soluble Vitamins
    var vitaminA: Double = 0 // mcg RAE
    var vitaminD: Double = 0 // mcg (D2 + D3)
    var vitaminE: Double = 0 // mg alpha-tocopherol
    var vitaminK: Double = 0 // mcg
    
    // MARK: - Major Minerals
    var calcium: Double = 0 // mg
    var phosphorus: Double = 0 // mg
    var magnesium: Double = 0 // mg
    var sodium: Double = 0 // mg
    var potassium: Double = 0 // mg
    var chloride: Double = 0 // mg
    var sulfur: Double = 0 // mg
    
    // MARK: - Trace Minerals
    var iron: Double = 0 // mg
    var zinc: Double = 0 // mg
    var copper: Double = 0 // mg
    var manganese: Double = 0 // mg
    var iodine: Double = 0 // mcg
    var selenium: Double = 0 // mcg
    var chromium: Double = 0 // mcg
    var molybdenum: Double = 0 // mcg
    var fluoride: Double = 0 // mg
    var boron: Double = 0 // mg
    var cobalt: Double = 0 // mcg
    var nickel: Double = 0 // mcg
    
    // MARK: - Other Compounds
    var caffeine: Double = 0 // mg
    var alcohol: Double = 0 // g
    var organicAcids: Double = 0 // g
    
    // MARK: - Amino Acids (Essential)
    var histidine: Double = 0 // g
    var isoleucine: Double = 0 // g
    var leucine: Double = 0 // g
    var lysine: Double = 0 // g
    var methionine: Double = 0 // g
    var phenylalanine: Double = 0 // g
    var threonine: Double = 0 // g
    var tryptophan: Double = 0 // g
    var valine: Double = 0 // g
    
    // MARK: - Fatty Acids (Specific)
    var omega3: Double = 0 // g
    var omega6: Double = 0 // g
    var dha: Double = 0 // g (Docosahexaenoic acid)
    var epa: Double = 0 // g (Eicosapentaenoic acid)
    var ala: Double = 0 // g (Alpha-linolenic acid)
}

// MARK: - USDA Nutrient ID Mapping
struct USDANutrientMapping {
    static let nutrientMap: [Int: WritableKeyPath<ComprehensiveNutrients, Double>] = [
        1008: \.energy, // Energy (kcal)
        1003: \.protein, // Protein
        1004: \.totalFat, // Total lipid (fat)
        1005: \.carbohydrate, // Carbohydrate, by difference
        1079: \.fiber, // Fiber, total dietary
        2000: \.sugars, // Sugars, total
        1258: \.saturatedFat, // Fatty acids, total saturated
        1268: \.monounsaturatedFat, // Fatty acids, total monounsaturated
        1269: \.polyunsaturatedFat, // Fatty acids, total polyunsaturated
        1257: \.cholesterol, // Cholesterol
        
        // Water-soluble vitamins
        1162: \.vitaminC, // Vitamin C, total ascorbic acid
        1165: \.thiamin, // Thiamin
        1166: \.riboflavin, // Riboflavin
        1167: \.niacin, // Niacin
        1170: \.pantothenicAcid, // Pantothenic acid
        1175: \.vitaminB6, // Vitamin B-6
        1177: \.folate, // Folate, DFE
        1178: \.vitaminB12, // Vitamin B-12
        1180: \.choline, // Choline, total
        
        // Fat-soluble vitamins
        1106: \.vitaminA, // Vitamin A, RAE
        1114: \.vitaminD, // Vitamin D (D2 + D3)
        1109: \.vitaminE, // Vitamin E (alpha-tocopherol)
        1185: \.vitaminK, // Vitamin K (phylloquinone)
        
        // Major minerals
        1087: \.calcium, // Calcium, Ca
        1091: \.phosphorus, // Phosphorus, P
        1090: \.magnesium, // Magnesium, Mg
        1093: \.sodium, // Sodium, Na
        1092: \.potassium, // Potassium, K
        
        // Trace minerals
        1089: \.iron, // Iron, Fe
        1095: \.zinc, // Zinc, Zn
        1098: \.copper, // Copper, Cu
        1101: \.manganese, // Manganese, Mn
        1100: \.selenium, // Selenium, Se
        1102: \.fluoride, // Fluoride, F
        
        // Other
        1057: \.caffeine, // Caffeine
        1018: \.alcohol, // Alcohol, ethyl
    ]
    
    static func extractNutrients(from usdaFoodNutrients: [USDANutrient]) -> ComprehensiveNutrients {
        var nutrients = ComprehensiveNutrients()
        
        for nutrient in usdaFoodNutrients {
            if let nutrientId = nutrient.nutrientId,
               let keyPath = nutrientMap[nutrientId],
               let value = nutrient.value {
                nutrients[keyPath: keyPath] = value
            }
        }
        
        return nutrients
    }
}
