

import SwiftUI
import Foundation

// MARK: - FoodSelectionSystem.swift
// Purpose: Provides a complete food selection system without naming conflicts
// Why needed: Your project has duplicate "PendingFoodSelection" definitions causing ambiguity

// ==========================================
// UNIQUE FOOD SELECTION DATA STRUCTURES
// ==========================================

// This struct represents a food that needs manual selection from USDA options
// I'm using "Manual" prefix to avoid conflicts with any existing "PendingFoodSelection"
public struct ManualFoodSelection: Identifiable {
    public let id = UUID()
    
    // The original food suggestion from the AI
    public let originalFood: SuggestedFood
    
    // The list of potential USDA matches for the user to choose from
    public let usdaOptions: [USDAFood]
    
    // Optional translation information if the food name was translated
    public let translationInfo: FoodTranslationInfo?
    
    // Confidence scores for each USDA option (0.0 to 1.0)
    public let confidenceScores: [Double]
    
    // Callback functions to handle user's selection
    public let onSelection: (USDAFood?) -> Void
    public let onSkip: () -> Void
    
    // Constructor that ensures we have valid data
    public init(
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
        
        // If confidence scores aren't provided, generate them based on name similarity
        if confidenceScores.isEmpty {
            self.confidenceScores = usdaOptions.map { usdaFood in
                self.calculateNameSimilarity(originalFood.name, usdaFood.description)
            }
        } else {
            self.confidenceScores = confidenceScores
        }
        
        self.onSelection = onSelection
        self.onSkip = onSkip
    }
    
    // Helper method to calculate how similar two food names are
    private func calculateNameSimilarity(_ name1: String, _ name2: String) -> Double {
        let cleanName1 = name1.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanName2 = name2.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Simple similarity based on common words
        let words1 = Set(cleanName1.components(separatedBy: .whitespaces))
        let words2 = Set(cleanName2.components(separatedBy: .whitespaces))
        
        let commonWords = words1.intersection(words2)
        let totalWords = words1.union(words2)
        
        guard !totalWords.isEmpty else { return 0.0 }
        
        return Double(commonWords.count) / Double(totalWords.count)
    }
}

// Supporting data structure for translation information
public struct FoodTranslationInfo {
    public let originalName: String
    public let translatedName: String
    public let confidence: Double
    public let alternativeNames: [String]
    
    public init(originalName: String, translatedName: String, confidence: Double, alternativeNames: [String] = []) {
        self.originalName = originalName
        self.translatedName = translatedName
        self.confidence = confidence
        self.alternativeNames = alternativeNames
    }
}

// ==========================================
// FOOD SELECTION MANAGER
// ==========================================

// This class manages the queue of foods that need manual selection
// Think of it as a "waiting room" where foods wait for the user to make decisions
public class ManualFoodSelectionManager: ObservableObject {
    // The list of foods waiting for user selection
    @Published public var waitingSelections: [ManualFoodSelection] = []
    
    // The food currently being shown to the user for selection
    @Published public var currentSelection: ManualFoodSelection?
    
    // Whether the selection interface is currently visible
    @Published public var isShowingSelectionInterface = false
    
    // Singleton pattern - one manager for the entire app
    public static let shared = ManualFoodSelectionManager()
    
    private init() {}
    
    // MARK: - Public Methods
    
    // Add a food that needs manual selection to the queue
    public func addFoodForSelection(_ selection: ManualFoodSelection) {
        // Always update UI on the main thread
        DispatchQueue.main.async {
            self.waitingSelections.append(selection)
            
            // If nothing is currently being shown, show this one
            if self.currentSelection == nil {
                self.showNextSelection()
            }
        }
    }
    
    // Display the next food in the queue for user selection
    public func showNextSelection() {
        // Take the first waiting selection and make it current
        if !waitingSelections.isEmpty {
            currentSelection = waitingSelections.removeFirst()
            isShowingSelectionInterface = true
        } else {
            // No more selections waiting
            currentSelection = nil
            isShowingSelectionInterface = false
        }
    }
    
    // Handle when user selects a USDA food option
    public func selectUSDAFood(_ selectedFood: USDAFood?) {
        guard let current = currentSelection else { return }
        
        // Call the selection callback with the user's choice
        current.onSelection(selectedFood)
        
        // Move to the next selection in the queue
        showNextSelection()
    }
    
