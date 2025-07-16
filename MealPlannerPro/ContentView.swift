import SwiftUI
import CoreData

// MARK: - Patient Extensions
extension Patient {
    var safeFullName: String {
        let first = self.firstName ?? ""
        let last = self.lastName ?? ""
        let fullName = "\(first) \(last)".trimmingCharacters(in: .whitespaces)
        return fullName.isEmpty ? "Patient" : fullName
    }
    
    var safeInitials: String {
        let firstInitial = self.firstName?.first?.uppercased() ?? "P"
        let lastInitial = self.lastName?.first?.uppercased() ?? ""
        return "\(firstInitial)\(lastInitial)"
    }
}

// MARK: - Main Content View with Dietician-Focused Workflow
struct ContentView: View {
    @EnvironmentObject var languageManager: LanguageManager
    @EnvironmentObject var foodSelectionManager: ManualFoodSelectionManager
    @EnvironmentObject var pdfService: RobustPDFService
    
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Patient.lastName, ascending: true)],
        animation: .default)
    private var patients: FetchedResults<Patient>
    
    @State private var selectedTab = 0
    @State private var showingSettings = false
    @State private var showingPatientCreation = false
    @State private var selectedPatient: Patient?
    
    var body: some View {
        ZStack {
            // Main content without NavigationView wrapper
            VStack(spacing: 0) {
                // Custom top bar
                customTopBar
                
                // Main content area
                if selectedPatient != nil {
                    // Patient selected - show full functionality
                    patientWorkflowView
                } else {
                    // No patient selected - show patient selection
                    patientSelectionView
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.compatibleWindowBackground)
        }
        .withManualFoodSelection()
        .compatibleSheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .compatibleSheet(isPresented: $showingPatientCreation) {
            PatientCreationView { newPatient in
                selectedPatient = newPatient
            }
        }
    }
    
    // MARK: - Custom Top Bar
    private var customTopBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                // App Title
                HStack(spacing: 8) {
                    Image(systemName: "heart.text.square.fill")
                        .font(.title2)
                        .foregroundColor(.green)
                    
                    Text("MealPlanner Pro")
                        .font(.title2)
                        .fontWeight(.bold)
                }
                
                Spacer()
                
                // Patient Selector
                if let patient = selectedPatient {
                    PatientBadge(patient: patient) {
                        selectedPatient = nil
                    }
                }
                
                // Status Indicators
                HStack(spacing: 12) {
                    if foodSelectionManager.selectionStatus != .noSelectionsNeeded {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.orange)
                                .frame(width: 8, height: 8)
                            Text("Food verification pending")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                    
                    if pdfService.isGenerating {
                        HStack(spacing: 4) {
                            ProgressView()
                                .scaleEffect(0.6)
                            Text("Generating PDF...")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                }
                
                // Language Switcher
                LanguageSwitcherView()
                
                // Settings
                Button(action: { showingSettings = true }) {
                    Image(systemName: "gear")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.compatibleControlBackground)
            
            Divider()
        }
    }
    
    // MARK: - Patient Selection View
    private var patientSelectionView: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // Welcome message
            VStack(spacing: 16) {
                Image(systemName: "person.2.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.blue.opacity(0.8))
                
                Text("Welcome to MealPlanner Pro")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Select or create a patient to begin")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            
            // Patient list or empty state
            if patients.isEmpty {
                VStack(spacing: 20) {
                    Text("No patients yet")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Button(action: { showingPatientCreation = true }) {
                        Label("Create First Patient", systemImage: "person.badge.plus")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                }
            } else {
                VStack(spacing: 16) {
                    Text("Select a Patient")
                        .font(.headline)
                    
                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(patients, id: \.objectID) { patient in
                                PatientCard(patient: patient) {
                                    selectedPatient = patient
                                }
                            }
                        }
                        .padding(.horizontal, 40)
                    }
                    .frame(maxHeight: 400)
                    
                    Button(action: { showingPatientCreation = true }) {
                        Label("New Patient", systemImage: "person.badge.plus")
                            .font(.headline)
                            .foregroundColor(.blue)
                    }
                }
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.compatibleWindowBackground)
    }
    
    // MARK: - Patient Workflow View
    private var patientWorkflowView: some View {
        TabView(selection: $selectedTab) {
            // Patient Dashboard
            PatientDashboardView(patient: selectedPatient!)
                .tabItem {
                    Image(systemName: "heart.text.square")
                    Text("Dashboard")
                }
                .tag(0)
            
            // Food Database & Meal Logging
            FoodDatabaseView(patient: selectedPatient!)
                .tabItem {
                    Image(systemName: "magnifyingglass")
                    Text("Food Database")
                }
                .tag(1)
            
            // Meal History & Analysis
            MealHistoryView(patient: selectedPatient!)
                .tabItem {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                    Text("Analysis")
                }
                .tag(2)
            
            // AI Meal Planning
            AIMealPlanningView(patient: selectedPatient!)
                .tabItem {
                    Image(systemName: "brain")
                    Text("AI Planning")
                }
                .tag(3)
            
            // PDF Export & Reports
            ReportsExportView(patient: selectedPatient!)
                .tabItem {
                    Image(systemName: "doc.text.fill")
                    Text("Reports")
                }
                .tag(4)
        }
    }
}

