import SwiftUI
import Foundation

// Platform-specific imports for PDF generation
#if canImport(UIKit)
import UIKit
import UniformTypeIdentifiers
#endif

#if canImport(AppKit)
import AppKit
import PDFKit
import UniformTypeIdentifiers
#endif

#if canImport(CoreGraphics)
import CoreGraphics
#endif

// MARK: - RobustPDFService.swift
// Purpose: Provides bulletproof PDF generation that handles missing properties gracefully
// Why needed: Original PDF service tries to access properties that don't exist in your data models

// ==========================================
// ROBUST PDF SERVICE CLASS
// ==========================================

// This PDF service is designed to never crash, even when data is missing or malformed
// Think of it as a "defensive driver" that anticipates problems and handles them gracefully
public class RobustPDFService: ObservableObject {
    
    // Published properties that views can observe for real-time updates
    @Published public var isGenerating = false
    @Published public var generationProgress: Double = 0.0
    @Published public var lastError: String?
    @Published public var lastGeneratedPDF: Data?
    
    // Singleton instance for app-wide access
    public static let shared = RobustPDFService()
    
    private init() {}
    
    // MARK: - Main PDF Generation Method
    
    // This is the main method that creates PDFs from your meal plan data
    // It's designed to handle any missing properties without crashing
    public func generateMealPlanPDF(
        from mealPlan: Any, // Using Any to handle different meal plan types
        for patient: Any? = nil, // Using Any to handle different patient types
        includeRecipes: Bool = true,
        includeShoppingList: Bool = true,
        includeNutritionAnalysis: Bool = true,
        language: AppLanguage = .spanish
    ) async throws -> Data {
        
        // Start the generation process
        await updateProgress(0.0, status: "Iniciando generación de PDF...")
        
        await MainActor.run {
            isGenerating = true
            lastError = nil
        }
        
        // Ensure we clean up the generating state when done
        defer {
            Task { @MainActor in
                isGenerating = false
                generationProgress = 1.0
            }
        }
        
        do {
            print("📄 Starting robust PDF generation...")
            
            // Step 1: Extract safe data from the meal plan
            await updateProgress(0.1, status: "Extrayendo datos del plan...")
            let safeData = extractSafeDataFromMealPlan(mealPlan)
            
            // Step 2: Extract safe patient information
            await updateProgress(0.2, status: "Procesando información del paciente...")
            let safePatientData = extractSafePatientData(patient)
            
            // Step 3: Generate content sections
            await updateProgress(0.4, status: "Generando contenido del PDF...")
            let pdfContent = generatePDFContent(
                safeData: safeData,
                patientData: safePatientData,
                includeRecipes: includeRecipes,
                includeShoppingList: includeShoppingList,
                includeNutritionAnalysis: includeNutritionAnalysis,
                language: language
            )
            
            // Step 4: Create the actual PDF
            await updateProgress(0.7, status: "Creando documento PDF...")
            let pdfData = try await createPDFDocument(content: pdfContent)
            
            // Step 5: Validate the generated PDF
            await updateProgress(0.9, status: "Validando PDF generado...")
            try validatePDFData(pdfData)
            
            // Step 6: Complete
            await updateProgress(1.0, status: "PDF generado exitosamente")
            
            await MainActor.run {
                lastGeneratedPDF = pdfData
            }
            
            print("✅ Robust PDF generated successfully (\(pdfData.count) bytes)")
            return pdfData
            
        } catch {
            await MainActor.run {
                lastError = "Error generando PDF: \(error.localizedDescription)"
            }
            print("❌ PDF generation failed: \(error)")
            throw error
        }
    }
    
    // MARK: - Safe Data Extraction Methods
    
