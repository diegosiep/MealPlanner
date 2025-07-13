import SwiftUI
import CoreData

// MARK: - Fixed Content View with Language Support
struct FixedContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var languageManager = LanguageManager.shared
    @StateObject private var usdaService = USDAFoodService()
    @StateObject private var foodManager: FoodDataManager
    
    @State private var selectedTab = 0
    @State private var showingSettings = false
    
    init() {
        let container = PersistenceController.shared.container
        _foodManager = StateObject(wrappedValue: FoodDataManager(container: container))
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // MARK: - Top Navigation Bar with Language Switcher
                HStack {
                    Text("MealPlannerPro")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    // Language Switcher
                    LanguageSwitcher()
                    
                    // Settings Button
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gear")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(NSColor.controlBackgroundColor))
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(Color.gray.opacity(0.3)),
                    alignment: .bottom
                )
                
                // MARK: - Main Content with Fixed Layout
                TabView(selection: $selectedTab) {
                    // Food Search Tab
                    FixedFoodSearchView(usdaService: usdaService, foodManager: foodManager)
                        .tabItem {
                            Image(systemName: "magnifyingglass")
                            Text(languageManager.currentLanguage.appStrings.foodSearch)
                        }
                        .tag(0)
                    
                    // My Foods Tab
                    FixedSavedFoodsView(foodManager: foodManager)
                        .tabItem {
                            Image(systemName: "heart.fill")
                            Text(languageManager.currentLanguage.appStrings.myFoods)
                        }
                        .tag(1)
                    
                    // Basic Meal Planning Tab
                    FixedMealPlanningView()
                        .tabItem {
                            Image(systemName: "calendar")
                            Text(languageManager.currentLanguage.appStrings.basicPlans)
                        }
                        .tag(2)
                    
                    // FIXED AI Assistant Tab
                    FixedAIMealPlannerView()
                        .tabItem {
                            Image(systemName: "brain.head.profile")
                            Text(languageManager.currentLanguage.appStrings.aiAssistant)
                        }
                        .tag(3)
                    
                    // Multi-Day Planner Tab
                    FixedEnhancedAIMealPlannerView()
                        .tabItem {
                            Image(systemName: "calendar.badge.plus")
                            Text(languageManager.currentLanguage.appStrings.multiDayPlanner)
                        }
                        .tag(4)
                }
            }
        }
        .frame(minWidth: 1200, minHeight: 800) // Fixed minimum window size
        .languageUpdatable()
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
    }
}

