import SwiftUI
import Foundation

// MARK: - LanguageManagement.swift
// Purpose: Provides a complete, conflict-free language management system
// Why needed: Your project has duplicate language-related definitions causing compilation errors

// ==========================================
// CORE LANGUAGE ENUM
// ==========================================

// This enum represents the supported languages in your app
// It's designed to work with your existing PlanLanguage enum if it exists
public enum AppLanguage: String, CaseIterable {
    case spanish = "es"
    case english = "en"
    
    // Human-readable names for display in the UI
    var displayName: String {
        switch self {
        case .spanish: return "Español"
        case .english: return "English"
        }
    }
    
    // Flag emojis for visual language identification
    var flag: String {
        switch self {
        case .spanish: return "🇪🇸"
        case .english: return "🇺🇸"
        }
    }
    
    // Short codes for compact display
    var shortCode: String {
        switch self {
        case .spanish: return "ES"
        case .english: return "EN"
        }
    }
}

// ==========================================
// LANGUAGE STRINGS PROTOCOL
// ==========================================

// This protocol defines all the text strings your app needs
// By using a protocol, we ensure both language implementations have the same strings
// Think of this as a contract that both Spanish and English must fulfill
public protocol AppTextProtocol {
    // Navigation and main interface
    var appTitle: String { get }
    var foodSearch: String { get }
    var myFoods: String { get }
    var basicPlans: String { get }
    var aiAssistant: String { get }
    var multiDayPlanner: String { get }
    
    // Actions and buttons
    var generate: String { get }
    var generating: String { get }
    var save: String { get }
    var cancel: String { get }
    var delete: String { get }
    var edit: String { get }
    var close: String { get }
    var retry: String { get }
    
    // Status and feedback
    var loading: String { get }
    var error: String { get }
    var success: String { get }
    var warning: String { get }
    var ok: String { get }
    var yes: String { get }
    var no: String { get }
    
    // Food and nutrition related
    var calories: String { get }
    var protein: String { get }
    var carbohydrates: String { get }
    var fat: String { get }
    var fiber: String { get }
    var searchFoods: String { get }
    var addToFavorites: String { get }
    var noResults: String { get }
    
    // AI Assistant specific
    var aiAssistantTitle: String { get }
    var aiAssistantSubtitle: String { get }
    var generateMeal: String { get }
    var mealGenerated: String { get }
    var selectPatient: String { get }
    var targetCalories: String { get }
    var mealType: String { get }
    var cuisine: String { get }
    var dietaryRestrictions: String { get }
    var medicalConditions: String { get }
    
    // PDF and export
    var generatePDF: String { get }
    var generatingPDF: String { get }
    var pdfGenerated: String { get }
    var exportOptions: String { get }
    var includeRecipes: String { get }
    var includeShoppingList: String { get }
    var includeNutritionAnalysis: String { get }
    
    // Food selection
    var verifyFoodSelection: String { get }
    var selectAccurateMatch: String { get }
    var skipThisFood: String { get }
    var useSelected: String { get }
    var confidence: String { get }
}

// ==========================================
// SPANISH LANGUAGE IMPLEMENTATION
// ==========================================

// This struct provides all Spanish translations
// Each property corresponds to a key in the protocol above
public struct SpanishAppText: AppTextProtocol {
    // Navigation and main interface
    public let appTitle = "MealPlannerPro"
    public let foodSearch = "Buscar Alimentos"
    public let myFoods = "Mis Alimentos"
    public let basicPlans = "Planes Básicos"
    public let aiAssistant = "Asistente IA"
    public let multiDayPlanner = "Planes Multi-Día"
    
    // Actions and buttons
    public let generate = "Generar"
    public let generating = "Generando..."
    public let save = "Guardar"
    public let cancel = "Cancelar"
    public let delete = "Eliminar"
    public let edit = "Editar"
    public let close = "Cerrar"
    public let retry = "Reintentar"
    
    // Status and feedback
    public let loading = "Cargando..."
    public let error = "Error"
    public let success = "Éxito"
    public let warning = "Advertencia"
    public let ok = "OK"
    public let yes = "Sí"
    public let no = "No"
    
    // Food and nutrition related
    public let calories = "Calorías"
    public let protein = "Proteína"
    public let carbohydrates = "Carbohidratos"
    public let fat = "Grasa"
    public let fiber = "Fibra"
    public let searchFoods = "Buscar Alimentos"
    public let addToFavorites = "Agregar a Favoritos"
    public let noResults = "No se encontraron resultados"
    