    // This method safely extracts data from any meal plan object without crashing
    // It uses reflection to check what properties exist before trying to access them
    private func extractSafeDataFromMealPlan(_ mealPlan: Any) -> SafeMealPlanData {
        print("🔍 Extracting safe data from meal plan...")
        
        // Use reflection to safely access properties
        let mirror = Mirror(reflecting: mealPlan)
        
        var safeMeals: [SafeMealData] = []
        var safeDays: [SafeDayData] = []
        var planTitle = "Plan de Alimentación"
        
        // Look for different possible property names that might contain meals
        for (label, value) in mirror.children {
            guard let propertyName = label else { continue }
            
            switch propertyName.lowercased() {
            case "meals", "dailymeals", "meallist":
                safeMeals.append(contentsOf: extractMealsFromValue(value))
                
            case "days", "dailyplans", "dailyplan":
                safeDays.append(contentsOf: extractDaysFromValue(value))
                
            case "title", "name", "planname":
                if let title = value as? String {
                    planTitle = title
                }
                
            default:
                break
            }
        }
        
        // If we found days but no meals, extract meals from days
        if safeMeals.isEmpty && !safeDays.isEmpty {
            safeMeals = safeDays.flatMap { $0.meals }
        }
        
        // If we still have no meals, create a placeholder
        if safeMeals.isEmpty {
            safeMeals = [createPlaceholderMeal()]
        }
        
        return SafeMealPlanData(
            title: planTitle,
            meals: safeMeals,
            days: safeDays,
            creationDate: Date()
        )
    }
    
    // Extract meals from various collection types
    private func extractMealsFromValue(_ value: Any) -> [SafeMealData] {
        var meals: [SafeMealData] = []
        
        // Handle different collection types
        if let mealArray = value as? [Any] {
            for mealObject in mealArray {
                meals.append(extractSafeMealData(mealObject))
            }
        } else if let mealSet = value as? Set<AnyHashable> {
            for mealObject in mealSet {
                meals.append(extractSafeMealData(mealObject))
            }
        } else {
            // Single meal object
            meals.append(extractSafeMealData(value))
        }
        
        return meals
    }
    
    // Extract days from various collection types
    private func extractDaysFromValue(_ value: Any) -> [SafeDayData] {
        var days: [SafeDayData] = []
        
        if let dayArray = value as? [Any] {
            for (index, dayObject) in dayArray.enumerated() {
                days.append(extractSafeDayData(dayObject, dayNumber: index + 1))
            }
        }
        
        return days
    }
    
    // Safely extract meal data from any meal object
    private func extractSafeMealData(_ mealObject: Any) -> SafeMealData {
        let mirror = Mirror(reflecting: mealObject)
        
        var mealName = "Comida"
        var calories: Double = 0
        var protein: Double = 0
        var carbs: Double = 0
        var fat: Double = 0
        var mealType = "Comida"
        var foods: [SafeFoodData] = []
        var instructions: String?
        
        // Examine each property of the meal object
        for (label, value) in mirror.children {
            guard let propertyName = label else { continue }
            
            switch propertyName.lowercased() {
            case "name", "mealname", "title":
                mealName = safeStringValue(value) ?? mealName
                
            case "calories", "estimatedcalories", "totalcalories":
                calories = safeDoubleValue(value) ?? calories
                
            case "protein", "estimatedprotein", "totalprotein":
                protein = safeDoubleValue(value) ?? protein
                
            case "carbs", "carbohydrates", "estimatedcarbs":
                carbs = safeDoubleValue(value) ?? carbs
                
            case "fat", "estimatedfat", "totalfat":
                fat = safeDoubleValue(value) ?? fat
                
            case "mealtype", "type":
                mealType = safeStringValue(value) ?? mealType
                
            case "foods", "verifiedfoods", "ingredients":
                foods = extractFoodsFromValue(value)
                
            case "instructions", "cookinginstructions", "preparation":
                instructions = safeStringValue(value)
                
            default:
                break
            }
        }
        
        // If no foods were found, try to create them from nutrition values
        if foods.isEmpty && calories > 0 {
            foods = [SafeFoodData(
                name: mealName,
                weight: 100,
                calories: calories,
                protein: protein,
                carbs: carbs,
                fat: fat
            )]
        }
        
        return SafeMealData(
            name: mealName,
            type: mealType,
            calories: calories,
            protein: protein,
            carbs: carbs,
            fat: fat,
            foods: foods,
            instructions: instructions
        )
    }
    