// MARK: - Patient Badge Component
struct PatientBadge: View {
    let patient: Patient
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "person.circle.fill")
                .foregroundColor(.blue)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Current Patient")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Text(patient.safeFullName)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(20)
    }
}

// MARK: - Patient Card Component
struct PatientCard: View {
    let patient: Patient
    let onSelect: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                // Patient Avatar
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: 60, height: 60)
                    
                    Text(patient.safeInitials)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                }
                
                // Patient Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(patient.safeFullName)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 12) {
                        if let dob = patient.dateOfBirth {
                            Label("\(calculateAge(from: dob)) years", systemImage: "calendar")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        if patient.currentWeight > 0 {
                            Label("\(Int(patient.currentWeight)) kg", systemImage: "scalemass")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .opacity(isHovered ? 1 : 0.5)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isHovered ? Color.blue.opacity(0.05) : Color.compatibleControlBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isHovered ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
    
    private func calculateAge(from date: Date) -> Int {
        Calendar.current.dateComponents([.year], from: date, to: Date()).year ?? 0
    }
}

// MARK: - Dashboard View
struct PatientDashboardView: View {
    let patient: Patient
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Patient Summary Card
                PatientSummaryCard(patient: patient)
                
                // Quick Actions
                QuickActionsGrid(patient: patient)
                
                // Today's Overview
                TodaysNutritionOverview(patient: patient)
                
                // Recent Meals
                RecentMealsCard(patient: patient)
                
                // Nutritional Goals Progress
                NutritionalGoalsCard(patient: patient)
            }
            .padding()
        }
    }
}

// MARK: - Patient Summary Card
struct PatientSummaryCard: View {
    let patient: Patient
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text(patient.safeFullName)
                        .font(.title)
                        .fontWeight(.bold)
                    
                    HStack(spacing: 20) {
                        if let dob = patient.dateOfBirth {
                            Label("\(calculateAge(from: dob)) years", systemImage: "calendar")
                        }
                        
                        Label("\(Int(patient.currentWeight)) kg", systemImage: "scalemass")
                        
                        Label("\(Int(patient.currentHeight)) cm", systemImage: "ruler")
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // BMI Indicator
                VStack(spacing: 4) {
                    Text("BMI")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(String(format: "%.1f", calculateBMI()))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(bmiColor)
                    
                    Text(bmiCategory)
                        .font(.caption)
                        .foregroundColor(bmiColor)
                }
                .padding()
                .background(bmiColor.opacity(0.1))
                .cornerRadius(8)
            }
            
            // Medical Conditions & Dietary Restrictions
            if let conditions = patient.medicalConditions, !conditions.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Medical Conditions")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(conditions)
                        .font(.subheadline)
                }
            }
            
            if let restrictions = patient.dietaryPreferences, !restrictions.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Dietary Restrictions")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(restrictions)
                        .font(.subheadline)
                }
            }
        }
        .padding()
        .background(Color.compatibleControlBackground)
        .cornerRadius(12)
    }
    
    private func calculateAge(from date: Date) -> Int {
        Calendar.current.dateComponents([.year], from: date, to: Date()).year ?? 0
    }
    
    private func calculateBMI() -> Double {
        let heightInMeters = patient.currentHeight / 100
        return patient.currentWeight / (heightInMeters * heightInMeters)
    }
    
    private var bmiCategory: String {
        let bmi = calculateBMI()
        switch bmi {
        case ..<18.5: return "Underweight"
        case 18.5..<25: return "Normal"
        case 25..<30: return "Overweight"
        default: return "Obese"
        }
    }
    
    private var bmiColor: Color {
        let bmi = calculateBMI()
        switch bmi {
        case ..<18.5: return .orange
        case 18.5..<25: return .green
        case 25..<30: return .orange
        default: return .red
        }
    }
}

