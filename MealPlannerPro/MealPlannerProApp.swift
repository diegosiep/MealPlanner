import SwiftUI
import CoreData

// MARK: - MainAppIntegration.swift
// Purpose: Provides the main app structure that integrates all fixed components
// Why needed: Your existing app structure has compilation conflicts

// ==========================================
// MAIN APP STRUCTURE
// ==========================================

// This is your new main app structure that replaces MealPlannerProApp
// It integrates all the fixed components without conflicts
@main
struct FixedMealPlannerProApp: App {
    // Core Data persistence controller
    let persistenceController = PersistenceController.shared
    
    // Global managers that need to be available app-wide
    @StateObject private var languageManager = AppLanguageManager.shared
    @StateObject private var foodSelectionManager = ManualFoodSelectionManager.shared
    @StateObject private var pdfService = RobustPDFService.shared
    
    var body: some Scene {
        WindowGroup {
            // Main content view with all managers injected
            FixedMainContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(languageManager)
                .environmentObject(foodSelectionManager)
                .environmentObject(pdfService)
                .withManualFoodSelection() // Add food selection capability
                .platformAdaptiveFrame() // Apply platform-appropriate sizing
                .onAppear {
                    configureApp()
                }
        }
        .windowStyle(DefaultWindowStyle())
        
        // Add menu commands for macOS
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Toggle Language") {
                    languageManager.toggleLanguage()
                }
                .keyboardShortcut("l", modifiers: [.command, .shift])
                
                Button("Generate Test PDF") {
                    generateTestPDF()
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])
            }
        }
    }
    
    // Configure app-wide settings
    private func configureApp() {
        print("🚀 FixedMealPlannerPro starting...")
        print("🌍 Current language: \(languageManager.currentLanguage.displayName)")
        
        // Configure any additional app settings here
        setupAppearance()
    }
    
    // Set up app appearance
    private func setupAppearance() {
        #if canImport(UIKit)
        // iOS-specific appearance configuration
        UINavigationBar.appearance().largeTitleTextAttributes = [
            .foregroundColor: UIColor.systemBlue
        ]
        #endif
    }
    
    // Generate a test PDF for debugging
    private func generateTestPDF() {
        Task {
            do {
                let testMeal = createTestMealData()
                let pdfData = try await pdfService.generateMealPlanPDF(from: testMeal)
                print("✅ Test PDF generated: \(pdfData.count) bytes")
            } catch {
                print("❌ Test PDF generation failed: \(error)")
            }
        }
    }
    
    // Create test meal data for PDF generation
    private func createTestMealData() -> [String: Any] {
        return [
            "title": "Plan de Prueba",
            "meals": [
                [
                    "name": "Desayuno Saludable",
                    "type": "Desayuno",
                    "calories": 400.0,
                    "protein": 20.0,
                    "carbs": 40.0,
                    "fat": 15.0,
                    "foods": [
                        [
                            "name": "Avena",
                            "weight": 50.0,
                            "calories": 200.0,
                            "protein": 10.0,
                            "carbs": 30.0,
                            "fat": 5.0
                        ],
                        [
                            "name": "Plátano",
                            "weight": 100.0,
                            "calories": 100.0,
                            "protein": 2.0,
                            "carbs": 25.0,
                            "fat": 1.0
                        ]
                    ],
                    "instructions": "Cocinar la avena con agua, agregar el plátano cortado."
                ]
            ]
        ]
    }
}

// ==========================================
// FIXED MAIN CONTENT VIEW
// ==========================================

// This replaces your existing ContentView and provides a clean, working interface
struct FixedMainContentView: View {
    @EnvironmentObject var languageManager: AppLanguageManager
    @EnvironmentObject var foodSelectionManager: ManualFoodSelectionManager
    @EnvironmentObject var pdfService: RobustPDFService
    
    @State private var selectedTab = 0
    @State private var showingAbout = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // FIXED: Top navigation bar with language switcher
                topNavigationBar
                
