import Foundation
import SwiftUI

/// API Key Setup Utility for secure migration and management
struct APIKeySetupUtility: View {
    @State private var showingSetup = false
    @State private var isSetupComplete = false
    
    private let keyManager = SecureAPIKeyManager.shared
    
    var body: some View {
        VStack(spacing: 16) {
            if !isSetupComplete {
                VStack(spacing: 12) {
                    Image(systemName: "key.fill")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    
                    Text("API Keys Setup Required")
                        .font(.headline)
                    
                    Text("Your API keys need to be migrated to secure storage")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button("Migrate API Keys to Secure Storage") {
                        migrateAPIKeys()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(12)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title)
                        .foregroundColor(.green)
                    
                    Text("API Keys Secured")
                        .font(.headline)
                        .foregroundColor(.green)
                    
                    Text("Your API keys are now stored securely in macOS Keychain")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .onAppear {
            checkSetupStatus()
        }
    }
    
    private func checkSetupStatus() {
        isSetupComplete = keyManager.hasAPIKey(for: .usdaAPI) && keyManager.hasAPIKey(for: .claudeAPI)
    }
    
    private func migrateAPIKeys() {
        // Migrate the hardcoded keys to secure storage
        keyManager.storeCurrentAPIKeys()
        isSetupComplete = true
        
        // Show success message
        print("✅ API keys have been successfully migrated to secure storage!")
        print("🔐 Keys are now encrypted and stored in macOS Keychain")
        print("⚠️ You should now remove the hardcoded keys from source code")
    }
}

/// Manual API Key Configuration View
struct ManualAPIKeySetup: View {
    @State private var usdaKey = ""
    @State private var claudeKey = ""
    @State private var showingSuccess = false
    
    private let keyManager = SecureAPIKeyManager.shared
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("USDA Food Database")) {
                    SecureField("USDA API Key", text: $usdaKey)
                    Text("Get your free API key from api.nal.usda.gov")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section(header: Text("Claude AI (Optional)")) {
                    SecureField("Claude API Key", text: $claudeKey)
                    Text("Required for AI meal planning features")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section {
                    Button("Save API Keys Securely") {
                        saveAPIKeys()
                    }
                    .disabled(usdaKey.isEmpty)
                }
            }
            .navigationTitle("API Key Setup")
            .alert("API Keys Saved", isPresented: $showingSuccess) {
                Button("OK") { }
            } message: {
                Text("Your API keys have been securely stored in macOS Keychain")
            }
        }
    }
    
    private func saveAPIKeys() {
        var success = true
        
        if !usdaKey.isEmpty {
            success = success && keyManager.storeAPIKey(usdaKey, for: .usdaAPI)
        }
        
        if !claudeKey.isEmpty {
            success = success && keyManager.storeAPIKey(claudeKey, for: .claudeAPI)
        }
        
        if success {
            showingSuccess = true
            usdaKey = ""
            claudeKey = ""
        }
    }
}

/// API Key Status Indicator
struct APIKeyStatusIndicator: View {
    private let keyManager = SecureAPIKeyManager.shared
    
    var body: some View {
        HStack(spacing: 8) {
            // USDA API Status
            HStack(spacing: 4) {
                Circle()
                    .fill(keyManager.hasAPIKey(for: .usdaAPI) ? Color.green : Color.red)
                    .frame(width: 6, height: 6)
                Text("USDA")
                    .font(.caption)
            }
            
            // Claude API Status
            HStack(spacing: 4) {
                Circle()
                    .fill(keyManager.hasAPIKey(for: .claudeAPI) ? Color.green : Color.red)
                    .frame(width: 6, height: 6)
                Text("Claude")
                    .font(.caption)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}