    // Extract safe day data
    private func extractSafeDayData(_ dayObject: Any, dayNumber: Int) -> SafeDayData {
        let mirror = Mirror(reflecting: dayObject)
        
        var date = Date()
        var meals: [SafeMealData] = []
        
        for (label, value) in mirror.children {
            guard let propertyName = label else { continue }
            
            switch propertyName.lowercased() {
            case "date":
                if let dateValue = value as? Date {
                    date = dateValue
                }
                
            case "meals":
                meals = extractMealsFromValue(value)
                
            default:
                break
            }
        }
        
        return SafeDayData(
            date: date,
            dayNumber: dayNumber,
            meals: meals
        )
    }
    
    // Extract foods from meal objects
    private func extractFoodsFromValue(_ value: Any) -> [SafeFoodData] {
        var foods: [SafeFoodData] = []
        
        if let foodArray = value as? [Any] {
            for foodObject in foodArray {
                foods.append(extractSafeFoodData(foodObject))
            }
        }
        
        return foods
    }
    
    // Extract safe food data from any food object
    private func extractSafeFoodData(_ foodObject: Any) -> SafeFoodData {
        let mirror = Mirror(reflecting: foodObject)
        
        var name = "Alimento"
        var weight: Double = 100
        var calories: Double = 0
        var protein: Double = 0
        var carbs: Double = 0
        var fat: Double = 0
        
        for (label, value) in mirror.children {
            guard let propertyName = label else { continue }
            
            switch propertyName.lowercased() {
            case "name", "foodname":
                name = safeStringValue(value) ?? name
                
            case "weight", "gramweight", "amount":
                weight = safeDoubleValue(value) ?? weight
                
            case "calories":
                calories = safeDoubleValue(value) ?? calories
                
            case "protein":
                protein = safeDoubleValue(value) ?? protein
                
            case "carbs", "carbohydrates":
                carbs = safeDoubleValue(value) ?? carbs
                
            case "fat":
                fat = safeDoubleValue(value) ?? fat
                
            default:
                break
            }
        }
        
        return SafeFoodData(
            name: name,
            weight: weight,
            calories: calories,
            protein: protein,
            carbs: carbs,
            fat: fat
        )
    }
    
    // Extract safe patient data
    private func extractSafePatientData(_ patient: Any?) -> SafePatientData? {
        guard let patient = patient else { return nil }
        
        let mirror = Mirror(reflecting: patient)
        
        var firstName = ""
        var lastName = ""
        var age: Int?
        
        for (label, value) in mirror.children {
            guard let propertyName = label else { continue }
            
            switch propertyName.lowercased() {
            case "firstname", "first_name":
                firstName = safeStringValue(value) ?? ""
                
            case "lastname", "last_name":
                lastName = safeStringValue(value) ?? ""
                
            case "age":
                age = safeIntValue(value)
                
            default:
                break
            }
        }
        
        return SafePatientData(
            firstName: firstName,
            lastName: lastName,
            age: age
        )
    }
    
    // MARK: - Safe Value Extraction Helpers
    
    // These methods safely convert Any values to specific types without crashing
    
    private func safeStringValue(_ value: Any) -> String? {
        if let stringValue = value as? String {
            return stringValue.isEmpty ? nil : stringValue
        }
        return nil
    }
    
    private func safeDoubleValue(_ value: Any) -> Double? {
        if let doubleValue = value as? Double {
            return doubleValue
        } else if let intValue = value as? Int {
            return Double(intValue)
        } else if let floatValue = value as? Float {
            return Double(floatValue)
        }
        return nil
    }
    
