import SwiftUI
import Charts

// MARK: - Nutrition Analysis View (Fixed)
struct NutritionAnalysisView: View {
    let food: Food
    let patient: Patient?
    
    @State private var selectedAnalysisType: AnalysisType = .macronutrients
    
    // Extract nutrients from food
    private var nutrients: ComprehensiveNutrients {
        // For now, we'll use the basic values from Food entity
        var nutritionData = ComprehensiveNutrients()
        nutritionData.energy = food.calories
        nutritionData.protein = food.protein
        nutritionData.carbohydrate = food.carbs
        nutritionData.totalFat = food.fat
        nutritionData.fiber = food.fiber
        nutritionData.sodium = food.sodium
        return nutritionData
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                // Header
                VStack {
                    Text("🔬 Complete Nutrition Analysis")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text(food.name ?? "Unknown Food")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    if let brand = food.brandOwner {
                        Text("Brand: \(brand)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Analysis Type Selector
                Picker("Analysis Type", selection: $selectedAnalysisType) {
                    ForEach(AnalysisType.allCases, id: \.self) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                // Main Chart
                analysisViewForType(selectedAnalysisType)
                    .frame(height: 400)
                    .padding()
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(15)
                
                // Detailed Nutrient Cards
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 20) {
                    MacronutrientInfoCard(nutrients: nutrients)
                    BasicNutrientInfoCard(nutrients: nutrients)
                }
                
                // Patient Goals Comparison (if patient selected)
                if let patient = patient,
                   let goalsJSON = patient.nutritionalGoals,
                   let goals = NutritionalGoals.fromJSONString(goalsJSON) {
                    PatientGoalsSection(nutrients: nutrients, goals: goals)
                }
            }
            .padding()
        }
        .navigationTitle("Nutrition Analysis")
    }
    
    @ViewBuilder
    private func analysisViewForType(_ type: AnalysisType) -> some View {
        switch type {
        case .macronutrients:
            MacronutrientPieChartView(nutrients: nutrients)
        case .vitamins:
            BasicVitaminView(nutrients: nutrients)
        case .minerals:
            BasicMineralView(nutrients: nutrients)
        case .comparison:
            if let patient = patient,
               let goalsJSON = patient.nutritionalGoals,
               let goals = NutritionalGoals.fromJSONString(goalsJSON) {
                GoalsComparisonChartView(nutrients: nutrients, goals: goals)
            } else {
                Text("Select a patient to see goals comparison")
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Analysis Types (Renamed to avoid conflicts)
enum AnalysisType: CaseIterable {
    case macronutrients, vitamins, minerals, comparison
    
    var displayName: String {
        switch self {
        case .macronutrients: return "Macros"
        case .vitamins: return "Vitamins"
        case .minerals: return "Minerals"
        case .comparison: return "vs Goals"
        }
    }
}

// MARK: - Macronutrient Pie Chart (Simplified)
struct MacronutrientPieChartView: View {
    let nutrients: ComprehensiveNutrients
    
    private var macroChartData: [MacroChartData] {
        [
            MacroChartData(name: "Protein", value: nutrients.protein * 4, color: .green),
            MacroChartData(name: "Carbohydrates", value: nutrients.carbohydrate * 4, color: .orange),
            MacroChartData(name: "Fat", value: nutrients.totalFat * 9, color: .purple)
        ].filter { $0.value > 0 }
    }
    
    var body: some View {
        VStack {
            Text("Macronutrient Distribution")
                .font(.headline)
                .padding(.bottom)
            
            Chart(macroChartData, id: \.name) { macro in
                SectorMark(
                    angle: .value("Calories", macro.value),
                    innerRadius: .ratio(0.4),
                    angularInset: 1.5
                )
                .foregroundStyle(macro.color)
                .opacity(0.8)
            }
            .frame(height: 250)
            
            // Legend
            HStack(spacing: 20) {
                ForEach(macroChartData, id: \.name) { macro in
                    HStack {
                        Circle()
                            .fill(macro.color)
                            .frame(width: 12, height: 12)
                        
                        VStack(alignment: .leading) {
                            Text(macro.name)
                                .font(.caption)
                                .fontWeight(.medium)
                            Text("\(Int(macro.value)) cal")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
    }
}

struct MacroChartData {
    let name: String
    let value: Double
    let color: Color
}

// MARK: - Basic Vitamin View (Simplified)
struct BasicVitaminView: View {
    let nutrients: ComprehensiveNutrients
    
    var body: some View {
        VStack {
            Text("Vitamin Analysis")
                .font(.headline)
                .padding(.bottom)
            
            Text("Comprehensive vitamin analysis coming soon!")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding()
            
            // Show basic vitamin info if available
            VStack(spacing: 10) {
                if nutrients.vitaminC > 0 {
                    HStack {
                        Text("Vitamin C")
                        Spacer()
                        Text("\(String(format: "%.1f", nutrients.vitaminC)) mg")
                    }
                }
                if nutrients.vitaminA > 0 {
                    HStack {
                        Text("Vitamin A")
                        Spacer()
                        Text("\(String(format: "%.1f", nutrients.vitaminA)) mcg")
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - Basic Mineral View (Simplified)
struct BasicMineralView: View {
    let nutrients: ComprehensiveNutrients
    
    var body: some View {
        VStack {
            Text("Mineral Analysis")
                .font(.headline)
                .padding(.bottom)
            
            VStack(spacing: 10) {
                HStack {
                    Text("Sodium")
                    Spacer()
                    Text("\(String(format: "%.1f", nutrients.sodium)) mg")
                }
                
                if nutrients.calcium > 0 {
                    HStack {
                        Text("Calcium")
                        Spacer()
                        Text("\(String(format: "%.1f", nutrients.calcium)) mg")
                    }
                }
                
                if nutrients.iron > 0 {
                    HStack {
                        Text("Iron")
                        Spacer()
                        Text("\(String(format: "%.1f", nutrients.iron)) mg")
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - Goals Comparison Chart (Simplified)
struct GoalsComparisonChartView: View {
    let nutrients: ComprehensiveNutrients
    let goals: NutritionalGoals
    
    var body: some View {
        VStack {
            Text("vs Patient Goals")
                .font(.headline)
                .padding(.bottom)
            
            VStack(spacing: 15) {
                GoalComparisonRow(
                    name: "Calories",
                    current: nutrients.energy,
                    goal: goals.calories,
                    unit: "kcal"
                )
                
                GoalComparisonRow(
                    name: "Protein",
                    current: nutrients.protein,
                    goal: goals.protein,
                    unit: "g"
                )
                
                GoalComparisonRow(
                    name: "Carbs",
                    current: nutrients.carbohydrate,
                    goal: goals.carbohydrates,
                    unit: "g"
                )
                
                GoalComparisonRow(
                    name: "Fat",
                    current: nutrients.totalFat,
                    goal: goals.fat,
                    unit: "g"
                )
            }
            .padding()
        }
    }
}

struct GoalComparisonRow: View {
    let name: String
    let current: Double
    let goal: Double
    let unit: String
    
    private var percentage: Double {
        return goal > 0 ? (current / goal) * 100 : 0
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(name)
                    .font(.caption)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text("\(String(format: "%.1f", current)) / \(String(format: "%.1f", goal)) \(unit)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            ProgressView(value: min(percentage / 100, 1.0))
                .progressViewStyle(LinearProgressViewStyle(tint: percentage >= 100 ? .green : .orange))
            
            Text("\(Int(percentage))% of goal")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Professional Nutrient Cards (Simplified)
struct MacronutrientInfoCard: View {
    let nutrients: ComprehensiveNutrients
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Macronutrients")
                .font(.headline)
                .foregroundColor(.blue)
            
            VStack(spacing: 8) {
                NutrientInfoRow(name: "Calories", value: nutrients.energy, unit: "kcal")
                NutrientInfoRow(name: "Protein", value: nutrients.protein, unit: "g")
                NutrientInfoRow(name: "Total Fat", value: nutrients.totalFat, unit: "g")
                NutrientInfoRow(name: "Carbohydrates", value: nutrients.carbohydrate, unit: "g")
                NutrientInfoRow(name: "Dietary Fiber", value: nutrients.fiber, unit: "g")
                NutrientInfoRow(name: "Sugars", value: nutrients.sugars, unit: "g")
            }
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .cornerRadius(12)
    }
}

struct BasicNutrientInfoCard: View {
    let nutrients: ComprehensiveNutrients
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Other Nutrients")
                .font(.headline)
                .foregroundColor(.green)
            
            VStack(spacing: 8) {
                NutrientInfoRow(name: "Sodium", value: nutrients.sodium, unit: "mg")
                NutrientInfoRow(name: "Vitamin C", value: nutrients.vitaminC, unit: "mg")
                NutrientInfoRow(name: "Calcium", value: nutrients.calcium, unit: "mg")
                NutrientInfoRow(name: "Iron", value: nutrients.iron, unit: "mg")
                NutrientInfoRow(name: "Vitamin A", value: nutrients.vitaminA, unit: "mcg")
                NutrientInfoRow(name: "Vitamin D", value: nutrients.vitaminD, unit: "mcg")
            }
        }
        .padding()
        .background(Color.green.opacity(0.05))
        .cornerRadius(12)
    }
}

struct NutrientInfoRow: View {
    let name: String
    let value: Double
    let unit: String
    
    var body: some View {
        HStack {
            Text(name)
                .font(.caption)
                .foregroundColor(.primary)
            
            Spacer()
            
            Text(value > 0 ? "\(String(format: "%.1f", value)) \(unit)" : "—")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(value > 0 ? .primary : .secondary)
        }
    }
}

// MARK: - Patient Goals Section
struct PatientGoalsSection: View {
    let nutrients: ComprehensiveNutrients
    let goals: NutritionalGoals
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("🎯 Patient Goals Comparison")
                .font(.title2)
                .fontWeight(.bold)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 15) {
                GoalProgressCircle(
                    name: "Calories",
                    current: nutrients.energy,
                    goal: goals.calories,
                    unit: "kcal",
                    color: .blue
                )
                GoalProgressCircle(
                    name: "Protein",
                    current: nutrients.protein,
                    goal: goals.protein,
                    unit: "g",
                    color: .green
                )
                GoalProgressCircle(
                    name: "Carbs",
                    current: nutrients.carbohydrate,
                    goal: goals.carbohydrates,
                    unit: "g",
                    color: .orange
                )
                GoalProgressCircle(
                    name: "Fat",
                    current: nutrients.totalFat,
                    goal: goals.fat,
                    unit: "g",
                    color: .purple
                )
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(15)
    }
}

struct GoalProgressCircle: View {
    let name: String
    let current: Double
    let goal: Double
    let unit: String
    let color: Color
    
    private var percentage: Double {
        return goal > 0 ? (current / goal) * 100 : 0
    }
    
    var body: some View {
        VStack(spacing: 8) {
            Text(name)
                .font(.caption)
                .fontWeight(.medium)
            
            ZStack {
                Circle()
                    .stroke(color.opacity(0.2), lineWidth: 8)
                
                Circle()
                    .trim(from: 0, to: min(percentage / 100, 1.0))
                    .stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 1.0), value: percentage)
                
                VStack {
                    Text("\(Int(percentage))%")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(color)
                    
                    Text("\(String(format: "%.0f", current))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 60, height: 60)
            
            Text("Goal: \(String(format: "%.0f", goal)) \(unit)")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(10)
        .shadow(color: .gray.opacity(0.2), radius: 2, x: 0, y: 1)
    }
}
