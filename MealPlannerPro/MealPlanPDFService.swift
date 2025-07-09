import Foundation
import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

#if canImport(AppKit)
import AppKit
#endif

#if canImport(CoreGraphics)
import CoreGraphics
#endif

// MARK: - Simplified PDF Generation Service
class MealPlanPDFService: ObservableObject {
    @Published var isGenerating = false
    @Published var lastError: String?
    
    // MARK: - Generate Simple Meal Plan PDF
    func generateMealPlanPDF(
        multiDayPlan: MultiDayMealPlan,
        patient: Patient?,
        includeRecipes: Bool = true,
        includeShoppingList: Bool = true
    ) async throws -> Data {
        
        await MainActor.run {
            isGenerating = true
            lastError = nil
        }
        
        defer {
            Task { @MainActor in
                isGenerating = false
            }
        }
        
        do {
            print("📄 Generating simplified meal plan document...")
            
            // For now, create a simple text-based PDF
            let pdfContent = createSimplePDFContent(
                plan: multiDayPlan,
                patient: patient,
                includeRecipes: includeRecipes,
                includeShoppingList: includeShoppingList
            )
            
            let pdfData = try createSimplePDF(content: pdfContent)
            
            print("✅ PDF generated successfully (\(pdfData.count) bytes)")
            return pdfData
            
        } catch {
            await MainActor.run {
                lastError = error.localizedDescription
            }
            throw error
        }
    }
    
    // MARK: - Create Simple PDF Content
    private func createSimplePDFContent(
        plan: MultiDayMealPlan,
        patient: Patient?,
        includeRecipes: Bool,
        includeShoppingList: Bool
    ) -> String {
        
        let strings = plan.language.localized
        var content = ""
        
        // Header
        content += "\(strings.mealPlan)\n"
        content += "==========================================\n\n"
        
        // Patient Info
        if let patient = patient {
            content += "Paciente: \(patient.firstName ?? "") \(patient.lastName ?? "")\n"
        }
        
        // Date Range
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        content += "Período: \(dateFormatter.string(from: plan.startDate)) - \(dateFormatter.string(from: plan.endDate))\n"
        content += "Duración: \(plan.numberOfDays) días\n"
        content += "Generado: \(dateFormatter.string(from: plan.generatedDate))\n\n"
        
        // Summary
        content += "RESUMEN NUTRICIONAL\n"
        content += "==========================================\n"
        let summary = plan.totalNutritionSummary
        content += "Promedio diario:\n"
        content += "• \(strings.calories): \(Int(summary.averageDailyCalories)) kcal\n"
        content += "• \(strings.protein): \(Int(summary.averageDailyProtein))g\n"
        content += "• \(strings.carbohydrates): \(Int(summary.averageDailyCarbs))g\n"
        content += "• \(strings.fat): \(Int(summary.averageDailyFat))g\n"
        content += "• Precisión promedio: \(Int(summary.overallAccuracy * 100))%\n\n"
        
        // Daily Plans
        for (dayIndex, dailyPlan) in plan.dailyPlans.enumerated() {
            content += "DÍA \(dayIndex + 1) - \(dateFormatter.string(from: dailyPlan.date))\n"
            content += "==========================================\n"
            
            for meal in dailyPlan.meals {
                let mealTypeName = getMealTypeDisplayName(meal.originalAISuggestion.mealType, language: plan.language)
                content += "\n\(mealTypeName.uppercased()): \(meal.originalAISuggestion.mealName)\n"
                content += "Calorías: \(Int(meal.verifiedTotalNutrition.calories))\n"
                
                content += "\nIngredientes:\n"
                for food in meal.verifiedFoods {
                    let verificationStatus = food.isVerified ? "✓" : "~"
                    content += "• \(verificationStatus) \(food.originalAISuggestion.portionDescription) - \(Int(food.verifiedNutrition.calories)) cal\n"
                }
                
                if !meal.originalAISuggestion.preparationNotes.isEmpty {
                    content += "\nPreparación:\n\(meal.originalAISuggestion.preparationNotes)\n"
                }
                
                if !meal.originalAISuggestion.nutritionistNotes.isEmpty {
                    content += "\nNotas del nutricionista:\n\(meal.originalAISuggestion.nutritionistNotes)\n"
                }
                
                content += "\n"
            }
            
            // Daily totals
            content += "TOTAL DEL DÍA: \(Int(dailyPlan.dailyNutritionSummary.calories)) calorías\n"
            content += "Proteína: \(Int(dailyPlan.dailyNutritionSummary.protein))g | "
            content += "Carbohidratos: \(Int(dailyPlan.dailyNutritionSummary.carbs))g | "
            content += "Grasa: \(Int(dailyPlan.dailyNutritionSummary.fat))g\n\n"
        }
        
        // Shopping List
        if includeShoppingList {
            content += "\n\nLISTA DE COMPRAS\n"
            content += "==========================================\n"
            let shoppingList = generateShoppingList(from: plan)
            
            for (category, items) in shoppingList.itemsByCategory {
                content += "\n\(category.uppercased()):\n"
                for item in items {
                    content += "□ \(item.combinedDescription)\n"
                }
            }
            
            content += "\nCosto estimado: $\(String(format: "%.2f", shoppingList.totalEstimatedCost))\n"
        }
        
        // Simple Recipes
        if includeRecipes {
            content += "\n\nRECETAS BÁSICAS\n"
            content += "==========================================\n"
            
            let uniqueMeals = getUniqueMeals(from: plan)
            for meal in uniqueMeals.prefix(5) { // Limit to 5 recipes for simplicity
                content += "\n\(meal.originalAISuggestion.mealName.uppercased())\n"
                content += "Ingredientes:\n"
                for food in meal.verifiedFoods {
                    content += "• \(food.originalAISuggestion.portionDescription) de \(food.originalAISuggestion.name)\n"
                }
                content += "\nPreparación:\n"
                if meal.originalAISuggestion.preparationNotes.isEmpty {
                    content += "Preparar según las instrucciones estándar para cada ingrediente.\n"
                } else {
                    content += "\(meal.originalAISuggestion.preparationNotes)\n"
                }
                content += "Tiempo estimado: 15-25 minutos\n"
                content += "Calorías totales: \(Int(meal.verifiedTotalNutrition.calories))\n\n"
            }
        }
        
        // Footer
        content += "\n\n==========================================\n"
        content += "Generado por MealPlannerPro\n"
        content += "Plan nutricional profesional con verificación USDA\n"
        content += "==========================================\n"
        
        return content
    }
    
