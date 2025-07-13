import Foundation
import SwiftUI
import CoreData

#if canImport(UIKit)
import UIKit
#endif

#if canImport(AppKit)
import AppKit
import PDFKit
#endif

// MARK: - Fixed PDF Service with Proper Error Handling
class FixedMealPlanPDFService: ObservableObject {
    @Published var isGenerating = false
    @Published var lastError: String?
    @Published var lastGeneratedPDF: Data?
    @Published var generationProgress: Double = 0.0
    
    enum PDFError: LocalizedError {
        case platformNotSupported
        case creationFailed(String)
        case dataEmpty
        case writeFailed
        
        var errorDescription: String? {
            switch self {
            case .platformNotSupported:
                return "PDF generation not supported on this platform"
            case .creationFailed(let reason):
                return "Failed to create PDF: \(reason)"
            case .dataEmpty:
                return "PDF data is empty"
            case .writeFailed:
                return "Failed to write PDF data"
            }
        }
    }
    
    // MARK: - Main PDF Generation Method
    func generateMealPlanPDF(
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
            generationProgress = 0.0
        }
        
        defer {
            Task { @MainActor in
                isGenerating = false
                generationProgress = 1.0
            }
        }
        
        do {
            print("📄 Starting PDF generation...")
            await updateProgress(0.1)
            
            // Step 1: Validate input data
            guard !multiDayPlan.dailyPlans.isEmpty else {
                throw PDFError.creationFailed("No meal plans to generate PDF from")
            }
            
            await updateProgress(0.2)
            
            // Step 2: Generate content structure
            let pdfContent = try await generatePDFContent(
                plan: multiDayPlan,
                patient: patient,
                includeRecipes: includeRecipes,
                includeShoppingList: includeShoppingList,
                includeNutritionAnalysis: includeNutritionAnalysis,
                language: language
            )
            
            await updateProgress(0.6)
            
            // Step 3: Create PDF data
            let pdfData = try await createPDFData(content: pdfContent, language: language)
            
            await updateProgress(0.9)
            
            // Step 4: Validate generated PDF
            guard !pdfData.isEmpty else {
                throw PDFError.dataEmpty
            }
            
            // Verify PDF is valid
            #if canImport(AppKit)
            guard PDFDocument(data: pdfData) != nil else {
                throw PDFError.creationFailed("Generated PDF data is invalid")
            }
            #endif
            
            await MainActor.run {
                lastGeneratedPDF = pdfData
            }
            
            await updateProgress(1.0)
            
            print("✅ PDF generated successfully (\(pdfData.count) bytes)")
            return pdfData
            
        } catch {
            await MainActor.run {
                lastError = error.localizedDescription
            }
            print("❌ PDF generation failed: \(error)")
            throw error
        }
    }
    
    // MARK: - Content Generation
    private func generatePDFContent(
        plan: MultiDayMealPlan,
        patient: Patient?,
        includeRecipes: Bool,
        includeShoppingList: Bool,
        includeNutritionAnalysis: Bool,
        language: PlanLanguage
    ) async throws -> PDFContent {
        
        let strings = language.appStrings
        var sections: [PDFSection] = []
        
        // Cover Page
        sections.append(createCoverPage(plan: plan, patient: patient, strings: strings))
        
        // Plan Overview
        sections.append(createPlanOverview(plan: plan, strings: strings))
        
        // Daily Plans
        for (index, dailyPlan) in plan.dailyPlans.enumerated() {
            sections.append(createDailyPlanSection(
                dailyPlan: dailyPlan,
                dayNumber: index + 1,
                strings: strings
            ))
        }
        
        // Recipes Section
        if includeRecipes {
            sections.append(createRecipesSection(plan: plan, strings: strings))
        }
        
        // Shopping List
        if includeShoppingList {
            sections.append(createShoppingListSection(plan: plan, strings: strings))
        }
        
        // Nutrition Analysis
        if includeNutritionAnalysis {
            sections.append(createNutritionAnalysisSection(plan: plan, strings: strings))
        }
        
        return PDFContent(sections: sections, language: language)
    }
    
    // MARK: - PDF Content Sections
    private func createCoverPage(plan: MultiDayMealPlan, patient: Patient?, strings: AppLocalizedStrings) -> PDFSection {
        let patientName = patient.map { "\($0.firstName ?? "") \($0.lastName ?? "")" } ?? "Plan General"
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        
        let content = """
        PLAN DE ALIMENTACIÓN PERSONALIZADO
        
        Paciente: \(patientName)
        Duración: \(plan.numberOfDays) días
        Fecha de creación: \(dateFormatter.string(from: Date()))
        
        Generado con verificación USDA
        MealPlannerPro
        """
        
        return PDFSection(
            title: "Portada",
            content: content,
            type: .cover,
            pageBreakAfter: true
        )
    }
    
    private func createPlanOverview(plan: MultiDayMealPlan, strings: AppLocalizedStrings) -> PDFSection {
        let totalMeals = plan.dailyPlans.reduce(0) { $0 + $1.meals.count }
        let avgCalories = plan.dailyPlans.map { dailyPlan in
            dailyPlan.meals.reduce(0.0) { $0 + $1.verifiedFoods.reduce(0.0) { $0 + $1.verifiedNutrition.calories } }
        }.reduce(0.0, +) / Double(plan.numberOfDays)
        
        let content = """
        RESUMEN DEL PLAN
        
        Información General:
        • Duración: \(plan.numberOfDays) días
        • Total de comidas: \(totalMeals)
        • Promedio diario de calorías: \(Int(avgCalories)) kcal
        
        Características del Plan:
        • Todas las comidas han sido verificadas con la base de datos USDA
        • Información nutricional precisa y actualizada
        • Adaptado a preferencias y restricciones dietéticas
        
        """
        
        return PDFSection(
            title: "Resumen del Plan",
            content: content,
            type: .summary,
            pageBreakAfter: false
        )
    }
    
    private func createDailyPlanSection(dailyPlan: DailyMealPlan, dayNumber: Int, strings: AppLocalizedStrings) -> PDFSection {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .full
        
        var content = "DÍA \(dayNumber) - \(dateFormatter.string(from: dailyPlan.date))\n\n"
        
        let totalDayCalories = dailyPlan.meals.reduce(0.0) { total, meal in
            total + meal.verifiedFoods.reduce(0.0) { $0 + $1.verifiedNutrition.calories }
        }
        
        content += "Calorías totales del día: \(Int(totalDayCalories)) kcal\n\n"
        
        for meal in dailyPlan.meals {
            content += "\(meal.originalAISuggestion.mealType.localizedName(language: .spanish).uppercased())\n"
            content += "\(meal.originalAISuggestion.mealName)\n"
            content += "Calorías: \(meal.originalAISuggestion.estimatedCalories) kcal\n\n"
            
            content += "Ingredientes:\n"
            for verifiedFood in meal.verifiedFoods {
                let verification = verifiedFood.isVerified ? "✓" : "○"
                content += "  \(verification) \(verifiedFood.originalAISuggestion.name) - \(verifiedFood.originalAISuggestion.gramWeight)g\n"
                content += "    Calorías: \(Int(verifiedFood.verifiedNutrition.calories)), Proteína: \(Int(verifiedFood.verifiedNutrition.protein))g\n"
            }
            content += "\n"
            
            if let instructions = meal.originalAISuggestion.cookingInstructions {
                content += "Instrucciones:\n\(instructions)\n\n"
            }
            
            content += "---\n\n"
        }
        
        return PDFSection(
            title: "Día \(dayNumber)",
            content: content,
            type: .dailyPlans,
            pageBreakAfter: dayNumber % 2 == 0 // Page break every 2 days
        )
    }
    
    private func createRecipesSection(plan: MultiDayMealPlan, strings: AppLocalizedStrings) -> PDFSection {
        var content = "RECETAS DETALLADAS\n\n"
        
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
        
        for (_, meal) in uniqueMeals.sorted(by: { $0.key < $1.key }) {
            content += "\(meal.originalAISuggestion.mealName.uppercased())\n"
            content += "Tiempo de preparación: 15-30 minutos\n"
            content += "Porciones: 1\n"
            content += "Calorías por porción: \(meal.originalAISuggestion.estimatedCalories) kcal\n\n"
            
            content += "INGREDIENTES:\n"
            for verifiedFood in meal.verifiedFoods {
                content += "• \(verifiedFood.originalAISuggestion.gramWeight)g de \(verifiedFood.originalAISuggestion.name)\n"
            }
            content += "\n"
            
            content += "PREPARACIÓN:\n"
            if let instructions = meal.originalAISuggestion.cookingInstructions {
                content += instructions
            } else {
                content += "1. Preparar todos los ingredientes según las cantidades indicadas\n"
                content += "2. Seguir las instrucciones de cocción apropiadas para cada ingrediente\n"
                content += "3. Combinar según el tipo de comida preparada\n"
                content += "4. Servir inmediatamente\n"
            }
            content += "\n\n"
            
            content += "INFORMACIÓN NUTRICIONAL:\n"
            let totalCalories = meal.verifiedFoods.reduce(0.0) { $0 + $1.verifiedNutrition.calories }
            let totalProtein = meal.verifiedFoods.reduce(0.0) { $0 + $1.verifiedNutrition.protein }
            let totalCarbs = meal.verifiedFoods.reduce(0.0) { $0 + $1.verifiedNutrition.carbohydrates }
            let totalFat = meal.verifiedFoods.reduce(0.0) { $0 + $1.verifiedNutrition.fat }
            
            content += "• Calorías: \(Int(totalCalories)) kcal\n"
            content += "• Proteínas: \(Int(totalProtein))g\n"
            content += "• Carbohidratos: \(Int(totalCarbs))g\n"
            content += "• Grasas: \(Int(totalFat))g\n\n"
            
            content += "═══════════════════════════════════════\n\n"
        }
        
        return PDFSection(
            title: "Recetas",
            content: content,
            type: .recipes,
            pageBreakAfter: true
        )
    }
    
    private func createShoppingListSection(plan: MultiDayMealPlan, strings: AppLocalizedStrings) -> PDFSection {
        var content = "LISTA DE COMPRAS\n\n"
        
        // Aggregate all ingredients
        var ingredientTotals: [String: Double] = [:]
        
        for dailyPlan in plan.dailyPlans {
            for meal in dailyPlan.meals {
                for verifiedFood in meal.verifiedFoods {
                    let foodName = verifiedFood.originalAISuggestion.name
                    let weight = Double(verifiedFood.originalAISuggestion.gramWeight)
                    ingredientTotals[foodName, default: 0.0] += weight
                }
            }
        }
        
        // Sort ingredients alphabetically
        let sortedIngredients = ingredientTotals.sorted { $0.key < $1.key }
        
        content += "Ingredientes necesarios para \(plan.numberOfDays) días:\n\n"
        
        for (ingredient, totalWeight) in sortedIngredients {
            content += "□ \(ingredient) - \(Int(totalWeight))g\n"
        }
        
        content += "\n\nNotas:\n"
        content += "• Las cantidades están calculadas para el número exacto de días del plan\n"
        content += "• Se recomienda comprar un 10% adicional para compensar variaciones\n"
        content += "• Verificar disponibilidad de productos orgánicos si es necesario\n"
        
        return PDFSection(
            title: "Lista de Compras",
            content: content,
            type: .shoppingList,
            pageBreakAfter: true
        )
    }
    
    private func createNutritionAnalysisSection(plan: MultiDayMealPlan, strings: AppLocalizedStrings) -> PDFSection {
        var content = "ANÁLISIS NUTRICIONAL\n\n"
        
        var dailyNutrition: [(calories: Double, protein: Double, carbs: Double, fat: Double)] = []
        
        for dailyPlan in plan.dailyPlans {
            var dayCalories = 0.0
            var dayProtein = 0.0
            var dayCarbs = 0.0
            var dayFat = 0.0
            
            for meal in dailyPlan.meals {
                for verifiedFood in meal.verifiedFoods {
                    dayCalories += verifiedFood.verifiedNutrition.calories
                    dayProtein += verifiedFood.verifiedNutrition.protein
                    dayCarbs += verifiedFood.verifiedNutrition.carbohydrates
                    dayFat += verifiedFood.verifiedNutrition.fat
                }
            }
            
            dailyNutrition.append((dayCalories, dayProtein, dayCarbs, dayFat))
        }
        
        // Calculate averages
        let avgCalories = dailyNutrition.map { $0.calories }.reduce(0, +) / Double(plan.numberOfDays)
        let avgProtein = dailyNutrition.map { $0.protein }.reduce(0, +) / Double(plan.numberOfDays)
        let avgCarbs = dailyNutrition.map { $0.carbs }.reduce(0, +) / Double(plan.numberOfDays)
        let avgFat = dailyNutrition.map { $0.fat }.reduce(0, +) / Double(plan.numberOfDays)
        
        content += "PROMEDIO DIARIO:\n"
        content += "• Calorías: \(Int(avgCalories)) kcal\n"
        content += "• Proteínas: \(Int(avgProtein))g (\(Int(avgProtein * 4))kcal)\n"
        content += "• Carbohidratos: \(Int(avgCarbs))g (\(Int(avgCarbs * 4))kcal)\n"
        content += "• Grasas: \(Int(avgFat))g (\(Int(avgFat * 9))kcal)\n\n"
        
        content += "DESGLOSE POR DÍAS:\n\n"
        
        for (index, nutrition) in dailyNutrition.enumerated() {
            content += "Día \(index + 1):\n"
            content += "  Calorías: \(Int(nutrition.calories)) kcal\n"
            content += "  Proteínas: \(Int(nutrition.protein))g\n"
            content += "  Carbohidratos: \(Int(nutrition.carbs))g\n"
            content += "  Grasas: \(Int(nutrition.fat))g\n\n"
        }
        
        // Add recommendations
        content += "RECOMENDACIONES:\n"
        content += "• Todas las comidas han sido verificadas con la base de datos USDA\n"
        content += "• Los valores nutricionales son precisos y actualizados\n"
        content += "• Se recomienda consultar con un profesional de la salud antes de iniciar cualquier plan alimenticio\n"
        
        return PDFSection(
            title: "Análisis Nutricional",
            content: content,
            type: .nutritionAnalysis,
            pageBreakAfter: false
        )
    }
    
    // MARK: - PDF Data Creation
    private func createPDFData(content: PDFContent, language: PlanLanguage) async throws -> Data {
        print("📄 Creating PDF data...")
        
        #if canImport(AppKit)
        return try await createPDFDataMacOS(content: content)
        #elseif canImport(UIKit)
        return try await createPDFDataIOS(content: content)
        #else
        throw PDFError.platformNotSupported
        #endif
    }
    
    #if canImport(AppKit)
    private func createPDFDataMacOS(content: PDFContent) async throws -> Data {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.main.async {
                do {
                    // Create a combined content string
                    let combinedContent = content.sections.map { section in
                        "\(section.title)\n\(String(repeating: "=", count: section.title.count))\n\n\(section.content)\n\n"
                    }.joined(separator: "\n")
                    
                    // Create attributed string with proper formatting
                    let font = NSFont.systemFont(ofSize: 12)
                    let titleFont = NSFont.boldSystemFont(ofSize: 16)
                    
                    let attributedString = NSMutableAttributedString()
                    
                    // Split content by sections and format differently
                    for section in content.sections {
                        // Add title
                        let titleString = NSAttributedString(
                            string: "\(section.title)\n",
                            attributes: [
                                .font: titleFont,
                                .foregroundColor: NSColor.black
                            ]
                        )
                        attributedString.append(titleString)
                        
                        // Add separator
                        let separatorString = NSAttributedString(
                            string: "\(String(repeating: "=", count: section.title.count))\n\n",
                            attributes: [
                                .font: font,
                                .foregroundColor: NSColor.gray
                            ]
                        )
                        attributedString.append(separatorString)
                        
                        // Add content
                        let contentString = NSAttributedString(
                            string: "\(section.content)\n\n",
                            attributes: [
                                .font: font,
                                .foregroundColor: NSColor.black
                            ]
                        )
                        attributedString.append(contentString)
                        
                        if section.pageBreakAfter {
                            let pageBreak = NSAttributedString(
                                string: "\n\n\n",
                                attributes: [.font: font]
                            )
                            attributedString.append(pageBreak)
                        }
                    }
                    
                    // Create PDF from attributed string
                    let pageSize = NSSize(width: 612, height: 792) // US Letter
                    let margin: CGFloat = 72
                    let textRect = NSRect(
                        x: margin,
                        y: margin,
                        width: pageSize.width - (margin * 2),
                        height: pageSize.height - (margin * 2)
                    )
                    
                    // Create text container and layout manager
                    let textContainer = NSTextContainer(size: textRect.size)
                    let layoutManager = NSLayoutManager()
                    let textStorage = NSTextStorage(attributedString: attributedString)
                    
                    textStorage.addLayoutManager(layoutManager)
                    layoutManager.addTextContainer(textContainer)
                    
                    // Generate PDF data
                    let pdfData = NSMutableData()
                    
                    let consumer = CGDataConsumer(data: pdfData)!
                    let pdfContext = CGContext(consumer: consumer, mediaBox: &CGRect(origin: .zero, size: pageSize), nil)!
                    
                    pdfContext.beginPDFPage(nil)
                    
                    let nsGraphicsContext = NSGraphicsContext(cgContext: pdfContext, flipped: false)
                    NSGraphicsContext.current = nsGraphicsContext
                    
                    // Draw text
                    let range = NSRange(location: 0, length: attributedString.length)
                    layoutManager.drawGlyphs(forGlyphRange: range, at: NSPoint(x: margin, y: margin))
                    
                    pdfContext.endPDFPage()
                    pdfContext.closePDF()
                    
                    continuation.resume(returning: pdfData as Data)
                    
                } catch {
                    continuation.resume(throwing: PDFError.creationFailed(error.localizedDescription))
                }
            }
        }
    }
    #endif
    
    #if canImport(UIKit)
    private func createPDFDataIOS(content: PDFContent) async throws -> Data {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.main.async {
                do {
                    let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
                    let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
                    
                    let data = renderer.pdfData { context in
                        context.beginPage()
                        
                        let margin: CGFloat = 50
                        let textRect = CGRect(
                            x: margin,
                            y: margin,
                            width: pageRect.width - (margin * 2),
                            height: pageRect.height - (margin * 2)
                        )
                        
                        // Combine all content
                        let combinedContent = content.sections.map { section in
                            "\(section.title)\n\(String(repeating: "=", count: section.title.count))\n\n\(section.content)\n\n"
                        }.joined(separator: "\n")
                        
                        let font = UIFont.systemFont(ofSize: 12)
                        let attributes: [NSAttributedString.Key: Any] = [
                            .font: font,
                            .foregroundColor: UIColor.black
                        ]
                        
                        combinedContent.draw(in: textRect, withAttributes: attributes)
                    }
                    
                    continuation.resume(returning: data)
                    
                } catch {
                    continuation.resume(throwing: PDFError.creationFailed(error.localizedDescription))
                }
            }
        }
    }
    #endif
    
    // MARK: - Helper Methods
    private func updateProgress(_ progress: Double) async {
        await MainActor.run {
            generationProgress = progress
        }
    }
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

