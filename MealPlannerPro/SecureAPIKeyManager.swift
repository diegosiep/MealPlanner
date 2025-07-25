import Foundation

class SecureAPIKeyManager {
    static let shared = SecureAPIKeyManager()
    
    private init() {}
    
    enum APIKeyType: String {
        case usdaAPI = "mealplanner.usda.apikey"
        case claudeAPI = "mealplanner.claude.apikey"
        case openaiAPI = "mealplanner.openai.apikey"
        case huggingfaceAPI = "mealplanner.huggingface.apikey"
    }
    
    // MARK: - Store API Key (Using UserDefaults)
    func storeAPIKey(_ key: String, for type: APIKeyType) -> Bool {
        guard !key.isEmpty else { return false }
        
        UserDefaults.standard.set(key, forKey: type.rawValue)
        return true
    }
    
    // MARK: - Retrieve API Key (Using UserDefaults)
    func retrieveAPIKey(for type: APIKeyType) -> String? {
        return UserDefaults.standard.string(forKey: type.rawValue)
    }
    
    // MARK: - Check if Key Exists
    func hasAPIKey(for type: APIKeyType) -> Bool {
        guard let key = retrieveAPIKey(for: type) else { return false }
        return !key.isEmpty && key != "DEMO_MODE"
    }
    
    // MARK: - Easy Access Properties
    var usdaAPIKey: String? {
        let key = retrieveAPIKey(for: .usdaAPI)
        return (key == "DEMO_MODE") ? nil : key
    }
    
    var claudeAPIKey: String? {
        return retrieveAPIKey(for: .claudeAPI)
    }
    
    var openaiAPIKey: String? {
        return retrieveAPIKey(for: .openaiAPI)
    }
    
    var huggingfaceAPIKey: String? {
        return retrieveAPIKey(for: .huggingfaceAPI)
    }
    
    // MARK: - Demo Mode Check
    var isInDemoMode: Bool {
        return retrieveAPIKey(for: .usdaAPI) == "DEMO_MODE"
    }
    
    // MARK: - Clear All Keys (for testing)
    func clearAllKeys() {
        UserDefaults.standard.removeObject(forKey: APIKeyType.usdaAPI.rawValue)
        UserDefaults.standard.removeObject(forKey: APIKeyType.claudeAPI.rawValue)
        UserDefaults.standard.removeObject(forKey: APIKeyType.openaiAPI.rawValue)
        UserDefaults.standard.removeObject(forKey: APIKeyType.huggingfaceAPI.rawValue)
    }
    
    // MARK: - Set Demo Mode
    func setDemoMode() {
        storeAPIKey("DEMO_MODE", for: .usdaAPI)
    }
}

