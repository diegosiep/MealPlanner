import Foundation
import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

#if canImport(AppKit)
import AppKit
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
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        
        return renderer.pdfData { context in
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12),
                .foregroundColor: UIColor.black
            ]
            
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 16),
                .foregroundColor: UIColor.black
            ]
            
            context.beginPage()
            
            let textRect = CGRect(x: 40, y: 40, width: pageRect.width - 80, height: pageRect.height - 80)
            
            // Split content into pages
            let lines = content.components(separatedBy: .newlines)
            var currentY: CGFloat = 40
            let lineHeight: CGFloat = 16
            let pageBottom: CGFloat = pageRect.height - 40
            
            for line in lines {
                if currentY + lineHeight > pageBottom {
                    context.beginPage()
                    currentY = 40
                }
                
                let useAttributes = line.contains("=====") || line.uppercased() == line ? titleAttributes : attributes
                let lineRect = CGRect(x: 40, y: currentY, width: textRect.width, height: lineHeight)
                line.draw(in: lineRect, withAttributes: useAttributes)
                currentY += lineHeight
            }
        }
    }
    #endif
    
    #if canImport(AppKit)
    private func createPDFmacOS(content: String) throws -> Data {
        // For macOS, we'll create a simple text-based PDF
        // This is a simplified implementation
        let pdfData = NSMutableData()
        
        // Create a simple PDF with NSString drawing
        var pageRect = NSRect(x: 0, y: 0, width: 612, height: 792)
        
        guard let context = CGContext(consumer: CGDataConsumer(data: pdfData)!, mediaBox: &pageRect, nil) else {
            throw PDFError.creationFailed
        }
        
        context.beginPDFPage(nil)
        
        let font = NSFont.systemFont(ofSize: 12)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.black
        ]
        
        let textRect = NSRect(x: 40, y: 40, width: pageRect.width - 80, height: pageRect.height - 80)
        content.draw(in: textRect, withAttributes: attributes)
        
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