// MARK: - Fixed AI Assistant View (Solving Column Layout Issues)
struct FixedAIMealPlannerView: View {
    @StateObject private var languageManager = LanguageManager.shared
    @StateObject private var llmService = LLMService()
    @StateObject private var verifiedService = USDAVerifiedMealPlanningService()
    
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
        // FIXED: Use HSplitView for proper two-column layout
        HSplitView {
            // LEFT COLUMN - Configuration Panel (Fixed Width)
            VStack(spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text(strings.aiAssistantTitle)
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text(strings.aiAssistantSubtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Patient Selection
                        configurationSection(title: strings.patientSelection) {
                            patientSelectionView
                        }
                        
                        // Meal Configuration
                        configurationSection(title: strings.mealConfiguration) {
                            mealConfigurationView
                        }
                        
                        // Preferences
                        configurationSection(title: strings.preferences) {
                            preferencesView
                        }
                        
                        // Generate Button
                        generateButton
                    }
                    .padding(.bottom, 20)
                }
                
                Spacer()
            }
            .frame(width: 350) // Fixed width for left panel
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            // RIGHT COLUMN - Results Display (Expandable)
            VStack(spacing: 0) {
                if isGenerating {
                    // Loading State
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text(strings.generating)
                            .font(.headline)
                        Text("Verificando alimentos con base de datos USDA...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.white)
                } else if let suggestion = currentSuggestion {
                    // Results Display
                    resultDisplayView(suggestion: suggestion)
                } else {
                    // Empty State
                    VStack(spacing: 20) {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 60))
                            .foregroundColor(.gray.opacity(0.5))
                        
                        Text(strings.generatePersonalizedMeals)
                            .font(.title2)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        Text("Configura los parámetros en el panel izquierdo y genera una comida personalizada")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.white)
                }
            }
            .overlay(
                Rectangle()
                    .frame(width: 1)
                    .foregroundColor(Color.gray.opacity(0.3)),
                alignment: .leading
            )
        }
        .alert(strings.mealGenerated, isPresented: $showingSuccess) {
            Button(strings.ok) { }
        }
        .alert(strings.error, isPresented: .constant(errorMessage != nil)) {
            Button(strings.ok) { errorMessage = nil }
        } message: {
            if let error = errorMessage {
                Text(error)
            }
        }
    }
    
    // MARK: - Configuration Sections
    private func configurationSection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            content()
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    private var patientSelectionView: some View {
        VStack(alignment: .leading, spacing: 8) {
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
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    private var mealConfigurationView: some View {
        VStack(spacing: 12) {
            // Target Calories
            VStack(alignment: .leading, spacing: 4) {
                Text(strings.targetCalories)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack {
                    Slider(value: Binding(
                        get: { Double(targetCalories) },
                        set: { targetCalories = Int($0) }
                    ), in: 200...1500, step: 50)
                    
                    Text("\(targetCalories) kcal")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .frame(width: 80, alignment: .trailing)
                }
            }
            
            // Meal Type
            VStack(alignment: .leading, spacing: 4) {
                Text(strings.mealType)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Picker("", selection: $selectedMealType) {
                    ForEach(MealType.allCases, id: \.self) { mealType in
                        Text(mealType.localizedName(language: languageManager.currentLanguage))
                            .tag(mealType)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
            }
            
            // Cuisine
            VStack(alignment: .leading, spacing: 4) {
                Text(strings.cuisine)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Picker("", selection: $selectedCuisine) {
                    Text("Mediterráneo").tag("Mediterráneo")
                    Text("Mexicano").tag("Mexicano")
                    Text("Asiático").tag("Asiático")
                    Text("Americano").tag("Americano")
                    Text("Vegetariano").tag("Vegetariano")
                }
                .pickerStyle(MenuPickerStyle())
            }
        }
    }
    
    private var preferencesView: some View {
        VStack(spacing: 12) {
            // Dietary Restrictions
            VStack(alignment: .leading, spacing: 8) {
                Text(strings.dietaryRestrictions)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 8) {
                    ForEach(["Sin gluten", "Sin lácteos", "Vegano", "Bajo sodio"], id: \.self) { restriction in
                        ToggleChip(
                            text: restriction,
                            isSelected: dietaryRestrictions.contains(restriction)
                        ) {
                            if dietaryRestrictions.contains(restriction) {
                                dietaryRestrictions.removeAll { $0 == restriction }
                            } else {
                                dietaryRestrictions.append(restriction)
                            }
                        }
                    }
                }
            }
            
            // Medical Conditions
            VStack(alignment: .leading, spacing: 8) {
                Text(strings.medicalConditions)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 8) {
                    ForEach(["Diabetes", "Hipertensión", "Renal", "Cardíaco"], id: \.self) { condition in
                        ToggleChip(
                            text: condition,
                            isSelected: medicalConditions.contains(condition)
                        ) {
                            if medicalConditions.contains(condition) {
                                medicalConditions.removeAll { $0 == condition }
                            } else {
                                medicalConditions.append(condition)
                            }
                        }
                    }
                }
            }
        }
    }
    
    private var generateButton: some View {
        Button(action: generateMeal) {
            HStack {
                if isGenerating {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "brain.head.profile")
                }
                Text(isGenerating ? strings.generating : strings.generateMeal)
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(isGenerating ? Color.gray : Color.blue)
            .cornerRadius(10)
        }
        .disabled(isGenerating)
    }
    
    private func resultDisplayView(suggestion: VerifiedMealPlanSuggestion) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                // Meal Header
                VStack(spacing: 8) {
                    Text(suggestion.originalAISuggestion.mealName)
                        .font(.title)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    Text("\(suggestion.originalAISuggestion.estimatedCalories) kcal • \(suggestion.verifiedFoods.count) alimentos")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                
                // Foods List
                LazyVStack(spacing: 12) {
                    ForEach(suggestion.verifiedFoods, id: \.originalAISuggestion.id) { verifiedFood in
                        VerifiedFoodCard(verifiedFood: verifiedFood)
                    }
                }
                .padding(.horizontal)
                
                // Nutrition Summary
                NutritionSummaryCard(suggestion: suggestion)
                    .padding(.horizontal)
                
                Spacer(minLength: 20)
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
    }
    
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
}

// MARK: - Supporting Components
struct ToggleChip: View {
    let text: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.blue : Color.gray.opacity(0.2))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(16)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct VerifiedFoodCard: View {
    let verifiedFood: VerifiedSuggestedFood
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(verifiedFood.originalAISuggestion.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("\(verifiedFood.originalAISuggestion.gramWeight)g")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if verifiedFood.isVerified {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Verificado USDA")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(Int(verifiedFood.verifiedNutrition.calories)) kcal")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("P: \(Int(verifiedFood.verifiedNutrition.protein))g")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.05), radius: 1, x: 0, y: 1)
    }
}