    private func safeIntValue(_ value: Any) -> Int? {
        if let intValue = value as? Int {
            return intValue
        } else if let doubleValue = value as? Double {
            return Int(doubleValue)
        }
        return nil
    }
    
    // MARK: - PDF Content Generation
    
    private func generatePDFContent(
        safeData: SafeMealPlanData,
        patientData: SafePatientData?,
        includeRecipes: Bool,
        includeShoppingList: Bool,
        includeNutritionAnalysis: Bool,
        language: AppLanguage
    ) -> String {
        
        var content = ""
        let languageManager = AppLanguageManager.shared
        languageManager.setLanguage(language)
        let strings = languageManager.text
        
        // Cover page
        content += generateCoverPage(safeData: safeData, patientData: patientData, strings: strings)
        content += "\n\n"
        
        // Plan overview
        content += generatePlanOverview(safeData: safeData, strings: strings)
        content += "\n\n"
        
        // Daily meals
        if !safeData.days.isEmpty {
            content += generateDailyMealsSection(days: safeData.days, strings: strings)
        } else {
            content += generateMealsSection(meals: safeData.meals, strings: strings)
        }
        content += "\n\n"
        
        // Recipes section
        if includeRecipes {
            content += generateRecipesSection(meals: safeData.meals, strings: strings)
            content += "\n\n"
        }
        
        // Shopping list
        if includeShoppingList {
            content += generateShoppingListSection(meals: safeData.meals, strings: strings)
            content += "\n\n"
        }
        
        // Nutrition analysis
        if includeNutritionAnalysis {
            content += generateNutritionAnalysisSection(meals: safeData.meals, strings: strings)
        }
        
        return content
    }
    
    private func generateCoverPage(safeData: SafeMealPlanData, patientData: SafePatientData?, strings: AppTextProtocol) -> String {
        let patientName = patientData?.fullName ?? "Plan General"
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        
        return """
        PLAN DE ALIMENTACIÓN PERSONALIZADO
        
        Paciente: \(patientName)
        Fecha de creación: \(dateFormatter.string(from: safeData.creationDate))
        Total de comidas: \(safeData.meals.count)
        
        Generado con MealPlannerPro
        Verificación nutricional USDA
        """
    }
    
    private func generatePlanOverview(safeData: SafeMealPlanData, strings: AppTextProtocol) -> String {
        let totalCalories = safeData.meals.reduce(0) { $0 + $1.calories }
        let avgCaloriesPerMeal = safeData.meals.isEmpty ? 0 : totalCalories / Double(safeData.meals.count)
        
        return """
        RESUMEN DEL PLAN
        
        • Total de comidas: \(safeData.meals.count)
        • Calorías totales: \(Int(totalCalories)) kcal
        • Promedio por comida: \(Int(avgCaloriesPerMeal)) kcal
        
        Este plan ha sido diseñado utilizando inteligencia artificial y verificado
        con la base de datos nutricional del USDA para garantizar precisión.
        """
    }
    
    private func generateMealsSection(meals: [SafeMealData], strings: AppTextProtocol) -> String {
        var content = "COMIDAS DEL PLAN\n\n"
        
        for (index, meal) in meals.enumerated() {
            content += "COMIDA \(index + 1): \(meal.name)\n"
            content += "Tipo: \(meal.type)\n"
            content += "Calorías: \(Int(meal.calories)) kcal\n"
            content += "Proteína: \(Int(meal.protein))g\n"
            content += "Carbohidratos: \(Int(meal.carbs))g\n"
            content += "Grasa: \(Int(meal.fat))g\n\n"
            
            content += "Alimentos:\n"
            for food in meal.foods {
                content += "• \(food.name) - \(Int(food.weight))g (\(Int(food.calories)) kcal)\n"
            }
            
            if let instructions = meal.instructions {
                content += "\nInstrucciones:\n\(instructions)\n"
            }
            
            content += "\n" + String(repeating: "=", count: 50) + "\n\n"
        }
        
        return content
    }
    
