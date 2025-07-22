import SwiftUI

struct ContentView: View {
    @StateObject private var apiManager = APIManager()
    @State private var selectedTab = 0
    @State private var showingAPISetup = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with API Status
            headerView
            
            // Main Content
            TabView(selection: $selectedTab) {
                SearchTab()
                    .tabItem {
                        Image(systemName: "magnifyingglass")
                        Text("Search")
                    }
                    .tag(0)
                
                FavoritesTab()
                    .tabItem {
                        Image(systemName: "heart.fill")
                        Text("My Foods")
                    }
                    .tag(1)
                
                AssistantTab()
                    .tabItem {
                        Image(systemName: "brain.head.profile")
                        Text("AI Assistant")
                    }
                    .tag(2)
                
                MealPlanTab()
                    .tabItem {
                        Image(systemName: "calendar")
                        Text("Planner")
                    }
                    .tag(3)
            }
        }
        .sheet(isPresented: $showingAPISetup) {
            APISetupView(apiManager: apiManager)
        }
    }
    
    // MARK: - Header View
    private var headerView: some View {
        HStack {
            // App Title
            VStack(alignment: .leading, spacing: 2) {
                Text("MealPlanner Pro")
                    .font(.title2)
                    .fontWeight(.bold)
                
                if apiManager.isInDemoMode {
                    Text("Demo Mode - Limited Features")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            
            Spacer()
            
            // API Status & Settings
            HStack(spacing: 12) {
                // Status Indicators
                HStack(spacing: 8) {
                    StatusDot(label: "USDA", isActive: apiManager.hasUSDAKey, color: .green)
                    StatusDot(label: "AI", isActive: apiManager.hasClaudeKey, color: .blue)
                }
                
                // Settings Button
                Button(action: {
                    showingAPISetup = true
                }) {
                    Image(systemName: "gear")
                        .font(.title3)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
    }
}

// MARK: - API Manager
class APIManager: ObservableObject {
    @Published var hasUSDAKey = false
    @Published var hasClaudeKey = false
    @Published var isInDemoMode = false
    
    private let keyManager = SecureAPIKeyManager.shared
    
    init() {
        updateStatus()
    }
    
    func updateStatus() {
        hasUSDAKey = keyManager.hasAPIKey(for: .usdaAPI) && !keyManager.isInDemoMode
        hasClaudeKey = keyManager.hasAPIKey(for: .claudeAPI)
        isInDemoMode = keyManager.isInDemoMode
    }
    
    func saveKeys(usdaKey: String, claudeKey: String) -> Bool {
        var success = true
        
        if !usdaKey.isEmpty {
            success = keyManager.storeAPIKey(usdaKey, for: .usdaAPI)
        }
        
        if !claudeKey.isEmpty && success {
            success = keyManager.storeAPIKey(claudeKey, for: .claudeAPI) && success
        }
        
        if success {
            updateStatus()
        }
        
        return success
    }
}

// MARK: - Status Dot Component
struct StatusDot: View {
    let label: String
    let isActive: Bool
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(isActive ? color : Color.gray)
                .frame(width: 8, height: 8)
            
            Text(label)
                .font(.caption)
                .foregroundColor(isActive ? .primary : .secondary)
        }
    }
}

// MARK: - API Setup View
struct APISetupView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var apiManager: APIManager
    
    @State private var usdaKey = ""
    @State private var claudeKey = ""
    @State private var showingSuccess = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "key.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.blue)
                    
                    Text("API Keys Setup")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    if apiManager.isInDemoMode {
                        Text("Currently in demo mode. Add real API keys for full functionality.")
                            .font(.subheadline)
                            .foregroundColor(.orange)
                            .multilineTextAlignment(.center)
                    }
                }
                
                // USDA Key Section
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("USDA Food Database API Key")
                            .font(.headline)
                        Text("(Required)")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    
                    TextField("Enter your USDA API key...", text: $usdaKey)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Link("Get free API key here", destination: URL(string: "https://fdc.nal.usda.gov/api-guide.html")!)
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                
                // Claude Key Section
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Claude AI API Key")
                            .font(.headline)
                        Text("(Optional)")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    
                    TextField("Enter Claude API key (optional)...", text: $claudeKey)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Link("Get Claude API key here", destination: URL(string: "https://console.anthropic.com/")!)
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                
                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                }
                
                Spacer()
                
                // Action Buttons
                VStack(spacing: 12) {
                    Button(action: saveKeys) {
                        HStack {
                            Image(systemName: "checkmark")
                            Text("Save API Keys")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(usdaKey.isEmpty ? Color.gray : Color.blue)
                        .cornerRadius(12)
                    }
                    .disabled(usdaKey.isEmpty)
                    
                    Button("Continue with Demo Mode") {
                        dismiss()
                    }
                    .foregroundColor(.secondary)
                }
            }
            .padding(24)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .alert("Success!", isPresented: $showingSuccess) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("API keys saved successfully!")
        }
    }
    
    private func saveKeys() {
        errorMessage = ""
        
        let success = apiManager.saveKeys(usdaKey: usdaKey, claudeKey: claudeKey)
        
        if success {
            showingSuccess = true
            usdaKey = ""
            claudeKey = ""
        } else {
            errorMessage = "Failed to save API keys. Please try again."
        }
    }
}