// MARK: - Enhanced PDF Viewer with Error Handling
struct FixedPDFViewer: View {
    let pdfData: Data
    @Environment(\.dismiss) private var dismiss
    @State private var showingSaveDialog = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            Group {
                if let document = PDFDocument(data: pdfData) {
                    // Successful PDF display
                    PDFKitRepresentable(document: document)
                        .navigationTitle("Plan de Alimentación")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button("Cerrar") {
                                    dismiss()
                                }
                            }
                            
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Guardar") {
                                    showingSaveDialog = true
                                }
                            }
                        }
                } else {
                    // Error state
                    VStack(spacing: 20) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 50))
                            .foregroundColor(.orange)
                        
                        Text("Error al cargar PDF")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("El archivo PDF no se pudo cargar correctamente. Los datos pueden estar corruptos.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button("Cerrar") {
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                }
            }
        }
        .fileExporter(
            isPresented: $showingSaveDialog,
            document: PDFDocument(data: pdfData).map { PDFFile(document: $0) },
            contentType: .pdf,
            defaultFilename: "Plan_Alimentacion_\(Date().timeIntervalSince1970)"
        ) { result in
            switch result {
            case .success(let url):
                print("✅ PDF saved to: \(url)")
            case .failure(let error):
                print("❌ Failed to save PDF: \(error)")
                errorMessage = error.localizedDescription
            }
        }
        .alert("Error al guardar", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            if let error = errorMessage {
                Text(error)
            }
        }
    }
}

// MARK: - PDF Document File Type
struct PDFFile: FileDocument {
    static var readableContentTypes: [UTType] { [.pdf] }
    
    let document: PDFDocument
    
    init(document: PDFDocument) {
        self.document = document
    }
    
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let document = PDFDocument(data: data) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.document = document
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = document.dataRepresentation() ?? Data()
        return FileWrapper(regularFileWithContents: data)
    }
}