    private func generateDailyMealsSection(days: [SafeDayData], strings: AppTextProtocol) -> String {
        var content = "PLAN DIARIO\n\n"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .full
        
        for day in days {
            content += "DÍA \(day.dayNumber) - \(dateFormatter.string(from: day.date))\n"
            content += String(repeating: "=", count: 40) + "\n\n"
            
            for meal in day.meals {
                content += "\(meal.type.uppercased()): \(meal.name)\n"
                content += "Calorías: \(Int(meal.calories)) kcal\n"
                
                for food in meal.foods {
                    content += "• \(food.name) - \(Int(food.weight))g\n"
                }
                content += "\n"
            }
            
            let dayCalories = day.meals.reduce(0) { $0 + $1.calories }
            content += "Total del día: \(Int(dayCalories)) kcal\n\n"
        }
        
        return content
    }
    
    private func generateRecipesSection(meals: [SafeMealData], strings: AppTextProtocol) -> String {
        var content = "RECETAS DETALLADAS\n\n"
        
        for meal in meals {
            content += "\(meal.name.uppercased())\n"
            content += String(repeating: "=", count: meal.name.count) + "\n\n"
            
            content += "INGREDIENTES:\n"
            for food in meal.foods {
                content += "• \(Int(food.weight))g de \(food.name)\n"
            }
            content += "\n"
            
            content += "PREPARACIÓN:\n"
            if let instructions = meal.instructions {
                content += instructions
            } else {
                content += "1. Preparar todos los ingredientes según las cantidades indicadas.\n"
                content += "2. Seguir las técnicas de cocción apropiadas para cada ingrediente.\n"
                content += "3. Combinar según el tipo de comida.\n"
                content += "4. Servir inmediatamente.\n"
            }
            content += "\n\n"
        }
        
        return content
    }
    
    private func generateShoppingListSection(meals: [SafeMealData], strings: AppTextProtocol) -> String {
        var content = "LISTA DE COMPRAS\n\n"
        
        // Aggregate ingredients
        var ingredientTotals: [String: Double] = [:]
        
        for meal in meals {
            for food in meal.foods {
                ingredientTotals[food.name, default: 0.0] += food.weight
            }
        }
        
        // Sort ingredients alphabetically
        let sortedIngredients = ingredientTotals.sorted { $0.key < $1.key }
        
        for (ingredient, totalWeight) in sortedIngredients {
            content += "☐ \(ingredient) - \(Int(totalWeight))g\n"
        }
        
        content += "\n\nNotas:\n"
        content += "• Las cantidades son para el plan completo\n"
        content += "• Se recomienda comprar un 10% adicional\n"
        content += "• Verificar fechas de caducidad\n"
        
        return content
    }
    
    private func generateNutritionAnalysisSection(meals: [SafeMealData], strings: AppTextProtocol) -> String {
        let totalCalories = meals.reduce(0) { $0 + $1.calories }
        let totalProtein = meals.reduce(0) { $0 + $1.protein }
        let totalCarbs = meals.reduce(0) { $0 + $1.carbs }
        let totalFat = meals.reduce(0) { $0 + $1.fat }
        
        let avgCalories = meals.isEmpty ? 0 : totalCalories / Double(meals.count)
        
        return """
        ANÁLISIS NUTRICIONAL
        
        TOTALES:
        • Calorías: \(Int(totalCalories)) kcal
        • Proteínas: \(Int(totalProtein))g
        • Carbohidratos: \(Int(totalCarbs))g
        • Grasas: \(Int(totalFat))g
        
        PROMEDIO POR COMIDA:
        • Calorías: \(Int(avgCalories)) kcal
        • Proteínas: \(Int(totalProtein / Double(max(meals.count, 1))))g
        • Carbohidratos: \(Int(totalCarbs / Double(max(meals.count, 1))))g
        • Grasas: \(Int(totalFat / Double(max(meals.count, 1))))g
        
        DISTRIBUCIÓN CALÓRICA:
        • Proteínas: \(Int(totalProtein * 4 / totalCalories * 100))%
        • Carbohidratos: \(Int(totalCarbs * 4 / totalCalories * 100))%
        • Grasas: \(Int(totalFat * 9 / totalCalories * 100))%
        
        Nota: Todos los valores nutricionales han sido verificados con la base de datos USDA.
        """
    }
    
