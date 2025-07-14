import SwiftUI
import CoreData

// MARK: - MealPlannerProApp.swift
// Fixed: Ambiguous use of 'init'

// ==========================================
// MAIN APP STRUCTURE
// ==========================================

@main
struct MealPlannerProApp: App {
    let persistenceController = PersistenceController.shared
    
    @StateObject private var languageManager = LanguageManager.shared
    @StateObject private var foodSelectionManager = ManualFoodSelectionManager.shared
    @StateObject private var pdfService = RobustPDFService.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(languageManager)
                .environmentObject(foodSelectionManager)
                .environmentObject(pdfService)
                .withManualFoodSelection()
        }
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Toggle Language") {
                    languageManager.toggleLanguage()
                }
                .keyboardShortcut("l", modifiers: [.command, .shift])
            }
        }
    }
}

// ==========================================
// MAIN CONTENT VIEW
// ==========================================

struct ContentView: View {
    @EnvironmentObject var languageManager: LanguageManager
    @EnvironmentObject var foodSelectionManager: ManualFoodSelectionManager
    @EnvironmentObject var pdfService: RobustPDFService
    
    @State private var selectedTab = 0
    @State private var showingAbout = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                topNavigationBar
                mainTabView
            }
        }
        .compatibleNavigationViewStyle()
        .compatibleSheet(isPresented: $showingAbout) {
            AboutView()
        }
    }
    
    private var topNavigationBar: some View {
        HStack {
            Text("MealPlanner Pro")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Spacer()
            
            HStack(spacing: 12) {
                if foodSelectionManager.selectionStatus != .noSelectionsNeeded {
                    foodSelectionStatusIndicator
                }
                
                if pdfService.isGenerating {
                    pdfGenerationStatusIndicator
                }
                
                LanguageSwitcherView()
                
                Button(action: { showingAbout = true }) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color.compatibleControlBackground)
    }
    
    private var foodSelectionStatusIndicator: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(Color.orange)
                .frame(width: 8, height: 8)
            
            Text("Selección pendiente")
                .font(.caption)
                .foregroundColor(.orange)
        }
    }
    
    private var pdfGenerationStatusIndicator: some View {
        HStack(spacing: 4) {
            ProgressView()
                .scaleEffect(0.6)
            
            Text("Generando PDF...")
                .font(.caption)
                .foregroundColor(.blue)
        }
    }
    
    private var mainTabView: some View {
        TabView(selection: $selectedTab) {
            FoodSearchTabView()
                .tabItem {
                    Image(systemName: "magnifyingglass")
                    Text(languageManager.currentLanguage.appStrings.foodSearch)
                }
                .tag(0)
            
            MyFoodsTabView()
                .tabItem {
                    Image(systemName: "heart.fill")
                    Text(languageManager.currentLanguage.appStrings.myFoods)
                }
                .tag(1)
            
            BasicPlansTabView()
                .tabItem {
                    Image(systemName: "calendar")
                    Text(languageManager.currentLanguage.appStrings.basicPlans)
                }
                .tag(2)
            
            AIAssistantTabView()
                .tabItem {
                    Image(systemName: "brain.head.profile")
                    Text(languageManager.currentLanguage.appStrings.aiAssistant)
                }
                .tag(3)
            
            MultiDayPlannerTabView()
                .tabItem {
                    Image(systemName: "calendar.badge.plus")
                    Text(languageManager.currentLanguage.appStrings.multiDayPlanner)
                }
                .tag(4)
        }
    }
}

// ==========================================
// TAB VIEWS
// ==========================================

struct FoodSearchTabView: View {
    @EnvironmentObject var languageManager: LanguageManager
    @State private var searchText = ""
    @State private var searchResults: [MockUSDAFood] = []
    @State private var isSearching = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text(languageManager.currentLanguage.appStrings.foodSearch)
                .font(.title)
                .fontWeight(.bold)
            
