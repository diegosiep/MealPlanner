import SwiftUI
import CoreData

// MARK: - Fixed MealPlannerPro App
@main
struct MealPlannerProApp_Fixed: App {
    let persistenceController = PersistenceController.shared
    
    // Global managers
    @StateObject private var languageManager = LanguageManager.shared
    @StateObject private var foodSelectionManager = FoodSelectionManager()
    @StateObject private var pdfService = FixedMealPlanPDFService()
    
    var body: some Scene {
        WindowGroup {
            FixedContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(languageManager)
                .environmentObject(foodSelectionManager)
                .environmentObject(pdfService)
                .foodSelectionOverlay(manager: foodSelectionManager)
                .onAppear {
                    setupApplication()
                }
        }
        .windowStyle(DefaultWindowStyle())
        .commands {
            // Add menu commands
            CommandGroup(after: .appInfo) {
                Button("Toggle Language") {
                    languageManager.toggleLanguage()
                }
                .keyboardShortcut("l", modifiers: [.command, .shift])
            }
        }
    }
    
    private func setupApplication() {
        // Configure app-wide settings
        configureLogging()
        setupErrorHandling()
        loadUserPreferences()
    }
    
    private func configureLogging() {
        // Set up comprehensive logging
        print("📱 MealPlannerPro starting with fixes applied")
        print("🌍 Current language: \(languageManager.currentLanguage.displayName)")
    }
    
    private func setupErrorHandling() {
        // Global error handling setup
        NSSetUncaughtExceptionHandler { exception in
            print("❌ Uncaught exception: \(exception)")
        }
    }
    
    private func loadUserPreferences() {
        // Load saved user preferences
        if let savedLanguage = UserDefaults.standard.string(forKey: "selectedLanguage"),
           let language = PlanLanguage(rawValue: savedLanguage) {
            languageManager.setLanguage(language)
        }
    }
}

// MARK: - Enhanced USDA Service Integration
class EnhancedUSDAService: USDAFoodService {
    @Published var searchHistory: [String] = []
    @Published var recentFoods: [USDAFood] = []
    
    override init() {
        super.init()
        loadSearchHistory()
    }
    
    override func searchFoods(query: String) async throws -> [USDAFood] {
        print("🔍 Enhanced USDA search for: '\(query)'")
        
        // Add to search history
        addToSearchHistory(query)
        
        do {
            let results = try await super.searchFoods(query: query)
            
            // Cache recent foods
            cacheRecentFoods(results.prefix(5).map { $0 })
            
            print("✅ Found \(results.count) USDA foods for '\(query)'")
            return results
            
        } catch {
            print("❌ USDA search failed for '\(query)': \(error)")
            throw error
        }
    }
    
    private func addToSearchHistory(_ query: String) {
        DispatchQueue.main.async {
            if !self.searchHistory.contains(query) {
                self.searchHistory.insert(query, at: 0)
                if self.searchHistory.count > 20 {
                    self.searchHistory = Array(self.searchHistory.prefix(20))
                }
                self.saveSearchHistory()
            }
        }
    }
    
    private func cacheRecentFoods(_ foods: [USDAFood]) {
        DispatchQueue.main.async {
            for food in foods {
                if !self.recentFoods.contains(where: { $0.fdcId == food.fdcId }) {
                    self.recentFoods.insert(food, at: 0)
                }
            }
            
            if self.recentFoods.count > 50 {
                self.recentFoods = Array(self.recentFoods.prefix(50))
            }
        }
    }
    
    private func saveSearchHistory() {
        UserDefaults.standard.set(searchHistory, forKey: "usdaSearchHistory")
    }
    
    private func loadSearchHistory() {
        if let saved = UserDefaults.standard.array(forKey: "usdaSearchHistory") as? [String] {
            searchHistory = saved
        }
    }
}

// MARK: - Enhanced AI Meal Planner with All Fixes
struct EnhancedAIMealPlannerView_Complete: View {
    @EnvironmentObject var languageManager: LanguageManager
    @EnvironmentObject var foodSelectionManager: FoodSelectionManager
    @EnvironmentObject var pdfService: FixedMealPlanPDFService
    
    @StateObject private var llmService = LLMService()
    @StateObject private var verifiedService = EnhancedUSDAVerifiedMealPlanningService()
    @StateObject private var usdaService = EnhancedUSDAService()
    
    @State private var selectedPatient: Patient?
    @State private var targetCalories = 600
    @State private var selectedMealType: MealType = .lunch
    @State private var selectedCuisine = "Mediterráneo"
    @State private var dietaryRestrictions: [String] = []
    @State private var medicalConditions: [String] = []
    
