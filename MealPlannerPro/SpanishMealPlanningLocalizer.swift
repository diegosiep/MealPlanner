// Enhanced Spanish Localization for Meal Planning
import Foundation

// MARK: - Comprehensive Spanish Localization
struct SpanishMealPlanningLocalizer {
    
    // MARK: - Food Name Translation
    static let foodTranslations: [String: String] = [
        // Proteins
        "chicken": "pollo",
        "chicken breast": "pechuga de pollo",
        "salmon": "salmón",
        "cod": "bacalao",
        "tuna": "atún",
        "beef": "carne de res",
        "turkey": "pavo",
        "eggs": "huevos",
        "tofu": "tofu",
        
        // Vegetables
        "spinach": "espinacas",
        "broccoli": "brócoli",
        "lettuce": "lechuga",
        "tomato": "tomate",
        "onion": "cebolla",
        "garlic": "ajo",
        "carrot": "zanahoria",
        "pepper": "pimiento",
        "zucchini": "calabacín",
        "cucumber": "pepino",
        
        // Grains & Starches
        "rice": "arroz",
        "brown rice": "arroz integral",
        "quinoa": "quinoa",
        "bread": "pan",
        "pasta": "pasta",
        "potato": "papa",
        "sweet potato": "camote",
        
        // Fruits
        "apple": "manzana",
        "banana": "plátano",
        "orange": "naranja",
        "berries": "frutos del bosque",
        "strawberry": "fresa",
        "avocado": "aguacate",
        "lemon": "limón",
        "lime": "lima",
        
        // Dairy & Fats
        "milk": "leche",
        "cheese": "queso",
        "yogurt": "yogur",
        "olive oil": "aceite de oliva",
        "butter": "mantequilla",
        
        // Cooking Methods
        "grilled": "a la parrilla",
        "baked": "horneado",
        "sautéed": "salteado",
        "steamed": "al vapor",
        "boiled": "hervido",
        "roasted": "asado",
        "fried": "frito"
    ]
    
    // MARK: - Measurement Translations
    static let measurementTranslations: [String: String] = [
        "cup": "taza",
        "cups": "tazas",
        "tablespoon": "cucharada",
        "tablespoons": "cucharadas",
        "teaspoon": "cucharadita",
        "teaspoons": "cucharaditas",
        "ounce": "onza",
        "ounces": "onzas",
        "pound": "libra",
        "pounds": "libras",
        "piece": "pieza",
        "pieces": "piezas",
        "slice": "rebanada",
        "slices": "rebanadas",
        "gram": "gramo",
        "grams": "gramos",
        "kilogram": "kilogramo",
        "kilograms": "kilogramos",
        "liter": "litro",
        "liters": "litros",
        "milliliter": "mililitro",
        "milliliters": "mililitros"
    ]
    
    // MARK: - Cooking Instructions in Spanish
    static let cookingInstructions: [String: String] = [
        "heat oil": "calentar aceite",
        "add garlic": "agregar ajo",
        "season with": "sazonar con",
        "cook until": "cocinar hasta",
        "serve hot": "servir caliente",
        "let cool": "dejar enfriar",
        "mix well": "mezclar bien",
        "bring to boil": "llevar a ebullición",
        "simmer": "cocinar a fuego lento",
        "drain": "escurrir",
        "rinse": "enjuagar",
        "chop": "picar",
        "dice": "cortar en cubos",
        "slice": "rebanar",
        "mince": "picar finamente"
    ]
    
    // MARK: - Recipe Templates in Spanish
    static let recipeTemplates: [MealType: RecipeTemplate] = [
        .breakfast: RecipeTemplate(
            structure: "Para el {meal_name}, necesitarás:",
            ingredientFormat: "• {amount} de {ingredient}",
            instructionsStart: "Preparación:",
            instructionsFormat: "{step_number}. {instruction}",
            servingInfo: "Rinde: 1 porción | Tiempo: {time} minutos",
            nutritionSummary: "Aporte nutricional: {calories} calorías, {protein}g proteína, {carbs}g carbohidratos, {fat}g grasa"
        ),
        .lunch: RecipeTemplate(
            structure: "Para preparar {meal_name}:",
            ingredientFormat: "• {amount} de {ingredient}",
            instructionsStart: "Modo de preparación:",
            instructionsFormat: "{step_number}. {instruction}",
            servingInfo: "Porciones: 1 | Tiempo de preparación: {time} minutos",
            nutritionSummary: "Información nutricional: {calories} kcal, {protein}g proteína, {carbs}g carbohidratos, {fat}g grasa"
        ),
        .dinner: RecipeTemplate(
            structure: "Receta para {meal_name}:",
            ingredientFormat: "• {amount} de {ingredient}",
            instructionsStart: "Instrucciones:",
            instructionsFormat: "{step_number}. {instruction}",
            servingInfo: "Para: 1 persona | Duración: {time} minutos",
            nutritionSummary: "Valores nutricionales: {calories} calorías, {protein}g proteína, {carbs}g carbohidratos, {fat}g grasa"
        ),
        .snack: RecipeTemplate(
            structure: "Para esta {meal_name} necesitas:",
            ingredientFormat: "• {amount} de {ingredient}",
            instructionsStart: "Preparación rápida:",
            instructionsFormat: "{step_number}. {instruction}",
            servingInfo: "Porción individual | Tiempo: {time} minutos",
            nutritionSummary: "Aporte: {calories} calorías, {protein}g proteína, {carbs}g carbohidratos, {fat}g grasa"
        )
    ]
    
