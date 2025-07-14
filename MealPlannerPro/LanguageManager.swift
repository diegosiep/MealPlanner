import SwiftUI
import Foundation

// MARK: - LanguageManager.swift
// Fixed: Invalid redeclarations of displayName, SpanishStrings, EnglishStrings, LanguageSwitcher

// ==========================================
// CORE LANGUAGE ENUM
// ==========================================

enum PlanLanguage: String, CaseIterable {
    case spanish = "es"
    case english = "en"
    
    var displayName: String {
        switch self {
        case .spanish: return "Español"
        case .english: return "English"
        }
    }
    
    var flag: String {
        switch self {
        case .spanish: return "🇪🇸"
        case .english: return "🇺🇸"
        }
    }
    
    var appStrings: AppLocalizedStrings {
        switch self {
        case .spanish:
            return SpanishLocalizedStrings()
        case .english:
            return EnglishLocalizedStrings()
        }
    }
}

// ==========================================
// LANGUAGE MANAGER CLASS
// ==========================================

class LanguageManager: ObservableObject {
    @Published var currentLanguage: PlanLanguage = .spanish
    @Published var isLanguageMenuOpen = false
    
    static let shared = LanguageManager()
    
    private init() {
        if let savedLanguage = UserDefaults.standard.object(forKey: "selectedLanguage") as? String,
           let language = PlanLanguage(rawValue: savedLanguage) {
            currentLanguage = language
        }
    }
    
    func setLanguage(_ language: PlanLanguage) {
        currentLanguage = language
        UserDefaults.standard.set(language.rawValue, forKey: "selectedLanguage")
        NotificationCenter.default.post(name: .languageChanged, object: language)
    }
    
    func toggleLanguage() {
        let newLanguage: PlanLanguage = currentLanguage == .spanish ? .english : .spanish
        setLanguage(newLanguage)
    }
}

// ==========================================
// LOCALIZATION PROTOCOL
// ==========================================

protocol AppLocalizedStrings {
    // Navigation
    var foodSearch: String { get }
    var myFoods: String { get }
    var basicPlans: String { get }
    var aiAssistant: String { get }
    var multiDayPlanner: String { get }
    
    // AI Assistant
    var aiAssistantTitle: String { get }
    var aiAssistantSubtitle: String { get }
    var generatePersonalizedMeals: String { get }
    var patientSelection: String { get }
    var selectPatient: String { get }
    var mealConfiguration: String { get }
    var targetCalories: String { get }
    var mealType: String { get }
    var cuisine: String { get }
    var preferences: String { get }
    var dietaryRestrictions: String { get }
    var medicalConditions: String { get }
    var generateMeal: String { get }
    var generating: String { get }
    var mealGenerated: String { get }
    var error: String { get }
    
    // Food Search
    var searchFoods: String { get }
    var searchPlaceholder: String { get }
    var noResults: String { get }
    var loading: String { get }
    var addToFavorites: String { get }
    
    // PDF Export
    var exportOptions: String { get }
    var includeInPDF: String { get }
    var detailedRecipes: String { get }
    var shoppingList: String { get }
    var nutritionalAnalysis: String { get }
    var generateCompletePDF: String { get }
    var generatingPDF: String { get }
    var pdfGenerated: String { get }
    var pdfError: String { get }
    
    // Food Matching
    var verifyFoodSelection: String { get }
    var selectAccurateMatch: String { get }
    var skipThisFood: String { get }
    var useSelected: String { get }
    var nutritionInfo: String { get }
    var confidence: String { get }
    
    // Common
    var save: String { get }
    var cancel: String { get }
    var delete: String { get }
    var edit: String { get }
    var close: String { get }
    var ok: String { get }
    var yes: String { get }
    var no: String { get }
    var retry: String { get }
}

// ==========================================
// SPANISH LOCALIZATION
// ==========================================

struct SpanishLocalizedStrings: AppLocalizedStrings {
    // Navigation
    let foodSearch = "Buscar Alimentos"
    let myFoods = "Mis Alimentos"
    let basicPlans = "Planes Básicos"
    let aiAssistant = "Asistente IA"
    let multiDayPlanner = "Planes Multi-Día"
    
    // AI Assistant
    let aiAssistantTitle = "🤖 Asistente de IA"
    let aiAssistantSubtitle = "Genera comidas personalizadas con verificación USDA"
    let generatePersonalizedMeals = "Generar Comidas Personalizadas"
    let patientSelection = "Selección de Paciente"
    let selectPatient = "Seleccionar Paciente"
    let mealConfiguration = "Configuración de Comida"
    let targetCalories = "Calorías Objetivo"
    let mealType = "Tipo de Comida"
    let cuisine = "Tipo de Cocina"
    let preferences = "Preferencias"
    let dietaryRestrictions = "Restricciones Dietéticas"
    let medicalConditions = "Condiciones Médicas"
    let generateMeal = "Generar Comida"
    let generating = "Generando..."
    let mealGenerated = "¡Comida Generada!"
    let error = "Error"
    
    // Food Search
    let searchFoods = "Buscar Alimentos"
    let searchPlaceholder = "Escriba el nombre del alimento..."
    let noResults = "No se encontraron resultados"
    let loading = "Cargando..."
    let addToFavorites = "Agregar a Favoritos"
    