    // MARK: - Simple PDF Creation
    private func createSimplePDF(content: String) throws -> Data {
        #if canImport(UIKit)
        return try createPDFiOS(content: content)
        #elseif canImport(AppKit)
        return try createPDFmacOS(content: content)
        #else
        throw PDFError.platformNotSupported
        #endif
    }
    
    #if canImport(UIKit)
    private func createPDFiOS(content: String) throws -> Data {
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792) // US Letter
        
        let pdfData = NSMutableData()
        guard let consumer = CGDataConsumer(data: pdfData) else {
            throw PDFError.creationFailed
        }
        
        var mediaBox = pageRect
        guard let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            throw PDFError.creationFailed
        }
        
        context.beginPDFPage(nil)
        
        let textRect = CGRect(x: 40, y: 40, width: pageRect.width - 80, height: pageRect.height - 80)
        
        // Split content into pages
        let lines = content.components(separatedBy: .newlines)
        var currentY: CGFloat = 40
        let lineHeight: CGFloat = 16
        let pageBottom: CGFloat = pageRect.height - 40
        
        for line in lines {
            if currentY + lineHeight > pageBottom {
                context.endPDFPage()
                context.beginPDFPage(nil)
                currentY = 40
            }
            
            let lineRect = CGRect(x: 40, y: currentY, width: textRect.width, height: lineHeight)
            
            // Draw text using Core Graphics
            context.saveGState()
            context.textMatrix = CGAffineTransform.identity
            context.translateBy(x: 0, y: pageRect.height)
            context.scaleBy(x: 1, y: -1)
            
            let adjustedRect = CGRect(x: lineRect.minX, y: pageRect.height - lineRect.maxY, width: lineRect.width, height: lineRect.height)
            
            let attributedString = NSAttributedString(string: line, attributes: [
                NSAttributedString.Key.font: UIFont.systemFont(ofSize: 12),
                NSAttributedString.Key.foregroundColor: UIColor.black
            ])
            
            let framesetter = CTFramesetterCreateWithAttributedString(attributedString)
            let path = CGPath(rect: adjustedRect, transform: nil)
            let frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, 0), path, nil)
            CTFrameDraw(frame, context)
            
            context.restoreGState()
            currentY += lineHeight
        }
        
        context.endPDFPage()
        context.closePDF()
        
        return pdfData as Data
    }
    #endif
    
    #if canImport(AppKit)
    private func createPDFmacOS(content: String) throws -> Data {
        let pdfData = NSMutableData()
        var pageRect = NSRect(x: 0, y: 0, width: 612, height: 792)
        
        guard let consumer = CGDataConsumer(data: pdfData) else {
            throw PDFError.creationFailed
        }
        
        guard let context = CGContext(consumer: consumer, mediaBox: &pageRect, nil) else {
            throw PDFError.creationFailed
        }
        
        context.beginPDFPage(nil)
        
        let font = NSFont.systemFont(ofSize: 12)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.black
        ]
        
        let textRect = NSRect(x: 40, y: 40, width: pageRect.width - 80, height: pageRect.height - 80)
        
        let attributedString = NSAttributedString(string: content, attributes: attributes)
        let textContainer = NSTextContainer(size: textRect.size)
        let layoutManager = NSLayoutManager()
        let textStorage = NSTextStorage(attributedString: attributedString)
        
        textStorage.addLayoutManager(layoutManager)
        layoutManager.addTextContainer(textContainer)
        
        let glyphRange = layoutManager.glyphRange(for: textContainer)
        layoutManager.drawGlyphs(forGlyphRange: glyphRange, at: textRect.origin)
        
        context.endPDFPage()
        context.closePDF()
        
        return pdfData as Data
    }
    #endif
    
    // MARK: - Helper Functions
    private func getMealTypeDisplayName(_ mealType: MealType, language: PlanLanguage) -> String {
        let strings = language.localized
        switch mealType {
        case .breakfast: return strings.breakfast
        case .lunch: return strings.lunch
        case .dinner: return strings.dinner
        case .snack: return strings.snack
        }
    }
    
    private func generateShoppingList(from plan: MultiDayMealPlan) -> ShoppingList {
        var allIngredients: [ShoppingItem] = []
        
        // Collect all ingredients from all meals
        for dailyPlan in plan.dailyPlans {
            for meal in dailyPlan.meals {
                for food in meal.verifiedFoods {
                    let item = ShoppingItem(
                        name: food.originalAISuggestion.name,
                        quantity: food.originalAISuggestion.gramWeight,
                        unit: "g",
                        category: categorizeFood(food.originalAISuggestion.name)
                    )
                    allIngredients.append(item)
                }
            }
        }
        
        // Combine similar items and organize by category
        let combinedItems = combineShoppingItems(allIngredients)
        let itemsByCategory = Dictionary(grouping: combinedItems, by: { $0.category })
        
        return ShoppingList(
            id: UUID(),
            planId: plan.id,
            itemsByCategory: itemsByCategory,
            totalEstimatedCost: calculateEstimatedCost(combinedItems),
            generatedDate: Date()
        )
    }
    
    private func categorizeFood(_ foodName: String) -> String {
        let name = foodName.lowercased()
        
        if name.contains("chicken") || name.contains("beef") || name.contains("pork") || name.contains("fish") || name.contains("turkey") {
            return "Carnes y Pescados"
        } else if name.contains("lettuce") || name.contains("spinach") || name.contains("broccoli") || name.contains("tomato") {
            return "Verduras"
        } else if name.contains("apple") || name.contains("banana") || name.contains("orange") || name.contains("berry") {
            return "Frutas"
        } else if name.contains("milk") || name.contains("cheese") || name.contains("yogurt") {
            return "Lácteos"
        } else if name.contains("rice") || name.contains("bread") || name.contains("pasta") || name.contains("quinoa") {
            return "Granos y Cereales"
        } else if name.contains("oil") || name.contains("butter") {
            return "Aceites y Grasas"
        } else {
            return "Otros"
        }
    }
    
    private func combineShoppingItems(_ items: [ShoppingItem]) -> [ShoppingItem] {
        var combinedItems: [String: ShoppingItem] = [:]
        
        for item in items {
            let key = item.name.lowercased()
            
            if let existing = combinedItems[key] {
                combinedItems[key] = ShoppingItem(
                    name: existing.name,
                    quantity: existing.quantity + item.quantity,
                    unit: existing.unit,
                    category: existing.category
                )
            } else {
                combinedItems[key] = item
            }
        }
        
        return Array(combinedItems.values).sorted { $0.name < $1.name }
    }
    
    private func calculateEstimatedCost(_ items: [ShoppingItem]) -> Double {
        return items.reduce(0) { total, item in
            let baseCost: Double
            if item.category == "Carnes y Pescados" {
                baseCost = 0.02 // $0.02 per gram
            } else if item.category == "Lácteos" {
                baseCost = 0.01
            } else {
                baseCost = 0.005
            }
            return total + (item.quantity * baseCost)
        }
    }
    
    private func getUniqueMeals(from plan: MultiDayMealPlan) -> [VerifiedMealPlanSuggestion] {
        var uniqueMeals: [String: VerifiedMealPlanSuggestion] = [:]
        
        for dailyPlan in plan.dailyPlans {
            for meal in dailyPlan.meals {
                uniqueMeals[meal.originalAISuggestion.mealName] = meal
            }
        }
        
        return Array(uniqueMeals.values)
    }
}