    // MARK: - Translation Functions
    static func translateFoodName(_ englishName: String) -> String {
        let lowercaseName = englishName.lowercased()
        
        for (english, spanish) in foodTranslations {
            if lowercaseName.contains(english) {
                return lowercaseName.replacingOccurrences(of: english, with: spanish)
            }
        }
        
        return englishName // Return original if no translation found
    }
    
    static func translateMeasurement(_ measurement: String) -> String {
        let components = measurement.lowercased().components(separatedBy: " ")
        var translatedComponents: [String] = []
        
        for component in components {
            if let translation = measurementTranslations[component] {
                translatedComponents.append(translation)
            } else {
                translatedComponents.append(component)
            }
        }
        
        return translatedComponents.joined(separator: " ")
    }
    
    static func generateSpanishRecipe(
        for meal: VerifiedMealPlanSuggestion,
        mealType: MealType
    ) -> SpanishRecipe {
        
        let template = recipeTemplates[mealType] ?? recipeTemplates[.lunch]!
        let translatedMealName = translateFoodName(meal.originalAISuggestion.name)
        
        // Translate ingredients
        var spanishIngredients: [SpanishIngredient] = []
        for food in meal.verifiedFoods {
            let spanishName = translateFoodName(food.originalAISuggestion.name)
            let spanishPortion = translateMeasurement(food.originalAISuggestion.portionDescription)
            
            spanishIngredients.append(SpanishIngredient(
                name: spanishName,
                amount: spanishPortion,
                calories: Int(food.verifiedNutrition.calories),
                isVerified: true // Always show as verified for now
            ))
        }
        
        // Generate Spanish cooking instructions
        let spanishInstructions = generateSpanishCookingInstructions(
            for: meal,
            ingredients: spanishIngredients
        )
        
        // Calculate estimated cooking time
        let cookingTime = estimateCookingTime(for: spanishIngredients, mealType: mealType)
        
        return SpanishRecipe(
            name: translatedMealName,
            mealType: mealType,
            ingredients: spanishIngredients,
            instructions: spanishInstructions,
            cookingTimeMinutes: cookingTime,
            servings: 1,
            nutrition: SpanishNutritionInfo(
                calories: Int(meal.verifiedTotalNutrition.calories),
                protein: Int(meal.verifiedTotalNutrition.protein),
                carbohydrates: Int(meal.verifiedTotalNutrition.carbs),
                fat: Int(meal.verifiedTotalNutrition.fat)
            ),
            difficulty: estimateDifficulty(for: spanishIngredients),
            tips: generateNutritionistTips(for: meal)
        )
    }
    
