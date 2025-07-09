import SwiftUI

// MARK: - Enhanced AI Meal Suggestion View with USDA Verification
struct EnhancedAIMealSuggestionView: View {
    let verifiedSuggestion: VerifiedMealPlanSuggestion
    @Binding var isVerifying: Bool
    let onApprove: () -> Void
    let onRegenerate: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header with Verification Status
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("🤖 AI Suggestion")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    // USDA Verification Badge
                    USDAVerificationBadge(verifiedSuggestion: verifiedSuggestion)
                }
                
                Text(verifiedSuggestion.originalAISuggestion.mealName)
                    .font(.headline)
                    .foregroundColor(.blue)
                
                // Verification Summary
                USDAVerificationSummary(verifiedSuggestion: verifiedSuggestion)
            }
            
            // Verified Foods List
            VStack(alignment: .leading, spacing: 12) {
                Text("Suggested Foods (USDA Verified):")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                ForEach(Array(verifiedSuggestion.verifiedFoods.enumerated()), id: \.offset) { index, verifiedFood in
                    VerifiedFoodRowView(verifiedFood: verifiedFood)
                }
            }
            
            // Verified Nutrition Summary
            VStack(alignment: .leading, spacing: 10) {
                Text("Total Nutrition (USDA Verified):")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                HStack {
                    VerifiedNutritionItem(
                        title: "Calories",
                        verified: "\(Int(verifiedSuggestion.verifiedTotalNutrition.calories))",
                        target: "\(verifiedSuggestion.originalAISuggestion.targetRequest.targetCalories)",
                        accuracy: verifiedSuggestion.detailedAccuracy.calories,
                        color: .blue
                    )
                    
                    VerifiedNutritionItem(
                        title: "Protein",
                        verified: "\(Int(verifiedSuggestion.verifiedTotalNutrition.protein))g",
                        target: "\(Int(verifiedSuggestion.originalAISuggestion.targetRequest.targetProtein))g",
                        accuracy: verifiedSuggestion.detailedAccuracy.protein,
                        color: .green
                    )
                    
                    VerifiedNutritionItem(
                        title: "Carbs",
                        verified: "\(Int(verifiedSuggestion.verifiedTotalNutrition.carbs))g",
                        target: "\(Int(verifiedSuggestion.originalAISuggestion.targetRequest.targetCarbs))g",
                        accuracy: verifiedSuggestion.detailedAccuracy.carbs,
                        color: .orange
                    )
                    
                    VerifiedNutritionItem(
                        title: "Fat",
                        verified: "\(Int(verifiedSuggestion.verifiedTotalNutrition.fat))g",
                        target: "\(Int(verifiedSuggestion.originalAISuggestion.targetRequest.targetFat))g",
                        accuracy: verifiedSuggestion.detailedAccuracy.fat,
                        color: .purple
                    )
                }
            }
            
            // USDA Verification Notes
            VStack(alignment: .leading, spacing: 8) {
                Text("🔍 USDA Verification Details:")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(verifiedSuggestion.verificationNotes)
                    .font(.caption)
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
            }
            
            // Original AI Notes (still valuable)
            if !verifiedSuggestion.originalAISuggestion.preparationNotes.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("👨‍🍳 Preparation Notes:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(verifiedSuggestion.originalAISuggestion.preparationNotes)
                        .font(.caption)
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
                }
            }
            
            if !verifiedSuggestion.originalAISuggestion.nutritionistNotes.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("💡 Nutritionist Notes:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(verifiedSuggestion.originalAISuggestion.nutritionistNotes)
                        .font(.caption)
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                }
            }
            
            // Action Buttons
            HStack {
                Button(action: onRegenerate) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Try Again")
                    }
                    .padding()
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                
                Spacer()
                
                Button(action: onApprove) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Approve USDA-Verified Plan")
                    }
                    .padding()
                    .background(verifiedSuggestion.overallAccuracy > 0.8 ? Color.green : Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color.green.opacity(0.05))
        .cornerRadius(15)
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(verifiedSuggestion.overallAccuracy > 0.8 ? Color.green : Color.orange, lineWidth: 2)
        )
    }
}

