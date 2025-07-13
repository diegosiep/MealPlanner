//
//  DietaryEvaluationService.swift
//  MealPlannerPro
//
//  Created by Diego Sierra on [current date]
//

import Foundation

// MARK: - Comprehensive Dietary Evaluation Service
class DietaryEvaluationService: ObservableObject {
    
    // MARK: - Daily Dietary Value Analysis
    func evaluateDailyNutrition(
        actualNutrition: ComprehensiveNutrients,
        targets: NutritionalGoals,
        patientProfile: NutritionPatientProfile? = nil
    ) -> DietaryEvaluationReport {
        
        let macroEvaluation = evaluateMacronutrients(
            actual: actualNutrition,
            targets: targets
        )
        
        let microEvaluation = evaluateMicronutrients(
            actual: actualNutrition,
            targets: targets,
            patientProfile: patientProfile
        )
        
        let overallScore = calculateOverallNutritionalScore(
            macroEvaluation: macroEvaluation,
            microEvaluation: microEvaluation
        )
        
        let recommendations = generateNutritionalRecommendations(
            macroEvaluation: macroEvaluation,
            microEvaluation: microEvaluation,
            patientProfile: patientProfile
        )
        
        let warnings = identifyNutritionalWarnings(
            actual: actualNutrition,
            targets: targets,
            patientProfile: patientProfile
        )
        
        return DietaryEvaluationReport(
            overallScore: overallScore,
            macronutrientEvaluation: macroEvaluation,
            micronutrientEvaluation: microEvaluation,
            recommendations: recommendations,
            warnings: warnings,
            evaluationDate: Date()
        )
    }
    
    // MARK: - Macronutrient Evaluation
    private func evaluateMacronutrients(
        actual: ComprehensiveNutrients,
        targets: NutritionalGoals
    ) -> MacronutrientEvaluation {
        
        let calorieStatus = evaluateNutrientStatus(
            actual: actual.energy,
            target: targets.calories,
            optimalRange: (0.95, 1.05), // 95-105%
            acceptableRange: (0.85, 1.15) // 85-115%
        )
        
        let proteinStatus = evaluateNutrientStatus(
            actual: actual.protein,
            target: targets.protein,
            optimalRange: (0.90, 1.10),
            acceptableRange: (0.80, 1.20)
        )
        
        let carbStatus = evaluateNutrientStatus(
            actual: actual.carbohydrate,
            target: targets.carbohydrates,
            optimalRange: (0.90, 1.10),
            acceptableRange: (0.75, 1.25)
        )
        
        let fatStatus = evaluateNutrientStatus(
            actual: actual.totalFat,
            target: targets.fat,
            optimalRange: (0.85, 1.15),
            acceptableRange: (0.70, 1.30)
        )
        
        let fiberStatus = evaluateNutrientStatus(
            actual: actual.fiber,
            target: targets.fiber,
            optimalRange: (0.90, 1.50), // Fiber can be higher
            acceptableRange: (0.70, 2.00)
        )
        
        return MacronutrientEvaluation(
            calories: calorieStatus,
            protein: proteinStatus,
            carbohydrates: carbStatus,
            fat: fatStatus,
            fiber: fiberStatus,
            proteinPercentage: (actual.protein * 4) / actual.energy * 100,
            carbPercentage: (actual.carbohydrate * 4) / actual.energy * 100,
            fatPercentage: (actual.totalFat * 9) / actual.energy * 100
        )
    }
    
