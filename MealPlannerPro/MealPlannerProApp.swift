import SwiftUI
import CoreData

@main
struct MealPlannerProApp: App {
    let persistenceController = PersistenceController.shared
    
    @StateObject private var languageManager = LanguageManager.shared
    @StateObject private var foodSelectionManager = ManualFoodSelectionManager.shared
    @StateObject private var pdfService = RobustPDFService.shared
    
    private var hasRequiredAPIKeys: Bool {
        let keyManager = SecureAPIKeyManager.shared
        return keyManager.hasAPIKey(for: .usdaAPI)
    }
    
    var body: some Scene {
        WindowGroup {
            VStack {
                // API Key Setup Check
                if !hasRequiredAPIKeys {
                    APIKeySetupUtility()
                        .padding()
                        .transition(.opacity)
                } else {
                    ContentView()
                        .environment(\.managedObjectContext, persistenceController.container.viewContext)
                        .environmentObject(languageManager)
                        .environmentObject(foodSelectionManager)
                        .environmentObject(pdfService)
                }
            }
            .frame(minWidth: 1200, minHeight: 800)
            .background(Color.compatibleWindowBackground)
        }
        .windowStyle(.automatic)
        .windowToolbarStyle(.unified)
        .commands {
            // File Menu additions
            CommandGroup(after: .newItem) {
                Button("New Patient...") {
                    NotificationCenter.default.post(name: .createNewPatient, object: nil)
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])
                
                Divider()
                
                Button("Export PDF Report...") {
                    NotificationCenter.default.post(name: .exportPDFReport, object: nil)
                }
                .keyboardShortcut("e", modifiers: .command)
            }
            
            // View Menu additions
            CommandGroup(after: .sidebar) {
                Button("Toggle Language") {
                    languageManager.toggleLanguage()
                }
                .keyboardShortcut("l", modifiers: [.command, .shift])
            }
        }
    }
}

// MARK: - Custom Notifications
extension Notification.Name {
    static let createNewPatient = Notification.Name("createNewPatient")
    static let exportPDFReport = Notification.Name("exportPDFReport")
}
