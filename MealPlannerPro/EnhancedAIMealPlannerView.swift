import SwiftUI
import PDFKit
import CoreData

#if canImport(UIKit)
import UIKit
#endif

#if canImport(AppKit)
import AppKit
#endif


// MARK: - Enhanced Multi-Day Meal Planner View
struct EnhancedAIMealPlannerView: View {
    @StateObject private var multiDayService = MultiDayMealPlanningService()
    @StateObject private var pdfService = FixedMealPlanPDFService()
    @StateObject private var usdaService = USDAFoodService()
    
    @State private var selectedPatient: Patient?
    @State private var planDuration = 3 // Default to 3 days
    @State private var selectedLanguage: PlanLanguage = .spanish
    @State private var startDate = Date()
    
    // Meal preferences
    @State private var includedMeals: Set<MealType> = [.breakfast, .lunch, .dinner]
    @State private var cuisineRotation: [String] = ["Mediterráneo", "Mexicano", "Asiático"]
    @State private var customCuisine = ""
    
    // Dietary preferences
    @State private var dietaryRestrictions: [String] = []
    @State private var medicalConditions: [String] = []
    
    // Customizable nutrition targets
    @State private var customCalories: String = "2000"
    @State private var customProtein: String = "150"
    @State private var customCarbs: String = "250"
    @State private var customFat: String = "78"
    @State private var useCustomTargets = false
    
    // Micronutrient targets
    @State private var customFiber: String = "25"
    @State private var customSodium: String = "2300"
    @State private var customPotassium: String = "4700"
    @State private var customCalcium: String = "1000"
    @State private var customIron: String = "18"
    @State private var customVitaminD: String = "15"
    @State private var customVitaminC: String = "90"
    @State private var customVitaminB12: String = "2.4"
    @State private var customFolate: String = "400"
    @State private var showMicronutrients = false
    
    // Portion preferences (fixed structure)
    @State private var portionPreferences = PortionPreferences(
        preferMetric: true,
        preferLargePortion: false,
        customPortionMultiplier: 1.0,
        avoidedFoodSizes: [],
        preferredMeasurements: ["taza", "cucharada", "pieza"]
    )
    
    // Results
    @State private var currentMultiDayPlan: MultiDayMealPlan?
    @State private var showingSuccess = false
    @State private var showingPDFViewer = false
    @State private var generatedPDFData: Data?
    
    // UI State
    @State private var selectedTab: PlannerTab = .setup
    