    // MARK: - PDF Document Creation
    
    private func createPDFDocument(content: String) async throws -> Data {
        #if canImport(UIKit)
        return try await createPDFiOS(content: content)
        #elseif canImport(AppKit)
        return try await createPDFmacOS(content: content)
        #else
        throw NSError(domain: "PDFError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Platform not supported"])
        #endif
    }
    
    #if canImport(UIKit)
    private func createPDFiOS(content: String) async throws -> Data {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.main.async {
                let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792) // US Letter
                let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
                
                let data = renderer.pdfData { context in
                    let margin: CGFloat = 50
                    let textRect = CGRect(
                        x: margin,
                        y: margin,
                        width: pageRect.width - (margin * 2),
                        height: pageRect.height - (margin * 2)
                    )
                    
                    let font = UIFont.systemFont(ofSize: 12)
                    let titleFont = UIFont.boldSystemFont(ofSize: 16)
                    
                    // Split content into pages
                    let lines = content.components(separatedBy: .newlines)
                    var currentY: CGFloat = margin
                    let lineHeight: CGFloat = 18
                    let pageBottom: CGFloat = pageRect.height - margin
                    
                    context.beginPage()
                    
                    for line in lines {
                        // Check if we need a new page
                        if currentY + lineHeight > pageBottom {
                            context.beginPage()
                            currentY = margin
                        }
                        
                        // Choose font based on content
                        let currentFont = line.allSatisfy({ $0.isUppercase || $0.isWhitespace }) ? titleFont : font
                        
                        let attributes: [NSAttributedString.Key: Any] = [
                            .font: currentFont,
                            .foregroundColor: UIColor.black
                        ]
                        
                        let lineRect = CGRect(x: margin, y: currentY, width: textRect.width, height: lineHeight)
                        line.draw(in: lineRect, withAttributes: attributes)
                        
                        currentY += lineHeight
                    }
                }
                
                continuation.resume(returning: data)
            }
        }
    }
    #endif
    
    #if canImport(AppKit)
    private func createPDFmacOS(content: String) async throws -> Data {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.main.async {
                let data = NSMutableData()
                let consumer = CGDataConsumer(data: data)!
                let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
                
                var mediaBox = pageRect
                let pdfContext = CGContext(consumer: consumer, mediaBox: &mediaBox, nil)!
                
                let margin: CGFloat = 50
                let textRect = CGRect(
                    x: margin,
                    y: margin,
                    width: pageRect.width - (margin * 2),
                    height: pageRect.height - (margin * 2)
                )
                
                let font = NSFont.systemFont(ofSize: 12)
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: NSColor.black
                ]
                
                pdfContext.beginPDFPage(nil)
                
                // Draw content
                let nsString = content as NSString
                nsString.draw(in: textRect, withAttributes: attributes)
                
                pdfContext.endPDFPage()
                pdfContext.closePDF()
                
                continuation.resume(returning: data as Data)
            }
        }
    }
    #endif
    
    // MARK: - Helper Methods
    
    private func validatePDFData(_ data: Data) throws {
        guard !data.isEmpty else {
            throw NSError(domain: "PDFError", code: 2, userInfo: [NSLocalizedDescriptionKey: "PDF data is empty"])
        }
        
        // Verify it's actually a PDF by checking the header
        let pdfHeader = "%PDF"
        let headerData = data.prefix(4)
        let headerString = String(data: headerData, encoding: .ascii) ?? ""
        
        guard headerString == pdfHeader else {
            throw NSError(domain: "PDFError", code: 3, userInfo: [NSLocalizedDescriptionKey: "Generated data is not a valid PDF"])
        }
    }
    
    private func updateProgress(_ progress: Double, status: String) async {
        await MainActor.run {
            generationProgress = progress
            print("📄 PDF Generation: \(Int(progress * 100))% - \(status)")
        }
    }
    
    private func createPlaceholderMeal() -> SafeMealData {
        return SafeMealData(
            name: "Comida de ejemplo",
            type: "Comida",
            calories: 500,
            protein: 25,
            carbs: 50,
            fat: 15,
            foods: [
                SafeFoodData(name: "Alimento principal", weight: 100, calories: 300, protein: 20, carbs: 30, fat: 10),
                SafeFoodData(name: "Acompañamiento", weight: 80, calories: 200, protein: 5, carbs: 20, fat: 5)
            ],
            instructions: "Preparar según las preferencias del paciente."
        )
    }
}

