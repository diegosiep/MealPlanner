//
//  Patient+CoreDataProperties.swift
//  
//
//  Created by Diego Sierra on 12/07/25.
//
//  This file was automatically generated and should not be edited.
//

public import Foundation
public import CoreData


public typealias PatientCoreDataPropertiesSet = NSSet

extension Patient {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Patient> {
        return NSFetchRequest<Patient>(entityName: "Patient")
    }

    @NSManaged public var activityLevel: String?
    @NSManaged public var allergies: String?
    @NSManaged public var createdDate: Date?
    @NSManaged public var currentHeight: Double
    @NSManaged public var currentWeight: Double
    @NSManaged public var dateOfBirth: Date?
    @NSManaged public var dietaryPreferences: String?
    @NSManaged public var firstName: String?
    @NSManaged public var gender: String?
    @NSManaged public var id: UUID?
    @NSManaged public var lastName: String?
    @NSManaged public var lastUpdated: Date?
    @NSManaged public var medicalConditions: String?
    @NSManaged public var notes: String?
    @NSManaged public var nutritionalGoals: String?
    @NSManaged public var meals: Meal?

}

extension Patient : Identifiable {

}
