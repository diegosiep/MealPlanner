import SwiftUI
import Foundation

// MARK: - FoodSelectionView.swift
// Fixed: PendingFoodSelection ambiguity and invalid redeclarations

// ==========================================
// ENHANCED FOOD SELECTION MANAGER
// ==========================================

class FoodSelectionManager: ObservableObject {
    @Published var pendingSelections: [FoodSelection] = []
    @Published var currentSelection: FoodSelection?
    @Published var isSelectingFood = false
    
    func addPendingSelection(_ selection: FoodSelection) {
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
        current.onSelection(selectedFood)
        showNextSelection()
    }
    
    func skipCurrentSelection() {
        guard let current = currentSelection else { return }
        current.onSkip()
        showNextSelection()
    }
}

// ==========================================
// FOOD SELECTION DATA STRUCTURE
// ==========================================

struct FoodSelection: Identifiable {
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

// ==========================================
// ENHANCED FOOD SELECTION INTERFACE
// ==========================================

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
                    headerSection(for: currentSelection)
                    searchSection
                    optionsListSection(for: currentSelection)
                    actionButtonsSection
                }
                .navigationTitle(strings.verifyFoodSelection)
                .compatibleNavigationBarTitleDisplayMode(.inline)
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
    private func headerSection(for selection: FoodSelection) -> some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Alimento Original:")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text(selection.originalFood.name)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    HStack {
                        Text("Peso: \(selection.originalFood.gramWeight)g")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        let calories = selection.originalFood.estimatedNutrition.calories
                        if calories > 0 {
                            Text("• \(Int(calories)) cal")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                VStack {
                    Image(systemName: "magnifyingglass.circle.fill")
                        .font(.largeTitle)
                        .foregroundColor(.blue)
                    
                    Text("Verificar")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            
            if let translatedFood = selection.translatedFood {
                VStack(spacing: 8) {
                    Text("Información de Traducción:")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Original: \(translatedFood.originalName)")
                        Text("Traducido: \(translatedFood.translatedName)")
                        Text("Confianza: \(Int(translatedFood.confidence * 100))%")
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            
            Divider()
            
            Text(strings.selectAccurateMatch)
                .font(.headline)
                .foregroundColor(.primary)
        }
        .padding()
        .background(Color.compatibleControlBackground)
    }
    
    // MARK: - Search Section
    private var searchSection: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Buscar entre opciones...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.compatibleTextBackground)
            .cornerRadius(8)
            
            Text("Mostrando \(filteredOptions.count) de \(selectionManager.currentSelection?.usdaOptions.count ?? 0) opciones")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
    
    // MARK: - Options List Section
    private func optionsListSection(for selection: FoodSelection) -> some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                if filteredOptions.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.magnifyingglass")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                        
                        Text("No se encontraron opciones")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        if !searchText.isEmpty {
                            Button("Limpiar búsqueda") {
                                searchText = ""
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    .padding(.top, 40)
                } else {
                    ForEach(Array(filteredOptions.enumerated()), id: \.element.fdcId) { index, usdaFood in
                        EnhancedFoodOptionCard(
                            usdaFood: usdaFood,
                            originalWeight: Int(selection.originalFood.gramWeight),
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
            .padding(.bottom, 100)
        }
        .background(Color.compatibleControlBackground)
    }
    
    // MARK: - Action Buttons Section
    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
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
            
            HStack(spacing: 16) {
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
                
                Button(action: {
                    selectionManager.completeCurrentSelection(with: selectedFood)
                }) {
                    HStack {
                        Image(systemName: selectedFood != nil ?
                              "checkmark.circle.fill" : "questionmark.circle")
                        Text(selectedFood != nil ? strings.useSelected : "Seleccionar Primero")
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
        .background(Color.compatibleWindowBackground)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: -1)
    }
    
    // MARK: - Helper Methods
    
    private func filterOptions(_ options: [USDAFood], searchText: String) {
        if searchText.isEmpty {
            filteredOptions = options
        } else {
            filteredOptions = options.filter { food in
                food.description.localizedCaseInsensitiveContains(searchText) ||
                (food.brandOwner?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                "\(food.fdcId)".contains(searchText)
            }
        }
    }
}

// ==========================================
// ENHANCED FOOD OPTION CARD
// ==========================================

struct EnhancedFoodOptionCard: View {
    let usdaFood: USDAFood
    let originalWeight: Int
    let isSelected: Bool
    let matchIndex: Int
    let totalMatches: Int
    let onTap: () -> Void
    let onNutritionTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("#\(matchIndex)")
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue)
                                .cornerRadius(4)
                            
                            Text(usdaFood.description)
                                .font(.headline)
                                .foregroundColor(.primary)
                                .lineLimit(2)
                        }
                        
                        if let brand = usdaFood.brandOwner, !brand.isEmpty {
                            Text("Marca: \(brand)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Text("FDC ID: \(usdaFood.fdcId)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(spacing: 8) {
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title2)
                                .foregroundColor(.green)
                        }
                        
                        Button("Nutrición") {
                            onNutritionTap()
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(6)
                    }
                }
                
                if let dataType = usdaFood.dataType {
                    HStack {
                        Text("Tipo: \(dataType)")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(4)
                        
                        Spacer()
                    }
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

// ==========================================
// SUPPORTING TYPES
// ==========================================

// Note: USDACompatibleFood is defined in FoodTranslationService.swift to avoid conflicts

// ==========================================
// VIEW MODIFIER FOR INTEGRATION
// ==========================================

struct FoodSelectionViewModifier: ViewModifier {
    @StateObject private var selectionManager = FoodSelectionManager()
    
    func body(content: Content) -> some View {
        content
            .environmentObject(selectionManager)
            .compatibleSheet(isPresented: $selectionManager.isSelectingFood) {
                FixedFoodSelectionView(selectionManager: selectionManager)
            }
    }
}

extension View {
    func withFoodSelection() -> some View {
        modifier(FoodSelectionViewModifier())
    }
}