            TextField(languageManager.currentLanguage.appStrings.searchPlaceholder, text: $searchText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .onSubmit {
                    performSearch()
                }
            
            if isSearching {
                ProgressView(languageManager.currentLanguage.appStrings.loading)
            } else if searchResults.isEmpty && !searchText.isEmpty {
                Text(languageManager.currentLanguage.appStrings.noResults)
                    .foregroundColor(.secondary)
            } else {
                List(searchResults, id: \.id) { food in
                    VStack(alignment: .leading) {
                        Text(food.name)
                            .font(.headline)
                        Text(food.description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
        }
        .padding()
    }
    
    private func performSearch() {
        guard !searchText.isEmpty else { return }
        
        isSearching = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            searchResults = generateMockResults(for: searchText)
            isSearching = false
        }
    }
    
    private func generateMockResults(for query: String) -> [MockUSDAFood] {
        return [
            MockUSDAFood(id: 1, name: "\(query) - Opción 1", description: "Resultado de búsqueda para \(query)"),
            MockUSDAFood(id: 2, name: "\(query) - Opción 2", description: "Otra opción para \(query)"),
            MockUSDAFood(id: 3, name: "\(query) - Opción 3", description: "Tercera opción para \(query)")
        ]
    }
}

struct MyFoodsTabView: View {
    @EnvironmentObject var languageManager: LanguageManager
    
    var body: some View {
        VStack(spacing: 20) {
            Text(languageManager.currentLanguage.appStrings.myFoods)
                .font(.title)
                .fontWeight(.bold)
            
            Text("Aquí aparecerán tus alimentos favoritos")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Button("Agregar Alimento Personalizado") {
                // TODO: Implement add custom food
            }
            .buttonStyle(.borderedProminent)
            
            Spacer()
        }
        .padding()
    }
}

struct BasicPlansTabView: View {
    @EnvironmentObject var languageManager: LanguageManager
    
    var body: some View {
        VStack(spacing: 20) {
            Text(languageManager.currentLanguage.appStrings.basicPlans)
                .font(.title)
                .fontWeight(.bold)
            
            Text("Planifica tus comidas semanales")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Rectangle()
                .fill(Color.gray.opacity(0.1))
                .frame(height: 300)
                .overlay(
                    Text("Calendario de Comidas")
                        .foregroundColor(.secondary)
                )
                .cornerRadius(12)
            
            Spacer()
        }
        .padding()
    }
}

struct AIAssistantTabView: View {
    @EnvironmentObject var languageManager: LanguageManager
    @EnvironmentObject var pdfService: RobustPDFService
    
    @State private var isGeneratingMeal = false
    @State private var targetCalories = 600
    @State private var generatedMeal: String?
    
    var body: some View {
        VStack(spacing: 20) {
            Text(languageManager.currentLanguage.appStrings.aiAssistantTitle)
                .font(.title)
                .fontWeight(.bold)
            
            Text(languageManager.currentLanguage.appStrings.aiAssistantSubtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            VStack(spacing: 16) {
                HStack {
                    Text(languageManager.currentLanguage.appStrings.targetCalories)
                    Spacer()
                    Text("\(targetCalories)")
                        .foregroundColor(.secondary)
                }
                
                Slider(value: Binding(
                    get: { Double(targetCalories) },
                    set: { targetCalories = Int($0) }
                ), in: 300...1200, step: 50)
            }
            .padding()
            .background(Color.compatibleControlBackground)
            .cornerRadius(8)
            
            Button(action: generateMeal) {
                HStack {
                    if isGeneratingMeal {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text(languageManager.currentLanguage.appStrings.generating)
                    } else {
                        Image(systemName: "wand.and.stars")
                        Text(languageManager.currentLanguage.appStrings.generateMeal)
                    }
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(isGeneratingMeal ? Color.gray : Color.blue)
                .cornerRadius(10)
            }
            .disabled(isGeneratingMeal)
            
            if let meal = generatedMeal {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Comida Generada:")
                        .font(.headline)
                    
                    Text(meal)
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                }
            }
            
            Spacer()
        }
        .padding()
    }
    
    private func generateMeal() {
        isGeneratingMeal = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            generatedMeal = "Ensalada de pollo con quinoa (\(targetCalories) cal)"
            isGeneratingMeal = false
        }
    }
}

struct MultiDayPlannerTabView: View {
    @EnvironmentObject var languageManager: LanguageManager
    
    var body: some View {
        EnhancedAIMealPlannerView()
    }
}

struct AboutView: View {
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("MealPlanner Pro")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Versión 1.0")
                    .font(.title2)
                    .foregroundColor(.secondary)
                
                Text("Una aplicación avanzada para planificación de comidas con verificación USDA y generación de PDFs.")
                    .multilineTextAlignment(.center)
                    .padding()
                
                Spacer()
            }
            .padding()
            .navigationTitle("Acerca de")
            .compatibleNavigationBarTitleDisplayMode(.inline)
            .compatibleNavigationBarTrailing {
                Button("Cerrar") {
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
    }
}

// ==========================================
// MOCK DATA STRUCTURES
// ==========================================

struct MockUSDAFood {
    let id: Int
    let name: String
    let description: String
}

// ==========================================
// PERSISTENCE CONTROLLER
// ==========================================
// Note: PersistenceController is defined in Persistence.swift to avoid conflicts
