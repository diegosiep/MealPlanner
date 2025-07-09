//
//  PortionSelectorView.swift
//  MealPlannerPro
//
//  Created by Diego Sierra on 03/07/25.
//

import SwiftUI

// MARK: - Advanced Portion Selector with Nutrition Calculation
struct PortionSelectorView: View {
    let food: USDAFood
    @Binding var selectedPortion: FoodPortion
    @Binding var customQuantity: Double
    @State private var showingCustomQuantity = false
    
    private var currentNutrients: PortionNutrients {
        let basePortion = selectedPortion
        let adjustedPortion = FoodPortion(
            id: basePortion.id,
            description: customQuantity == 1.0 ? basePortion.description : "\(String(format: "%.1f", customQuantity)) × \(basePortion.description)",
            gramWeight: basePortion.gramWeight * customQuantity,
            modifier: basePortion.modifier,
            isDefault: basePortion.isDefault
        )
        return adjustedPortion.calculateNutrients(from: food)
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack {
                Text("📏 Portion & Serving Size")
                    .font(.headline)
                    .fontWeight(.bold)
                
                Text("Select how you want to measure this food")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Portion Size Picker
            VStack(alignment: .leading, spacing: 15) {
                Text("Available Portions:")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 10) {
                    ForEach(food.availablePortions, id: \.id) { portion in
                        PortionButton(
                            portion: portion,
                            isSelected: selectedPortion.id == portion.id,
                            action: {
                                selectedPortion = portion
                                customQuantity = 1.0
                            }
                        )
                    }
                }
            }
            .padding()
            .background(Color.gray.opacity(0.05))
            .cornerRadius(12)
            
            // Custom Quantity Adjuster
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Quantity:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Button(showingCustomQuantity ? "Use Presets" : "Custom Amount") {
                        showingCustomQuantity.toggle()
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
                
                if showingCustomQuantity {
                    // Custom quantity input
                    HStack {
                        TextField("Amount", value: $customQuantity, format: .number)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 80)
                        
                        Text("× \(selectedPortion.description)")
                            .font(.subheadline)
                        
                        Spacer()
                    }
                } else {
                    // Quick quantity buttons
                    HStack {
                        ForEach([0.5, 1.0, 1.5, 2.0, 3.0], id: \.self) { quantity in
                            Button(action: { customQuantity = quantity }) {
                                Text(quantity == 1.0 ? "1" : String(format: "%.1f", quantity))
                                    .font(.caption)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(customQuantity == quantity ? Color.blue : Color.gray.opacity(0.2))
                                    .foregroundColor(customQuantity == quantity ? .white : .primary)
                                    .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                        }
                        
                        Spacer()
                    }
                }
                
                // Total weight display
                Text("Total weight: \(Int(selectedPortion.gramWeight * customQuantity))g")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.blue.opacity(0.05))
            .cornerRadius(12)
            
            // Live Nutrition Preview
            NutritionPreviewCard(nutrients: currentNutrients)
        }
    }
}

// MARK: - Portion Button Component
struct PortionButton: View {
    let portion: FoodPortion
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                Text(portion.description)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                Text("\(Int(portion.gramWeight))g")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                if portion.isDefault {
                    Text("USDA Standard")
                        .font(.caption2)
                        .foregroundColor(.green)
                        .fontWeight(.bold)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(isSelected ? Color.blue.opacity(0.2) : Color.gray.opacity(0.1))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Live Nutrition Preview
struct NutritionPreviewCard: View {
    let nutrients: PortionNutrients
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Text("🍎 Nutrition for Selected Portion")
                    .font(.subheadline)
                    .fontWeight(.bold)
                
                Spacer()
                
                Text(nutrients.portion.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Key nutrients
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 10) {
                QuickNutrientView(name: "Calories", value: nutrients.calories, unit: "", color: .blue)
                QuickNutrientView(name: "Protein", value: nutrients.protein, unit: "g", color: .green)
                QuickNutrientView(name: "Carbs", value: nutrients.carbs, unit: "g", color: .orange)
                QuickNutrientView(name: "Fat", value: nutrients.fat, unit: "g", color: .purple)
                QuickNutrientView(name: "Fiber", value: nutrients.fiber, unit: "g", color: .brown)
                QuickNutrientView(name: "Sodium", value: nutrients.sodium, unit: "mg", color: .red)
            }
        }
        .padding()
        .background(Color.green.opacity(0.05))
        .cornerRadius(12)
    }
}

struct QuickNutrientView: View {
    let name: String
    let value: Double
    let unit: String
    let color: Color
    
    var body: some View {
        VStack {
            Text(name)
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Text("\(String(format: "%.1f", value))\(unit)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .cornerRadius(6)
    }
}
