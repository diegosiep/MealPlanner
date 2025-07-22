import SwiftUI

@main
struct MealPlannerProApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    setupDemoMode()
                }
        }
    }
    
    private func setupDemoMode() {
        // Clear any blocking settings
        UserDefaults.standard.removeObject(forKey: "api_keys_required")
        UserDefaults.standard.removeObject(forKey: "needs_api_setup")
        
        // Set demo keys so app doesn't crash
        let keyManager = SecureAPIKeyManager.shared
        if !keyManager.hasAPIKey(for: .usdaAPI) {
            _ = keyManager.storeAPIKey("DEMO_MODE", for: .usdaAPI)
        }
        
        print("✅ App ready - demo mode enabled if no real keys")
    }
}
