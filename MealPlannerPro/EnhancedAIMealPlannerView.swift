import SwiftUI
import CoreData

// MARK: - EnhancedAIMealPlannerView.swift
// Fixed: RobustPDFService initializer accessibility issue

enum PlannerTab {
    case setup, results, export
}

struct EnhancedAIMealPlannerView: View {
    // Services and state management
    @StateObject private var multiDayService = MultiDayMealPlanningService()
    @StateObject private var languageManager = LanguageManager.shared
    @StateObject private var pdfService = RobustPDFService.shared // Fixed: Use shared instance
    
    // Planning configuration
    @State private var selectedPatient: Patient?
    @State private var planDuration = 3
    @State private var dailyCalories = 2000
    @State private var selectedMealTypes: [MealType] = [.breakfast, .lunch, .dinner]
    @State private var dietaryRestrictions: [String] = []
    @State private var medicalConditions: [String] = []
    
    // Generation state
    @State private var isGenerating = false
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
    
    // Convert FetchedResults to Array for ForEach
    private var patientsArray: [Patient] {
        Array(patients)
    }
    
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
    
    private var setupView: some View {
        VStack(spacing: 24) {
            // Patient Selection
            patientSelectionSection
            
            // Plan Configuration
            planConfigurationSection
            
            // Dietary Information
            dietaryInformationSection
            
            // Generate Button
            generatePlanButton
        }
        .padding()
    }
    
    private var patientSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("👤 Selección de Paciente")
                .font(.headline)
                .foregroundColor(.primary)
            