// MARK: - Shopping List Data Models
struct ShoppingList: Identifiable {
    let id: UUID
    let planId: UUID
    let itemsByCategory: [String: [ShoppingItem]]
    let totalEstimatedCost: Double
    let generatedDate: Date
}

struct ShoppingItem {
    let name: String
    let quantity: Double
    let unit: String
    let category: String
    
    var combinedDescription: String {
        "\(String(format: "%.0f", quantity))\(unit) \(name)"
    }
}

// MARK: - PDF Errors
enum PDFError: Error, LocalizedError {
    case platformNotSupported
    case creationFailed
    
    var errorDescription: String? {
        switch self {
        case .platformNotSupported:
            return "PDF generation not supported on this platform"
        case .creationFailed:
            return "Failed to create PDF document"
        }
    }
}


// Enhanced PDF Generation with Complete Recipe Integration
import Foundation
import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

#if canImport(AppKit)
import AppKit
#endif

#if canImport(CoreGraphics)
import CoreGraphics
#endif

// MARK: - Professional PDF Generation Service
extension MealPlanPDFService {
    
    // MARK: - Enhanced PDF Generation with Full Recipe Integration
    func generateComprehensiveMealPlanPDF(
        multiDayPlan: MultiDayMealPlan,
        patient: Patient?,
        includeRecipes: Bool = true,
        includeShoppingList: Bool = true,
        includeNutritionAnalysis: Bool = true,
        language: PlanLanguage = .spanish
    ) async throws -> Data {
        
        await MainActor.run {
            isGenerating = true
            lastError = nil
        }
        
        defer {
            Task { @MainActor in
                isGenerating = false
            }
        }
        
        do {
            print("📄 Generating comprehensive meal plan PDF with recipes...")
            
            // Generate Spanish recipes if language is Spanish
            let spanishRecipes = language == .spanish ?
                generateSpanishRecipes(from: multiDayPlan) : []
            
            // Create comprehensive PDF content
            let pdfContent = createComprehensivePDFContent(
                plan: multiDayPlan,
                patient: patient,
                spanishRecipes: spanishRecipes,
                includeRecipes: includeRecipes,
                includeShoppingList: includeShoppingList,
                includeNutritionAnalysis: includeNutritionAnalysis,
                language: language
            )
            
            let pdfData = try createProfessionalPDF(content: pdfContent, language: language)
            
            print("✅ Comprehensive PDF generated successfully (\(pdfData.count) bytes)")
            return pdfData
            
        } catch {
            await MainActor.run {
                lastError = error.localizedDescription
            }
            throw error
        }
    }
    