    // Access to patients
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Patient.lastName, ascending: true)],
        animation: .default)
    private var patients: FetchedResults<Patient>
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Tab Selection
                Picker("Planner Section", selection: $selectedTab) {
                    Text("Configuración").tag(PlannerTab.setup)
                    Text("Plan Generado").tag(PlannerTab.results)
                    Text("Exportar PDF").tag(PlannerTab.export)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                // Tab Content
                ScrollView {
                    switch selectedTab {
                    case .setup:
                        setupView
                    case .results:
                        resultsView
                    case .export:
                        exportView
                    }
                }
            }
        }
        .navigationTitle("🤖 Planificador AI Avanzado")
        .sheet(isPresented: $showingPDFViewer) {
            if let pdfData = generatedPDFData {
                PDFViewerSheet(pdfData: pdfData)
            }
        }
        .sheet(item: Binding<PendingFoodSelection?>(
            get: { multiDayService.verificationService.pendingFoodSelections.first },
            set: { _ in }
        )) { pendingSelection in
            FoodSelectionView(
                originalFood: pendingSelection.originalFood,
                usdaOptions: pendingSelection.usdaOptions,
                onSelection: { selectedFood in
                    multiDayService.verificationService.selectFoodForPendingItem(pendingSelection, selectedFood: selectedFood)
                },
                onSkip: {
                    multiDayService.verificationService.selectFoodForPendingItem(pendingSelection, selectedFood: nil)
                }
            )
        }
        .alert("¡Plan Creado!", isPresented: $showingSuccess) {
            Button("Ver Resultados") {
                selectedTab = .results
            }
            Button("OK") { }
        } message: {
            Text("Plan de comidas de \(planDuration) días generado exitosamente con verificación USDA!")
        }
    }
    
    // MARK: - Setup View
    @ViewBuilder
    private var setupView: some View {
        VStack(spacing: 30) {
            // Header
            VStack {
                Text("🌟 Planificador Multi-Día")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Genera planes de comidas inteligentes con verificación USDA")
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Patient and Duration Selection
            patientAndDurationSection
            
            // Language and Meal Type Selection
            languageAndMealsSection
            
            // Cuisine and Dietary Preferences
            cuisineAndDietarySection
            
            // Nutrition Targets
            nutritionTargetsSection
            
            // Portion Preferences
            portionPreferencesSection
            
            // Generate Button
            generateButton
        }
        .padding()
    }
    
    // MARK: - Results View
    @ViewBuilder
    private var resultsView: some View {
        Group {
            if let plan = currentMultiDayPlan {
                MultiDayPlanResultsView(
                    plan: plan,
                    onRegenerateDay: { dayIndex in
                        // Implement day regeneration
                        print("Regenerating day \(dayIndex + 1)")
                    }
                )
            } else {
                VStack(spacing: 20) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 64))
                        .foregroundColor(.gray)
                    
                    Text("Sin Plan Generado")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Configura y genera un plan de comidas para ver los resultados aquí.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            }
        }
        .padding()
    }
    
    // MARK: - Export View
    @ViewBuilder
    private var exportView: some View {
        Group {
            if let plan = currentMultiDayPlan {
                ExportOptionsView(
                    plan: plan,
                    patient: selectedPatient,
                    pdfService: pdfService,
                    onPDFGenerated: { pdfData in
                        generatedPDFData = pdfData
                        showingPDFViewer = true
                    }
                )
            } else {
                VStack(spacing: 20) {
                    Image(systemName: "doc.badge.plus")
                        .font(.system(size: 64))
                        .foregroundColor(.gray)
                    
                    Text("Plan Requerido")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Genera un plan de comidas primero para poder exportarlo.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            }
        }
        .padding()
    }
    
    // MARK: - Section Views
    @ViewBuilder
    private var patientAndDurationSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("👤 Paciente y Duración")
                .font(.title2)
                .fontWeight(.bold)
            
            // Patient Selection
            VStack(alignment: .leading, spacing: 8) {
                Text("Paciente:")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Picker("Seleccionar Paciente", selection: $selectedPatient) {
                    Text("Seleccionar un paciente...").tag(Patient?(nil))
                    ForEach(patients, id: \.objectID) { patient in
                        Text("\(patient.firstName ?? "") \(patient.lastName ?? "")")
                            .tag(Patient?(patient))
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
            
            // Duration Selection
            VStack(alignment: .leading, spacing: 8) {
                Text("Duración del Plan:")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                HStack {
                    ForEach([1, 3, 5, 7, 14], id: \.self) { days in
                        Button(action: { planDuration = days }) {
                            VStack {
                                Text("\(days)")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                Text(days == 1 ? "día" : "días")
                                    .font(.caption)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(planDuration == days ? Color.blue : Color.gray.opacity(0.2))
                            .foregroundColor(planDuration == days ? .white : .primary)
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            // Start Date
            VStack(alignment: .leading, spacing: 8) {
                Text("Fecha de Inicio:")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                DatePicker("Fecha de Inicio", selection: $startDate, displayedComponents: .date)
                    .datePickerStyle(CompactDatePickerStyle())
            }
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .cornerRadius(15)
    }
    
    @ViewBuilder
    private var languageAndMealsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("🌍 Idioma y Comidas")
                .font(.title2)
                .fontWeight(.bold)
            
            // Language Selection
            VStack(alignment: .leading, spacing: 8) {
                Text("Idioma del Plan:")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Picker("Idioma", selection: $selectedLanguage) {
                    ForEach(PlanLanguage.allCases, id: \.self) { language in
                        Text(language.displayName).tag(language)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
            }
            
            // Meal Types
            VStack(alignment: .leading, spacing: 8) {
                Text("Comidas a Incluir:")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 10) {
                    ForEach(MealType.allCases, id: \.self) { mealType in
                        Button(action: {
                            if includedMeals.contains(mealType) {
                                includedMeals.remove(mealType)
                            } else {
                                includedMeals.insert(mealType)
                            }
                        }) {
                            HStack {
                                Text(mealType.emoji)
                                Text(getMealDisplayName(mealType))
                            }
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(includedMeals.contains(mealType) ? Color.green : Color.gray.opacity(0.2))
                            .foregroundColor(includedMeals.contains(mealType) ? .white : .primary)
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding()
        .background(Color.green.opacity(0.05))
        .cornerRadius(15)
    }
    
    @ViewBuilder
    private var cuisineAndDietarySection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("🍽️ Preferencias Culinarias")
                .font(.title2)
                .fontWeight(.bold)
            
            // Cuisine Rotation
            VStack(alignment: .leading, spacing: 8) {
                Text("Rotación de Cocinas:")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 10) {
                    ForEach(commonCuisines, id: \.self) { cuisine in
                        Button(action: {
                            if cuisineRotation.contains(cuisine) {
                                cuisineRotation.removeAll { $0 == cuisine }
                            } else {
                                cuisineRotation.append(cuisine)
                            }
                        }) {
                            Text(cuisine)
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(cuisineRotation.contains(cuisine) ? Color.orange : Color.gray.opacity(0.2))
                                .foregroundColor(cuisineRotation.contains(cuisine) ? .white : .primary)
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                // Custom cuisine input
                HStack {
                    TextField("Cocina personalizada", text: $customCuisine)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Button("Agregar") {
                        if !customCuisine.isEmpty && !cuisineRotation.contains(customCuisine) {
                            cuisineRotation.append(customCuisine)
                            customCuisine = ""
                        }
                    }
                    .disabled(customCuisine.isEmpty)
                }
            }
            
            // Dietary Restrictions and Medical Conditions
            HStack {
                // Dietary Restrictions
                VStack(alignment: .leading, spacing: 8) {
                    Text("Restricciones:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    LazyVGrid(columns: [GridItem(.flexible())], spacing: 8) {
                        ForEach(commonRestrictions, id: \.self) { restriction in
                            RestrictionToggle(
                                restriction: restriction,
                                isSelected: dietaryRestrictions.contains(restriction),
                                toggle: { toggleRestriction(restriction) }
                            )
                        }
                    }
                }
                
                Spacer()
                
                // Medical Conditions
                VStack(alignment: .leading, spacing: 8) {
                    Text("Condiciones:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    LazyVGrid(columns: [GridItem(.flexible())], spacing: 8) {
                        ForEach(commonConditions, id: \.self) { condition in
                            RestrictionToggle(
                                restriction: condition,
                                isSelected: medicalConditions.contains(condition),
                                toggle: { toggleCondition(condition) }
                            )
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color.orange.opacity(0.05))
        .cornerRadius(15)
    }
    
    @ViewBuilder
    private var nutritionTargetsSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("🎯 Objetivos Nutricionales")
                .font(.title2)
                .fontWeight(.bold)
            
            // Toggle for custom targets
            Toggle("Usar objetivos personalizados", isOn: $useCustomTargets)
                .font(.subheadline)
                .fontWeight(.medium)
            
            if useCustomTargets {
                VStack(spacing: 15) {
                    // Calories
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Calorías Diarias:")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        HStack {
                            TextField("2000", text: $customCalories)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            //                                .keyboardType(.numberPad)
                            Text("kcal")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Macronutrients in a grid
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 15) {
                        // Protein
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Proteína:")
                                .font(.caption)
                                .fontWeight(.medium)
                            
                            HStack {
                                TextField("150", text: $customProtein)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                //                                    .keyboardType(.numberPad)
                                Text("g")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        // Carbs
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Carbohidratos:")
                                .font(.caption)
                                .fontWeight(.medium)
                            
                            HStack {
                                TextField("250", text: $customCarbs)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                //                                    .keyboardType(.numberPad)
                                Text("g")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        // Fat
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Grasas:")
                                .font(.caption)
                                .fontWeight(.medium)
                            
                            HStack {
                                TextField("78", text: $customFat)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                //                                    .keyboardType(.numberPad)
                                Text("g")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .padding()
                .background(Color.yellow.opacity(0.1))
                .cornerRadius(8)
                
                // Micronutrients section
                VStack(alignment: .leading, spacing: 12) {
                    Button(action: { showMicronutrients.toggle() }) {
                        HStack {
                            Text("Micronutrientes")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Spacer()
                            Image(systemName: showMicronutrients ? "chevron.up" : "chevron.down")
                        }
                    }
                    .buttonStyle(.plain)
                    
                    if showMicronutrients {
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 12) {
                            MicronutrientField(label: "Fibra", value: $customFiber, unit: "g")
                            MicronutrientField(label: "Sodio", value: $customSodium, unit: "mg")
                            MicronutrientField(label: "Potasio", value: $customPotassium, unit: "mg")
                            MicronutrientField(label: "Calcio", value: $customCalcium, unit: "mg")
                            MicronutrientField(label: "Hierro", value: $customIron, unit: "mg")
                            MicronutrientField(label: "Vit. D", value: $customVitaminD, unit: "mcg")
                            MicronutrientField(label: "Vit. C", value: $customVitaminC, unit: "mg")
                            MicronutrientField(label: "B12", value: $customVitaminB12, unit: "mcg")
                            MicronutrientField(label: "Folato", value: $customFolate, unit: "mcg")
                        }
                        .padding()
                        .background(Color.blue.opacity(0.05))
                        .cornerRadius(8)
                    }
                }
            } else {
                Text("Se usarán los objetivos del perfil del paciente")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
        .padding()
        .background(Color.yellow.opacity(0.05))
        .cornerRadius(15)
    }
    
    @ViewBuilder
    private var portionPreferencesSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("⚖️ Preferencias de Porciones")
                .font(.title2)
                .fontWeight(.bold)
            
            // Metric vs Imperial
            VStack(alignment: .leading, spacing: 8) {
                Text("Sistema de Medidas:")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Picker("Medidas", selection: $portionPreferences.preferMetric) {
                    Text("Métrico (gramos, ml)").tag(true)
                    Text("Imperial (onzas, tazas)").tag(false)
                }
                .pickerStyle(SegmentedPickerStyle())
            }
            
            // Portion Size Multiplier
            VStack(alignment: .leading, spacing: 8) {
                Text("Tamaño de Porciones: \(String(format: "%.1fx", portionPreferences.customPortionMultiplier))")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Slider(value: $portionPreferences.customPortionMultiplier, in: 0.5...2.0, step: 0.1) {
                    Text("Multiplicador")
                } minimumValueLabel: {
                    Text("Pequeño")
                        .font(.caption)
                } maximumValueLabel: {
                    Text("Grande")
                        .font(.caption)
                }
            }
            
            // Large Portion Preference
            Toggle("Preferir porciones grandes", isOn: $portionPreferences.preferLargePortion)
        }
        .padding()
        .background(Color.purple.opacity(0.05))
        .cornerRadius(15)
    }
    
    @ViewBuilder
    private var generateButton: some View {
        Button(action: generateMultiDayPlan) {
            HStack {
                if multiDayService.isGenerating {
                    ProgressView()
                        .scaleEffect(0.8)
                    
                    VStack {
                        Text("Generando Plan (\(multiDayService.currentProgress)/\(multiDayService.totalProgress))")
                        
                        if multiDayService.totalProgress > 0 {
                            ProgressView(value: Double(multiDayService.currentProgress), total: Double(multiDayService.totalProgress))
                                .frame(width: 200)
                        }
                    }
                } else {
                    Image(systemName: "brain.head.profile.fill")
                    Text("Generar Plan de \(planDuration) Días con IA")
                }
            }
            .font(.headline)
            .foregroundColor(.white)
            .padding()
            .frame(maxWidth: .infinity)
            .background(canGenerate ? Color.blue : Color.gray)
            .cornerRadius(10)
        }
        .disabled(!canGenerate || multiDayService.isGenerating)
    }
    
    // MARK: - Helper Properties and Functions
    private var canGenerate: Bool {
        selectedPatient != nil && !includedMeals.isEmpty && planDuration > 0
    }
    
    private let commonCuisines = [
        "Mediterráneo", "Mexicano", "Asiático", "Italiano", "Francés",
        "Japonés", "Indio", "Tailandés", "Peruano", "Argentino"
    ]
    
    private let commonRestrictions = [
        "Vegetariano", "Vegano", "Sin Gluten", "Sin Lácteos",
        "Sin Nueces", "Bajo en Sodio", "Bajo en Grasa", "Keto", "Paleo"
    ]
    
    private let commonConditions = [
        "Diabetes", "Hipertensión", "Enfermedad Cardíaca", "Enfermedad Renal",
        "Colesterol Alto", "Enfermedad Celíaca", "Alergias Alimentarias"
    ]
    
    private func getMealDisplayName(_ mealType: MealType) -> String {
        switch mealType {
        case .breakfast: return "Desayuno"
        case .lunch: return "Almuerzo"
        case .dinner: return "Cena"
        case .snack: return "Merienda"
        }
    }
    
    private func toggleRestriction(_ restriction: String) {
        if dietaryRestrictions.contains(restriction) {
            dietaryRestrictions.removeAll { $0 == restriction }
        } else {
            dietaryRestrictions.append(restriction)
        }
    }
    
    private func toggleCondition(_ condition: String) {
        if medicalConditions.contains(condition) {
            medicalConditions.removeAll { $0 == condition }
        } else {
            medicalConditions.append(condition)
        }
    }
    
    // MARK: - Main Generation Function
    private func generateMultiDayPlan() {
        guard let patient = selectedPatient else { return }
        
        let goals = getPatientGoals(patient)
        
        let request = MultiDayPlanRequest(
            patientId: patient.id,
            numberOfDays: planDuration,
            startDate: startDate,
            dailyCalories: Int(goals.calories),
            dailyProtein: goals.protein,
            dailyCarbs: goals.carbohydrates,
            dailyFat: goals.fat,
            mealsPerDay: Array(includedMeals),
            cuisineRotation: cuisineRotation,
            dietaryRestrictions: dietaryRestrictions,
            medicalConditions: medicalConditions,
            language: selectedLanguage,
            customPortionPreferences: portionPreferences
        )
        
        Task {
            do {
                let plan = try await multiDayService.generateMultiDayPlan(request: request)
                await MainActor.run {
                    currentMultiDayPlan = plan
                    showingSuccess = true
                }
            } catch {
                print("❌ Error generating multi-day plan: \(error)")
            }
        }
    }
    
    private func getPatientGoals(_ patient: Patient) -> NutritionalGoals {
        if useCustomTargets {
            // Use custom targets from UI
            return NutritionalGoals(
                calories: Double(customCalories) ?? 2000,
                protein: Double(customProtein) ?? 150,
                carbohydrates: Double(customCarbs) ?? 250,
                fat: Double(customFat) ?? 78,
                fiber: Double(customFiber) ?? 25,
                sodium: Double(customSodium) ?? 2300,
                potassium: Double(customPotassium) ?? 4700,
                calcium: Double(customCalcium) ?? 1000,
                iron: Double(customIron) ?? 18,
                vitaminD: Double(customVitaminD) ?? 15,
                vitaminC: Double(customVitaminC) ?? 90,
                vitaminB12: Double(customVitaminB12) ?? 2.4,
                folate: Double(customFolate) ?? 400
            )
        }
        
        if let goalsJSON = patient.nutritionalGoals,
           let goals = NutritionalGoals.fromJSONString(goalsJSON) {
            return goals
        }
        
        // Default goals
        return NutritionalGoals(
            calories: 2000, protein: 150, carbohydrates: 250, fat: 78,
            fiber: 25, sodium: 2300, potassium: 4700, calcium: 1000,
            iron: 18, vitaminD: 15, vitaminC: 90, vitaminB12: 2.4, folate: 400
        )
    }
}

// MARK: - Supporting Views
enum PlannerTab: CaseIterable {
    case setup, results, export
}

// MARK: - Restriction Toggle Component
struct RestrictionToggle: View {
    let restriction: String
    let isSelected: Bool
    let toggle: () -> Void
    
    var body: some View {
        Button(action: toggle) {
            Text(restriction)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(isSelected ? Color.blue : Color.gray.opacity(0.2))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Multi-Day Plan Results View
struct MultiDayPlanResultsView: View {
    let plan: MultiDayMealPlan
    let onRegenerateDay: (Int) -> Void
    
    private var dateRangeText: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        return "\(dateFormatter.string(from: plan.startDate)) - \(dateFormatter.string(from: plan.endDate))"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Plan Header
            VStack(alignment: .leading, spacing: 10) {
                Text("📅 Plan de \(plan.numberOfDays) Días")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text(dateRangeText)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
            }
            
            // Overall Summary
            HStack {
                SummaryCard(title: "Promedio Diario", value: "\(Int(plan.totalNutritionSummary.averageDailyCalories)) cal", color: .blue)
                SummaryCard(title: "Precisión", value: "\(Int(plan.totalNutritionSummary.overallAccuracy * 100))%", color: .green)
                SummaryCard(title: "Días", value: "\(plan.numberOfDays)", color: .orange)
            }
        }
        
        // Daily Plans
        ForEach(Array(plan.dailyPlans.enumerated()), id: \.offset) { dayIndex, dailyPlan in
            DailyPlanCard(
                dailyPlan: dailyPlan,
                dayNumber: dayIndex + 1,
                language: plan.language,
                onRegenerate: { onRegenerateDay(dayIndex) }
            )
        }
    }
}

struct SummaryCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

struct DailyPlanCard: View {
    let dailyPlan: DailyMealPlan
    let dayNumber: Int
    let language: PlanLanguage
    let onRegenerate: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            // Day Header
            HStack {
                Text("Día \(dayNumber)")
                    .font(.headline)
                    .fontWeight(.bold)
                
                Spacer()
                
                Text("\(Int(dailyPlan.dailyNutritionSummary.calories)) cal")
                    .font(.subheadline)
                    .foregroundColor(.blue)
                
                Button("Regenerar", action: onRegenerate)
                    .font(.caption)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
            
            // Meals
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 10) {
                ForEach(Array(dailyPlan.meals.enumerated()), id: \.offset) { mealIndex, meal in
                    MealSummaryCard(meal: meal, language: language)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
}

struct MealSummaryCard: View {
    let meal: VerifiedMealPlanSuggestion
    let language: PlanLanguage
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(getMealTypeDisplayName(meal.originalAISuggestion.mealType, language: language))
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            Text(meal.originalAISuggestion.mealName)
                .font(.subheadline)
                .fontWeight(.bold)
                .lineLimit(2)
            
            Text("\(Int(meal.verifiedTotalNutrition.calories)) cal")
                .font(.caption)
                .foregroundColor(.blue)
            
            // Verification badge
            HStack {
                let verifiedCount = meal.verifiedFoods.filter { $0.isVerified }.count
                let totalCount = meal.verifiedFoods.count
                
                Image(systemName: verifiedCount == totalCount ? "checkmark.seal.fill" : "checkmark.seal")
                    .foregroundColor(verifiedCount == totalCount ? .green : .orange)
                    .font(.caption)
                
                Text("\(verifiedCount)/\(totalCount) verificado")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.white)
        .cornerRadius(8)
        .shadow(radius: 1)
    }
    
    private func getMealTypeDisplayName(_ mealType: MealType, language: PlanLanguage) -> String {
        let strings = language.localized
        switch mealType {
        case .breakfast: return strings.breakfast
        case .lunch: return strings.lunch
        case .dinner: return strings.dinner
        case .snack: return strings.snack
        }
    }
}

// MARK: - Export Options View
struct ExportOptionsView: View {
    let plan: MultiDayMealPlan
    let patient: Patient?
    @ObservedObject var pdfService: FixedMealPlanPDFService
    let onPDFGenerated: (Data) -> Void
    
    @State private var includeRecipes = true
    @State private var includeShoppingList = true
    @State private var includeNutritionAnalysis = true
    
    var body: some View {
        VStack(spacing: 30) {
            Text("📤 Opciones de Exportación")
                .font(.title)
                .fontWeight(.bold)
            
            // Export Options
            VStack(alignment: .leading, spacing: 15) {
                Text("Incluir en el PDF:")
                    .font(.headline)
                
                Toggle("📝 Recetas detalladas", isOn: $includeRecipes)
                Toggle("🛒 Lista de compras", isOn: $includeShoppingList)
                Toggle("📊 Análisis nutricional", isOn: $includeNutritionAnalysis)
            }
            .padding()
            .background(Color.blue.opacity(0.05))
            .cornerRadius(12)
            
            // Generate PDF Button
            Button(action: generatePDF) {
                HStack {
                    if pdfService.isGenerating {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Generando PDF...")
                    } else {
                        Image(systemName: "doc.badge.plus")
                        Text("Generar PDF Completo")
                    }
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.red)
                .cornerRadius(10)
            }
            .disabled(pdfService.isGenerating)
            
            // Error Display
            if let error = pdfService.lastError {
                Text("Error: \(error)")
                    .foregroundColor(.red)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
            }
            
            Spacer()
        }
    }
    
    private func generatePDF() {
        Task {
            do {
                let pdfData = try await pdfService.generateMealPlanPDF(
                    multiDayPlan: plan,
                    patient: patient,
                    includeRecipes: includeRecipes,
                    includeShoppingList: includeShoppingList
                )
                
                await MainActor.run {
                    onPDFGenerated(pdfData)
                }
            } catch {
                print("❌ Error generating PDF: \(error)")
            }
        }
    }
}

// MARK: - Simplified PDF Viewer
struct PDFViewerSheet: View {
    let pdfData: Data
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Group {
                if let document = PDFDocument(data: pdfData) {
                    PDFKitRepresentable(document: document)
                } else {
                    Text("Error al cargar el PDF")
                        .foregroundColor(.red)
                }
            }
            .navigationTitle("Plan de Comidas")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cerrar") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Compartir") {
                        sharePDF()
                    }
                }
            }
#else
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button("Cerrar") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .automatic) {
                    Button("Compartir") {
                        sharePDF()
                    }
                }
            }
#endif
        }
    }
    
    private func sharePDF() {
#if canImport(UIKit)
        let activityViewController = UIActivityViewController(
            activityItems: [pdfData],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityViewController, animated: true)
        }
#endif
    }
}

// MARK: - PDFKit Integration
struct PDFKitRepresentable: View {
    let document: PDFDocument
    
    var body: some View {
#if canImport(UIKit)
        PDFKitUIViewRepresentable(document: document)
#elseif canImport(AppKit)
        PDFKitNSViewRepresentable(document: document)
#else
        Text("PDF viewing not supported on this platform")
#endif
    }
}

#if canImport(UIKit)
struct PDFKitUIViewRepresentable: UIViewRepresentable {
    let document: PDFDocument
    
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = document
        pdfView.autoScales = true
        return pdfView
    }
    
    func updateUIView(_ uiView: PDFView, context: Context) {
        uiView.document = document
    }
}
#endif

#if canImport(AppKit)
struct PDFKitNSViewRepresentable: NSViewRepresentable {
    let document: PDFDocument
    
    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = document
        pdfView.autoScales = true
        return pdfView
    }
    
    func updateNSView(_ nsView: PDFView, context: Context) {
        nsView.document = document
    }
}
#endif

// MARK: - Micronutrient Field Component
struct MicronutrientField: View {
    let label: String
    @Binding var value: String
    let unit: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption2)
                .fontWeight(.medium)
            
            HStack {
                TextField("0", text: $value)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                //                    .keyboardType(.decimalPad)
                //                    .font(.caption)
                Text(unit)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}
