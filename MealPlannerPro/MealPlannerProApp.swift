// Final Integration Steps and Testing Guide
import SwiftUI
import CoreData

// MARK: - Step 1: Update your main MealPlannerProApp.swift
@main
struct MealPlannerProApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            UpdatedContentView() // Use the new enhanced ContentView
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .preferredColorScheme(.light) // Ensure good PDF generation
        }
        .windowStyle(.automatic)
        .windowResizability(.contentSize)
    }
}

// MARK: - Step 2: Enhanced Error Handling and Logging
class MealPlannerLogger {
    static let shared = MealPlannerLogger()
    private init() {}
    
    enum LogLevel: String {
        case debug = "🔍 DEBUG"
        case info = "ℹ️ INFO"
        case warning = "⚠️ WARNING"
        case error = "❌ ERROR"
        case success = "✅ SUCCESS"
    }
    
    func log(_ message: String, level: LogLevel = .info, function: String = #function, file: String = #file, line: Int = #line) {
        let fileName = (file as NSString).lastPathComponent
        let timestamp = DateFormatter.logFormatter.string(from: Date())
        
        print("[\(timestamp)] \(level.rawValue) [\(fileName):\(line)] \(function) - \(message)")
    }
}

extension DateFormatter {
    static let logFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter
    }()
}

// MARK: - Step 3: Performance Monitoring
class PerformanceMonitor {
    static let shared = PerformanceMonitor()
    private var startTimes: [String: Date] = [:]
    
    func startTimer(for operation: String) {
        startTimes[operation] = Date()
        MealPlannerLogger.shared.log("Started: \(operation)", level: .debug)
    }
    
    func endTimer(for operation: String) {
        guard let startTime = startTimes[operation] else { return }
        let duration = Date().timeIntervalSince(startTime)
        MealPlannerLogger.shared.log("Completed: \(operation) in \(String(format: "%.2f", duration))s", level: .success)
        startTimes.removeValue(forKey: operation)
    }
}

// MARK: - Step 4: Enhanced Testing Framework
class MealPlannerTester {
    static let shared = MealPlannerTester()
    
    // Test USDA ingredient separation
    func testIngredientSeparation() async {
        let testCases = [
            "Spinach, sautéed in olive oil",
            "Chicken breast, grilled with herbs",
            "Rice with vegetables",
            "Salmon, baked with lemon"
        ]
        
        MealPlannerLogger.shared.log("Testing ingredient separation...", level: .info)
        
        for testCase in testCases {
            let separatedIngredients = separateCompoundFood(testCase)
            MealPlannerLogger.shared.log("'\(testCase)' → \(separatedIngredients)", level: .debug)
        }
    }
    
    // Test Spanish localization
    func testSpanishLocalization() {
        let testFoods = ["chicken breast", "salmon", "spinach", "olive oil", "brown rice"]
        
        MealPlannerLogger.shared.log("Testing Spanish localization...", level: .info)
        
        for food in testFoods {
            let spanish = SpanishMealPlanningLocalizer.translateFoodName(food)
            MealPlannerLogger.shared.log("'\(food)' → '\(spanish)'", level: .debug)
        }
    }
    
    // Test PDF generation
    func testPDFGeneration() async {
        // Create a sample plan for testing
        let samplePlan = createSampleMealPlan()
        let pdfService = MealPlanPDFService()
        
        do {
            PerformanceMonitor.shared.startTimer(for: "PDF Generation")
            let pdfData = try await pdfService.generateComprehensiveMealPlanPDF(
                multiDayPlan: samplePlan,
                patient: nil,
                includeRecipes: true,
                includeShoppingList: true,
                includeNutritionAnalysis: true,
                language: .spanish
            )
            PerformanceMonitor.shared.endTimer(for: "PDF Generation")
            
            MealPlannerLogger.shared.log("PDF generated successfully: \(pdfData.count) bytes", level: .success)
        } catch {
            MealPlannerLogger.shared.log("PDF generation failed: \(error)", level: .error)
        }
    }
    