// MARK: - Quick Actions Grid
struct QuickActionsGrid: View {
    let patient: Patient
    
    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            QuickActionButton(
                icon: "plus.circle.fill",
                title: "Log Meal",
                color: .blue
            ) {
                // Action
            }
            
            QuickActionButton(
                icon: "magnifyingglass",
                title: "Search Food",
                color: .green
            ) {
                // Action
            }
            
            QuickActionButton(
                icon: "brain",
                title: "AI Plan",
                color: .purple
            ) {
                // Action
            }
            
            QuickActionButton(
                icon: "doc.text.fill",
                title: "Export PDF",
                color: .orange
            ) {
                // Action
            }
        }
    }
}

struct QuickActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(color.opacity(0.1))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Placeholder Views
struct TodaysNutritionOverview: View {
    let patient: Patient
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today's Nutrition")
                .font(.headline)
            
            HStack(spacing: 16) {
                NutrientProgressCard(
                    nutrient: "Calories",
                    current: 1250,
                    target: 2000,
                    unit: "kcal",
                    color: .blue
                )
                
                NutrientProgressCard(
                    nutrient: "Protein",
                    current: 65,
                    target: 120,
                    unit: "g",
                    color: .green
                )
                
                NutrientProgressCard(
                    nutrient: "Carbs",
                    current: 180,
                    target: 250,
                    unit: "g",
                    color: .orange
                )
                
                NutrientProgressCard(
                    nutrient: "Fat",
                    current: 45,
                    target: 78,
                    unit: "g",
                    color: .purple
                )
            }
        }
    }
}

struct NutrientProgressCard: View {
    let nutrient: String
    let current: Double
    let target: Double
    let unit: String
    let color: Color
    
    private var progress: Double {
        min(current / target, 1.0)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(nutrient)
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack(alignment: .firstTextBaseline) {
                Text("\(Int(current))")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(color)
                
                Text("/ \(Int(target)) \(unit)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            ProgressView(value: progress)
                .progressViewStyle(LinearProgressViewStyle(tint: color))
                .frame(height: 4)
            
            Text("\(Int(progress * 100))%")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.compatibleControlBackground)
        .cornerRadius(8)
    }
}

struct RecentMealsCard: View {
    let patient: Patient
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Meals")
                    .font(.headline)
                
                Spacer()
                
                Button("View All") {
                    // Action
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            VStack(spacing: 8) {
                RecentMealRow(
                    mealType: "Breakfast",
                    time: "8:30 AM",
                    calories: 420,
                    icon: "sunrise.fill"
                )
                
                RecentMealRow(
                    mealType: "Lunch",
                    time: "1:00 PM",
                    calories: 650,
                    icon: "sun.max.fill"
                )
                
                RecentMealRow(
                    mealType: "Snack",
                    time: "3:30 PM",
                    calories: 180,
                    icon: "leaf.fill"
                )
            }
        }
        .padding()
        .background(Color.compatibleControlBackground)
        .cornerRadius(12)
    }
}

struct RecentMealRow: View {
    let mealType: String
    let time: String
    let calories: Int
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.orange)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(mealType)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(time)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text("\(calories) kcal")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct NutritionalGoalsCard: View {
    let patient: Patient
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Weekly Progress")
                .font(.headline)
            
            // Placeholder for chart
            Rectangle()
                .fill(Color.gray.opacity(0.1))
                .frame(height: 200)
                .overlay(
                    Text("Nutrition Trends Chart")
                        .foregroundColor(.secondary)
                )
                .cornerRadius(8)
        }
        .padding()
        .background(Color.compatibleControlBackground)
        .cornerRadius(12)
    }
}

// MARK: - Food Database View
struct FoodDatabaseView: View {
    let patient: Patient
    @StateObject private var usdaService = USDAFoodService()
    @StateObject private var foodManager: FoodDataManager
    
    init(patient: Patient) {
        self.patient = patient
        let container = PersistenceController.shared.container
        _foodManager = StateObject(wrappedValue: FoodDataManager(container: container))
    }
    