    private static func generateSpanishCookingInstructions(
        for meal: VerifiedMealPlanSuggestion,
        ingredients: [SpanishIngredient]
    ) -> [String] {
        
        var instructions: [String] = []
        
        // Analyze ingredients to determine cooking method
        let hasProtein = ingredients.contains { $0.name.contains("pollo") || $0.name.contains("salmón") || $0.name.contains("carne") }
        let hasVegetables = ingredients.contains { $0.name.contains("espinacas") || $0.name.contains("brócoli") || $0.name.contains("tomate") }
        let hasOil = ingredients.contains { $0.name.contains("aceite") }
        let hasRice = ingredients.contains { $0.name.contains("arroz") }
        
        // Generate contextual instructions
        if hasOil {
            instructions.append("Calentar el aceite en una sartén a fuego medio")
        }
        
        if hasProtein {
            let proteinIngredient = ingredients.first { $0.name.contains("pollo") || $0.name.contains("salmón") || $0.name.contains("carne") }
            if let protein = proteinIngredient {
                if protein.name.contains("pollo") {
                    instructions.append("Cocinar el pollo hasta que esté dorado y bien cocido (165°F interno)")
                } else if protein.name.contains("salmón") {
                    instructions.append("Cocinar el salmón 3-4 minutos por lado hasta que esté tierno")
                } else {
                    instructions.append("Cocinar la proteína según las indicaciones hasta que esté bien cocida")
                }
            }
        }
        
        if hasVegetables {
            instructions.append("Agregar las verduras y saltear hasta que estén tiernas pero crujientes")
        }
        
        if hasRice {
            instructions.append("Servir sobre el arroz previamente cocido")
        }
        
        instructions.append("Sazonar al gusto con sal, pimienta y especias preferidas")
        instructions.append("Servir inmediatamente mientras esté caliente")
        
        // Use original AI notes if available and translate them
        // Preparation notes not available in current SuggestedFood structure
        // if !meal.originalAISuggestion.preparationNotes.isEmpty {
        //     let translatedNotes = translateCookingNotes(meal.originalAISuggestion.preparationNotes)
        //     instructions.append("Nota especial: \(translatedNotes)")
        // }
        
        return instructions
    }
    
    private static func translateCookingNotes(_ englishNotes: String) -> String {
        var translatedNotes = englishNotes
        
        for (english, spanish) in cookingInstructions {
            translatedNotes = translatedNotes.replacingOccurrences(of: english, with: spanish)
        }
        
        return translatedNotes
    }
    
    private static func estimateCookingTime(for ingredients: [SpanishIngredient], mealType: MealType) -> Int {
        let baseTime: Int
        
        switch mealType {
        case .breakfast: baseTime = 10
        case .lunch: baseTime = 20
        case .dinner: baseTime = 25
        case .snack: baseTime = 5
        }
        
        // Add time for complex ingredients
        var additionalTime = 0
        for ingredient in ingredients {
            if ingredient.name.contains("arroz") {
                additionalTime += 15 // Rice takes time to cook
            } else if ingredient.name.contains("pollo") || ingredient.name.contains("carne") {
                additionalTime += 10 // Protein cooking time
            }
        }
        
        return min(baseTime + additionalTime, 45) // Cap at 45 minutes
    }
    
    private static func estimateDifficulty(for ingredients: [SpanishIngredient]) -> DifficultyLevel {
        let complexIngredients = ingredients.count
        
        if complexIngredients <= 3 {
            return .facil
        } else if complexIngredients <= 5 {
            return .intermedio
        } else {
            return .avanzado
        }
    }
    
    private static func generateNutritionistTips(for meal: VerifiedMealPlanSuggestion) -> [String] {
        var tips: [String] = []
        
        let nutrition = meal.verifiedTotalNutrition
        
        if nutrition.protein > 25 {
            tips.append("Rica en proteínas para el desarrollo muscular")
        }
        
        if nutrition.fat > 15 {
            tips.append("Contiene grasas saludables importantes para la absorción de vitaminas")
        }
        
        if nutrition.carbs > 30 {
            tips.append("Aporta energía de carbohidratos para actividades diarias")
        }
        
        // Add custom nutritionist notes if available
        // Nutritionist notes not available in current SuggestedFood structure
        // if !meal.originalAISuggestion.nutritionistNotes.isEmpty {
        //     tips.append(meal.originalAISuggestion.nutritionistNotes)
        // }
        
        return tips
    }
}

// MARK: - Spanish Recipe Data Models
struct SpanishRecipe {
    let name: String
    let mealType: MealType
    let ingredients: [SpanishIngredient]
    let instructions: [String]
    let cookingTimeMinutes: Int
    let servings: Int
    let nutrition: SpanishNutritionInfo
    let difficulty: DifficultyLevel
    let tips: [String]
}

struct SpanishIngredient {
    let name: String
    let amount: String
    let calories: Int
    let isVerified: Bool
}

struct SpanishNutritionInfo {
    let calories: Int
    let protein: Int
    let carbohydrates: Int
    let fat: Int
}

enum DifficultyLevel: String {
    case facil = "Fácil"
    case intermedio = "Intermedio"
    case avanzado = "Avanzado"
}

struct RecipeTemplate {
    let structure: String
    let ingredientFormat: String
    let instructionsStart: String
    let instructionsFormat: String
    let servingInfo: String
    let nutritionSummary: String
}
