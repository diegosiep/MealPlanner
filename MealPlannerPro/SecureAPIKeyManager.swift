import Foundation
import Security

class SecureAPIKeyManager {
    static let shared = SecureAPIKeyManager()
    
    private init() {}
    
    enum APIKeyType: String {
        case usdaAPI = "com.mealplanner.usda.apikey"
        case claudeAPI = "com.mealplanner.claude.apikey"
        case openaiAPI = "com.mealplanner.openai.apikey"
        case huggingfaceAPI = "com.mealplanner.huggingface.apikey"
    }
    
    // MARK: - Store API Key
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
        
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        
        return status == errSecSuccess
    }
    
    // MARK: - Retrieve API Key
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
        }
        
        return nil
    }
    
    // MARK: - Check if Key Exists
    func hasAPIKey(for type: APIKeyType) -> Bool {
        return retrieveAPIKey(for: type) != nil
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
}