    var body: some View {
        VStack {
            Text("USDA Food Database Search")
                .font(.title)
            
            // Search interface
            Text("Search and verify foods with USDA database")
                .foregroundColor(.secondary)
            
            // Implement search UI
        }
        .padding()
    }
}

// MARK: - Meal History View
struct MealHistoryView: View {
    let patient: Patient
    
    var body: some View {
        VStack {
            Text("Meal History & Nutritional Analysis")
                .font(.title)
            
            Text("Track and analyze patient's dietary intake")
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

// MARK: - AI Meal Planning View
struct AIMealPlanningView: View {
    let patient: Patient
    
    var body: some View {
        VStack {
            Text("AI-Powered Meal Planning")
                .font(.title)
            
            Text("Generate creative, culturally-adapted meal plans")
                .foregroundColor(.secondary)
            
            // Use existing AI meal planner
            AIMealPlannerView()
        }
    }
}

// MARK: - Reports Export View
struct ReportsExportView: View {
    let patient: Patient
    @StateObject private var pdfService = RobustPDFService.shared
    
    var body: some View {
        VStack {
            Text("Reports & PDF Export")
                .font(.title)
            
            Text("Generate beautiful bilingual PDFs for patients")
                .foregroundColor(.secondary)
            
            Button("Generate Comprehensive PDF Report") {
                // Generate PDF
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

// MARK: - Patient Creation View
struct PatientCreationView: View {
    let onSave: (Patient) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var dateOfBirth = Date()
    @State private var gender = "Male"
    @State private var weight: Double = 70
    @State private var height: Double = 170
    @State private var activityLevel = "Moderately Active"
    @State private var medicalConditions = ""
    @State private var dietaryRestrictions = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("Basic Information") {
                    TextField("First Name", text: $firstName)
                    TextField("Last Name", text: $lastName)
                    DatePicker("Date of Birth", selection: $dateOfBirth, displayedComponents: .date)
                    Picker("Gender", selection: $gender) {
                        Text("Male").tag("Male")
                        Text("Female").tag("Female")
                        Text("Other").tag("Other")
                    }
                }
                
                Section("Physical Measurements") {
                    HStack {
                        Text("Weight")
                        Spacer()
                        TextField("Weight", value: $weight, format: .number)
                            .frame(width: 80)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        Text("kg")
                    }
                    
                    HStack {
                        Text("Height")
                        Spacer()
                        TextField("Height", value: $height, format: .number)
                            .frame(width: 80)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        Text("cm")
                    }
                }
                
                Section("Activity & Health") {
                    Picker("Activity Level", selection: $activityLevel) {
                        Text("Sedentary").tag("Sedentary")
                        Text("Lightly Active").tag("Lightly Active")
                        Text("Moderately Active").tag("Moderately Active")
                        Text("Very Active").tag("Very Active")
                        Text("Extremely Active").tag("Extremely Active")
                    }
                    
                    TextField("Medical Conditions", text: $medicalConditions)
                    TextField("Dietary Restrictions", text: $dietaryRestrictions)
                }
            }
            .navigationTitle("New Patient")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        savePatient()
                    }
                    .disabled(firstName.isEmpty || lastName.isEmpty)
                }
            }
        }
    }
    
    private func savePatient() {
        let patientManager = PatientManager(container: PersistenceController.shared.container)
        
        let newPatient = patientManager.createNewPatient(
            firstName: firstName,
            lastName: lastName,
            dateOfBirth: dateOfBirth,
            gender: gender,
            height: height,
            weight: weight,
            activityLevel: activityLevel,
            medicalConditions: medicalConditions.isEmpty ? [] : [medicalConditions],
            allergies: [],
            dietaryPreferences: dietaryRestrictions.isEmpty ? [] : [dietaryRestrictions]
        )
        
        onSave(newPatient)
        dismiss()
    }
}

// MARK: - Settings View Update
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var languageManager = LanguageManager.shared
    
    var body: some View {
        NavigationView {
            Form {
                Section("Language") {
                    Picker("App Language", selection: $languageManager.currentLanguage) {
                        ForEach(PlanLanguage.allCases, id: \.self) { language in
                            HStack {
                                Text(language.flag)
                                Text(language.displayName)
                            }
                            .tag(language)
                        }
                    }
                }
                
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Developer")
                        Spacer()
                        Text("Diego Sierra")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