    // MARK: - Micronutrient Evaluation
    private func evaluateMicronutrients(
        actual: ComprehensiveNutrients,
        targets: NutritionalGoals,
        patientProfile: NutritionPatientProfile?
    ) -> MicronutrientEvaluation {
        
        // Essential vitamins
        let vitaminEvaluations = [
            "Vitamin C": evaluateNutrientStatus(
                actual: actual.vitaminC,
                target: targets.vitaminC,
                optimalRange: (0.90, 2.00),
                acceptableRange: (0.70, 3.00)
            ),
            "Vitamin D": evaluateNutrientStatus(
                actual: actual.vitaminD,
                target: targets.vitaminD,
                optimalRange: (0.90, 1.50),
                acceptableRange: (0.70, 2.00)
            ),
            "Vitamin B12": evaluateNutrientStatus(
                actual: actual.vitaminB12,
                target: targets.vitaminB12,
                optimalRange: (0.90, 2.00),
                acceptableRange: (0.70, 3.00)
            ),
            "Folate": evaluateNutrientStatus(
                actual: actual.folate,
                target: targets.folate,
                optimalRange: (0.90, 1.50),
                acceptableRange: (0.70, 2.00)
            )
        ]
        
        // Essential minerals
        let mineralEvaluations = [
            "Calcium": evaluateNutrientStatus(
                actual: actual.calcium,
                target: targets.calcium,
                optimalRange: (0.90, 1.20),
                acceptableRange: (0.70, 1.50)
            ),
            "Iron": evaluateNutrientStatus(
                actual: actual.iron,
                target: targets.iron,
                optimalRange: (0.90, 1.50),
                acceptableRange: (0.70, 2.00)
            ),
            "Potassium": evaluateNutrientStatus(
                actual: actual.potassium,
                target: targets.potassium,
                optimalRange: (0.85, 1.15),
                acceptableRange: (0.70, 1.30)
            ),
            "Sodium": evaluateNutrientStatus(
                actual: actual.sodium,
                target: targets.sodium,
                optimalRange: (0.50, 0.90), // Lower is better for sodium
                acceptableRange: (0.30, 1.10)
            )
        ]
        
        return MicronutrientEvaluation(
            vitamins: vitaminEvaluations,
            minerals: mineralEvaluations,
            overallMicronutrientScore: calculateMicronutrientScore(
                vitamins: vitaminEvaluations,
                minerals: mineralEvaluations
            )
        )
    }
    
    // MARK: - Nutrient Status Evaluation
    private func evaluateNutrientStatus(
        actual: Double,
        target: Double,
        optimalRange: (Double, Double),
        acceptableRange: (Double, Double)
    ) -> NutrientStatus {
        
        guard target > 0 else {
            return NutrientStatus(
                actualValue: actual,
                targetValue: target,
                percentageOfTarget: 0,
                status: .unknown,
                score: 0.0
            )
        }
        
        let percentage = actual / target
        let status: NutrientLevel
        let score: Double
        
        if percentage >= optimalRange.0 && percentage <= optimalRange.1 {
            status = .optimal
            score = 1.0
        } else if percentage >= acceptableRange.0 && percentage <= acceptableRange.1 {
            status = .adequate
            if percentage < optimalRange.0 {
                // Below optimal but acceptable
                let range = optimalRange.0 - acceptableRange.0
                let position = percentage - acceptableRange.0
                score = 0.7 + (position / range) * 0.3
            } else {
                // Above optimal but acceptable
                let range = acceptableRange.1 - optimalRange.1
                let position = acceptableRange.1 - percentage
                score = 0.7 + (position / range) * 0.3
            }
        } else if percentage < acceptableRange.0 {
            status = .deficient
            score = max(0.0, 0.7 * (percentage / acceptableRange.0))
        } else {
            status = .excessive
            score = max(0.0, 0.7 * (acceptableRange.1 / percentage))
        }
        
        return NutrientStatus(
            actualValue: actual,
            targetValue: target,
            percentageOfTarget: percentage * 100,
            status: status,
            score: score
        )
    }
    
    // MARK: - Overall Score Calculation
    private func calculateOverallNutritionalScore(
        macroEvaluation: MacronutrientEvaluation,
        microEvaluation: MicronutrientEvaluation
    ) -> Double {
        
        // Weight macronutrients more heavily (60%) than micronutrients (40%)
        let macroScore = (
            macroEvaluation.calories.score * 0.30 +
            macroEvaluation.protein.score * 0.25 +
            macroEvaluation.carbohydrates.score * 0.20 +
            macroEvaluation.fat.score * 0.15 +
            macroEvaluation.fiber.score * 0.10
        )
        
        let microScore = microEvaluation.overallMicronutrientScore
        
        return (macroScore * 0.60) + (microScore * 0.40)
    }
    
