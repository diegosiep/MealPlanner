import SwiftUI
import Foundation

// MARK: - FoodSelectionSystem.swift
// Fixed: Public properties using internal types - changed access levels to internal

// ==========================================
// FOOD SELECTION DATA STRUCTURES
// ==========================================

struct ManualFoodSelection: Identifiable {
    let id = UUID()
    let originalFood: SuggestedFood
    let usdaOptions: [USDAFood]
    let translationInfo: FoodTranslationInfo?
    let confidenceScores: [Double]
    let onSelection: (USDAFood?) -> Void
    let onSkip: () -> Void
    
    init(
        originalFood: SuggestedFood,
        usdaOptions: [USDAFood],
        translationInfo: FoodTranslationInfo? = nil,
        confidenceScores: [Double] = [],
        onSelection: @escaping (USDAFood?) -> Void,
        onSkip: @escaping () -> Void
    ) {
        self.originalFood = originalFood
        self.usdaOptions = usdaOptions
        self.translationInfo = translationInfo
        self.confidenceScores = confidenceScores.isEmpty ?
        Array(repeating: 0.7, count: usdaOptions.count) : confidenceScores
        self.onSelection = onSelection
        self.onSkip = onSkip
    }
}

struct FoodTranslationInfo {
    let originalText: String
    let translatedText: String
    let sourceLanguage: String
    let targetLanguage: String
    let confidence: Double
}

// ==========================================
// FOOD SELECTION MANAGER
// ==========================================

class ManualFoodSelectionManager: ObservableObject {
    @Published var waitingSelections: [ManualFoodSelection] = []
    @Published var currentSelection: ManualFoodSelection?
    @Published var isShowingSelectionInterface = false
    
    static let shared = ManualFoodSelectionManager()
    
    private init() {}
    
    // MARK: - Internal Methods (Fixed access levels)
    
    func addFoodForSelection(_ selection: ManualFoodSelection) {
        DispatchQueue.main.async {
            self.waitingSelections.append(selection)
            
            if self.currentSelection == nil {
                self.showNextSelection()
            }
        }
    }
    
    func showNextSelection() {
        if !waitingSelections.isEmpty {
            currentSelection = waitingSelections.removeFirst()
            isShowingSelectionInterface = true
        } else {
            currentSelection = nil
            isShowingSelectionInterface = false
        }
    }
    
    func selectUSDAFood(_ selectedFood: USDAFood?) {
        guard let current = currentSelection else { return }
        current.onSelection(selectedFood)
        showNextSelection()
    }
    
    func skipCurrentFood() {
        guard let current = currentSelection else { return }
        current.onSkip()
        showNextSelection()
    }
    
    var selectionStatus: SelectionStatus {
        if currentSelection != nil {
            return .selectingFood
        } else if !waitingSelections.isEmpty {
            return .waitingInQueue
        } else {
            return .noSelectionsNeeded
        }
    }
    
    func clearAllSelections() {
        waitingSelections.removeAll()
        currentSelection = nil
        isShowingSelectionInterface = false
    }
}

enum SelectionStatus {
    case noSelectionsNeeded
    case waitingInQueue
    case selectingFood
}

// ==========================================
// FOOD SELECTION USER INTERFACE
// ==========================================

struct ManualFoodSelectionView: View {
    @ObservedObject private var selectionManager = ManualFoodSelectionManager.shared
    @ObservedObject private var languageManager = LanguageManager.shared
    
    @State private var selectedUSDAFood: USDAFood?
    @State private var showNutritionDetails = false
    @State private var searchText = ""
    @State private var filteredOptions: [USDAFood] = []
    
    var body: some View {
        if let currentSelection = selectionManager.currentSelection {
            NavigationView {
                VStack(spacing: 0) {
                    headerSection(for: currentSelection)
                    searchSection
                    optionsListSection(for: currentSelection)
                    actionButtonsSection
                }
                .navigationTitle("Verificar Selección")
                .compatibleNavigationBarTitleDisplayMode(.inline)
            }
            .onAppear {
                filteredOptions = currentSelection.usdaOptions
                selectedUSDAFood = nil
            }
            .onChange(of: searchText) { newValue in
                filterOptions(currentSelection.usdaOptions, searchText: newValue)
            }
        } else {
            EmptyView()
        }
    }
    