    // AI Assistant specific
    public let aiAssistantTitle = "🤖 Asistente de IA"
    public let aiAssistantSubtitle = "Genera comidas personalizadas con verificación USDA"
    public let generateMeal = "Generar Comida"
    public let mealGenerated = "¡Comida Generada!"
    public let selectPatient = "Seleccionar Paciente"
    public let targetCalories = "Calorías Objetivo"
    public let mealType = "Tipo de Comida"
    public let cuisine = "Tipo de Cocina"
    public let dietaryRestrictions = "Restricciones Dietéticas"
    public let medicalConditions = "Condiciones Médicas"
    
    // PDF and export
    public let generatePDF = "Generar PDF"
    public let generatingPDF = "Generando PDF..."
    public let pdfGenerated = "PDF Generado"
    public let exportOptions = "Opciones de Exportación"
    public let includeRecipes = "Incluir Recetas"
    public let includeShoppingList = "Incluir Lista de Compras"
    public let includeNutritionAnalysis = "Incluir Análisis Nutricional"
    
    // Food selection
    public let verifyFoodSelection = "Verificar Selección de Alimento"
    public let selectAccurateMatch = "Selecciona la coincidencia más precisa:"
    public let skipThisFood = "Omitir Este Alimento"
    public let useSelected = "Usar Seleccionado"
    public let confidence = "Confianza"
}

// ==========================================
// ENGLISH LANGUAGE IMPLEMENTATION
// ==========================================

// This struct provides all English translations
// Notice how it mirrors the Spanish structure exactly
public struct EnglishAppText: AppTextProtocol {
    // Navigation and main interface
    public let appTitle = "MealPlannerPro"
    public let foodSearch = "Search Foods"
    public let myFoods = "My Foods"
    public let basicPlans = "Basic Plans"
    public let aiAssistant = "AI Assistant"
    public let multiDayPlanner = "Multi-Day Planner"
    
    // Actions and buttons
    public let generate = "Generate"
    public let generating = "Generating..."
    public let save = "Save"
    public let cancel = "Cancel"
    public let delete = "Delete"
    public let edit = "Edit"
    public let close = "Close"
    public let retry = "Retry"
    
    // Status and feedback
    public let loading = "Loading..."
    public let error = "Error"
    public let success = "Success"
    public let warning = "Warning"
    public let ok = "OK"
    public let yes = "Yes"
    public let no = "No"
    
    // Food and nutrition related
    public let calories = "Calories"
    public let protein = "Protein"
    public let carbohydrates = "Carbohydrates"
    public let fat = "Fat"
    public let fiber = "Fiber"
    public let searchFoods = "Search Foods"
    public let addToFavorites = "Add to Favorites"
    public let noResults = "No results found"
    
    // AI Assistant specific
    public let aiAssistantTitle = "🤖 AI Assistant"
    public let aiAssistantSubtitle = "Generate personalized meals with USDA verification"
    public let generateMeal = "Generate Meal"
    public let mealGenerated = "Meal Generated!"
    public let selectPatient = "Select Patient"
    public let targetCalories = "Target Calories"
    public let mealType = "Meal Type"
    public let cuisine = "Cuisine Type"
    public let dietaryRestrictions = "Dietary Restrictions"
    public let medicalConditions = "Medical Conditions"
    
    // PDF and export
    public let generatePDF = "Generate PDF"
    public let generatingPDF = "Generating PDF..."
    public let pdfGenerated = "PDF Generated"
    public let exportOptions = "Export Options"
    public let includeRecipes = "Include Recipes"
    public let includeShoppingList = "Include Shopping List"
    public let includeNutritionAnalysis = "Include Nutrition Analysis"
    
    // Food selection
    public let verifyFoodSelection = "Verify Food Selection"
    public let selectAccurateMatch = "Select the most accurate match:"
    public let skipThisFood = "Skip This Food"
    public let useSelected = "Use Selected"
    public let confidence = "Confidence"
}

// ==========================================
// LANGUAGE MANAGER CLASS
// ==========================================

// This class manages the current language state throughout your app
// It's a singleton, meaning there's only one instance shared across the entire app
// Think of it as the "brain" that remembers which language the user has chosen
public class AppLanguageManager: ObservableObject {
    // @Published means SwiftUI will automatically update views when this changes
    @Published public var currentLanguage: AppLanguage = .spanish
    
    // Singleton instance - there's only one language manager for the whole app
    public static let shared = AppLanguageManager()
    
    // Private initializer ensures only one instance can be created
    private init() {
        loadSavedLanguage()
    }
    
    // This computed property gives you the current text translations
    // It's like asking the manager: "What words should I use right now?"
    public var text: AppTextProtocol {
        switch currentLanguage {
        case .spanish:
            return SpanishAppText()
        case .english:
            return EnglishAppText()
        }
    }
    
