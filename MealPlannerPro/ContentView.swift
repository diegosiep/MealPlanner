import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var usdaService = USDAFoodService()
    @StateObject private var foodManager: FoodDataManager
    
    @State private var selectedTab = 0
    
    init() {
        let container = PersistenceController.shared.container
        _foodManager = StateObject(wrappedValue: FoodDataManager(container: container))
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Food Search Tab
            FoodSearchView(usdaService: usdaService, foodManager: foodManager)
                .tabItem {
                    Image(systemName: "magnifyingglass")
                    Text("Search Foods")
                }
                .tag(0)
            
            // My Foods Tab
            SavedFoodsView(foodManager: foodManager)
                .tabItem {
                    Image(systemName: "heart.fill")
                    Text("My Foods")
                }
                .tag(1)
            
            // Meal Planning Tab
            MealPlanningView()
                .tabItem {
                    Image(systemName: "calendar")
                    Text("Meal Plans")
                }
                .tag(2)
            
            // AI Assistant Tab
            AIMealPlannerView()
                .tabItem {
                    Image(systemName: "brain.head.profile")
                    Text("AI Assistant")
                }
                .tag(3)
        }
        .frame(minWidth: 800, minHeight: 600)
    }
}

// MARK: - Food Search View
struct FoodSearchView: View {
    @ObservedObject var usdaService: USDAFoodService
    @ObservedObject var foodManager: FoodDataManager
    
    @State private var searchText = ""
    @State private var foods: [USDAFood] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack {
                Text("🔍 Food Database Search")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Search the USDA database for nutritional information")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            
            // Search Bar
            HStack {
                TextField("Search for any food (e.g., 'salmon', 'quinoa', 'Greek yogurt')", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onSubmit {
                        Task { await searchFoods() }
                    }
                
                Button("Search") {
                    Task { await searchFoods() }
                }
                .disabled(isLoading || searchText.isEmpty)
                .buttonStyle(.borderedProminent)
            }
            .padding()
            
            // Status
            if isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Searching USDA database...")
                }
            }
            
            if let error = errorMessage {
                Text("Error: \(error)")
                    .foregroundColor(.red)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
            }
            