    @State private var currentSuggestion: VerifiedMealPlanSuggestion?
    @State private var showingSuccess = false
    @State private var errorMessage: String?
    @State private var isGenerating = false
    @State private var showingPDFViewer = false
    @State private var generatedPDF: Data?
    
    // Access to patients
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Patient.lastName, ascending: true)],
        animation: .default)
    private var patients: FetchedResults<Patient>
    
    private var strings: AppLocalizedStrings {
        languageManager.currentLanguage.appStrings
    }
    
    var body: some View {
        HSplitView {
            // LEFT PANEL - Configuration (Fixed)
            leftConfigurationPanel
                .frame(width: 380)
            
            // RIGHT PANEL - Results Display (Expandable)
            rightResultsPanel
        }
        .navigationTitle(strings.aiAssistant)
        .alert(strings.mealGenerated, isPresented: $showingSuccess) {
            Button(strings.ok) { }
            if currentSuggestion != nil {
                Button("Generar PDF") {
                    generatePDF()
                }
            }
        }
        .alert(strings.error, isPresented: .constant(errorMessage != nil)) {
            Button(strings.ok) { errorMessage = nil }
        } message: {
            if let error = errorMessage {
                Text(error)
            }
        }
        .sheet(isPresented: $showingPDFViewer) {
            if let pdfData = generatedPDF {
                FixedPDFViewer(pdfData: pdfData)
            }
        }
        .onAppear {
            setupEnhancedService()
        }
    }
    
    // MARK: - Left Configuration Panel
    private var leftConfigurationPanel: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text(strings.aiAssistantTitle)
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text(strings.aiAssistantSubtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Divider()
                
                // Configuration Sections
                Group {
                    patientSelectionSection
                    mealConfigurationSection
                    preferencesSection
                }
                
                Spacer(minLength: 20)
                
                // Generate Button
                generateButton
                
                // PDF Export Button
                if currentSuggestion != nil {
                    pdfExportButton
                }
            }
            .padding()
        }
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    // MARK: - Right Results Panel
    private var rightResultsPanel: some View {
        Group {
            if isGenerating {
                generatingStateView
            } else if let suggestion = currentSuggestion {
                resultsDisplayView(suggestion: suggestion)
            } else {
                emptyStateView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
    }
    
    // MARK: - Configuration Sections
    private var patientSelectionSection: some View {
        configurationCard(title: strings.patientSelection, icon: "person.circle") {
            VStack(alignment: .leading, spacing: 12) {
                Text(strings.selectPatient)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Picker("", selection: $selectedPatient) {
                    Text("Sin paciente específico").tag(nil as Patient?)
                    ForEach(patients, id: \.self) { patient in
                        Text("\(patient.firstName ?? "") \(patient.lastName ?? "")")
                            .tag(patient as Patient?)
                    }
                }
                .pickerStyle(MenuPickerStyle())
            }
        }
    }
    
    private var mealConfigurationSection: some View {
        configurationCard(title: strings.mealConfiguration, icon: "fork.knife") {
            VStack(spacing: 16) {
                // Calories
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(strings.targetCalories)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Text("\(targetCalories) kcal")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                    }
                    
                    Slider(value: Binding(
                        get: { Double(targetCalories) },
                        set: { targetCalories = Int($0) }
                    ), in: 200...1500, step: 25) {
                        Text("Calorías")
                    }
                    .accentColor(.blue)
                }
                
                // Meal Type
                VStack(alignment: .leading, spacing: 8) {
                    Text(strings.mealType)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Picker("", selection: $selectedMealType) {
                        ForEach(MealType.allCases, id: \.self) { mealType in
                            Text(mealType.localizedName(language: languageManager.currentLanguage))
                                .tag(mealType)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                // Cuisine
                VStack(alignment: .leading, spacing: 8) {
                    Text(strings.cuisine)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Picker("", selection: $selectedCuisine) {
                        Text("🇪🇸 Mediterráneo").tag("Mediterráneo")
                        Text("🇲🇽 Mexicano").tag("Mexicano")
                        Text("🍜 Asiático").tag("Asiático")
                        Text("🍔 Americano").tag("Americano")
                        Text("🥗 Vegetariano").tag("Vegetariano")
                        Text("🌱 Vegano").tag("Vegano")
                    }
                    .pickerStyle(MenuPickerStyle())
                }
            }
        }
    }
    
    private var preferencesSection: some View {
        configurationCard(title: strings.preferences, icon: "slider.horizontal.3") {
            VStack(spacing: 16) {
                // Dietary Restrictions
                restrictionsGrid(
                    title: strings.dietaryRestrictions,
                    options: ["Sin gluten", "Sin lácteos", "Vegano", "Vegetariano", "Bajo sodio", "Sin azúcar"],
                    selectedItems: $dietaryRestrictions
                )
                
                Divider()
                
                // Medical Conditions
                restrictionsGrid(
                    title: strings.medicalConditions,
                    options: ["Diabetes", "Hipertensión", "Renal", "Cardíaco", "Colesterol alto", "Celíaco"],
                    selectedItems: $medicalConditions
                )
            }
        }
    }
    
    private var generateButton: some View {
        Button(action: generateMeal) {
            HStack(spacing: 12) {
                if isGenerating {
                    ProgressView()
                        .scaleEffect(0.9)
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Image(systemName: "brain.head.profile")
                        .font(.title3)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(isGenerating ? strings.generating : strings.generateMeal)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    if isGenerating {
                        Text("Verificando con USDA...")
                            .font(.caption)
                    }
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: isGenerating ? [Color.gray] : [Color.blue, Color.blue.opacity(0.8)]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(12)
            .shadow(color: .blue.opacity(0.3), radius: 4, x: 0, y: 2)
        }
        .disabled(isGenerating)
        .buttonStyle(PlainButtonStyle())
    }
    
    private var pdfExportButton: some View {
        Button(action: generatePDF) {
            HStack(spacing: 8) {
                if pdfService.isGenerating {
                    ProgressView()
                        .scaleEffect(0.8)
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Image(systemName: "doc.badge.plus")
                }
                
                Text(pdfService.isGenerating ? strings.generatingPDF : "Generar PDF")
                    .font(.headline)
                    .fontWeight(.medium)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color.red, Color.red.opacity(0.8)]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(10)
            .shadow(color: .red.opacity(0.3), radius: 2, x: 0, y: 1)
        }
        .disabled(pdfService.isGenerating)
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - State Views
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 80))
                .foregroundColor(.blue.opacity(0.3))
            
            VStack(spacing: 8) {
                Text(strings.generatePersonalizedMeals)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text("Configura los parámetros en el panel izquierdo y genera una comida personalizada con verificación USDA")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            VStack(spacing: 12) {
                HStack(spacing: 16) {
                    FeatureBadge(icon: "checkmark.seal", text: "Verificación USDA", color: .green)
                    FeatureBadge(icon: "brain", text: "IA Avanzada", color: .blue)
                }
                
                HStack(spacing: 16) {
                    FeatureBadge(icon: "doc.text", text: "Exportar PDF", color: .orange)
                    FeatureBadge(icon: "globe", text: "Multi-idioma", color: .purple)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var generatingStateView: some View {
        VStack(spacing: 30) {
            // Animated progress indicator
            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(2.0)
                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                
                Text(strings.generating)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text("Verificando alimentos con base de datos USDA...")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Progress steps
            VStack(spacing: 12) {
                ProgressStep(text: "Generando comida con IA", isCompleted: true, isActive: false)
                ProgressStep(text: "Buscando en base de datos USDA", isCompleted: false, isActive: true)
                ProgressStep(text: "Verificando información nutricional", isCompleted: false, isActive: false)
                ProgressStep(text: "Finalizando recomendación", isCompleted: false, isActive: false)
            }
            .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func resultsDisplayView(suggestion: VerifiedMealPlanSuggestion) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    Text(suggestion.originalAISuggestion.mealName)
                        .font(.title)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    HStack(spacing: 20) {
                        InfoChip(icon: "flame", text: "\(suggestion.originalAISuggestion.estimatedCalories) kcal", color: .orange)
                        InfoChip(icon: "list.bullet", text: "\(suggestion.verifiedFoods.count) alimentos", color: .blue)
                        InfoChip(icon: "checkmark.seal", text: "Verificado USDA", color: .green)
                    }
                }
                .padding()
                
                // Foods list
                LazyVStack(spacing: 16) {
                    ForEach(suggestion.verifiedFoods, id: \.originalAISuggestion.id) { verifiedFood in
                        EnhancedVerifiedFoodCard(verifiedFood: verifiedFood)
                    }
                }
                .padding(.horizontal)
                
                // Nutrition summary
                EnhancedNutritionSummaryCard(suggestion: suggestion)
                    .padding(.horizontal)
                
                // Cooking instructions
                if let instructions = suggestion.originalAISuggestion.cookingInstructions {
                    CookingInstructionsCard(instructions: instructions)
                        .padding(.horizontal)
                }
                
                Spacer(minLength: 40)
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    // MARK: - Helper Components
    private func configurationCard<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                    .font(.title3)
                
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            content()
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 1)
    }
    
    private func restrictionsGrid(title: String, options: [String], selectedItems: Binding<[String]>) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                ForEach(options, id: \.self) { option in
                    EnhancedToggleChip(
                        text: option,
                        isSelected: selectedItems.wrappedValue.contains(option)
                    ) {
                        if selectedItems.wrappedValue.contains(option) {
                            selectedItems.wrappedValue.removeAll { $0 == option }
                        } else {
                            selectedItems.wrappedValue.append(option)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Actions
    private func generateMeal() {
        isGenerating = true
        errorMessage = nil
        
        Task {
            do {
                let suggestion = try await verifiedService.generateVerifiedMealPlan(
                    targetCalories: targetCalories,
                    mealType: selectedMealType,
                    cuisineType: selectedCuisine,
                    dietaryRestrictions: dietaryRestrictions,
                    medicalConditions: medicalConditions,
                    language: languageManager.currentLanguage
                )
                
                await MainActor.run {
                    currentSuggestion = suggestion
                    isGenerating = false
                    showingSuccess = true
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isGenerating = false
                }
            }
        }
    }
    
    private func generatePDF() {
        guard let suggestion = currentSuggestion else { return }
        
        // Create a multi-day plan with single day for PDF generation
        let dailyPlan = DailyMealPlan(
            date: Date(),
            meals: [suggestion]
        )
        
        let multiDayPlan = MultiDayMealPlan(
            numberOfDays: 1,
            dailyPlans: [dailyPlan]
        )
        
        Task {
            do {
                let pdfData = try await pdfService.generateMealPlanPDF(
                    multiDayPlan: multiDayPlan,
                    patient: selectedPatient,
                    includeRecipes: true,
                    includeShoppingList: true,
                    includeNutritionAnalysis: true,
                    language: languageManager.currentLanguage
                )
                
                await MainActor.run {
                    generatedPDF = pdfData
                    showingPDFViewer = true
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Error al generar PDF: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func setupEnhancedService() {
        // Configure the enhanced verification service with food selection manager
        verifiedService.foodSelectionManager = foodSelectionManager
    }
}

// MARK: - Enhanced Components
struct FeatureBadge: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
            Text(text)
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundColor(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .cornerRadius(6)
    }
}

struct InfoChip: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
            Text(text)
                .font(.caption)
                .fontWeight(.semibold)
        }
        .foregroundColor(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.15))
        .cornerRadius(8)
    }
}

struct EnhancedToggleChip: View {
    let text: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption2)
                        .fontWeight(.bold)
                }
                
                Text(text)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
            }
            .foregroundColor(isSelected ? .white : .primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? Color.blue : Color.gray.opacity(0.1))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.3), lineWidth: isSelected ? 0 : 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ProgressStep: View {
    let text: String
    let isCompleted: Bool
    let isActive: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isCompleted ? "checkmark.circle.fill" : (isActive ? "circle.dotted" : "circle"))
                .foregroundColor(isCompleted ? .green : (isActive ? .blue : .gray))
                .font(.title3)
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(isCompleted ? .green : (isActive ? .primary : .secondary))
            
            Spacer()
        }
    }
}

// MARK: - Enhanced Verified Service
class EnhancedUSDAVerifiedMealPlanningService: USDAVerifiedMealPlanningService {
    var foodSelectionManager: FoodSelectionManager?
    
    override func generateVerifiedMealPlan(
        targetCalories: Int,
        mealType: MealType,
        cuisineType: String,
        dietaryRestrictions: [String],
        medicalConditions: [String],
        language: PlanLanguage
    ) async throws -> VerifiedMealPlanSuggestion {
        
        print("🧠 Starting enhanced verified meal plan generation...")
        
        // Use the parent implementation but with enhanced food selection
        let suggestion = try await super.generateVerifiedMealPlan(
            targetCalories: targetCalories,
            mealType: mealType,
            cuisineType: cuisineType,
            dietaryRestrictions: dietaryRestrictions,
            medicalConditions: medicalConditions,
            language: language
        )
        
        // Check for any pending food selections
        if let manager = foodSelectionManager, !manager.pendingSelections.isEmpty {
            print("⏳ Waiting for manual food selections...")
            
            // Wait for all pending selections to be completed
            while !manager.pendingSelections.isEmpty || manager.currentSelection != nil {
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            }
            
            print("✅ All food selections completed")
        }
        
        return suggestion
    }
}

// MARK: - Additional Enhanced Components
struct EnhancedVerifiedFoodCard: View {
    let verifiedFood: VerifiedSuggestedFood
    
    var body: some View {
        HStack(spacing: 16) {
            // Food icon and verification status
            VStack(spacing: 8) {
                Image(systemName: verifiedFood.isVerified ? "checkmark.seal.fill" : "questionmark.circle")
                    .font(.title2)
                    .foregroundColor(verifiedFood.isVerified ? .green : .orange)
                
                Text(verifiedFood.isVerified ? "Verificado" : "Estimado")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(verifiedFood.isVerified ? .green : .orange)
            }
            .frame(width: 80)
            
            // Food details
            VStack(alignment: .leading, spacing: 8) {
                Text(verifiedFood.originalAISuggestion.name)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text("\(verifiedFood.originalAISuggestion.gramWeight)g")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if verifiedFood.isVerified {
                    Text("USDA: \(verifiedFood.matchedUSDAFood?.description ?? "N/A")")
                        .font(.caption)
                        .foregroundColor(.blue)
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            // Nutrition summary
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(Int(verifiedFood.verifiedNutrition.calories)) kcal")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.orange)
                
                Text("P: \(Int(verifiedFood.verifiedNutrition.protein))g")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("C: \(Int(verifiedFood.verifiedNutrition.carbohydrates))g")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("G: \(Int(verifiedFood.verifiedNutrition.fat))g")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

struct EnhancedNutritionSummaryCard: View {
    let suggestion: VerifiedMealPlanSuggestion
    
    private var totalNutrition: (calories: Double, protein: Double, carbs: Double, fat: Double) {
        let calories = suggestion.verifiedFoods.reduce(0) { $0 + $1.verifiedNutrition.calories }
        let protein = suggestion.verifiedFoods.reduce(0) { $0 + $1.verifiedNutrition.protein }
        let carbs = suggestion.verifiedFoods.reduce(0) { $0 + $1.verifiedNutrition.carbohydrates }
        let fat = suggestion.verifiedFoods.reduce(0) { $0 + $1.verifiedNutrition.fat }
        
        return (calories, protein, carbs, fat)
    }
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "chart.pie")
                    .foregroundColor(.blue)
                    .font(.title3)
                
                Text("Resumen Nutricional")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("Total")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack(spacing: 0) {
                NutritionColumn(
                    label: "Calorías",
                    value: "\(Int(totalNutrition.calories))",
                    unit: "kcal",
                    color: .orange,
                    percentage: nil
                )
                
                Divider()
                    .frame(height: 60)
                
                NutritionColumn(
                    label: "Proteína",
                    value: "\(Int(totalNutrition.protein))",
                    unit: "g",
                    color: .green,
                    percentage: Int((totalNutrition.protein * 4) / totalNutrition.calories * 100)
                )
                
                Divider()
                    .frame(height: 60)
                
                NutritionColumn(
                    label: "Carbohidratos",
                    value: "\(Int(totalNutrition.carbs))",
                    unit: "g",
                    color: .blue,
                    percentage: Int((totalNutrition.carbs * 4) / totalNutrition.calories * 100)
                )
                
                Divider()
                    .frame(height: 60)
                
                NutritionColumn(
                    label: "Grasa",
                    value: "\(Int(totalNutrition.fat))",
                    unit: "g",
                    color: .purple,
                    percentage: Int((totalNutrition.fat * 9) / totalNutrition.calories * 100)
                )
            }
        }
        .padding()
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color.blue.opacity(0.05), Color.white]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
        )
    }
}

struct NutritionColumn: View {
    let label: String
    let value: String
    let unit: String
    let color: Color
    let percentage: Int?
    
    var body: some View {
        VStack(spacing: 8) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(unit)
                .font(.caption)
                .foregroundColor(color)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
            
            if let percentage = percentage {
                Text("\(percentage)%")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(color.opacity(0.1))
                    .cornerRadius(4)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct CookingInstructionsCard: View {
    let instructions: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "book.pages")
                    .foregroundColor(.orange)
                    .font(.title3)
                
                Text("Instrucciones de Preparación")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            Text(instructions)
                .font(.body)
                .foregroundColor(.primary)
                .lineSpacing(4)
        }
        .padding()
        .background(Color.orange.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.2), lineWidth: 1)
        )
    }
}