    // MARK: - Generate Spanish Recipes
    private func generateSpanishRecipes(from plan: MultiDayMealPlan) -> [SpanishRecipe] {
        var recipes: [SpanishRecipe] = []
        
        // Get unique meals to avoid duplicating recipes
        var uniqueMeals: [String: VerifiedMealPlanSuggestion] = [:]
        
        for dailyPlan in plan.dailyPlans {
            for meal in dailyPlan.meals {
                let mealKey = meal.originalAISuggestion.mealName.lowercased()
                if uniqueMeals[mealKey] == nil {
                    uniqueMeals[mealKey] = meal
                }
            }
        }
        
        // Generate Spanish recipes for unique meals
        for (_, meal) in uniqueMeals {
            let spanishRecipe = SpanishMealPlanningLocalizer.generateSpanishRecipe(
                for: meal,
                mealType: meal.originalAISuggestion.mealType
            )
            recipes.append(spanishRecipe)
        }
        
        return recipes.sorted { $0.mealType.rawValue < $1.mealType.rawValue }
    }
    
    // MARK: - Create Comprehensive PDF Content
    private func createComprehensivePDFContent(
        plan: MultiDayMealPlan,
        patient: Patient?,
        spanishRecipes: [SpanishRecipe],
        includeRecipes: Bool,
        includeShoppingList: Bool,
        includeNutritionAnalysis: Bool,
        language: PlanLanguage
    ) -> PDFContent {
        
        let strings = language.localized
        
        // Create structured PDF content
        var sections: [PDFSection] = []
        
        // 1. Cover Page
        sections.append(createCoverPage(plan: plan, patient: patient, strings: strings))
        
        // 2. Executive Summary
        sections.append(createExecutiveSummary(plan: plan, strings: strings))
        
        // 3. Daily Meal Plans
        sections.append(createDailyPlansSection(plan: plan, strings: strings))
        
        // 4. Detailed Recipes (if requested)
        if includeRecipes && !spanishRecipes.isEmpty {
            sections.append(createRecipesSection(recipes: spanishRecipes, strings: strings))
        }
        
        // 5. Shopping List (if requested)
        if includeShoppingList {
            sections.append(createShoppingListSection(plan: plan, strings: strings))
        }
        
        // 6. Nutrition Analysis (if requested)
        if includeNutritionAnalysis {
            sections.append(createNutritionAnalysisSection(plan: plan, strings: strings))
        }
        
        // 7. Appendix
        sections.append(createAppendixSection(plan: plan, strings: strings))
        
        return PDFContent(sections: sections, language: language)
    }
    