    private func headerSection(for selection: ManualFoodSelection) -> some View {
        VStack(spacing: 16) {
            Text("Alimento Sugerido:")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text(selection.originalFood.name)
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            HStack {
                Text("Peso:")
                Text("\(selection.originalFood.gramWeight)g")
                    .fontWeight(.semibold)
            }
            .foregroundColor(.secondary)
            
            if let translation = selection.translationInfo {
                VStack(spacing: 4) {
                    Text("Traducido de: \(translation.originalText)")
                        .font(.caption)
                        .foregroundColor(.blue)
                    
                    Text("Confianza: \(Int(translation.confidence * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color.compatibleControlBackground)
    }
    
    private var searchSection: some View {
        VStack(spacing: 8) {
            Text("Buscar entre \(filteredOptions.count) opciones:")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            TextField("Buscar alimentos...", text: $searchText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)
        }
        .padding(.vertical)
    }
    
    private func optionsListSection(for selection: ManualFoodSelection) -> some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                if filteredOptions.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "magnifyingglass")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                        
                        Text("No se encontraron opciones")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("Intenta con diferentes términos de búsqueda")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 40)
                } else {
                    ForEach(Array(filteredOptions.enumerated()), id: \.element.fdcId) { index, usdaFood in
                        FoodOptionCard(
                            usdaFood: usdaFood,
                            originalWeight: Int(selection.originalFood.gramWeight),
                            isSelected: selectedUSDAFood?.fdcId == usdaFood.fdcId,
                            confidence: index < selection.confidenceScores.count ?
                            selection.confidenceScores[index] : 0.7,
                            onTap: {
                                selectedUSDAFood = usdaFood
                            },
                            onNutritionTap: {
                                selectedUSDAFood = usdaFood
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
    
    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            if let selected = selectedUSDAFood {
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
                    selectionManager.skipCurrentFood()
                }) {
                    HStack {
                        Image(systemName: "arrow.right.circle")
                        Text("Omitir")
                    }
                    .font(.headline)
                    .foregroundColor(.orange)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(10)
                }
                
                Button(action: {
                    selectionManager.selectUSDAFood(selectedUSDAFood)
                }) {
                    HStack {
                        Image(systemName: selectedUSDAFood != nil ?
                              "checkmark.circle.fill" : "questionmark.circle")
                        Text(selectedUSDAFood != nil ? "Usar Seleccionado" : "Seleccionar Primero")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(selectedUSDAFood != nil ? Color.green : Color.gray)
                    .cornerRadius(10)
                }
                .disabled(selectedUSDAFood == nil)
            }
            .padding(.horizontal)
        }
        .padding(.vertical)
        .background(Color.compatibleWindowBackground)
    }
    
    private func filterOptions(_ options: [USDAFood], searchText: String) {
        if searchText.isEmpty {
            filteredOptions = options
        } else {
            filteredOptions = options.filter { food in
                food.description.localizedCaseInsensitiveContains(searchText) ||
                (food.brandOwner?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
    }
}

// ==========================================
// FOOD OPTION CARD
// ==========================================

struct FoodOptionCard: View {
    let usdaFood: USDAFood
    let originalWeight: Int
    let isSelected: Bool
    let confidence: Double
    let onTap: () -> Void
    let onNutritionTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(usdaFood.description)
                            .font(.headline)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                        
                        if let brand = usdaFood.brandOwner, !brand.isEmpty {
                            Text(brand)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    VStack(spacing: 4) {
                        Circle()
                            .fill(confidenceColor)
                            .frame(width: 12, height: 12)
                        
                        Text("\(Int(confidence * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack {
                    Text("FDC ID: \(usdaFood.fdcId)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button("Ver Nutrición") {
                        onNutritionTap()
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            }
            .padding()
            .background(isSelected ? Color.green.opacity(0.1) : Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.green : Color.gray.opacity(0.2),
                            lineWidth: isSelected ? 2 : 1)
            )
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var confidenceColor: Color {
        if confidence >= 0.8 {
            return .green
        } else if confidence >= 0.6 {
            return .orange
        } else {
            return .red
        }
    }
}

// ==========================================
// VIEW MODIFIER FOR INTEGRATION
// ==========================================

struct ManualFoodSelectionModifier: ViewModifier {
    @ObservedObject private var selectionManager = ManualFoodSelectionManager.shared
    
    func body(content: Content) -> some View {
        content
            .compatibleSheet(isPresented: $selectionManager.isShowingSelectionInterface) {
                ManualFoodSelectionView()
            }
    }
}

extension View {
    func withManualFoodSelection() -> some View {
        modifier(ManualFoodSelectionModifier())
    }
}

// ==========================================
// SUPPORTING DATA TYPES
// ==========================================

// Note: USDAFood is defined in USDAFoodService.swift to avoid conflicts

// Note: SuggestedFood and EstimatedNutrition are defined in LLMService.swift to avoid conflicts