struct NutritionSummaryCard: View {
    let suggestion: VerifiedMealPlanSuggestion
    
    var totalCalories: Double {
        suggestion.verifiedFoods.reduce(0) { $0 + $1.verifiedNutrition.calories }
    }
    
    var totalProtein: Double {
        suggestion.verifiedFoods.reduce(0) { $0 + $1.verifiedNutrition.protein }
    }
    
    var totalCarbs: Double {
        suggestion.verifiedFoods.reduce(0) { $0 + $1.verifiedNutrition.carbohydrates }
    }
    
    var totalFat: Double {
        suggestion.verifiedFoods.reduce(0) { $0 + $1.verifiedNutrition.fat }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Resumen Nutricional")
                .font(.headline)
                .foregroundColor(.primary)
            
            HStack(spacing: 20) {
                NutritionItem(label: "Calorías", value: "\(Int(totalCalories))", unit: "kcal")
                NutritionItem(label: "Proteína", value: "\(Int(totalProtein))", unit: "g")
                NutritionItem(label: "Carbohidratos", value: "\(Int(totalCarbs))", unit: "g")
                NutritionItem(label: "Grasa", value: "\(Int(totalFat))", unit: "g")
            }
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .cornerRadius(12)
    }
}

struct NutritionItem: View {
    let label: String
    let value: String
    let unit: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.blue)
            
            Text(unit)
                .font(.caption)
                .foregroundColor(.blue)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Extensions for Localization
extension MealType {
    func localizedName(language: PlanLanguage) -> String {
        switch language {
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

// MARK: - Placeholder Views (to be implemented)
struct FixedFoodSearchView: View {
    let usdaService: USDAFoodService
    let foodManager: FoodDataManager
    
    var body: some View {
        Text("Food Search - Coming Soon")
    }
}

struct FixedSavedFoodsView: View {
    let foodManager: FoodDataManager
    
    var body: some View {
        Text("Saved Foods - Coming Soon")
    }
}

struct FixedMealPlanningView: View {
    var body: some View {
        Text("Meal Planning - Coming Soon")
    }
}

struct FixedEnhancedAIMealPlannerView: View {
    var body: some View {
        Text("Enhanced AI Meal Planner - Coming Soon")
    }
}

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack {
            Text("Settings")
                .font(.title)
            
            Button("Close") {
                dismiss()
            }
        }
        .padding()
        .frame(width: 400, height: 300)
    }
}