            // Results
            if !foods.isEmpty {
                VStack {
                    Text("Found \(foods.count) foods:")
                        .font(.headline)
                    
                    List(foods) { food in
                        FoodRowView(food: food, foodManager: foodManager)
                    }
                }
            }
        }
        .padding()
    }
    
    private func searchFoods() async {
        isLoading = true
        errorMessage = nil
        foods = []
        
        do {
            let searchResults = try await usdaService.searchFoods(query: searchText)
            foods = searchResults
            
            if foods.isEmpty {
                errorMessage = "No foods found for '\(searchText)'. Try a more general term."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
}

// MARK: - Updated Food Row View (Fixed)
struct FoodRowView: View {
    let food: USDAFood
    @ObservedObject var foodManager: FoodDataManager
    
    @State private var showingDetail = false
    @State private var isSaved = false
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                Text(food.description)
                    .font(.headline)
                    .lineLimit(2)
                
                // Nutrition summary
                HStack {
                    NutrientBadge(value: Int(food.calories), unit: "cal", color: .blue)
                    NutrientBadge(value: Int(food.protein), unit: "g protein", color: .green)
                    NutrientBadge(value: Int(food.carbs), unit: "g carbs", color: .orange)
                    NutrientBadge(value: Int(food.fat), unit: "g fat", color: .purple)
                }
                
                if let brand = food.brandOwner {
                    Text("Brand: \(brand)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Action buttons
            VStack {
                Button(action: { showingDetail = true }) {
                    Image(systemName: "info.circle")
                        .font(.title2)
                }
                .buttonStyle(.borderless)
                
                Button(action: { saveFood() }) {
                    Image(systemName: isSaved ? "heart.fill" : "heart")
                        .font(.title2)
                        .foregroundColor(isSaved ? .red : .gray)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.vertical, 4)
        .sheet(isPresented: $showingDetail) {
            USDAFoodDetailView(food: food) // Changed this to use USDA food
        }
    }
    
    private func saveFood() {
        foodManager.saveFood(from: food)
        isSaved = true
        
        // Visual feedback
        withAnimation(.easeInOut(duration: 0.3)) {
            // You could add some visual feedback here
        }
    }
}

// MARK: - Updated Food Detail View
struct FoodDetailView: View {
    let food: Food
    @State private var selectedPatient: Patient?
    
    var body: some View {
        NavigationView {
            VStack {
                Text("📊 Detailed Nutrition")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text(food.name ?? "Unknown Food")
                    .font(.headline)
                    .padding()
                
                // Add button to open nutrition analysis
                NavigationLink(destination: NutritionAnalysisView(food: food, patient: selectedPatient)) {
                    Text("Open Complete Analysis")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                .padding()
                
                Spacer()
            }
            .padding()
        }
        .frame(minWidth: 500, minHeight: 400)
    }
}

// MARK: - Nutrient Badge
struct NutrientBadge: View {
    let value: Int
    let unit: String
    let color: Color
    
    var body: some View {
        Text("\(value) \(unit)")
            .font(.caption)
            .padding(4)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .cornerRadius(4)
    }
}

// MARK: - Saved Foods View
struct SavedFoodsView: View {
    @ObservedObject var foodManager: FoodDataManager
    @State private var savedFoods: [Food] = []
    @State private var searchText = ""
    
    var filteredFoods: [Food] {
        if searchText.isEmpty {
            return savedFoods
        } else {
            return savedFoods.filter { food in
                food.name?.lowercased().contains(searchText.lowercased()) ?? false
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack {
                Text("💖 My Food Library")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Your personal collection of saved foods")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            
            // Stats
            HStack(spacing: 30) {
                StatCard(title: "Total Foods", value: "\(savedFoods.count)", color: .blue)
                StatCard(title: "This Week", value: "\(foodsThisWeek)", color: .green)
                StatCard(title: "Favorites", value: "\(savedFoods.count)", color: .red)
            }
            .padding()
            
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                
                TextField("Search your saved foods...", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            .padding(.horizontal)
            
            // Foods list
            if filteredFoods.isEmpty {
                ContentUnavailableView(
                    "No saved foods yet",
                    systemImage: "heart",
                    description: Text("Start searching for foods and save them to build your library!")
                )
            } else {
                List(filteredFoods, id: \.objectID) { food in
                    SavedFoodRowView(food: food, foodManager: foodManager)
                }
            }
        }
        .padding()
        .onAppear {
            refreshSavedFoods()
        }
    }
    
    private var foodsThisWeek: Int {
        let oneWeekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return savedFoods.filter { food in
            food.dateAdded ?? Date.distantPast > oneWeekAgo
        }.count
    }
    
    private func refreshSavedFoods() {
        savedFoods = foodManager.getSavedFoods()
    }
}

// MARK: - Stat Card
struct StatCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack {
            Text(value)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(width: 80)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Saved Food Row
struct SavedFoodRowView: View {
    let food: Food
    @ObservedObject var foodManager: FoodDataManager
    @State private var showingDetail = false
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                Text(food.name ?? "Unknown Food")
                    .font(.headline)
                    .lineLimit(2)
                
                // Nutrition summary
                HStack {
                    NutrientBadge(value: Int(food.calories), unit: "cal", color: .blue)
                    NutrientBadge(value: Int(food.protein), unit: "g protein", color: .green)
                    NutrientBadge(value: Int(food.carbs), unit: "g carbs", color: .orange)
                    NutrientBadge(value: Int(food.fat), unit: "g fat", color: .purple)
                }
                
                if let brand = food.brandOwner {
                    Text("Brand: \(brand)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text("Added \(formatDate(food.dateAdded))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Action buttons
            VStack(spacing: 10) {
                Button(action: { showingDetail = true }) {
                    Image(systemName: "info.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                .buttonStyle(.borderless)
                
                Button(action: { addToCurrentMeal() }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.green)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.vertical, 4)
        .sheet(isPresented: $showingDetail) {
            SavedFoodDetailView(food: food)
        }
    }
    
    private func formatDate(_ date: Date?) -> String {
        guard let date = date else { return "Unknown" }
        let formatter = RelativeDateTimeFormatter()
        formatter.dateTimeStyle = .named
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    private func addToCurrentMeal() {
        // We'll implement this when we build meal creation
        print("Adding \(food.name ?? "food") to meal!")
    }
}

// MARK: - Saved Food Detail View (for Core Data foods)
struct SavedFoodDetailView: View {
    let food: Food // This is the Core Data entity
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading) {
                        Text(food.name ?? "Unknown Food")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        if let brand = food.brandOwner {
                            Text("by \(brand)")
                                .font(.headline)
                                .foregroundColor(.secondary)
                        }
                        
                        Text("USDA ID: \(food.fdcId)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Divider()
                    
                    // Nutrition Facts Panel for saved food
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Nutrition Facts")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Per \(Int(food.servingSize)) \(food.servingSizeUnit ?? "g")")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        BasicNutritionFactRow(nutrient: "Calories", value: "\(Int(food.calories))", unit: "")
                        BasicNutritionFactRow(nutrient: "Protein", value: "\(String(format: "%.1f", food.protein))", unit: "g")
                        BasicNutritionFactRow(nutrient: "Carbohydrates", value: "\(String(format: "%.1f", food.carbs))", unit: "g")
                        BasicNutritionFactRow(nutrient: "Fat", value: "\(String(format: "%.1f", food.fat))", unit: "g")
                        BasicNutritionFactRow(nutrient: "Fiber", value: "\(String(format: "%.1f", food.fiber))", unit: "g")
                        BasicNutritionFactRow(nutrient: "Sodium", value: "\(String(format: "%.1f", food.sodium))", unit: "mg")
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                    
                    // Advanced Analysis Button (for saved foods)
                    NavigationLink(destination: NutritionAnalysisView(food: food, patient: nil)) {
                        HStack {
                            Image(systemName: "chart.bar.fill")
                            Text("Open Advanced Analysis")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                    }
                    .padding()
                    
                    Spacer()
                }
                .padding()
            }
        }
        .frame(minWidth: 500, minHeight: 600)
    }
}


// MARK: - Nutrition Fact Row
struct NutritionFactRow: View {
    let nutrient: String
    let value: String
    let unit: String
    
    var body: some View {
        HStack {
            Text(nutrient)
                .fontWeight(.medium)
            
            Spacer()
            
            Text("\(value)\(unit)")
                .fontWeight(.bold)
        }
        .padding(.vertical, 4)
    }
}


// MARK: - Professional USDA Food Detail View with Portions
// MARK: - Professional USDA Food Detail View with Patient Integration
struct USDAFoodDetailView: View {
    let food: USDAFood
    @State private var selectedPortion: FoodPortion
    @State private var customQuantity: Double = 1.0
    @State private var selectedPatient: Patient?
    @State private var selectedMealType: MealType = .lunch
    @State private var showingAddSuccess = false
    @State private var showingPatientSelector = false
    
    // Access to Core Data for patient management
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Patient.lastName, ascending: true)],
        animation: .default)
    private var patients: FetchedResults<Patient>
    
    init(food: USDAFood) {
        self.food = food
        _selectedPortion = State(initialValue: food.availablePortions.first { $0.isDefault } ?? food.availablePortions[0])
    }
    
    private var currentNutrients: PortionNutrients {
        let adjustedPortion = FoodPortion(
            id: selectedPortion.id,
            description: customQuantity == 1.0 ? selectedPortion.description : "\(String(format: "%.1f", customQuantity)) × \(selectedPortion.description)",
            gramWeight: selectedPortion.gramWeight * customQuantity,
            modifier: selectedPortion.modifier,
            isDefault: selectedPortion.isDefault
        )
        return adjustedPortion.calculateNutrients(from: food)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 25) {
                    // Header
                    VStack(alignment: .leading, spacing: 10) {
                        Text(food.description)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        if let brand = food.brandOwner {
                            Text("by \(brand)")
                                .font(.headline)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("USDA ID: \(food.fdcId)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Text("\(food.dataType ?? "Unknown")")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.2))
                                .cornerRadius(4)
                        }
                    }
                    
                    Divider()
                    
                    // Portion Selector
                    PortionSelectorView(
                        food: food,
                        selectedPortion: $selectedPortion,
                        customQuantity: $customQuantity
                    )
                    
                    Divider()
                    
                    // ADD TO PATIENT PLAN SECTION
                    VStack(alignment: .leading, spacing: 15) {
                        Text("👥 Add to Patient Plan")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                        
                        // Patient Selector
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Select Patient:")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            if patients.isEmpty {
                                Button("Create First Patient") {
                                    showingPatientSelector = true
                                }
                                .padding()
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                            } else {
                                Picker("Patient", selection: $selectedPatient) {
                                    Text("Select a patient...").tag(Patient?(nil))
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
                        }
                        
                        // Meal Type Selector
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Add to Meal:")
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
                        
                        // Current Selection Summary
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Will Add:")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(currentNutrients.portion.description)
                                        .font(.caption)
                                        .fontWeight(.bold)
                                    Text("of \(food.description)")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .trailing) {
                                    Text("\(Int(currentNutrients.calories)) cal")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundColor(.blue)
                                    Text("\(Int(currentNutrients.portion.gramWeight))g")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding()
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(8)
                        }
                        
                        // Add Button
                        Button(action: addToPatientPlan) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Add to \(selectedPatient?.firstName ?? "Patient")'s \(selectedMealType.displayName)")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(selectedPatient != nil ? Color.green : Color.gray)
                            .cornerRadius(10)
                        }
                        .disabled(selectedPatient == nil)
                    }
                    .padding()
                    .background(Color.green.opacity(0.05))
                    .cornerRadius(15)
                    
                    Divider()
                    
                    // Detailed Nutrition Facts for Selected Portion
                    VStack(alignment: .leading, spacing: 15) {
                        Text("📊 Detailed Nutrition Facts")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Per \(currentNutrients.portion.description)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        // Macronutrients
                        NutritionFactsSection(
                            title: "Macronutrients",
                            color: Color.blue,
                            nutrients: [
                                ("Calories", currentNutrients.calories, "kcal"),
                                ("Protein", currentNutrients.protein, "g"),
                                ("Total Fat", currentNutrients.fat, "g"),
                                ("Carbohydrates", currentNutrients.carbs, "g"),
                                ("Dietary Fiber", currentNutrients.fiber, "g"),
                                ("Sodium", currentNutrients.sodium, "mg")
                            ]
                        )
                        
                        // All Other Nutrients
                        if !currentNutrients.allNutrients.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("All Available Nutrients")
                                    .font(.headline)
                                    .foregroundColor(Color.green)
                                
                                LazyVGrid(columns: [
                                    GridItem(.flexible()),
                                    GridItem(.flexible())
                                ], spacing: 8) {
                                    ForEach(currentNutrients.allNutrients.prefix(30), id: \.name) { nutrient in
                                        HStack {
                                            Text(nutrient.name)
                                                .font(.caption)
                                                .lineLimit(2)
                                            
                                            Spacer()
                                            
                                            if nutrient.value > 0 {
                                                Text("\(String(format: "%.2f", nutrient.value)) \(nutrient.unit)")
                                                    .font(.caption)
                                                    .fontWeight(.medium)
                                            } else {
                                                Text("—")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        .padding(.vertical, 4)
                                    }
                                }
                            }
                            .padding()
                            .background(Color.green.opacity(0.05))
                            .cornerRadius(12)
                        }
                    }
                    
                    Spacer()
                }
                .padding()
            }
        }
        .frame(minWidth: 800, minHeight: 900)
        .alert("Added to Meal Plan!", isPresented: $showingAddSuccess) {
            Button("OK") { }
        } message: {
            Text("Successfully added \(currentNutrients.portion.description) to \(selectedPatient?.firstName ?? "")'s \(selectedMealType.displayName)!")
        }
        .sheet(isPresented: $showingPatientSelector) {
            QuickPatientCreator()
        }
    }
    
    // MARK: - Add to Patient Plan Function
    private func addToPatientPlan() {
        guard let patient = selectedPatient else { return }
        
        // Save the food to Core Data first (if not already saved)
        let foodManager = FoodDataManager(container: PersistenceController.shared.container)
        foodManager.saveFood(from: food)
        
        // Get the saved food
        let request: NSFetchRequest<Food> = Food.fetchRequest()
        request.predicate = NSPredicate(format: "fdcId == %d", food.fdcId)
        
        do {
            let savedFoods = try viewContext.fetch(request)
            guard let savedFood = savedFoods.first else { return }
            
            // Create or find today's meal
            let today = Calendar.current.startOfDay(for: Date())
            let mealRequest: NSFetchRequest<Meal> = Meal.fetchRequest()
            mealRequest.predicate = NSPredicate(format: "patient == %@ AND mealType == %@ AND date >= %@ AND date < %@",
                                               patient, selectedMealType.rawValue, today as NSDate, Calendar.current.date(byAdding: .day, value: 1, to: today)! as NSDate)
            
            let existingMeals = try viewContext.fetch(mealRequest)
            let meal: Meal
            
            if let existingMeal = existingMeals.first {
                meal = existingMeal
            } else {
                // Create new meal
                meal = Meal(context: viewContext)
                meal.name = selectedMealType.displayName
                meal.mealType = selectedMealType.rawValue
                meal.date = Date()
                meal.patient = patient
                meal.totalCalories = 0
            }
            
            // Create MealFood entry
            let mealFood = MealFood(context: viewContext)
            mealFood.quantity = currentNutrients.portion.gramWeight
            mealFood.unit = "g"
            mealFood.food = savedFood
            mealFood.meal = meal
            
            // Update meal totals
            meal.totalCalories = meal.totalCalories + currentNutrients.calories
            
            try viewContext.save()
            
            showingAddSuccess = true
            print("✅ Successfully added \(currentNutrients.portion.description) to \(patient.firstName ?? "")'s \(selectedMealType.displayName)")
            
        } catch {
            print("❌ Error adding food to patient plan: \(error)")
        }
    }
}

// MARK: - Quick Patient Creator
struct QuickPatientCreator: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    
    @State private var firstName = ""
    @State private var lastName = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Create New Patient")
                    .font(.title)
                    .fontWeight(.bold)
                
                VStack(alignment: .leading, spacing: 10) {
                    Text("First Name:")
                    TextField("Enter first name", text: $firstName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Text("Last Name:")
                    TextField("Enter last name", text: $lastName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                .padding()
                
                Button("Create Patient") {
                    createPatient()
                }
                .disabled(firstName.isEmpty || lastName.isEmpty)
                .buttonStyle(.borderedProminent)
                
                Spacer()
            }
            .padding()
            .navigationTitle("New Patient")
//            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .frame(minWidth: 400, minHeight: 300)
    }
    
    private func createPatient() {
        let patient = Patient(context: viewContext)
        patient.id = UUID()
        patient.firstName = firstName
        patient.lastName = lastName
        patient.dateOfBirth = Calendar.current.date(byAdding: .year, value: -30, to: Date()) // Default age
        patient.gender = "Unknown"
        patient.currentHeight = 170
        patient.currentWeight = 70
        patient.activityLevel = "Moderately Active"
        patient.createdDate = Date()
        patient.lastUpdated = Date()
        
        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("Error creating patient: \(error)")
        }
    }
}
// MARK: - Basic Nutrition Fact Row
struct BasicNutritionFactRow: View {
    let nutrient: String
    let value: String
    let unit: String
    
    var body: some View {
        HStack {
            Text(nutrient)
                .fontWeight(.medium)
            
            Spacer()
            
            Text("\(value)\(unit)")
                .fontWeight(.bold)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Nutrition Facts Section (Missing Struct)
struct NutritionFactsSection: View {
    let title: String
    let color: Color
    let nutrients: [(String, Double, String)]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .foregroundColor(color)
            
            VStack(spacing: 6) {
                ForEach(Array(nutrients.enumerated()), id: \.offset) { _, nutrient in
                    HStack {
                        Text(nutrient.0)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Text("\(String(format: "%.1f", nutrient.1)) \(nutrient.2)")
                            .fontWeight(.bold)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding()
        .background(color.opacity(0.05))
        .cornerRadius(12)
    }
}



#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