// MARK: - USDA Verification Badge
struct USDAVerificationBadge: View {
    let verifiedSuggestion: VerifiedMealPlanSuggestion
    
    private var verificationStatus: (text: String, color: Color, icon: String) {
        let verifiedCount = verifiedSuggestion.verifiedFoods.filter { $0.isVerified }.count
        let totalCount = verifiedSuggestion.verifiedFoods.count
        
        if verifiedCount == totalCount {
            return ("100% USDA Verified", .green, "checkmark.seal.fill")
        } else if verifiedCount > 0 {
            return ("\(Int(Double(verifiedCount)/Double(totalCount) * 100))% USDA Verified", .orange, "checkmark.seal")
        } else {
            return ("AI Estimate Only", .red, "brain.head.profile")
        }
    }
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: verificationStatus.icon)
                .font(.caption)
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(verificationStatus.text)
                    .font(.caption)
                    .fontWeight(.bold)
                
                Text("\(Int(verifiedSuggestion.overallAccuracy * 100))% accurate")
                    .font(.caption2)
            }
        }
        .foregroundColor(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(verificationStatus.color)
        .cornerRadius(8)
    }
}

// MARK: - USDA Verification Summary
struct USDAVerificationSummary: View {
    let verifiedSuggestion: VerifiedMealPlanSuggestion
    
    var body: some View {
        let verifiedCount = verifiedSuggestion.verifiedFoods.filter { $0.isVerified }.count
        let totalCount = verifiedSuggestion.verifiedFoods.count
        
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            
            Text("\(verifiedCount) of \(totalCount) foods verified with USDA database")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text("Accuracy: \(Int(verifiedSuggestion.overallAccuracy * 100))%")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(verifiedSuggestion.overallAccuracy > 0.8 ? .green : .orange)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(6)
    }
}

// MARK: - Verified Food Row
struct VerifiedFoodRowView: View {
    let verifiedFood: VerifiedSuggestedFood
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(verifiedFood.originalAISuggestion.portionDescription)
                        .font(.caption)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    // Verification Status Icon
                    Image(systemName: verifiedFood.isVerified ? "checkmark.circle.fill" : "questionmark.circle")
                        .foregroundColor(verifiedFood.isVerified ? .green : .orange)
                        .font(.caption)
                }
                
                if verifiedFood.isVerified, let usdaFood = verifiedFood.matchedUSDAFood {
                    Text("USDA: \(usdaFood.description)")
                        .font(.caption2)
                        .foregroundColor(.green)
                        .lineLimit(2)
                } else {
                    Text("AI Estimate: \(verifiedFood.originalAISuggestion.name)")
                        .font(.caption2)
                        .foregroundColor(.orange)
                        .lineLimit(2)
                }
                
                if verifiedFood.isVerified {
                    Text("Match confidence: \(Int(verifiedFood.matchConfidence * 100))%")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(verifiedFood.verifiedNutrition.calories)) cal")
                    .font(.caption)
                    .fontWeight(.medium)
                
                Text("\(Int(verifiedFood.originalAISuggestion.gramWeight))g")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(verifiedFood.isVerified ? Color.green.opacity(0.05) : Color.orange.opacity(0.05))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(verifiedFood.isVerified ? Color.green.opacity(0.3) : Color.orange.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Verified Nutrition Item
struct VerifiedNutritionItem: View {
    let title: String
    let verified: String
    let target: String
    let accuracy: Double
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Text(verified)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text("/ \(target)")
                .font(.caption2)
                .foregroundColor(.secondary)
            
            // Accuracy indicator
            Circle()
                .fill(accuracy > 0.9 ? Color.green : (accuracy > 0.7 ? Color.orange : Color.red))
                .frame(width: 6, height: 6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .cornerRadius(6)
    }
}
