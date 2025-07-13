import SwiftUI
import Foundation

// MARK: - Enhanced Food Selection System
class FoodSelectionManager: ObservableObject {
    @Published var pendingSelections: [PendingFoodSelection] = []
    @Published var currentSelection: PendingFoodSelection?
    @Published var isSelectingFood = false
    
    func addPendingSelection(_ selection: PendingFoodSelection) {
        DispatchQueue.main.async {
            self.pendingSelections.append(selection)
            if self.currentSelection == nil {
                self.showNextSelection()
            }
        }
    }
    
    func showNextSelection() {
        if !pendingSelections.isEmpty {
            currentSelection = pendingSelections.removeFirst()
            isSelectingFood = true
        } else {
            currentSelection = nil
            isSelectingFood = false
        }
    }
    
    func completeCurrentSelection(with selectedFood: USDAFood?) {
        guard let current = currentSelection else { return }
        
        // Execute completion handler
        current.onSelection(selectedFood)
        
        // Move to next selection
        showNextSelection()
    }
    
    func skipCurrentSelection() {
        guard let current = currentSelection else { return }
        
        // Execute skip handler
        current.onSkip()
        
        // Move to next selection
        showNextSelection()
    }
}

// MARK: - Pending Food Selection Data
struct PendingFoodSelection: Identifiable {
    let id = UUID()
    let originalFood: SuggestedFood
    let usdaOptions: [USDAFood]
    let translatedFood: USDACompatibleFood?
    let onSelection: (USDAFood?) -> Void
    let onSkip: () -> Void
    
    init(
        originalFood: SuggestedFood,
        usdaOptions: [USDAFood],
        translatedFood: USDACompatibleFood? = nil,
        onSelection: @escaping (USDAFood?) -> Void,
        onSkip: @escaping () -> Void
    ) {
        self.originalFood = originalFood
        self.usdaOptions = usdaOptions
        self.translatedFood = translatedFood
        self.onSelection = onSelection
        self.onSkip = onSkip
    }
}

// MARK: - Enhanced Food Selection Interface
struct FixedFoodSelectionView: View {
    @ObservedObject var selectionManager: FoodSelectionManager
    @StateObject private var languageManager = LanguageManager.shared
    
    @State private var selectedFood: USDAFood?
    @State private var showNutritionDetails = false
    @State private var searchText = ""
    @State private var filteredOptions: [USDAFood] = []
    
    private var strings: AppLocalizedStrings {
        languageManager.currentLanguage.appStrings
    }
    
    var body: some View {
        if let currentSelection = selectionManager.currentSelection {
            NavigationView {
                VStack(spacing: 0) {
                    // Header Section
                    headerSection(for: currentSelection)
                    
                    // Search Bar
                    searchSection
                    
                    // Options List
                    optionsListSection(for: currentSelection)
                    
                    // Action Buttons
                    actionButtonsSection
                }
                .navigationTitle(strings.verifyFoodSelection)
                .navigationBarTitleDisplayMode(.inline)
            }
            .onAppear {
                filteredOptions = currentSelection.usdaOptions
                selectedFood = nil
            }
            .onChange(of: searchText) { newValue in
                filterOptions(currentSelection.usdaOptions, searchText: newValue)
            }
        } else {
            EmptyView()
        }
    }
    
