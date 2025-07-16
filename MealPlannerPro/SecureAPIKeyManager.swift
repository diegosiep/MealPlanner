import Foundation
import Security

/// Secure API Key Manager using macOS Keychain
class SecureAPIKeyManager {
    static let shared = SecureAPIKeyManager()
    
    private init() {}
    
    // MARK: - API Key Identifiers
    enum APIKeyType: String {
        case usdaAPI = "com.mealplanner.usda.apikey"
        case claudeAPI = "com.mealplanner.claude.apikey"
        case openaiAPI = "com.mealplanner.openai.apikey"
        case huggingfaceAPI = "com.mealplanner.huggingface.apikey"
    }
    
    // MARK: - Store API Key in Keychain
    func storeAPIKey(_ key: String, for type: APIKeyType) -> Bool {
        guard !key.isEmpty else { return false }
        
        let data = key.data(using: .utf8)!
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: type.rawValue,
            kSecAttrAccount as String: "api_key",
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        // Delete any existing item
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status == errSecSuccess {
            print("✅ API key for \(type.rawValue) stored securely")
            return true
        } else {
            print("❌ Failed to store API key for \(type.rawValue): \(status)")
            return false
        }
    }
    
    // MARK: - Retrieve API Key from Keychain
    func retrieveAPIKey(for type: APIKeyType) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: type.rawValue,
            kSecAttrAccount as String: "api_key",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess,
           let data = result as? Data,
           let apiKey = String(data: data, encoding: .utf8) {
            return apiKey
        } else {
            print("⚠️ Could not retrieve API key for \(type.rawValue)")
            return nil
        }
    }
    
    // MARK: - Delete API Key from Keychain
    func deleteAPIKey(for type: APIKeyType) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: type.rawValue,
            kSecAttrAccount as String: "api_key"
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess
    }
    
    // MARK: - Check if API Key Exists
    func hasAPIKey(for type: APIKeyType) -> Bool {
        return retrieveAPIKey(for: type) != nil
    }
    
    // MARK: - Setup Initial API Keys (call this once during first setup)
    func setupInitialAPIKeys() {
        // This method should be called once to store your API keys
        // You can call this from your app's first launch or settings
        
        // Example usage - you would replace these with your actual keys:
        // storeAPIKey("your-actual-usda-key", for: .usdaAPI)
        // storeAPIKey("your-actual-claude-key", for: .claudeAPI)
        
        print("⚠️ Call setupInitialAPIKeys() with your actual API keys to store them securely")
    }
    
    // MARK: - Development Helper (Remove in production)
    func storeCurrentAPIKeys() {
        // TEMPORARILY store the hardcoded keys to migrate them to keychain
        // This should be called once, then removed
        
        let usdaKey = "KED0QmItd8YsnsLur1Q7bRpaQKsRv1NHF2MhjMEY"
        let claudeKey = "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"
        
        _ = storeAPIKey(usdaKey, for: .usdaAPI)
        _ = storeAPIKey(claudeKey, for: .claudeAPI)
        
        print("🔐 API keys have been migrated to secure keychain storage")
        print("⚠️ Remove the storeCurrentAPIKeys() method and hardcoded keys from source code")
    }
}

// MARK: - Extensions for Easy Access
extension SecureAPIKeyManager {
    var usdaAPIKey: String? {
        return retrieveAPIKey(for: .usdaAPI)
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
}