            if patients.isEmpty {
                Text("No hay pacientes registrados. Crea un paciente primero.")
                    .foregroundColor(.secondary)
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Seleccionar Paciente")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Button(action: {
                        // For now, select the first patient if available
                        if !patients.isEmpty {
                            selectedPatient = patients.first
                        }
                    }) {
                        HStack {
                            Text(selectedPatient != nil ? "\(selectedPatient!.firstName ?? "") \(selectedPatient!.lastName ?? "")" : "Tocar para seleccionar paciente")
                                .foregroundColor(selectedPatient == nil ? .secondary : .primary)
                            Spacer()
                            Image(systemName: "person.circle")
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    private var planConfigurationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("⚙️ Configuración del Plan")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 16) {
                // Plan Duration
                HStack {
                    Text("Duración:")
                    Spacer()
                    Picker("Días", selection: $planDuration) {
                        ForEach(1...14, id: \.self) { day in
                            Text("\(day) día\(day == 1 ? "" : "s")").tag(day)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                
                // Daily Calories
                HStack {
                    Text("Calorías diarias:")
                    Spacer()
                    Text("\(dailyCalories)")
                        .foregroundColor(.secondary)
                }
                
                Slider(value: Binding(
                    get: { Double(dailyCalories) },
                    set: { dailyCalories = Int($0) }
                ), in: 1200...3500, step: 50)
                
                // Meal Types
                VStack(alignment: .leading) {
                    Text("Tipos de comidas:")
                    ForEach(MealType.allCases, id: \.self) { mealType in
                        Toggle(mealType.localizedName, isOn: Binding(
                            get: { selectedMealTypes.contains(mealType) },
                            set: { isSelected in
                                if isSelected {
                                    selectedMealTypes.append(mealType)
                                } else {
                                    selectedMealTypes.removeAll { $0 == mealType }
                                }
                            }
                        ))
                    }
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
        }
    }
    
    private var dietaryInformationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("🥗 Información Dietética")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(spacing: 16) {
                // Dietary Restrictions
                VStack(alignment: .leading) {
                    Text("Restricciones dietéticas:")
                    ForEach(["Vegetariano", "Vegano", "Sin gluten", "Sin lactosa", "Bajo en sodio"], id: \.self) { restriction in
                        Toggle(restriction, isOn: Binding(
                            get: { dietaryRestrictions.contains(restriction) },
                            set: { isSelected in
                                if isSelected {
                                    dietaryRestrictions.append(restriction)
                                } else {
                                    dietaryRestrictions.removeAll { $0 == restriction }
                                }
                            }
                        ))
                    }
                }
                
                // Medical Conditions
                VStack(alignment: .leading) {
                    Text("Condiciones médicas:")
                    ForEach(["Diabetes", "Hipertensión", "Colesterol alto", "Enfermedad cardíaca"], id: \.self) { condition in
                        Toggle(condition, isOn: Binding(
                            get: { medicalConditions.contains(condition) },
                            set: { isSelected in
                                if isSelected {
                                    medicalConditions.append(condition)
                                } else {
                                    medicalConditions.removeAll { $0 == condition }
                                }
                            }
                        ))
                    }
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
        }
    }
    
    private var generatePlanButton: some View {
        Button(action: generateMealPlan) {
            HStack {
                if isGenerating {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Generando plan...")
                } else {
                    Image(systemName: "wand.and.stars")
                    Text("Generar Plan Multi-Día")
                }
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(isGenerating ? Color.gray : Color.blue)
            .cornerRadius(10)
        }
        .disabled(isGenerating || selectedPatient == nil)
    }
    
    // MARK: - Results View
    
    private var resultsView: some View {
        VStack(spacing: 20) {
            if let currentPlan = multiDayService.currentPlan {
                Text("Plan generado para \(currentPlan.numberOfDays) días")
                    .font(.title2)
                    .fontWeight(.bold)
                
                // Daily plans overview
                ForEach(0..<currentPlan.dailyPlans.count, id: \.self) { dayIndex in
                    DailyPlanSummaryView(
                        dayPlan: currentPlan.dailyPlans[dayIndex],
                        dayNumber: dayIndex + 1
                    )
                }
            } else {
                Text("No hay plan generado")
                    .foregroundColor(.secondary)
                    .font(.title2)
                
                Button("Volver a Configuración") {
                    selectedTab = .setup
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }
    
    // MARK: - Export View
    
    private var exportView: some View {
        VStack(spacing: 20) {
            Text("📄 Exportar PDF")
                .font(.title2)
                .fontWeight(.bold)
            
            if multiDayService.currentPlan != nil {
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
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(pdfService.isGenerating ? Color.gray : Color.green)
                    .cornerRadius(10)
                }
                .disabled(pdfService.isGenerating)
                
                if let error = pdfService.lastError {
                    Text("Error: \(error)")
                        .foregroundColor(.red)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                }
            } else {
                Text("Genera un plan primero para exportar PDF")
                    .foregroundColor(.secondary)
                
                Button("Ir a Configuración") {
                    selectedTab = .setup
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }
    
    // MARK: - Actions
    
    private func generateMealPlan() {
        guard let patient = selectedPatient else { return }
        
        isGenerating = true
        
        let configuration = MultiDayPlanConfiguration(
            patientId: patient.id ?? UUID(),
            numberOfDays: planDuration,
            startDate: Date(),
            dailyCalories: dailyCalories,
            dailyProtein: Double(dailyCalories) * 0.15 / 4, // 15% of calories from protein
            dailyCarbs: Double(dailyCalories) * 0.55 / 4,   // 55% of calories from carbs
            dailyFat: Double(dailyCalories) * 0.30 / 9,     // 30% of calories from fat
            mealsPerDay: selectedMealTypes,
            cuisineRotation: ["Mediterranean", "Mexican", "Asian"],
            dietaryRestrictions: dietaryRestrictions,
            medicalConditions: medicalConditions,
            language: .spanish,
            customPortionPreferences: nil
        )
        
        Task {
            do {
                let plan = try await multiDayService.generateMultiDayPlan(configuration: configuration)
                
                await MainActor.run {
                    isGenerating = false
                    showingSuccess = true
                }
            } catch {
                await MainActor.run {
                    isGenerating = false
                    // Handle error
                    print("Error generating plan: \(error)")
                }
            }
        }
    }
    
    private func generatePDF() {
        guard let plan = multiDayService.currentPlan else { return }
        
        Task {
            do {
                let pdfData = try await pdfService.generateMealPlanPDF(
                    from: plan,
                    for: selectedPatient,
                    includeRecipes: true,
                    includeShoppingList: true,
                    includeNutritionAnalysis: true,
                    language: .spanish
                )
                
                await MainActor.run {
                    generatedPDFData = pdfData
                    showingPDFViewer = true
                }
            } catch {
                print("Error generating PDF: \(error)")
            }
        }
    }
}

// MARK: - Supporting Views

struct DailyPlanSummaryView: View {
    let dayPlan: DailyMealPlan
    let dayNumber: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Día \(dayNumber)")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("Calorías: \(Int(dayPlan.dailyNutritionSummary.calories))")
                .foregroundColor(.secondary)
            
            Text("\(dayPlan.meals.count) comidas planificadas")
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

struct PDFViewerSheet: View {
    let pdfData: Data
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Vista previa del PDF")
                    .font(.title2)
                    .padding()
                
                // PDF preview would go here
                Rectangle()
                    .fill(Color.gray.opacity(0.1))
                    .overlay(
                        Text("Vista previa del PDF\n\(pdfData.count) bytes")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                    )
                    .cornerRadius(8)
                    .padding()
                
                Spacer()
            }
            .navigationTitle("PDF Generado")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Cerrar") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}
