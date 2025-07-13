import SwiftUI
import Foundation

// MARK: - Global Language Manager
class LanguageManager: ObservableObject {
    @Published var currentLanguage: PlanLanguage = .spanish
    @Published var isLanguageMenuOpen = false
    
    static let shared = LanguageManager()
    
    private init() {
        // Load saved language preference
        if let savedLanguage = UserDefaults.standard.object(forKey: "selectedLanguage") as? String,
           let language = PlanLanguage(rawValue: savedLanguage) {
            currentLanguage = language
        }
    }
    
    func setLanguage(_ language: PlanLanguage) {
        currentLanguage = language
        UserDefaults.standard.set(language.rawValue, forKey: "selectedLanguage")
        
        // Post notification for other parts of the app
        NotificationCenter.default.post(name: .languageChanged, object: language)
    }
    
    func toggleLanguage() {
        let newLanguage: PlanLanguage = currentLanguage == .spanish ? .english : .spanish
        setLanguage(newLanguage)
    }
}

// MARK: - Enhanced Localization System
extension PlanLanguage {
    var appStrings: AppLocalizedStrings {
        switch self {
        case .spanish:
            return SpanishStrings()
        case .english:
            return EnglishStrings()
        }
    }
    
    var flag: String {
        switch self {
        case .spanish: return "🇪🇸"
        case .english: return "🇺🇸"
        }
    }
    
    var displayName: String {
        switch self {
        case .spanish: return "Español"
        case .english: return "English"
        }
    }
}

// MARK: - Comprehensive App Strings Protocol
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

// MARK: - Spanish Localization
struct SpanishStrings: AppLocalizedStrings {
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
    let searchPlaceholder = "Escribe el nombre del alimento..."
    let noResults = "No se encontraron resultados"
    let loading = "Cargando..."
    let addToFavorites = "Agregar a Favoritos"
    
    // PDF Export
    let exportOptions = "📤 Opciones de Exportación"
    let includeInPDF = "Incluir en el PDF:"
    let detailedRecipes = "📝 Recetas detalladas"
    let shoppingList = "🛒 Lista de compras"
    let nutritionalAnalysis = "📊 Análisis nutricional"
    let generateCompletePDF = "Generar PDF Completo"
    let generatingPDF = "Generando PDF..."
    let pdfGenerated = "PDF Generado Exitosamente"
    let pdfError = "Error al generar PDF"
    
    // Food Matching
    let verifyFoodSelection = "Verificar Selección de Alimento"
    let selectAccurateMatch = "Selecciona la coincidencia más precisa de la base de datos USDA:"
    let skipThisFood = "Omitir Este Alimento"
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

// MARK: - English Localization
struct EnglishStrings: AppLocalizedStrings {
    // Navigation
    let foodSearch = "Search Foods"
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
    let searchPlaceholder = "Type food name..."
    let noResults = "No results found"
    let loading = "Loading..."
    let addToFavorites = "Add to Favorites"
    
    // PDF Export
    let exportOptions = "📤 Export Options"
    let includeInPDF = "Include in PDF:"
    let detailedRecipes = "📝 Detailed recipes"
    let shoppingList = "🛒 Shopping list"
    let nutritionalAnalysis = "📊 Nutritional analysis"
    let generateCompletePDF = "Generate Complete PDF"
    let generatingPDF = "Generating PDF..."
    let pdfGenerated = "PDF Generated Successfully"
    let pdfError = "PDF Generation Error"
    
    // Food Matching
    let verifyFoodSelection = "Verify Food Selection"
    let selectAccurateMatch = "Select the most accurate match from USDA database:"
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

// MARK: - Language Switcher Component
struct LanguageSwitcher: View {
    @ObservedObject var languageManager = LanguageManager.shared
    
    var body: some View {
        Menu {
            ForEach([PlanLanguage.spanish, PlanLanguage.english], id: \.self) { language in
                Button(action: {
                    languageManager.setLanguage(language)
                }) {
                    HStack {
                        Text(language.flag)
                        Text(language.displayName)
                        if languageManager.currentLanguage == language {
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
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
    }
}

// MARK: - Notification Extension
extension Notification.Name {
    static let languageChanged = Notification.Name("languageChanged")
}

// MARK: - View Modifier for Automatic Language Updates
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
