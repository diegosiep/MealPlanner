//
//  MealPlannerProApp.swift
//  MealPlannerPro
//
//  Created by Diego Sierra on 03/07/25.
//

import SwiftUI

@main
struct MealPlannerProApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