// MARK: - Tab Views (Renamed to avoid conflicts)
struct SearchTab: View {
    @StateObject private var foodService = NewUSDAService()
    @State private var searchText = ""
    @State private var searchResults: [SimpleFoodItem] = []
    @State private var isSearching = false
    
    var body: some View {
        VStack {
            // Search Bar
            HStack {
                TextField("Search foods...", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onSubmit {
                        performSearch()
                    }
                
                Button("Search") {
                    performSearch()
                }
                .disabled(searchText.isEmpty || isSearching)
            }
            .padding()
            
            // Results
            if isSearching {
                ProgressView("Searching...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if searchResults.isEmpty && !searchText.isEmpty {
                Text("No results found")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(searchResults) { food in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(food.name)
                            .font(.headline)
                        Text("\(food.calories) calories per 100g")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Food Search")
    }
    
    private func performSearch() {
        guard !searchText.isEmpty else { return }
        
        isSearching = true
        
        Task {
            let results = await foodService.searchFoods(query: searchText)
            
            await MainActor.run {
                searchResults = results
                isSearching = false
            }
        }
    }
}

struct FavoritesTab: View {
    var body: some View {
        VStack {
            Text("My Foods")
                .font(.title)
            Text("Your saved foods will appear here")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}

struct AssistantTab: View {
    var body: some View {
        VStack {
            Text("AI Assistant")
                .font(.title)
            Text("AI meal planning features")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}

struct MealPlanTab: View {
    var body: some View {
        VStack {
            Text("Meal Planner")
                .font(.title)
            Text("Plan your meals here")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - New USDA Food Service (Renamed to avoid conflicts)
class NewUSDAService: ObservableObject {
    private let keyManager = SecureAPIKeyManager.shared
    
    func searchFoods(query: String) async -> [SimpleFoodItem] {
        // Check if we have a real API key
        guard let apiKey = keyManager.usdaAPIKey, !keyManager.isInDemoMode else {
            // Return demo data
            return getDemoFoods(matching: query)
        }
        
        // Real API call
        return await performRealSearch(query: query, apiKey: apiKey)
    }
    
    private func getDemoFoods(matching query: String) -> [SimpleFoodItem] {
        let demoFoods = [
            SimpleFoodItem(id: "1", name: "Chicken, broilers or fryers, breast, meat only, cooked, grilled", calories: 165),
            SimpleFoodItem(id: "2", name: "Rice, brown, long-grain, cooked", calories: 111),
            SimpleFoodItem(id: "3", name: "Broccoli, cooked, boiled, drained, without salt", calories: 34),
            SimpleFoodItem(id: "4", name: "Salmon, Atlantic, farmed, cooked, dry heat", calories: 206),
            SimpleFoodItem(id: "5", name: "Sweet potato, cooked, baked in skin, without salt", calories: 90),
            SimpleFoodItem(id: "6", name: "Spinach, cooked, boiled, drained, without salt", calories: 23)
        ]
        
        return demoFoods.filter { food in
            food.name.localizedCaseInsensitiveContains(query)
        }
    }
    
    private func performRealSearch(query: String, apiKey: String) async -> [SimpleFoodItem] {
        // Real USDA API implementation would go here
        // For now, return demo data
        return getDemoFoods(matching: query)
    }
}

// MARK: - Simple Data Models (Renamed to avoid conflicts)
struct SimpleFoodItem: Identifiable {
    let id: String
    let name: String
    let calories: Int
}