    // Test multi-day plan generation
    func testMultiDayPlanGeneration() async {
        let service = MultiDayMealPlanningService()
        
        let request = MultiDayPlanRequest(
            patientId: nil,
            numberOfDays: 3,
            startDate: Date(),
            dailyCalories: 2000,
            dailyProtein: 150,
            dailyCarbs: 250,
            dailyFat: 78,
            mealsPerDay: [.breakfast, .lunch, .dinner],
            cuisineRotation: ["Mediterráneo", "Mexicano"],
            dietaryRestrictions: [],
            medicalConditions: [],
            language: .spanish,
            customPortionPreferences: nil
        )
        
        do {
            PerformanceMonitor.shared.startTimer(for: "Multi-day Plan Generation")
            let plan = try await service.generateMultiDayPlan(request: request)
            PerformanceMonitor.shared.endTimer(for: "Multi-day Plan Generation")
            
            MealPlannerLogger.shared.log("Multi-day plan generated: \(plan.numberOfDays) days, \(plan.dailyPlans.reduce(0) { $0 + $1.meals.count }) meals", level: .success)
        } catch {
            MealPlannerLogger.shared.log("Multi-day plan generation failed: \(error)", level: .error)
        }
    }
    
    private func separateCompoundFood(_ input: String) -> [String] {
        // Implement your compound food separation logic here
        // This is a simplified version for testing
        if input.contains("sautéed in") {
            let base = input.components(separatedBy: ", sautéed in").first ?? input
            return [base, "olive oil"]
        }
        return [input]
    }
    
    private func createSampleMealPlan() -> MultiDayMealPlan {
        // Create a sample plan for testing
        let sampleFood = VerifiedSuggestedFood(
            originalAISuggestion: SuggestedFood(
                name: "Pollo a la parrilla",
                portionDescription: "150g",
                gramWeight: 150,
                estimatedNutrition: EstimatedNutrition(calories: 250, protein: 30, carbs: 0, fat: 12)
            ),
            matchedUSDAFood: nil,
            verifiedNutrition: EstimatedNutrition(calories: 250, protein: 30, carbs: 0, fat: 12),
            matchConfidence: 0.95,
            isVerified: true,
            verificationNotes: "Sample food for testing"
        )
        
        let sampleMeal = VerifiedMealPlanSuggestion(
            originalAISuggestion: MealPlanSuggestion(
                id: UUID(),
                mealName: "Almuerzo Mediterráneo",
                mealType: .lunch,
                suggestedFoods: [sampleFood.originalAISuggestion],
                totalNutrition: EstimatedNutrition(calories: 250, protein: 30, carbs: 0, fat: 12),
                preparationNotes: "Cocinar a fuego medio hasta que esté bien cocido",
                nutritionistNotes: "Rica en proteínas de alta calidad",
                targetRequest: MealPlanRequest(
                    targetCalories: 250,
                    targetProtein: 30,
                    targetCarbs: 0,
                    targetFat: 12,
                    mealType: .lunch,
                    cuisinePreference: "Mediterráneo",
                    dietaryRestrictions: [],
                    medicalConditions: [],
                    patientId: nil
                )
            ),
            verifiedFoods: [sampleFood],
            verifiedTotalNutrition: EstimatedNutrition(calories: 250, protein: 30, carbs: 0, fat: 12),
            overallAccuracy: 0.95,
            detailedAccuracy: DetailedAccuracy(overall: 0.95, calories: 0.95, protein: 0.95, carbs: 0.95, fat: 0.95),
            verificationNotes: "Sample meal for testing"
        )
        
        let dailyPlan = DailyMealPlan(
            date: Date(),
            meals: [sampleMeal],
            dailyNutritionSummary: DailyNutritionSummary(
                calories: 250,
                protein: 30,
                carbs: 0,
                fat: 12,
                averageAccuracy: 0.95
            )
        )
        
        return MultiDayMealPlan(
            id: UUID(),
            patientId: nil,
            startDate: Date(),
            numberOfDays: 1,
            dailyPlans: [dailyPlan],
            totalNutritionSummary: MultiDayNutritionSummary(
                totalCalories: 250,
                totalProtein: 30,
                totalCarbs: 0,
                totalFat: 12,
                averageDailyCalories: 250,
                averageDailyProtein: 30,
                averageDailyCarbs: 0,
                averageDailyFat: 12,
                overallAccuracy: 0.95
            ),
            language: .spanish,
            generatedDate: Date()
        )
    }
}