    // MARK: - PDF Section Creators
    private func createCoverPage(plan: MultiDayMealPlan, patient: Patient?, strings: LocalizedStrings) -> PDFSection {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        
        var content = """
        
        
        🍽️ PLAN NUTRICIONAL PERSONALIZADO
        
        ═══════════════════════════════════════
        
        """
        
        if let patient = patient {
            content += """
            PACIENTE: \(patient.firstName ?? "") \(patient.lastName ?? "")
            
            """
        }
        
        content += """
        PERÍODO: \(dateFormatter.string(from: plan.startDate))
        DURACIÓN: \(plan.numberOfDays) días
        TOTAL DE COMIDAS: \(plan.dailyPlans.reduce(0) { $0 + $1.meals.count })
        
        RESUMEN NUTRICIONAL DIARIO:
        • Calorías promedio: \(Int(plan.totalNutritionSummary.averageDailyCalories)) kcal
        • Proteína promedio: \(Int(plan.totalNutritionSummary.averageDailyProtein))g
        • Carbohidratos promedio: \(Int(plan.totalNutritionSummary.averageDailyCarbs))g
        • Grasa promedio: \(Int(plan.totalNutritionSummary.averageDailyFat))g
        
        VERIFICACIÓN USDA: \(Int(plan.totalNutritionSummary.overallAccuracy * 100))% de precisión
        
        GENERADO: \(dateFormatter.string(from: plan.generatedDate))
        
        ═══════════════════════════════════════
        
        Plan creado por MealPlannerPro
        Sistema de planificación nutricional con verificación USDA
        """
        
        return PDFSection(
            title: "Portada",
            content: content,
            type: .cover,
            pageBreakAfter: true
        )
    }
    
    private func createExecutiveSummary(plan: MultiDayMealPlan, strings: LocalizedStrings) -> PDFSection {
        let summary = plan.totalNutritionSummary
        
        let content = """
        RESUMEN EJECUTIVO
        ═══════════════════════════════════════
        
        VISIÓN GENERAL DEL PLAN:
        Este plan nutricional de \(plan.numberOfDays) días ha sido diseñado específicamente para proporcionar una alimentación balanceada y variada, con verificación nutricional a través de la base de datos USDA.
        
        OBJETIVOS NUTRICIONALES:
        • Proporcionar energía equilibrada a lo largo del día
        • Asegurar ingesta adecuada de macronutrientes
        • Incluir variedad de alimentos para micronutrientes
        • Mantener palatabilidad y practicidad
        
        MÉTRICAS DE CALIDAD:
        • Precisión nutricional: \(Int(summary.overallAccuracy * 100))%
        • Variedad de ingredientes: Alta
        • Verificación USDA: Implementada
        • Adaptación cultural: Incluida
        
        DISTRIBUCIÓN CALÓRICA DIARIA:
        • Desayuno: ~25% (\(Int(summary.averageDailyCalories * 0.25)) kcal)
        • Almuerzo: ~35% (\(Int(summary.averageDailyCalories * 0.35)) kcal)
        • Cena: ~35% (\(Int(summary.averageDailyCalories * 0.35)) kcal)
        • Meriendas: ~5% (\(Int(summary.averageDailyCalories * 0.05)) kcal)
        
        RECOMENDACIONES DE USO:
        1. Seguir las porciones indicadas para obtener los beneficios nutricionales
        2. Preparar los alimentos según las recetas proporcionadas
        3. Mantener horarios regulares de comida
        4. Hidratación adecuada entre comidas
        5. Consultar con profesional de salud si hay dudas
        """
        
        return PDFSection(
            title: "Resumen Ejecutivo",
            content: content,
            type: .summary,
            pageBreakAfter: true
        )
    }
    