    private func calculateMicronutrientScore(
        vitamins: [String: NutrientStatus],
        minerals: [String: NutrientStatus]
    ) -> Double {
        
        let allNutrients = Array(vitamins.values) + Array(minerals.values)
        guard !allNutrients.isEmpty else { return 0.0 }
        
        let totalScore = allNutrients.reduce(0.0) { $0 + $1.score }
        return totalScore / Double(allNutrients.count)
    }
    
    // MARK: - Recommendations Generation
    private func generateNutritionalRecommendations(
        macroEvaluation: MacronutrientEvaluation,
        microEvaluation: MicronutrientEvaluation,
        patientProfile: NutritionPatientProfile?
    ) -> [NutritionalRecommendation] {
        
        var recommendations: [NutritionalRecommendation] = []
        
        // Macronutrient recommendations
        if macroEvaluation.calories.status == .deficient {
            recommendations.append(NutritionalRecommendation(
                type: .increase,
                nutrient: "Calorías",
                priority: .high,
                message: "Aumentar ingesta calórica con alimentos densos en nutrientes",
                suggestedActions: ["Agregar frutos secos", "Incluir aguacate", "Aumentar porciones de granos integrales"]
            ))
        } else if macroEvaluation.calories.status == .excessive {
            recommendations.append(NutritionalRecommendation(
                type: .decrease,
                nutrient: "Calorías",
                priority: .high,
                message: "Reducir ingesta calórica manteniendo densidad nutricional",
                suggestedActions: ["Reducir porciones", "Elegir alimentos menos calóricos", "Aumentar vegetales"]
            ))
        }
        
        if macroEvaluation.protein.status == .deficient {
            recommendations.append(NutritionalRecommendation(
                type: .increase,
                nutrient: "Proteína",
                priority: .high,
                message: "Aumentar fuentes de proteína de alta calidad",
                suggestedActions: ["Incluir legumbres", "Agregar pescado", "Considerar quinoa"]
            ))
        }
        
        if macroEvaluation.fiber.status == .deficient {
            recommendations.append(NutritionalRecommendation(
                type: .increase,
                nutrient: "Fibra",
                priority: .medium,
                message: "Aumentar alimentos ricos en fibra",
                suggestedActions: ["Más vegetales", "Frutas con cáscara", "Granos integrales"]
            ))
        }
        
        // Micronutrient recommendations
        for (nutrient, status) in microEvaluation.vitamins {
            if status.status == .deficient {
                recommendations.append(generateMicronutrientRecommendation(nutrient: nutrient))
            }
        }
        
        for (nutrient, status) in microEvaluation.minerals {
            if status.status == .deficient {
                recommendations.append(generateMicronutrientRecommendation(nutrient: nutrient))
            }
        }
        
        return recommendations
    }
    
    private func generateMicronutrientRecommendation(nutrient: String) -> NutritionalRecommendation {
        let foodSources: [String]
        let message: String
        
        switch nutrient {
        case "Vitamin C":
            foodSources = ["Cítricos", "Pimientos", "Brócoli", "Fresas"]
            message = "Incluir más alimentos ricos en vitamina C"
        case "Vitamin D":
            foodSources = ["Pescado graso", "Huevos", "Exposición solar"]
            message = "Aumentar alimentos con vitamina D y exposición solar"
        case "Calcium":
            foodSources = ["Lácteos", "Vegetales verdes", "Almendras", "Sardinas"]
            message = "Incluir más fuentes de calcio"
        case "Iron":
            foodSources = ["Carnes magras", "Espinacas", "Legumbres", "Quinoa"]
            message = "Aumentar alimentos ricos en hierro"
        default:
            foodSources = ["Alimentos variados", "Dieta balanceada"]
            message = "Incluir más fuentes de \(nutrient)"
        }
        
        return NutritionalRecommendation(
            type: .increase,
            nutrient: nutrient,
            priority: .medium,
            message: message,
            suggestedActions: foodSources
        )
    }
    