// MARK: - Step 5: User Onboarding and Help System
struct OnboardingView: View {
    @Binding var showingOnboarding: Bool
    @State private var currentPage = 0
    
    private let onboardingPages = [
        OnboardingPage(
            title: "¡Bienvenido a MealPlannerPro!",
            description: "Tu asistente nutricional con verificación USDA",
            imageName: "brain.head.profile.fill",
            color: .blue
        ),
        OnboardingPage(
            title: "Búsqueda Inteligente",
            description: "Busca alimentos complejos como 'pollo salteado con espinacas' y automáticamente los separamos en ingredientes individuales",
            imageName: "magnifyingglass",
            color: .green
        ),
        OnboardingPage(
            title: "Planes Multi-Día",
            description: "Genera planes de 1 a 14 días con variedad automática y rotación de cocinas",
            imageName: "calendar.badge.plus",
            color: .orange
        ),
        OnboardingPage(
            title: "Recetas en Español",
            description: "Obtén recetas detalladas paso a paso en español, adaptadas culturalmente",
            imageName: "doc.text.fill",
            color: .purple
        ),
        OnboardingPage(
            title: "PDFs Profesionales",
            description: "Exporta planes completos con recetas, listas de compras y análisis nutricional",
            imageName: "doc.badge.plus",
            color: .red
        )
    ]
    
    var body: some View {
        VStack {
            TabView(selection: $currentPage) {
                ForEach(Array(onboardingPages.enumerated()), id: \.offset) { index, page in
                    OnboardingPageView(page: page)
                        .tag(index)
                }
            }
            .tabViewStyle(PageTabViewStyle())
            .frame(height: 400)
            
            HStack {
                if currentPage > 0 {
                    Button("Anterior") {
                        withAnimation {
                            currentPage -= 1
                        }
                    }
                    .buttonStyle(.bordered)
                }
                
                Spacer()
                
                if currentPage < onboardingPages.count - 1 {
                    Button("Siguiente") {
                        withAnimation {
                            currentPage += 1
                        }
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("¡Comenzar!") {
                        showingOnboarding = false
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
        }
        .padding()
    }
}

struct OnboardingPage {
    let title: String
    let description: String
    let imageName: String
    let color: Color
}

struct OnboardingPageView: View {
    let page: OnboardingPage
    
    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: page.imageName)
                .font(.system(size: 80))
                .foregroundColor(page.color)
            
            Text(page.title)
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            Text(page.description)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
        }
        .padding()
    }
}

// MARK: - Step 6: Settings and Configuration
struct SettingsView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @AppStorage("preferredLanguage") private var preferredLanguage = "spanish"
    @AppStorage("defaultPortionSize") private var defaultPortionSize = "medium"
    @AppStorage("enableDebugMode") private var enableDebugMode = false
    
    var body: some View {
        Form {
            Section("Preferencias Generales") {
                Picker("Idioma", selection: $preferredLanguage) {
                    Text("Español").tag("spanish")
                    Text("English").tag("english")
                }
                
                Picker("Tamaño de Porción por Defecto", selection: $defaultPortionSize) {
                    Text("Extra Pequeña").tag("extra_small")
                    Text("Pequeña").tag("small")
                    Text("Media").tag("medium")
                    Text("Grande").tag("large")
                    Text("Extra Grande").tag("extra_large")
                }
            }
            
            Section("Funciones Avanzadas") {
                Toggle("Modo Debug", isOn: $enableDebugMode)
                
                Button("Ejecutar Pruebas") {
                    Task {
                        await runAllTests()
                    }
                }
                .buttonStyle(.borderedProminent)
                
                Button("Mostrar Tutorial Nuevamente") {
                    hasSeenOnboarding = false
                }
            }
        }
        .navigationTitle("Configuración")
    }
    
    private func runAllTests() async {
        let tester = MealPlannerTester.shared
        await tester.testIngredientSeparation()
        tester.testSpanishLocalization()
        await tester.testPDFGeneration()
        await tester.testMultiDayPlanGeneration()
    }
}
