//
//  MealPlanningView.swift
//  MealPlannerPro
//
//  Created by Diego Sierra on 03/07/25.
//

import Foundation
import SwiftUI

// MARK: - Meal Planning View
struct MealPlanningView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var mealManager = MealManager()
    @State private var selectedDate = Date()
    @State private var showingMealBuilder = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Date Selection
                DatePicker("Select Date", selection: $selectedDate, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .padding(.horizontal)
                
                // Quick Add Meal Section
                VStack(alignment: .leading, spacing: 10) {
                    Text("Quick Add Meal")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 10) {
                        ForEach(MealType.allCases, id: \.self) { mealType in
                            Button(action: { createQuickMeal(type: mealType) }) {
                                HStack {
                                    Text(mealType.emoji)
                                    Text(mealType.displayName)
                                        .font(.caption)
                                    Spacer()
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundColor(.green)
                                        .font(.caption)
                                }
                                .padding(8)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
                
                Divider()
                
                // Main content: Daily meal plan
                DailyMealPlanView(
                    selectedDate: selectedDate,
                    mealManager: mealManager,
                    showingMealBuilder: $showingMealBuilder
                )
                
                Spacer()
            }
        }
        .sheet(isPresented: $showingMealBuilder) {
            MealBuilderView(mealManager: mealManager)
        }
        .environmentObject(mealManager)
    }
    
    private func createQuickMeal(type: MealType) {
        mealManager.createNewMeal(name: type.displayName, type: type.rawValue, date: selectedDate)
        showingMealBuilder = true
    }
}

// MARK: - Meal Type Enum (if not already added)
enum MealType: String, CaseIterable {
    case breakfast = "breakfast"
    case lunch = "lunch"
    case dinner = "dinner"
    case snack = "snack"
 
}

// MARK: - Daily Meal Plan View
struct DailyMealPlanView: View {
    let selectedDate: Date
    @ObservedObject var mealManager: MealManager
    @Binding var showingMealBuilder: Bool
    
    private var dayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack {
                Text("🍽️ Meal Plan")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text(dayFormatter.string(from: selectedDate))
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            
            // Daily nutrition summary
            DailyNutritionSummaryView(date: selectedDate)
            
            // Meals for the day
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 20) {
                ForEach(MealType.allCases, id: \.self) { mealType in
                    MealCardView(
                        mealType: mealType,
                        date: selectedDate,
                        mealManager: mealManager
                    )
                }
            }
            .padding()
            
            Spacer()
        }
        .padding()
    }
}

// MARK: - Quick placeholder views for the meal system
struct DailyNutritionSummaryView: View {
    let date: Date
    
    var body: some View {
        HStack(spacing: 20) {
            NutrientSummaryCard(title: "Calories", value: "1,847", target: "2,000", color: .blue)
            NutrientSummaryCard(title: "Protein", value: "89g", target: "150g", color: .green)
            NutrientSummaryCard(title: "Carbs", value: "234g", target: "250g", color: .orange)
            NutrientSummaryCard(title: "Fat", value: "67g", target: "78g", color: .purple)
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
}

struct NutrientSummaryCard: View {
    let title: String
    let value: String
    let target: String
    let color: Color
    
    var body: some View {
        VStack {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text("/ \(target)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct MealCardView: View {
    let mealType: MealType
    let date: Date
    @ObservedObject var mealManager: MealManager
    
    var body: some View {
        VStack {
            HStack {
                Text(mealType.emoji)
                    .font(.title)
                
                VStack(alignment: .leading) {
                    Text(mealType.displayName)
                        .font(.headline)
                    
                    Text("245 calories") // Placeholder
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            Spacer()
            
            Button("Add Foods") {
                // We'll implement this
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(height: 120)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
}

struct MealBuilderView: View {
    @ObservedObject var mealManager: MealManager
    
    var body: some View {
        VStack {
            Text("🔨 Meal Builder")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Advanced meal building coming next!")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(minWidth: 600, minHeight: 400)
    }
}

// MARK: - Meal Manager
class MealManager: ObservableObject {
    @Published var currentMeal: Meal?
    
    func createNewMeal(name: String, type: String, date: Date) {
        print("Creating meal: \(name) for \(date)")
        // We'll implement Core Data creation here
    }
}