    // MARK: - Header Section
    private func headerSection(for selection: PendingFoodSelection) -> some View {
        VStack(spacing: 16) {
            // Original Food Information
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "questionmark.circle.fill")
                        .foregroundColor(.orange)
                        .font(.title2)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Alimento Original")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(selection.originalFood.name)
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Cantidad")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("\(selection.originalFood.gramWeight)g")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                }
                
                // Translation Information
                if let translated = selection.translatedFood {
                    HStack {
                        Image(systemName: "arrow.right.circle")
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Búsqueda USDA")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(translated.translatedName)
                                .font(.subheadline)
                                .foregroundColor(.blue)
                        }
                        
                        Spacer()
                        
                        Text("Confianza: \(Int(translated.confidence * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
            }
            .padding()
            .background(Color.orange.opacity(0.05))
            .cornerRadius(12)
            
            // Instructions
            VStack(alignment: .leading, spacing: 8) {
                Text(strings.selectAccurateMatch)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                
                Text("Se encontraron \(selection.usdaOptions.count) opciones. Selecciona la más precisa:")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    // MARK: - Search Section
    private var searchSection: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Buscar en opciones USDA...", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            if !searchText.isEmpty {
                Text("Mostrando \(filteredOptions.count) de \(selectionManager.currentSelection?.usdaOptions.count ?? 0) opciones")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
        .background(Color.white)
    }
    
    // MARK: - Options List Section
    private func optionsListSection(for selection: PendingFoodSelection) -> some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if filteredOptions.isEmpty {
                    // No results
                    VStack(spacing: 16) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                        
                        Text("No se encontraron coincidencias")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("Intenta con términos de búsqueda diferentes")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Button("Mostrar todas las opciones") {
                            searchText = ""
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(.top, 40)
                } else {
                    ForEach(Array(filteredOptions.enumerated()), id: \.element.fdcId) { index, usdaFood in
                        EnhancedFoodOptionCard(
                            usdaFood: usdaFood,
                            originalWeight: selection.originalFood.gramWeight,
                            isSelected: selectedFood?.fdcId == usdaFood.fdcId,
                            matchIndex: index + 1,
                            totalMatches: filteredOptions.count,
                            onTap: {
                                selectedFood = usdaFood
                            },
                            onNutritionTap: {
                                selectedFood = usdaFood
                                showNutritionDetails = true
                            }
                        )
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 100) // Space for action buttons
        }
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    // MARK: - Action Buttons Section
    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            // Selection Status
            if let selected = selectedFood {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    
                    Text("Seleccionado: \(selected.description)")
                        .font(.subheadline)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    
                    Spacer()
                }
                .padding(.horizontal)
            }
            
            // Action Buttons
            HStack(spacing: 16) {
                // Skip Button
                Button(action: {
                    selectionManager.skipCurrentSelection()
                }) {
                    HStack {
                        Image(systemName: "arrow.right.circle")
                        Text(strings.skipThisFood)
                    }
                    .font(.headline)
                    .foregroundColor(.orange)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(10)
                }
                
                // Use Selected Button
                Button(action: {
                    selectionManager.completeCurrentSelection(with: selectedFood)
                }) {
                    HStack {
                        Image(systemName: selectedFood != nil ? "checkmark.circle" : "exclamationmark.circle")
                        Text(strings.useSelected)
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(selectedFood != nil ? Color.green : Color.gray)
                    .cornerRadius(10)
                }
                .disabled(selectedFood == nil)
            }
            .padding(.horizontal)
        }
        .padding(.vertical)
        .background(Color.white)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: -1)
    }
    
    // MARK: - Helper Methods
    private func filterOptions(_ options: [USDAFood], searchText: String) {
        if searchText.isEmpty {
            filteredOptions = options
        } else {
            let lowercaseSearch = searchText.lowercased()
            filteredOptions = options.filter { food in
                food.description.lowercased().contains(lowercaseSearch) ||
                (food.brandName?.lowercased().contains(lowercaseSearch) ?? false)
            }
        }
    }
}

// MARK: - Enhanced Food Option Card
struct EnhancedFoodOptionCard: View {
    let usdaFood: USDAFood
    let originalWeight: Int
    let isSelected: Bool
    let matchIndex: Int
    let totalMatches: Int
    let onTap: () -> Void
    let onNutritionTap: () -> Void
    
    @State private var showingNutritionPopover = false
    
    private var adjustedNutrition: EstimatedNutrition {
        calculateUSDAPortionNutrition(usdaFood: usdaFood, targetWeight: Double(originalWeight))
    }
    
    private var matchScore: Double {
        // Simple scoring based on position in list (earlier = better match)
        return max(0.0, 1.0 - (Double(matchIndex - 1) / Double(totalMatches)))
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                // Header with match info
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("#\(matchIndex)")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue)
                                .cornerRadius(4)
                            