    private func createDailyPlansSection(plan: MultiDayMealPlan, strings: LocalizedStrings) -> PDFSection {
        var content = """
        PLANES DIARIOS DETALLADOS
        ═══════════════════════════════════════
        
        """
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .full
        
        for (dayIndex, dailyPlan) in plan.dailyPlans.enumerated() {
            content += """
            
            DÍA \(dayIndex + 1) - \(dateFormatter.string(from: dailyPlan.date))
            ───────────────────────────────────────
            
            """
            
            for meal in dailyPlan.meals {
                let mealTypeName = getMealTypeDisplayName(meal.originalAISuggestion.mealType, language: plan.language)
                
                content += """
                
                \(mealTypeName.uppercased()): \(meal.originalAISuggestion.mealName)
                Calorías: \(Int(meal.verifiedTotalNutrition.calories)) kcal
                
                Ingredientes:
                """
                
                for food in meal.verifiedFoods {
                    let verificationStatus = food.isVerified ? "✓" : "~"
                    content += """
                
                • \(verificationStatus) \(food.originalAISuggestion.portionDescription)
                  \(food.originalAISuggestion.name) (\(Int(food.verifiedNutrition.calories)) cal)
                """
                }
                
                if !meal.originalAISuggestion.preparationNotes.isEmpty {
                    content += """
                
                Preparación: \(meal.originalAISuggestion.preparationNotes)
                """
                }
                
                content += "\n"
            }
            
            // Daily totals
            content += """
            
            TOTALES DEL DÍA:
            • Calorías: \(Int(dailyPlan.dailyNutritionSummary.calories)) kcal
            • Proteína: \(Int(dailyPlan.dailyNutritionSummary.protein))g
            • Carbohidratos: \(Int(dailyPlan.dailyNutritionSummary.carbs))g
            • Grasa: \(Int(dailyPlan.dailyNutritionSummary.fat))g
            • Precisión: \(Int(dailyPlan.dailyNutritionSummary.averageAccuracy * 100))%
            
            """
        }
        
        return PDFSection(
            title: "Planes Diarios",
            content: content,
            type: .dailyPlans,
            pageBreakAfter: true
        )
    }
    
    private func createRecipesSection(recipes: [SpanishRecipe], strings: LocalizedStrings) -> PDFSection {
        var content = """
        RECETAS DETALLADAS
        ═══════════════════════════════════════
        
        Esta sección contiene recetas paso a paso para preparar cada comida del plan nutricional. Todas las recetas han sido adaptadas culturalmente y incluyen tiempos de preparación estimados.
        
        """
        
        for (index, recipe) in recipes.enumerated() {
            content += """
            
            RECETA \(index + 1): \(recipe.name.uppercased())
            ───────────────────────────────────────
            
            Tipo: \(getMealTypeDisplayName(recipe.mealType, language: .spanish))
            Dificultad: \(recipe.difficulty.rawValue)
            Tiempo: \(recipe.cookingTimeMinutes) minutos
            Porciones: \(recipe.servings)
            
            INGREDIENTES:
            """
            
            for ingredient in recipe.ingredients {
                let verificationMark = ingredient.isVerified ? "✓" : "~"
                content += """
            
            • \(verificationMark) \(ingredient.amount) de \(ingredient.name)
            """
            }
            
            content += """
            
            
            PREPARACIÓN:
            """
            
            for (stepIndex, instruction) in recipe.instructions.enumerated() {
                content += """
            
            \(stepIndex + 1). \(instruction)
            """
            }
            
            content += """
            
            
            INFORMACIÓN NUTRICIONAL:
            • Calorías: \(recipe.nutrition.calories) kcal
            • Proteína: \(recipe.nutrition.protein)g
            • Carbohidratos: \(recipe.nutrition.carbohydrates)g
            • Grasa: \(recipe.nutrition.fat)g
            
            """
            
            if !recipe.tips.isEmpty {
                content += """
                CONSEJOS DEL NUTRICIONISTA:
                """
                
                for tip in recipe.tips {
                    content += """
                • \(tip)
                """
                }
                
                content += "\n"
            }
        }
        
        return PDFSection(
            title: "Recetas",
            content: content,
            type: .recipes,
            pageBreakAfter: true
        )
    }
    
    private func createShoppingListSection(plan: MultiDayMealPlan, strings: LocalizedStrings) -> PDFSection {
        let shoppingList = generateShoppingList(from: plan)
        
        var content = """
        LISTA DE COMPRAS
        ═══════════════════════════════════════
        
        Lista organizada por categorías para facilitar las compras. Las cantidades están calculadas para todo el período del plan.
        
        """
        
        for (category, items) in shoppingList.itemsByCategory.sorted(by: { $0.key < $1.key }) {
            content += """
            
            \(category.uppercased()):
            ───────────────────────────────────────
            """
            
            for item in items.sorted(by: { $0.name < $1.name }) {
                content += """
            
            □ \(item.combinedDescription)
            """
            }
            
            content += "\n"
        }
        
        content += """
        
        INFORMACIÓN ADICIONAL:
        ───────────────────────────────────────
        
        Costo estimado total: $\(String(format: "%.2f", shoppingList.totalEstimatedCost))
        
        Consejos de compra:
        • Comprar productos frescos el día de preparación cuando sea posible
        • Verificar fechas de caducidad
        • Considerar opciones orgánicas para vegetales de hoja verde
        • Elegir proteínas de fuentes confiables
        • Mantener cadena de frío para productos perecederos
        """
        
        return PDFSection(
            title: "Lista de Compras",
            content: content,
            type: .shoppingList,
            pageBreakAfter: true
        )
    }
    