    // Handle when user chooses to skip this food
    public func skipCurrentFood() {
        guard let current = currentSelection else { return }
        
        // Call the skip callback
        current.onSkip()
        
        // Move to the next selection in the queue
        showNextSelection()
    }
    
    // Get information about the current selection state
    public var selectionStatus: SelectionStatus {
        if currentSelection != nil {
            return .selectingFood
        } else if !waitingSelections.isEmpty {
            return .waitingInQueue
        } else {
            return .noSelectionsNeeded
        }
    }
    
    // Clear all pending selections (useful for canceling operations)
    public func clearAllSelections() {
        waitingSelections.removeAll()
        currentSelection = nil
        isShowingSelectionInterface = false
    }
}

// Enum to represent the current state of food selection
public enum SelectionStatus {
    case noSelectionsNeeded  // No foods need manual selection
    case waitingInQueue     // Foods are waiting but none currently being shown
    case selectingFood      // User is currently selecting a food
}

// ==========================================
// FOOD SELECTION USER INTERFACE
// ==========================================

// This SwiftUI view provides the interface for users to manually select foods
public struct ManualFoodSelectionView: View {
    @ObservedObject private var selectionManager = ManualFoodSelectionManager.shared
    @ObservedObject private var languageManager = AppLanguageManager.shared
    
    @State private var selectedUSDAFood: USDAFood?
    @State private var searchText = ""
    @State private var showingFoodDetails = false
    
    public init() {}
    
    public var body: some View {
        // Only show the interface if there's a current selection
        if let currentSelection = selectionManager.currentSelection {
            NavigationView {
                VStack(spacing: 0) {
                    // Header explaining what the user needs to do
                    selectionHeaderView(for: currentSelection)
                    
                    // Search bar to filter USDA options
                    searchBarView
                    
                    // List of USDA food options
                    usdaOptionsListView(for: currentSelection)
                    
                    // Action buttons at the bottom
                    actionButtonsView
                }
                .navigationTitle(languageManager.text.verifyFoodSelection)
                .compatibleNavigationBarTitleDisplayMode(.inline)
            }
        } else {
            // This view should not be visible when there's no current selection
            EmptyView()
        }
    }
    
    // MARK: - View Components
    
