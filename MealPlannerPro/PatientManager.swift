//
//  PatientManager.swift
//  MealPlannerPro
//
//  Created by Diego Sierra on 03/07/25.
//

import Foundation
import CoreData

// MARK: - Patient Management System
class PatientManager: ObservableObject {
    let container: NSPersistentContainer
    @Published var patients: [Patient] = []
    @Published var currentPatient: Patient?
    
    init(container: NSPersistentContainer) {
        self.container = container
        fetchPatients()
    }
    
    func fetchPatients() {
        let request: NSFetchRequest<Patient> = Patient.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Patient.lastName, ascending: true)]
        
        do {
            patients = try container.viewContext.fetch(request)
        } catch {
            print("Error fetching patients: \(error)")
        }
    }
    
    func createNewPatient(
        firstName: String,
        lastName: String,
        dateOfBirth: Date,
        gender: String,
        height: Double,
        weight: Double,
        activityLevel: String,
        medicalConditions: [String] = [],
        allergies: [String] = [],
        dietaryPreferences: [String] = []
    ) -> Patient {
        let context = container.viewContext
        let patient = Patient(context: context)
        
        patient.id = UUID()
        patient.firstName = firstName
        patient.lastName = lastName
        patient.dateOfBirth = dateOfBirth
        patient.gender = gender
        patient.currentHeight = height
        patient.currentWeight = weight
        patient.activityLevel = activityLevel
        patient.medicalConditions = medicalConditions.joined(separator: ",")
        patient.allergies = allergies.joined(separator: ",")
        patient.dietaryPreferences = dietaryPreferences.joined(separator: ",")
        patient.createdDate = Date()
        patient.lastUpdated = Date()
        
        // Calculate nutritional goals
        patient.nutritionalGoals = calculateNutritionalGoals(for: patient).toJSONString()
        
        do {
            try context.save()
            fetchPatients()
        } catch {
            print("Error saving patient: \(error)")
        }
        
        return patient
    }
    
    private func calculateNutritionalGoals(for patient: Patient) -> NutritionalGoals {
        let age = Calendar.current.dateComponents([.year], from: patient.dateOfBirth ?? Date(), to: Date()).year ?? 25
        let isMale = patient.gender?.lowercased() == "male"
        
        // Calculate BMR using Mifflin-St Jeor Equation
        let bmr = isMale ?
            (10 * patient.currentWeight) + (6.25 * patient.currentHeight) - (5 * Double(age)) + 5 :
            (10 * patient.currentWeight) + (6.25 * patient.currentHeight) - (5 * Double(age)) - 161
        
        // Adjust for activity level
        let activityMultiplier: Double = {
            switch patient.activityLevel?.lowercased() {
            case "sedentary": return 1.2
            case "lightly active": return 1.375
            case "moderately active": return 1.55
            case "very active": return 1.725
            case "extremely active": return 1.9
            default: return 1.375
            }
        }()
        
        let calories = bmr * activityMultiplier
        
        return NutritionalGoals(
            calories: calories,
            protein: calories * 0.15 / 4, // 15% of calories
            carbohydrates: calories * 0.55 / 4, // 55% of calories
            fat: calories * 0.30 / 9, // 30% of calories
            fiber: 25, // Standard recommendation
            sodium: 2300, // mg
            potassium: 4700, // mg
            calcium: isMale ? (age > 70 ? 1200 : 1000) : (age > 50 ? 1200 : 1000),
            iron: isMale ? 8 : (age > 50 ? 8 : 18),
            vitaminD: 15, // mcg
            vitaminC: isMale ? 90 : 75, // mg
            vitaminB12: 2.4, // mcg
            folate: 400 // mcg DFE
        )
    }
}

// MARK: - Nutritional Goals Model
struct NutritionalGoals: Codable {
    let calories: Double
    let protein: Double
    let carbohydrates: Double
    let fat: Double
    let fiber: Double
    let sodium: Double
    let potassium: Double
    let calcium: Double
    let iron: Double
    let vitaminD: Double
    let vitaminC: Double
    let vitaminB12: Double
    let folate: Double
    
    func toJSONString() -> String {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(self),
           let jsonString = String(data: data, encoding: .utf8) {
            return jsonString
        }
        return "{}"
    }
    
    static func fromJSONString(_ jsonString: String) -> NutritionalGoals? {
        let decoder = JSONDecoder()
        if let data = jsonString.data(using: .utf8),
           let goals = try? decoder.decode(NutritionalGoals.self, from: data) {
            return goals
        }
        return nil
    }
}