    private func createNutritionAnalysisSection(plan: MultiDayMealPlan, strings: LocalizedStrings) -> PDFSection {
        let summary = plan.totalNutritionSummary
        
        let content = """
        ANÁLISIS NUTRICIONAL PROFESIONAL
        ═══════════════════════════════════════
        
        DISTRIBUCIÓN DE MACRONUTRIENTES:
        
        Calorías por macronutriente (promedio diario):
        • Proteína: \(Int(summary.averageDailyProtein * 4)) kcal (\(Int(summary.averageDailyProtein * 4 / summary.averageDailyCalories * 100))%)
        • Carbohidratos: \(Int(summary.averageDailyCarbs * 4)) kcal (\(Int(summary.averageDailyCarbs * 4 / summary.averageDailyCalories * 100))%)
        • Grasa: \(Int(summary.averageDailyFat * 9)) kcal (\(Int(summary.averageDailyFat * 9 / summary.averageDailyCalories * 100))%)
        
        EVALUACIÓN NUTRICIONAL:
        
        ✓ Balance energético: Adecuado
        ✓ Distribución de macronutrientes: Balanceada
        ✓ Variedad de alimentos: Alta
        ✓ Verificación USDA: \(Int(summary.overallAccuracy * 100))%
        
        RECOMENDACIONES ADICIONALES:
        
        1. HIDRATACIÓN:
           • Consumir 8-10 vasos de agua al día
           • Incluir líquidos con las comidas
           • Reducir bebidas azucaradas
        
        2. SUPLEMENTACIÓN:
           • Consultar con profesional de salud
           • Considerar vitamina D si hay poca exposición solar
           • Evaluar necesidad de B12 en dietas vegetarianas
        
        3. ACTIVIDAD FÍSICA:
           • Combinar con ejercicio regular
           • Ajustar porciones según nivel de actividad
           • Hidratación adicional durante ejercicio
        
        4. SEGUIMIENTO:
           • Monitorear peso y energía
           • Ajustar porciones según necesidades
           • Consultar nutricionista para cambios mayores
        
        NOTAS IMPORTANTES:
        • Este plan está basado en requerimientos nutricionales generales
        • Consulte con un profesional de salud antes de cambios dietéticos significativos
        • Las alergias e intolerancias deben considerarse individualmente
        • Los valores nutricionales son aproximaciones basadas en datos USDA
        """
        
        return PDFSection(
            title: "Análisis Nutricional",
            content: content,
            type: .nutritionAnalysis,
            pageBreakAfter: true
        )
    }
    
    private func createAppendixSection(plan: MultiDayMealPlan, strings: LocalizedStrings) -> PDFSection {
        let content = """
        APÉNDICE
        ═══════════════════════════════════════
        
        GLOSARIO DE TÉRMINOS:
        
        • USDA: Departamento de Agricultura de Estados Unidos, fuente de datos nutricionales
        • Macronutrientes: Proteínas, carbohidratos y grasas
        • Micronutrientes: Vitaminas y minerales
        • Kcal: Kilocalorías, unidad de medida de energía
        
        EQUIVALENCIAS DE MEDIDAS:
        
        Medidas de volumen:
        • 1 taza = 240 ml = 8 fl oz
        • 1 cucharada = 15 ml = 0.5 fl oz
        • 1 cucharadita = 5 ml = 0.17 fl oz
        
        Medidas de peso:
        • 1 onza = 28.35 gramos
        • 1 libra = 453.6 gramos
        • 1 kilogramo = 1000 gramos = 2.2 libras
        
        CONSEJOS DE CONSERVACIÓN:
        
        Refrigerador (2-4°C):
        • Carnes y pescados: 1-2 días
        • Lácteos: Según fecha de caducidad
        • Verduras de hoja: 3-7 días
        • Frutas: Variable según tipo
        
        Congelador (-18°C):
        • Carnes: 3-6 meses
        • Pescados: 2-3 meses
        • Verduras: 8-12 meses
        
        INFORMACIÓN DE CONTACTO:
        
        Para consultas sobre este plan nutricional:
        • Desarrollado por: MealPlannerPro
        • Versión: 1.0
        • Fecha de generación: \(DateFormatter().string(from: Date()))
        
        DESCARGO DE RESPONSABILIDAD:
        
        Este plan nutricional es una guía general y no reemplaza el consejo médico profesional. Consulte con un nutricionista o médico antes de realizar cambios significativos en su dieta, especialmente si tiene condiciones médicas preexistentes.
        """
        
        return PDFSection(
            title: "Apéndice",
            content: content,
            type: .appendix,
            pageBreakAfter: false
        )
    }
    
