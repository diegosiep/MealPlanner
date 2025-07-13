//
//  FoodSelectionView.swift
//  MealPlannerPro
//
//  User interface for selecting accurate USDA food matches
//

import SwiftUI

#if canImport(AppKit)
import AppKit
#endif

// MARK: - Food Selection Interface for Accuracy
struct FoodSelectionView: View {
    let originalFood: SuggestedFood
    let usdaOptions: [USDAFood]
    let onSelection: (USDAFood?) -> Void
    let onSkip: () -> Void
    
    @State private var selectedFood: USDAFood?
    @State private var showNutritionDetails = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Header with original food
            VStack(alignment: .leading, spacing: 12) {
                Text("Verify Food Selection")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Original: \(originalFood.name)")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("Select the most accurate match from USDA database:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)
            
            // USDA Options List
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(usdaOptions, id: \.fdcId) { usdaFood in
                        FoodOptionCard(
                            usdaFood: usdaFood,
                            originalWeight: originalFood.gramWeight,
                            isSelected: selectedFood?.fdcId == usdaFood.fdcId,
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
                .padding(.horizontal)
            }
            
            Spacer()
            
            // Action Buttons
            HStack(spacing: 16) {
                Button("Skip This Food") {
                    onSkip()
                }
                .foregroundColor(.orange)
                
                Spacer()
                
                Button("Use Selected") {
                    onSelection(selectedFood)
                }
                .disabled(selectedFood == nil)
                .foregroundColor(selectedFood != nil ? .white : .gray)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(selectedFood != nil ? Color.blue : Color(NSColor.controlColor))
                .cornerRadius(8)
            }
            .padding()
        }
        .frame(minWidth: 600, minHeight: 500)
        .background(Color(NSColor.windowBackgroundColor))
        .sheet(isPresented: $showNutritionDetails) {
            if let selectedFood = selectedFood {
                NutritionComparisonView(
                    originalFood: originalFood,
                    usdaFood: selectedFood
                )
            }
        }
    }
}

// MARK: - Individual Food Option Card
struct FoodOptionCard: View {
    let usdaFood: USDAFood
    let originalWeight: Double
    let isSelected: Bool
    let onTap: () -> Void
    let onNutritionTap: () -> Void
    
    private var adjustedNutrition: EstimatedNutrition {
        let multiplier = originalWeight / 100.0
        return EstimatedNutrition(
            calories: usdaFood.calories * multiplier,
            protein: usdaFood.protein * multiplier,
            carbs: usdaFood.carbs * multiplier,
            fat: usdaFood.fat * multiplier
        )
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Food Name and Selection
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(usdaFood.description)
                        .font(.headline)
                        .lineLimit(2)
                    
                    Text("FDC ID: \(usdaFood.fdcId)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .gray)
                    .font(.title2)
            }
            
            // Nutrition Preview
            HStack(spacing: 16) {
                NutritionBadge(
                    label: "Cal",
                    value: String(format: "%.0f", adjustedNutrition.calories),
                    color: .orange
                )
                
                NutritionBadge(
                    label: "Pro",
                    value: String(format: "%.1f", adjustedNutrition.protein),
                    color: .blue
                )
                
                NutritionBadge(
                    label: "Carb",
                    value: String(format: "%.1f", adjustedNutrition.carbs),
                    color: .green
                )
                
                NutritionBadge(
                    label: "Fat",
                    value: String(format: "%.1f", adjustedNutrition.fat),
                    color: .purple
                )
                
                Spacer()
                
                Button("Details") {
                    onNutritionTap()
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
        }
        .padding()
        .background(isSelected ? Color.blue.opacity(0.1) : Color(NSColor.controlBackgroundColor))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.blue : Color(NSColor.separatorColor), lineWidth: isSelected ? 2 : 1)
        )
        .cornerRadius(12)
        .onTapGesture {
            onTap()
        }
    }
}

// MARK: - Nutrition Badge Component
struct NutritionBadge: View {
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
    }
}

// MARK: - Detailed Nutrition Comparison
struct NutritionComparisonView: View {
    let originalFood: SuggestedFood
    let usdaFood: USDAFood
    @Environment(\.presentationMode) var presentationMode
    
    private var adjustedNutrition: EstimatedNutrition {
        let multiplier = originalFood.gramWeight / 100.0
        return EstimatedNutrition(
            calories: usdaFood.calories * multiplier,
            protein: usdaFood.protein * multiplier,
            carbs: usdaFood.carbs * multiplier,
            fat: usdaFood.fat * multiplier
        )
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Nutrition Comparison")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Portion: \(String(format: "%.0f", originalFood.gramWeight))g")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    // Original vs USDA Comparison
                    VStack(spacing: 16) {
                        ComparisonRow(
                            label: "Calories",
                            originalValue: originalFood.estimatedNutrition.calories,
                            usdaValue: adjustedNutrition.calories,
                            unit: "kcal"
                        )
                        
                        ComparisonRow(
                            label: "Protein",
                            originalValue: originalFood.estimatedNutrition.protein,
                            usdaValue: adjustedNutrition.protein,
                            unit: "g"
                        )
                        
                        ComparisonRow(
                            label: "Carbohydrates",
                            originalValue: originalFood.estimatedNutrition.carbs,
                            usdaValue: adjustedNutrition.carbs,
                            unit: "g"
                        )
                        
                        ComparisonRow(
                            label: "Fat",
                            originalValue: originalFood.estimatedNutrition.fat,
                            usdaValue: adjustedNutrition.fat,
                            unit: "g"
                        )
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(12)
                    
                    // USDA Food Details
                    VStack(alignment: .leading, spacing: 8) {
                        Text("USDA Food Details")
                            .font(.headline)
                        
                        Text(usdaFood.description)
                            .font(.body)
                        
                        Text("FDC ID: \(usdaFood.fdcId)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(12)
                }
                .padding()
            }
            .navigationTitle("Food Details")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                #else
                ToolbarItem(placement: .primaryAction) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                #endif
            }
        }
    }
}

// MARK: - Comparison Row Component
struct ComparisonRow: View {
    let label: String
    let originalValue: Double
    let usdaValue: Double
    let unit: String
    
    private var percentDifference: Double {
        guard originalValue > 0 else { return 0 }
        return abs(originalValue - usdaValue) / originalValue * 100
    }
    
    private var isAccurate: Bool {
        return percentDifference <= 20 // 20% tolerance
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("Difference: \(String(format: "%.1f", percentDifference))%")
                    .font(.caption)
                    .foregroundColor(isAccurate ? .green : .orange)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 8) {
                    VStack(alignment: .trailing) {
                        Text("Original")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(String(format: "%.1f", originalValue)) \(unit)")
                            .font(.body)
                    }
                    
                    Text("→")
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .trailing) {
                        Text("USDA")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(String(format: "%.1f", usdaValue)) \(unit)")
                            .font(.body)
                            .fontWeight(.semibold)
                            .foregroundColor(isAccurate ? .green : .primary)
                    }
                }
            }
        }
    }
}
