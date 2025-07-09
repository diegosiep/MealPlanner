import SwiftUI
import CoreData

// MARK: - AI Meal Planner View
struct AIMealPlannerView: View {
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
    
    // Access to patients
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Patient.lastName, ascending: true)],
        animation: .default)
    private var patients: FetchedResults<Patient>
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // Header
                VStack {
                    Text("🤖 Asistente de IA")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Genera comidas personalizadas con verificación USDA")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                ScrollView {
                    VStack(spacing: 25) {
                        // Patient Selection
                        patientSelectionSection
                        
                        // Meal Configuration
                        mealConfigurationSection
                        
                        // Preferences
                        preferencesSection
                        
                        // Generate Button
                        generateButton
                        
                        // Results
                        if let suggestion = currentSuggestion {
                            resultSection(suggestion: suggestion)
                        }
                        
                        // Error Display
                        if let error = errorMessage {
                            Text("Error: \(error)")
                                .foregroundColor(.red)
                                .padding()
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("AI Assistant")
        .alert("¡Comida Generada!", isPresented: $showingSuccess) {
            Button("OK") { }
        } message: {
            Text("Se ha generado una sugerencia de comida verificada con USDA")
        }
    }
    
    // MARK: - Section Views
    private var patientSelectionSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("👤 Selección de Paciente")
                .font(.title2)
                .fontWeight(.bold)
            
            Picker("Paciente", selection: $selectedPatient) {
                Text("Seleccionar paciente...").tag(Patient?(nil))
                ForEach(patients, id: \.objectID) { patient in
                    Text("\(patient.firstName ?? "") \(patient.lastName ?? "")")
                        .tag(Patient?(patient))
                }
            }
            .pickerStyle(MenuPickerStyle())
            .padding()
            .background(Color.blue.opacity(0.05))
            .cornerRadius(8)
            
            if let patient = selectedPatient {
                patientInfoCard(patient: patient)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(15)
    }
    
    private var mealConfigurationSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("🍽️ Configuración de Comida")
                .font(.title2)
                .fontWeight(.bold)
            
            // Meal Type
            VStack(alignment: .leading, spacing: 8) {
                Text("Tipo de Comida:")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                HStack {
                    ForEach(MealType.allCases, id: \.self) { mealType in
                        Button(action: { selectedMealType = mealType }) {
                            HStack {
                                Text(mealType.emoji)
                                Text(mealType.displayName)
                            }
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(selectedMealType == mealType ? Color.green : Color.gray.opacity(0.2))
                            .foregroundColor(selectedMealType == mealType ? .white : .primary)
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            // Calories
            VStack(alignment: .leading, spacing: 8) {
                Text("Calorías Objetivo: \(targetCalories)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Slider(value: Binding(
                    get: { Double(targetCalories) },
                    set: { targetCalories = Int($0) }
                ), in: 200...1000, step: 50) {
                    Text("Calorías")
                } minimumValueLabel: {
                    Text("200")
                        .font(.caption)
                } maximumValueLabel: {
                    Text("1000")
                        .font(.caption)
                }
            }
            
            // Cuisine
            VStack(alignment: .leading, spacing: 8) {
                Text("Estilo de Cocina:")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 8) {
                    ForEach(availableCuisines, id: \.self) { cuisine in
                        Button(action: { selectedCuisine = cuisine }) {
                            Text(cuisine)
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(selectedCuisine == cuisine ? Color.orange : Color.gray.opacity(0.2))
                                .foregroundColor(selectedCuisine == cuisine ? .white : .primary)
                                .cornerRadius(6)
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
    
    private var preferencesSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("⚙️ Preferencias Dietéticas")
                .font(.title2)
                .fontWeight(.bold)
            
            HStack {
                // Dietary Restrictions
                VStack(alignment: .leading, spacing: 8) {
                    Text("Restricciones:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    LazyVGrid(columns: [GridItem(.flexible())], spacing: 6) {
                        ForEach(availableRestrictions, id: \.self) { restriction in
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
                    
                    LazyVGrid(columns: [GridItem(.flexible())], spacing: 6) {
                        ForEach(availableConditions, id: \.self) { condition in
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
    
    private var generateButton: some View {
        Button(action: generateMealSuggestion) {
            HStack {
                if verifiedService.isGenerating {
                    ProgressView()
                        .scaleEffect(0.8)
                    
                    if verifiedService.isVerifying {
                        Text("Verificando con USDA...")
                    } else {
                        Text("Generando sugerencia...")
                    }
                } else {
                    Image(systemName: "brain.head.profile.fill")
                    Text("Generar Comida con IA + USDA")
                }
            }
            .font(.headline)
            .foregroundColor(.white)
            .padding()
            .frame(maxWidth: .infinity)
            .background(canGenerate ? Color.blue : Color.gray)
            .cornerRadius(10)
        }
        .disabled(!canGenerate || verifiedService.isGenerating)
    }
    
    // MARK: - Helper Views
    private func patientInfoCard(patient: Patient) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Información del Paciente")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.blue)
            
            HStack {
                Text("Edad: \(calculateAge(from: patient.dateOfBirth)) años")
                Spacer()
                Text("Peso: \(Int(patient.currentWeight)) kg")
            }
            .font(.caption)
            .foregroundColor(.secondary)
            
            if let goals = getNutritionalGoals(for: patient) {
                Text("Meta diaria: \(Int(goals.calories)) cal")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(8)
    }
    
    private func resultSection(suggestion: VerifiedMealPlanSuggestion) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("🎯 Sugerencia Generada")
                .font(.title2)
                .fontWeight(.bold)
            
            EnhancedAIMealSuggestionView(
                verifiedSuggestion: suggestion,
                isVerifying: .constant(false),
                onApprove: {
                    // Implement approval logic
                    showingSuccess = true
                },
                onRegenerate: {
                    generateMealSuggestion()
                }
            )
        }
        .padding()
        .background(Color.purple.opacity(0.05))
        .cornerRadius(15)
    }
    
    // MARK: - Data and Logic
    private let availableCuisines = [
        "Mediterráneo", "Mexicano", "Asiático", "Italiano", "Francés",
        "Americano", "Indio", "Tailandés", "Japonés", "Peruano"
    ]
    
    private let availableRestrictions = [
        "Vegetariano", "Vegano", "Sin Gluten", "Sin Lácteos",
        "Sin Nueces", "Bajo en Sodio", "Keto", "Paleo"
    ]
    
    private let availableConditions = [
        "Diabetes", "Hipertensión", "Enfermedad Cardíaca",
        "Colesterol Alto", "Enfermedad Renal", "Enfermedad Celíaca"
    ]
    
    private var canGenerate: Bool {
        selectedPatient != nil && targetCalories > 0
    }
    
    // MARK: - Helper Functions
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
    
    private func calculateAge(from dateOfBirth: Date?) -> Int {
        guard let dob = dateOfBirth else { return 25 }
        let calendar = Calendar.current
        let now = Date()
        let ageComponents = calendar.dateComponents([.year], from: dob, to: now)
        return ageComponents.year ?? 25
    }
    
    private func getNutritionalGoals(for patient: Patient) -> NutritionalGoals? {
        guard let goalsJSON = patient.nutritionalGoals else { return nil }
        return NutritionalGoals.fromJSONString(goalsJSON)
    }
    
    // MARK: - Main Generation Function
    private func generateMealSuggestion() {
        guard let patient = selectedPatient else { return }
        
        let goals = getNutritionalGoals(for: patient)
        
        // Calculate proportional macros for this meal
        let totalCalories = goals?.calories ?? 2000
        let mealProportion = Double(targetCalories) / totalCalories
        
        let request = MealPlanRequest(
            targetCalories: targetCalories,
            targetProtein: (goals?.protein ?? 150) * mealProportion,
            targetCarbs: (goals?.carbohydrates ?? 250) * mealProportion,
            targetFat: (goals?.fat ?? 78) * mealProportion,
            mealType: selectedMealType,
            cuisinePreference: selectedCuisine,
            dietaryRestrictions: dietaryRestrictions,
            medicalConditions: medicalConditions,
            patientId: patient.id
        )
        
        Task {
            do {
                errorMessage = nil
                let suggestion = try await verifiedService.generateVerifiedMealPlan(request: request)
                
                await MainActor.run {
                    currentSuggestion = suggestion
                    showingSuccess = true
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
                print("❌ Error generating meal suggestion: \(error)")
            }
        }
    }
}

// MARK: - MealType Extension for Display
extension MealType {
    var displayName: String {
        switch self {
        case .breakfast: return "Desayuno"
        case .lunch: return "Almuerzo"
        case .dinner: return "Cena"
        case .snack: return "Merienda"
        }
    }
    
    var emoji: String {
        switch self {
        case .breakfast: return "🌅"
        case .lunch: return "🌞"
        case .dinner: return "🌙"
        case .snack: return "🍎"
        }
    }
}