    // Call this method to change the language
    // It updates the current language AND saves the preference for next time
    public func setLanguage(_ language: AppLanguage) {
        currentLanguage = language
        saveLanguagePreference()
        
        // Post a notification so other parts of your app can react to the change
        NotificationCenter.default.post(
            name: .languageDidChange,
            object: language
        )
    }
    
    // Convenient method to switch between Spanish and English
    public func toggleLanguage() {
        let newLanguage: AppLanguage = currentLanguage == .spanish ? .english : .spanish
        setLanguage(newLanguage)
    }
    
    // MARK: - Private Helper Methods
    
    // Saves the current language choice to UserDefaults so it persists between app launches
    private func saveLanguagePreference() {
        UserDefaults.standard.set(currentLanguage.rawValue, forKey: "AppLanguagePreference")
    }
    
    // Loads the previously saved language choice when the app starts
    private func loadSavedLanguage() {
        if let savedLanguageCode = UserDefaults.standard.string(forKey: "AppLanguagePreference"),
           let savedLanguage = AppLanguage(rawValue: savedLanguageCode) {
            currentLanguage = savedLanguage
        }
        // If no saved preference, it defaults to Spanish (set in the property declaration above)
    }
}

// ==========================================
// LANGUAGE SWITCHER UI COMPONENT
// ==========================================

// This is a reusable SwiftUI view that displays a language toggle button
// You can place this anywhere in your UI where you want users to change languages
public struct LanguageSwitcher: View {
    // We observe the language manager so the UI updates when language changes
    @ObservedObject private var languageManager = AppLanguageManager.shared
    
    public init() {}
    
    public var body: some View {
        Button(action: {
            // When tapped, toggle between languages
            languageManager.toggleLanguage()
        }) {
            HStack(spacing: 6) {
                Text(languageManager.currentLanguage.flag)
                    .font(.body)
                
                Text(languageManager.currentLanguage.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// ==========================================
// CONVENIENT VIEW EXTENSION
// ==========================================

// This extension makes it easy to get translated text from any SwiftUI view
// Instead of writing AppLanguageManager.shared.text.someProperty every time,
// you can just write appText.someProperty
extension View {
    var appText: AppTextProtocol {
        AppLanguageManager.shared.text
    }
}

// ==========================================
// NOTIFICATION NAMES
// ==========================================

// Custom notification that gets posted when language changes
// Other parts of your app can listen for this notification to react to language changes
extension Notification.Name {
    static let languageDidChange = Notification.Name("AppLanguageDidChange")
}

// ==========================================
// COMPATIBILITY WITH EXISTING CODE
// ==========================================

// If your existing code uses PlanLanguage, this extension provides compatibility
// You can remove this section if you don't have PlanLanguage in your project
extension AppLanguage {
    // Convert to PlanLanguage if your project already uses it
    var toPlanLanguage: PlanLanguage? {
        switch self {
        case .spanish:
            return .spanish
        case .english:
            return .english
        }
    }
    
    // Create from PlanLanguage if your project already uses it
    init?(from planLanguage: PlanLanguage) {
        switch planLanguage {
        case .spanish:
            self = .spanish
        case .english:
            self = .english
        }
    }
}

// ==========================================
// USAGE INSTRUCTIONS
// ==========================================

/*
 HOW TO INTEGRATE THIS LANGUAGE SYSTEM:

 STEP 1: ADD THE FILE
 - Add this file to your project as "LanguageManagement.swift"
 - Build the project to make sure there are no conflicts

 STEP 2: REPLACE HARDCODED STRINGS
 In your existing views, replace hardcoded Spanish text:
 
 BEFORE:
 Text("Buscar Alimentos")
 Text("Mis Alimentos")
 
 AFTER:
 Text(appText.foodSearch)
 Text(appText.myFoods)

 STEP 3: ADD LANGUAGE SWITCHER TO YOUR MAIN VIEW
 In your ContentView or main navigation, add:
 
 HStack {
     Text("MealPlannerPro")
         .font(.title)
     Spacer()
     LanguageSwitcher()  // <-- Add this
 }

 STEP 4: REMOVE DUPLICATE DEFINITIONS
 Search your project for these and DELETE any duplicates:
 - class LanguageManager
 - struct SpanishStrings
 - struct EnglishStrings
 - Keep only the ones in this file

 STEP 5: TEST LANGUAGE SWITCHING
 - Build and run your app
 - Tap the language switcher
 - Verify that text changes from Spanish to English and back

 STEP 6: HANDLE EXISTING CODE CONFLICTS
 If you have existing PlanLanguage enum, you can either:
 - Replace it with AppLanguage everywhere, OR
 - Use the compatibility extensions above to convert between them

 This approach is designed to be the single source of truth for language management
 in your app, eliminating the duplicate definition errors you're seeing.
 */