    // PDF Export
    let exportOptions = "Opciones de Exportación"
    let includeInPDF = "Incluir en PDF"
    let detailedRecipes = "Recetas Detalladas"
    let shoppingList = "Lista de Compras"
    let nutritionalAnalysis = "Análisis Nutricional"
    let generateCompletePDF = "Generar PDF Completo"
    let generatingPDF = "Generando PDF..."
    let pdfGenerated = "PDF Generado"
    let pdfError = "Error al generar PDF"
    
    // Food Matching
    let verifyFoodSelection = "Verificar Selección de Alimentos"
    let selectAccurateMatch = "Selecciona la opción más precisa:"
    let skipThisFood = "Omitir este Alimento"
    let useSelected = "Usar Seleccionado"
    let nutritionInfo = "Información Nutricional"
    let confidence = "Confianza"
    
    // Common
    let save = "Guardar"
    let cancel = "Cancelar"
    let delete = "Eliminar"
    let edit = "Editar"
    let close = "Cerrar"
    let ok = "OK"
    let yes = "Sí"
    let no = "No"
    let retry = "Reintentar"
}

// ==========================================
// ENGLISH LOCALIZATION
// ==========================================

struct EnglishLocalizedStrings: AppLocalizedStrings {
    // Navigation
    let foodSearch = "Food Search"
    let myFoods = "My Foods"
    let basicPlans = "Basic Plans"
    let aiAssistant = "AI Assistant"
    let multiDayPlanner = "Multi-Day Planner"
    
    // AI Assistant
    let aiAssistantTitle = "🤖 AI Assistant"
    let aiAssistantSubtitle = "Generate personalized meals with USDA verification"
    let generatePersonalizedMeals = "Generate Personalized Meals"
    let patientSelection = "Patient Selection"
    let selectPatient = "Select Patient"
    let mealConfiguration = "Meal Configuration"
    let targetCalories = "Target Calories"
    let mealType = "Meal Type"
    let cuisine = "Cuisine Type"
    let preferences = "Preferences"
    let dietaryRestrictions = "Dietary Restrictions"
    let medicalConditions = "Medical Conditions"
    let generateMeal = "Generate Meal"
    let generating = "Generating..."
    let mealGenerated = "Meal Generated!"
    let error = "Error"
    
    // Food Search
    let searchFoods = "Search Foods"
    let searchPlaceholder = "Enter food name..."
    let noResults = "No results found"
    let loading = "Loading..."
    let addToFavorites = "Add to Favorites"
    
    // PDF Export
    let exportOptions = "Export Options"
    let includeInPDF = "Include in PDF"
    let detailedRecipes = "Detailed Recipes"
    let shoppingList = "Shopping List"
    let nutritionalAnalysis = "Nutritional Analysis"
    let generateCompletePDF = "Generate Complete PDF"
    let generatingPDF = "Generating PDF..."
    let pdfGenerated = "PDF Generated"
    let pdfError = "PDF Generation Error"
    
    // Food Matching
    let verifyFoodSelection = "Verify Food Selection"
    let selectAccurateMatch = "Select the most accurate match:"
    let skipThisFood = "Skip This Food"
    let useSelected = "Use Selected"
    let nutritionInfo = "Nutrition Information"
    let confidence = "Confidence"
    
    // Common
    let save = "Save"
    let cancel = "Cancel"
    let delete = "Delete"
    let edit = "Edit"
    let close = "Close"
    let ok = "OK"
    let yes = "Yes"
    let no = "No"
    let retry = "Retry"
}

// ==========================================
// LANGUAGE SWITCHER COMPONENT
// ==========================================

struct LanguageSwitcherView: View {
    @ObservedObject private var languageManager = LanguageManager.shared
    
    var body: some View {
        Button(action: {
            languageManager.toggleLanguage()
        }) {
            HStack(spacing: 8) {
                Text(languageManager.currentLanguage.flag)
                Text(languageManager.currentLanguage.displayName)
                Image(systemName: "chevron.down")
                    .font(.caption)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// ==========================================
// NOTIFICATION EXTENSION
// ==========================================

extension Notification.Name {
    static let languageChanged = Notification.Name("languageChanged")
}

// ==========================================
// VIEW MODIFIER FOR LANGUAGE UPDATES
// ==========================================

struct LanguageUpdateModifier: ViewModifier {
    @ObservedObject var languageManager = LanguageManager.shared
    
    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .languageChanged)) { _ in
                // Trigger view update when language changes
            }
    }
}

extension View {
    func languageUpdatable() -> some View {
        modifier(LanguageUpdateModifier())
    }
}

// ==========================================
// MEAL TYPE LOCALIZATION
// ==========================================

enum MealType: String, CaseIterable {
    case breakfast = "breakfast"
    case lunch = "lunch"
    case dinner = "dinner"
    case snack = "snack"
    
    var displayName: String {
        return localizedName
    }
    
    var localizedName: String {
        let languageManager = LanguageManager.shared
        switch languageManager.currentLanguage {
        case .spanish:
            switch self {
            case .breakfast: return "Desayuno"
            case .lunch: return "Almuerzo"
            case .dinner: return "Cena"
            case .snack: return "Merienda"
            }
        case .english:
            switch self {
            case .breakfast: return "Breakfast"
            case .lunch: return "Lunch"
            case .dinner: return "Dinner"
            case .snack: return "Snack"
            }
        }
    }
}