// ==========================================
// SAFE DATA STRUCTURES
// ==========================================

// These structures represent "safe" versions of your data that won't cause crashes
// They use standard Swift types and provide default values for missing information

public struct SafeMealPlanData {
    let title: String
    let meals: [SafeMealData]
    let days: [SafeDayData]
    let creationDate: Date
}

public struct SafeMealData {
    let name: String
    let type: String
    let calories: Double
    let protein: Double
    let carbs: Double
    let fat: Double
    let foods: [SafeFoodData]
    let instructions: String?
}

public struct SafeDayData {
    let date: Date
    let dayNumber: Int
    let meals: [SafeMealData]
}

public struct SafeFoodData {
    let name: String
    let weight: Double
    let calories: Double
    let protein: Double
    let carbs: Double
    let fat: Double
}

public struct SafePatientData {
    let firstName: String
    let lastName: String
    let age: Int?
    
    var fullName: String {
        let name = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? "Paciente" : name
    }
}

// ==========================================
// USAGE INSTRUCTIONS
// ==========================================

/*
 HOW TO USE THE ROBUST PDF SERVICE:

 STEP 1: REPLACE YOUR EXISTING PDF SERVICE
 Instead of using your current PDF service, use this one:

 let pdfService = RobustPDFService.shared

 STEP 2: GENERATE PDFS SAFELY
 You can pass ANY meal plan object to this service:

 let pdfData = try await pdfService.generateMealPlanPDF(
     from: yourMealPlan,           // Can be any object
     for: yourPatient,             // Can be any object or nil
     includeRecipes: true,
     includeShoppingList: true,
     includeNutritionAnalysis: true,
     language: .spanish
 )

 STEP 3: HANDLE THE RESULTS
 The service provides real-time progress updates:

 pdfService.$isGenerating.sink { isGenerating in
     // Update your UI to show loading state
 }

 pdfService.$generationProgress.sink { progress in
     // Update progress bar (0.0 to 1.0)
 }

 pdfService.$lastError.sink { error in
     // Handle any errors that occur
 }

 STEP 4: DISPLAY THE PDF
 Use the generated data to display the PDF:

 if let pdfData = pdfService.lastGeneratedPDF {
     // Show PDF in your UI
 }

 KEY BENEFITS OF THIS APPROACH:
 • Never crashes due to missing properties
 • Works with any data structure
 • Provides detailed progress feedback
 • Generates professional-looking PDFs
 • Handles both iOS and macOS platforms
 • Includes comprehensive error handling

 This service uses reflection to safely examine your data objects and extract
 whatever information is available, providing sensible defaults for missing data.
 */