    // MARK: - Warning Identification
    private func identifyNutritionalWarnings(
        actual: ComprehensiveNutrients,
        targets: NutritionalGoals,
        patientProfile: NutritionPatientProfile?
    ) -> [NutritionalWarning] {
        
        var warnings: [NutritionalWarning] = []
        
        // High sodium warning
        if actual.sodium > targets.sodium * 1.2 {
            warnings.append(NutritionalWarning(
                type: .excessive,
                nutrient: "Sodio",
                severity: .high,
                message: "Ingesta de sodio excesiva puede aumentar riesgo cardiovascular",
                recommendedAction: "Reducir alimentos procesados y sal añadida"
            ))
        }
        
        // Low protein warning
        if actual.protein < targets.protein * 0.7 {
            warnings.append(NutritionalWarning(
                type: .deficient,
                nutrient: "Proteína",
                severity: .medium,
                message: "Ingesta de proteína insuficiente puede afectar masa muscular",
                recommendedAction: "Incluir más fuentes de proteína completa"
            ))
        }
        
        // Excessive sugar warning
        if actual.addedSugars > 50 { // WHO recommendation: <10% of calories
            warnings.append(NutritionalWarning(
                type: .excessive,
                nutrient: "Azúcares añadidos",
                severity: .medium,
                message: "Alto consumo de azúcares añadidos",
                recommendedAction: "Limitar bebidas azucaradas y dulces procesados"
            ))
        }
        
        return warnings
    }
}

// MARK: - Data Models

struct DietaryEvaluationReport {
    let overallScore: Double
    let macronutrientEvaluation: MacronutrientEvaluation
    let micronutrientEvaluation: MicronutrientEvaluation
    let recommendations: [NutritionalRecommendation]
    let warnings: [NutritionalWarning]
    let evaluationDate: Date
    
    var scoreGrade: String {
        switch overallScore {
        case 0.9...1.0: return "Excelente"
        case 0.8..<0.9: return "Muy Bueno"
        case 0.7..<0.8: return "Bueno"
        case 0.6..<0.7: return "Regular"
        default: return "Necesita Mejora"
        }
    }
}

struct MacronutrientEvaluation {
    let calories: NutrientStatus
    let protein: NutrientStatus
    let carbohydrates: NutrientStatus
    let fat: NutrientStatus
    let fiber: NutrientStatus
    let proteinPercentage: Double
    let carbPercentage: Double
    let fatPercentage: Double
}

struct MicronutrientEvaluation {
    let vitamins: [String: NutrientStatus]
    let minerals: [String: NutrientStatus]
    let overallMicronutrientScore: Double
}

struct NutrientStatus {
    let actualValue: Double
    let targetValue: Double
    let percentageOfTarget: Double
    let status: NutrientLevel
    let score: Double
}

enum NutrientLevel {
    case deficient, adequate, optimal, excessive, unknown
    
    var color: String {
        switch self {
        case .deficient: return "red"
        case .adequate: return "orange"
        case .optimal: return "green"
        case .excessive: return "purple"
        case .unknown: return "gray"
        }
    }
    
    var description: String {
        switch self {
        case .deficient: return "Deficiente"
        case .adequate: return "Adecuado"
        case .optimal: return "Óptimo"
        case .excessive: return "Excesivo"
        case .unknown: return "Desconocido"
        }
    }
}

struct NutritionalRecommendation {
    let type: RecommendationType
    let nutrient: String
    let priority: RecommendationPriority
    let message: String
    let suggestedActions: [String]
}

enum RecommendationType {
    case increase, decrease, maintain, modify
}

enum RecommendationPriority {
    case low, medium, high, critical
}

struct NutritionalWarning {
    let type: WarningType
    let nutrient: String
    let severity: WarningSeverity
    let message: String
    let recommendedAction: String
}

enum WarningType {
    case deficient, excessive, imbalanced
}

enum WarningSeverity {
    case low, medium, high, critical
}

struct NutritionPatientProfile {
    let age: Int
    let gender: String
    let weight: Double
    let height: Double
    let activityLevel: String
    let medicalConditions: [String]
    let medications: [String]
}