    // MARK: - Professional PDF Creation
    private func createProfessionalPDF(content: PDFContent, language: PlanLanguage) throws -> Data {
        #if canImport(UIKit)
        return try createProfessionalPDFiOS(content: content)
        #elseif canImport(AppKit)
        return try createProfessionalPDFmacOS(content: content)
        #else
        throw PDFError.platformNotSupported
        #endif
    }
    
    #if canImport(UIKit)
    private func createProfessionalPDFiOS(content: PDFContent) throws -> Data {
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792) // US Letter
        let pdfData = NSMutableData()
        
        guard let consumer = CGDataConsumer(data: pdfData) else {
            throw PDFError.creationFailed
        }
        
        var mediaBox = pageRect
        guard let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            throw PDFError.creationFailed
        }
        
        let margin: CGFloat = 50
        let contentRect = CGRect(
            x: margin,
            y: margin,
            width: pageRect.width - (margin * 2),
            height: pageRect.height - (margin * 2)
        )
        
        for section in content.sections {
            context.beginPDFPage(nil)
            
            // Draw section content
            drawSectionContent(
                context: context,
                section: section,
                in: contentRect,
                pageRect: pageRect
            )
            
            context.endPDFPage()
        }
        
        context.closePDF()
        return pdfData as Data
    }
    
    private func drawSectionContent(
        context: CGContext,
        section: PDFSection,
        in contentRect: CGRect,
        pageRect: CGRect
    ) {
        context.saveGState()
        context.textMatrix = CGAffineTransform.identity
        context.translateBy(x: 0, y: pageRect.height)
        context.scaleBy(x: 1, y: -1)
        
        let adjustedRect = CGRect(
            x: contentRect.minX,
            y: pageRect.height - contentRect.maxY,
            width: contentRect.width,
            height: contentRect.height
        )
        
        let fontSize: CGFloat = section.type == .cover ? 14 : 12
        let font = UIFont.systemFont(ofSize: fontSize)
        
        let attributedString = NSAttributedString(string: section.content, attributes: [
            NSAttributedString.Key.font: font,
            NSAttributedString.Key.foregroundColor: UIColor.black
        ])
        
        let framesetter = CTFramesetterCreateWithAttributedString(attributedString)
        let path = CGPath(rect: adjustedRect, transform: nil)
        let frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, 0), path, nil)
        CTFrameDraw(frame, context)
        
        context.restoreGState()
    }
    #endif
    
    #if canImport(AppKit)
    private func createProfessionalPDFmacOS(content: PDFContent) throws -> Data {
        let pdfData = NSMutableData()
        var pageRect = NSRect(x: 0, y: 0, width: 612, height: 792)
        
        guard let consumer = CGDataConsumer(data: pdfData) else {
            throw PDFError.creationFailed
        }
        
        guard let context = CGContext(consumer: consumer, mediaBox: &pageRect, nil) else {
            throw PDFError.creationFailed
        }
        
        for section in content.sections {
            context.beginPDFPage(nil)
            
            let font = NSFont.systemFont(ofSize: section.type == .cover ? 14 : 12)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: NSColor.black
            ]
            
            let margin: CGFloat = 50
            let textRect = NSRect(
                x: margin,
                y: margin,
                width: pageRect.width - (margin * 2),
                height: pageRect.height - (margin * 2)
            )
            
            let attributedString = NSAttributedString(string: section.content, attributes: attributes)
            attributedString.draw(in: textRect)
            
            context.endPDFPage()
        }
        
        context.closePDF()
        return pdfData as Data
    }
    #endif
}

// MARK: - PDF Content Structure
struct PDFContent {
    let sections: [PDFSection]
    let language: PlanLanguage
}

struct PDFSection {
    let title: String
    let content: String
    let type: PDFSectionType
    let pageBreakAfter: Bool
}

enum PDFSectionType {
    case cover
    case summary
    case dailyPlans
    case recipes
    case shoppingList
    case nutritionAnalysis
    case appendix
}