                // FIXED: Main content with proper tab structure
                mainTabView
            }
        }
        .compatibleNavigationViewStyle() // Apply platform-appropriate navigation style
        .sheet(isPresented: $showingAbout) {
            AboutView()
        }
    }
    
    // MARK: - Top Navigation Bar
    
    private var topNavigationBar: some View {
        HStack {
            // App title
            Text(languageManager.text.appTitle)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Spacer()
            
            // Status indicators
            HStack(spacing: 12) {
                // Food selection status
                if foodSelectionManager.selectionStatus != .noSelectionsNeeded {
                    foodSelectionStatusIndicator
                }
                
                // PDF generation status
                if pdfService.isGenerating {
                    pdfGenerationStatusIndicator
                }
                
                // Language switcher
                LanguageSwitcher()
                
                // About button
                Button(action: { showingAbout = true }) {
                    Image(systemName: "info.circle")
                        .font(.title3)
                        .foregroundColor(.blue)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.compatibleControlBackground)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color.gray.opacity(0.3)),
            alignment: .bottom
        )
    }
    
    private var foodSelectionStatusIndicator: some View {
        HStack(spacing: 4) {
            Image(systemName: "questionmark.circle.fill")
                .foregroundColor(.orange)
            Text("Selección pendiente")
                .font(.caption)
                .foregroundColor(.orange)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(6)
    }
    
    private var pdfGenerationStatusIndicator: some View {
        HStack(spacing: 4) {
            ProgressView()
                .scaleEffect(0.7)
                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
            Text("Generando PDF...")
                .font(.caption)
                .foregroundColor(.blue)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(6)
    }
    
    // MARK: - Main Tab View
    
    private var mainTabView: some View {
        TabView(selection: $selectedTab) {
            // Food Search Tab
            FixedFoodSearchTabView()
                .tabItem {
                    Image(systemName: "magnifyingglass")
                    Text(languageManager.text.foodSearch)
                }
                .tag(0)
            
            // My Foods Tab
            FixedMyFoodsTabView()
                .tabItem {
                    Image(systemName: "heart.fill")
                    Text(languageManager.text.myFoods)
                }
                .tag(1)
            
            // Basic Plans Tab
            FixedBasicPlansTabView()
                .tabItem {
                    Image(systemName: "calendar")
                    Text(languageManager.text.basicPlans)
                }
                .tag(2)
            
            // AI Assistant Tab
            FixedAIAssistantTabView()
                .tabItem {
                    Image(systemName: "brain.head.profile")
                    Text(languageManager.text.aiAssistant)
                }
                .tag(3)
            
            // Multi-Day Planner Tab
            FixedMultiDayPlannerTabView()
                .tabItem {
                    Image(systemName: "calendar.badge.plus")
                    Text(languageManager.text.multiDayPlanner)
                }
                .tag(4)
        }
    }
}

// ==========================================
// FIXED TAB VIEWS
// ==========================================

// These are simplified, working versions of your tab views
// They integrate with the fixed components and provide a stable foundation

struct FixedFoodSearchTabView: View {
    @EnvironmentObject var languageManager: AppLanguageManager
    @State private var searchText = ""
    @State private var isSearching = false
    @State private var searchResults: [MockUSDAFood] = []
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                Text(languageManager.text.foodSearch)
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Busca alimentos en la base de datos USDA")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Search bar
            HStack {
                TextField("Escribe el nombre de un alimento...", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onSubmit {
                        performSearch()
                    }
                
                Button("Buscar", action: performSearch)
                    .buttonStyle(.borderedProminent)
                    .disabled(searchText.isEmpty)
            }
            .padding(.horizontal)
            
            // Results
            if isSearching {
                ProgressView("Buscando...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if searchResults.isEmpty && !searchText.isEmpty {
                Text("No se encontraron resultados")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !searchResults.isEmpty {
                List(searchResults) { food in
                    FoodResultRow(food: food)
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 60))
                        .foregroundColor(.gray.opacity(0.5))
                    
                    Text("Ingresa un término de búsqueda")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("Busca cualquier alimento en la base de datos USDA")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding()
    }
    
    private func performSearch() {
        guard !searchText.isEmpty else { return }
        
        isSearching = true
        
        // Simulate API call
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            searchResults = createMockResults(for: searchText)
            isSearching = false
        }
    }
    
    private func createMockResults(for query: String) -> [MockUSDAFood] {
        // Create mock results for demonstration
        return [
            MockUSDAFood(id: 1, name: "\(query) - Opción 1", description: "Resultado de búsqueda para \(query)"),
            MockUSDAFood(id: 2, name: "\(query) - Opción 2", description: "Otra opción para \(query)"),
            MockUSDAFood(id: 3, name: "\(query) - Opción 3", description: "Tercera opción para \(query)")
        ]
    }
}

struct FixedMyFoodsTabView: View {
    @EnvironmentObject var languageManager: AppLanguageManager
    
    var body: some View {
        VStack(spacing: 20) {
            Text(languageManager.text.myFoods)
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

struct FixedBasicPlansTabView: View {
    @EnvironmentObject var languageManager: AppLanguageManager
    
    var body: some View {
        VStack(spacing: 20) {
            Text(languageManager.text.basicPlans)
                .font(.title)
                .fontWeight(.bold)
            
            Text("Planifica tus comidas semanales")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Calendar placeholder
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

struct FixedAIAssistantTabView: View {
    @EnvironmentObject var languageManager: AppLanguageManager
    @EnvironmentObject var pdfService: RobustPDFService
    
    @State private var isGeneratingMeal = false
    @State private var targetCalories = 600
    @State private var generatedMeal: String?
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                Text(languageManager.text.aiAssistantTitle)
                    .font(.title)
                    .fontWeight(.bold)
                
                Text(languageManager.text.aiAssistantSubtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Configuration
            VStack(spacing: 16) {
                HStack {
                    Text(languageManager.text.targetCalories)
                        .font(.headline)
                    
                    Spacer()
                    
                    Text("\(targetCalories) kcal")
                        .font(.headline)
                        .foregroundColor(.blue)
                }
                
                Slider(value: Binding(
                    get: { Double(targetCalories) },
                    set: { targetCalories = Int($0) }
                ), in: 200...1500, step: 50)
                .accentColor(.blue)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
            
            // Generate button
            Button(action: generateMeal) {
                HStack {
                    if isGeneratingMeal {
                        ProgressView()
                            .scaleEffect(0.8)
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: "brain.head.profile")
                    }
                    
                    Text(isGeneratingMeal ? languageManager.text.generating : languageManager.text.generateMeal)
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .cornerRadius(12)
            }
            .disabled(isGeneratingMeal)
            
            // Results
            if let meal = generatedMeal {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Comida Generada:")
                        .font(.headline)
                    
                    Text(meal)
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                    
                    Button("Generar PDF") {
                        generateMealPDF()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            Spacer()
        }
        .padding()
    }
    
    private func generateMeal() {
        isGeneratingMeal = true
        
        // Simulate AI meal generation
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            generatedMeal = "Comida saludable de \(targetCalories) kcal:\n\n• Pechuga de pollo a la plancha (150g)\n• Arroz integral (80g)\n• Brócoli al vapor (100g)\n• Aceite de oliva (1 cucharada)\n\nInstrucciones: Cocinar la pechuga de pollo a fuego medio. Hervir el arroz integral. Cocinar el brócoli al vapor hasta que esté tierno."
            isGeneratingMeal = false
        }
    }
    
    private func generateMealPDF() {
        guard let meal = generatedMeal else { return }
        
        Task {
            do {
                let mealData = ["generatedMeal": meal]
                let pdfData = try await pdfService.generateMealPlanPDF(from: mealData)
                print("✅ Meal PDF generated: \(pdfData.count) bytes")
            } catch {
                print("❌ Error generating meal PDF: \(error)")
            }
        }
    }
}

struct FixedMultiDayPlannerTabView: View {
    @EnvironmentObject var languageManager: AppLanguageManager
    
    var body: some View {
        VStack(spacing: 20) {
            Text(languageManager.text.multiDayPlanner)
                .font(.title)
                .fontWeight(.bold)
            
            Text("Genera planes de múltiples días con IA")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            VStack(spacing: 16) {
                Text("Características del planificador:")
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 8) {
                    FeatureRow(icon: "calendar", text: "Planes de 3-30 días")
                    FeatureRow(icon: "brain.head.profile", text: "Generación con IA")
                    FeatureRow(icon: "checkmark.seal", text: "Verificación USDA")
                    FeatureRow(icon: "doc.text", text: "Exportación PDF")
                }
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(12)
            
            Button("Próximamente") {
                // TODO: Implement multi-day planner
            }
            .buttonStyle(.borderedProminent)
            .disabled(true)
            
            Spacer()
        }
        .padding()
    }
}

// ==========================================
// SUPPORTING COMPONENTS
// ==========================================

struct FoodResultRow: View {
    let food: MockUSDAFood
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(food.name)
                    .font(.headline)
                
                Text(food.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button("Agregar") {
                // TODO: Add to favorites
            }
            .buttonStyle(.bordered)
        }
        .padding(.vertical, 4)
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            Text(text)
                .font(.subheadline)
            
            Spacer()
        }
    }
}

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "heart.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.red)
                
                Text("MealPlannerPro")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Planificación de comidas con IA")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Características:")
                        .font(.headline)
                    
                    Text("• Verificación nutricional USDA")
                    Text("• Generación con inteligencia artificial")
                    Text("• Soporte multi-idioma")
                    Text("• Exportación PDF profesional")
                    Text("• Selección manual de alimentos")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Acerca de")
            .compatibleNavigationBarTitleDisplayMode(.inline)
            .compatibleNavigationBarLeading {
                Button("Cerrar") {
                    dismiss()
                }
            }
        }
    }
}

// ==========================================
// MOCK DATA STRUCTURES
// ==========================================

struct MockUSDAFood: Identifiable {
    let id: Int
    let name: String
    let description: String
}

// ==========================================
// USAGE INSTRUCTIONS
// ==========================================

/*
 HOW TO INTEGRATE THIS MAIN APP STRUCTURE:

 STEP 1: REPLACE YOUR MAIN APP FILE
 - Comment out or rename your existing App file (MealPlannerProApp.swift)
 - Add this file as "MainAppIntegration.swift"
 - Build the project to ensure it starts up

 STEP 2: TEST BASIC FUNCTIONALITY
 - Run the app and verify it starts without crashes
 - Test language switching with the toggle in the top bar
 - Navigate between tabs to ensure they all work
 - Try generating a test PDF from the menu (Cmd+Shift+P on Mac)

 STEP 3: CUSTOMIZE THE TAB VIEWS
 The tab views are currently simplified placeholders. Replace them with your
 actual implementations:
 
 - FixedFoodSearchTabView -> Your actual food search implementation
 - FixedMyFoodsTabView -> Your actual saved foods implementation
 - etc.

 STEP 4: INTEGRATE YOUR EXISTING SERVICES
 Add your existing services to the app structure:
 
 @StateObject private var yourExistingService = YourService()
 
 Then inject them into the environment:
 
 .environmentObject(yourExistingService)

 STEP 5: ADD YOUR CORE DATA MODELS
 Ensure your Core Data model is properly integrated by updating:
 
 let persistenceController = PersistenceController.shared

 To use your actual persistence controller.

 This structure provides a stable foundation that integrates all the fixed
 components while allowing you to gradually replace the placeholder tab views
 with your actual implementations.
 */