                            Text("Coincidencia: \(Int(matchScore * 100))%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Text(usdaFood.description)
                            .font(.headline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(3)
                    }
                    
                    Spacer()
                    
                    // Selection indicator
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.green)
                    } else {
                        Image(systemName: "circle")
                            .font(.title2)
                            .foregroundColor(.gray.opacity(0.3))
                    }
                }
                
                // Brand information
                if let brandName = usdaFood.brandName, !brandName.isEmpty {
                    HStack {
                        Image(systemName: "building.2")
                            .foregroundColor(.secondary)
                            .font(.caption)
                        
                        Text(brandName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                    }
                }
                
                // Nutrition preview
                VStack(spacing: 8) {
                    HStack {
                        Text("Nutrición para \(originalWeight)g:")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Button(action: onNutritionTap) {
                            HStack(spacing: 4) {
                                Text("Ver detalles")
                                Image(systemName: "info.circle")
                            }
                            .font(.caption)
                            .foregroundColor(.blue)
                        }
                    }
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 8) {
                        NutritionBadge(
                            label: "Calorías",
                            value: "\(Int(adjustedNutrition.calories))",
                            unit: "kcal",
                            color: .orange
                        )
                        
                        NutritionBadge(
                            label: "Proteína",
                            value: "\(String(format: "%.1f", adjustedNutrition.protein))",
                            unit: "g",
                            color: .green
                        )
                        
                        NutritionBadge(
                            label: "Carbohidratos",
                            value: "\(String(format: "%.1f", adjustedNutrition.carbohydrates))",
                            unit: "g",
                            color: .blue
                        )
                        
                        NutritionBadge(
                            label: "Grasa",
                            value: "\(String(format: "%.1f", adjustedNutrition.fat))",
                            unit: "g",
                            color: .purple
                        )
                    }
                }
                
                // USDA verification badge
                HStack {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                    
                    Text("Verificado por USDA • ID: \(usdaFood.fdcId)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
            }
            .padding()
            .background(isSelected ? Color.green.opacity(0.1) : Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.green : Color.gray.opacity(0.2), lineWidth: isSelected ? 2 : 1)
            )
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Nutrition Badge Component
struct NutritionBadge: View {
    let label: String
    let value: String
    let unit: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(unit)
                .font(.caption2)
                .foregroundColor(color)
            
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Helper Function for Nutrition Calculation
private func calculateUSDAPortionNutrition(usdaFood: USDAFood, targetWeight: Double) -> EstimatedNutrition {
    // USDA nutrition is typically per 100g
    let conversionFactor = targetWeight / 100.0
    
    // Extract nutrition from USDA food nutrients
    var calories: Double = 0
    var protein: Double = 0
    var carbs: Double = 0
    var fat: Double = 0
    
    for nutrient in usdaFood.foodNutrients {
        switch nutrient.nutrientNumber {
        case 208: // Energy (kcal)
            calories = (nutrient.value ?? 0) * conversionFactor
        case 203: // Protein
            protein = (nutrient.value ?? 0) * conversionFactor
        case 205: // Carbohydrates
            carbs = (nutrient.value ?? 0) * conversionFactor
        case 204: // Total fat
            fat = (nutrient.value ?? 0) * conversionFactor
        default:
            break
        }
    }
    
    return EstimatedNutrition(
        calories: calories,
        protein: protein,
        carbohydrates: carbs,
        fat: fat,
        fiber: 0, // Can be added later
        sugar: 0  // Can be added later
    )
}

// MARK: - Food Selection Overlay Component
struct FoodSelectionOverlay: ViewModifier {
    @ObservedObject var selectionManager: FoodSelectionManager
    
    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $selectionManager.isSelectingFood) {
                FixedFoodSelectionView(selectionManager: selectionManager)
            }
    }
}

extension View {
    func foodSelectionOverlay(manager: FoodSelectionManager) -> some View {
        modifier(FoodSelectionOverlay(selectionManager: manager))
    }
}