    private func selectionHeaderView(for selection: ManualFoodSelection) -> some View {
        VStack(spacing: 16) {
            // Original food information
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
                
                // Translation information if available
                if let translationInfo = selection.translationInfo {
                    HStack {
                        Image(systemName: "arrow.right.circle")
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Traducción USDA")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(translationInfo.translatedName)
                                .font(.subheadline)
                                .foregroundColor(.blue)
                        }
                        
                        Spacer()
                        
                        Text("Confianza: \(Int(translationInfo.confidence * 100))%")
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
                Text(languageManager.text.selectAccurateMatch)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                
                Text("Se encontraron \(selection.usdaOptions.count) opciones. Selecciona la más precisa:")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(Color.compatibleControlBackground)
    }
    
    private var searchBarView: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Buscar en opciones USDA...", text: $searchText)
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            
            if !searchText.isEmpty {
                Text("Filtrando opciones...")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
        .background(Color.white)
    }
    
    private func usdaOptionsListView(for selection: ManualFoodSelection) -> some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                let filteredOptions = filterOptions(selection.usdaOptions)
                
                if filteredOptions.isEmpty {
                    noResultsView
                } else {
                    ForEach(Array(filteredOptions.enumerated()), id: \.element.fdcId) { index, usdaFood in
                        USDAFoodOptionCard(
                            usdaFood: usdaFood,
                            originalWeight: selection.originalFood.gramWeight,
                            isSelected: selectedUSDAFood?.fdcId == usdaFood.fdcId,
                            confidence: getConfidenceForFood(usdaFood, in: selection),
                            matchIndex: index + 1,
                            totalMatches: filteredOptions.count
                        ) {
                            selectedUSDAFood = usdaFood
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 100) // Space for action buttons
        }
        .background(Color.compatibleControlBackground)
    }
    
    private var noResultsView: some View {
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
    }
    
    private var actionButtonsView: some View {
        VStack(spacing: 12) {
            // Selection status
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
            
            // Action buttons
            HStack(spacing: 16) {
                // Skip button
                Button(action: {
                    selectionManager.skipCurrentFood()
                }) {
                    HStack {
                        Image(systemName: "arrow.right.circle")
                        Text(languageManager.text.skipThisFood)
                    }
                    .font(.headline)
                    .foregroundColor(.orange)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(10)
                }
                
                // Use selected button
                Button(action: {
                    selectionManager.selectUSDAFood(selectedUSDAFood)
                }) {
                    HStack {
                        Image(systemName: selectedUSDAFood != nil ? "checkmark.circle" : "exclamationmark.circle")
                        Text(languageManager.text.useSelected)
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
        .background(Color.white)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: -1)
    }
    
    // MARK: - Helper Methods
    
    private func filterOptions(_ options: [USDAFood]) -> [USDAFood] {
        if searchText.isEmpty {
            return options
        } else {
            let lowercaseSearch = searchText.lowercased()
            return options.filter { food in
                food.description.lowercased().contains(lowercaseSearch) ||
                (food.brandName?.lowercased().contains(lowercaseSearch) ?? false)
            }
        }
    }
    
    private func getConfidenceForFood(_ food: USDAFood, in selection: ManualFoodSelection) -> Double {
        // Find the confidence score for this specific food
        if let index = selection.usdaOptions.firstIndex(where: { $0.fdcId == food.fdcId }),
           index < selection.confidenceScores.count {
            return selection.confidenceScores[index]
        }
        return 0.5 // Default confidence if not found
    }
}

// ==========================================
// USDA FOOD OPTION CARD COMPONENT
// ==========================================

// This card displays a single USDA food option for the user to select
struct USDAFoodOptionCard: View {
    let usdaFood: USDAFood
    let originalWeight: Int
    let isSelected: Bool
    let confidence: Double
    let matchIndex: Int
    let totalMatches: Int
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                // Header with match information
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
                            
                            Text("Coincidencia: \(Int(confidence * 100))%")
                                .font(.caption)
                                .foregroundColor(confidenceColor)
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
                
                // Brand information if available
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
// VIEW MODIFIER FOR EASY INTEGRATION
// ==========================================

// This view modifier makes it easy to add food selection capability to any view
public struct ManualFoodSelectionModifier: ViewModifier {
    @ObservedObject private var selectionManager = ManualFoodSelectionManager.shared
    
    public func body(content: Content) -> some View {
        content
            .compatibleSheet(isPresented: $selectionManager.isShowingSelectionInterface) {
                ManualFoodSelectionView()
            }
    }
}

extension View {
    // Add this modifier to any view that might trigger food selection
    public func withManualFoodSelection() -> some View {
        modifier(ManualFoodSelectionModifier())
    }
}

// ==========================================
// USAGE INSTRUCTIONS
// ==========================================

/*
 HOW TO INTEGRATE THIS FOOD SELECTION SYSTEM:

 STEP 1: ADD THE FILE
 - Add this file to your project as "FoodSelectionSystem.swift"
 - Build to ensure no conflicts with existing code

 STEP 2: REMOVE DUPLICATE DEFINITIONS
 - Search your project for "PendingFoodSelection"
 - Delete or comment out any existing definitions
 - This file provides "ManualFoodSelection" as a replacement

 STEP 3: UPDATE YOUR FOOD VERIFICATION CODE
 Instead of creating PendingFoodSelection, use ManualFoodSelection:

 BEFORE:
 pendingFoodSelections.append(PendingFoodSelection(...))

 AFTER:
 let selection = ManualFoodSelection(
     originalFood: aiFood,
     usdaOptions: potentialMatches,
     onSelection: { selectedFood in
         // Handle the user's selection
     },
     onSkip: {
         // Handle when user skips this food
     }
 )
 ManualFoodSelectionManager.shared.addFoodForSelection(selection)

 STEP 4: ADD THE MODIFIER TO YOUR MAIN VIEW
 In your ContentView or main navigation view:

 struct ContentView: View {
     var body: some View {
         // Your existing content
         YourMainView()
             .withManualFoodSelection()  // Add this line
     }
 }

 STEP 5: TEST THE FOOD SELECTION FLOW
 - Trigger food generation that requires manual selection
 - Verify that the selection interface appears
 - Test selecting foods and skipping foods
 - Ensure the queue works properly with multiple foods

 This system is designed to be completely independent of your existing code,
 eliminating the naming conflicts while providing robust food selection functionality.
 */
