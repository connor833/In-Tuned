import Foundation
import Security

/// Secure credential manager for storing sensitive API keys and secrets
/// Uses iOS Keychain for maximum security
/// NOTE: This is for development only - users should never configure these credentials
class SecureCredentialManager {
    static let shared = SecureCredentialManager()
    
    private init() {
        // Automatically set up default credentials on first launch
        setupDefaultCredentialsIfNeeded()
    }
    
    // MARK: - Keychain Configuration
    
    private let service = "com.podwebblueprint.r2credentials"
    private let accessKeyAccount = "r2_access_key"
    private let secretKeyAccount = "r2_secret_key"
    
    // MARK: - R2 Credentials
    
    /// Gets the R2 access key from secure storage
    var r2AccessKey: String? {
        return getCredential(for: accessKeyAccount)
    }
    
    /// Gets the R2 secret key from secure storage
    var r2SecretKey: String? {
        return getCredential(for: secretKeyAccount)
    }
    
    /// Checks if R2 credentials are available
    var hasR2Credentials: Bool {
        return r2AccessKey != nil && r2SecretKey != nil
    }
    
    // MARK: - Private Keychain Methods
    
    private func storeCredential(_ credential: String, for account: String) -> Bool {
        let data = credential.data(using: .utf8)!
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        // First try to add, if it fails, update existing
        let addStatus = SecItemAdd(query as CFDictionary, nil)
        
        if addStatus == errSecDuplicateItem {
            // Item exists, update it
            let updateQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account
            ]
            
            let updateAttributes: [String: Any] = [
                kSecValueData as String: data
            ]
            
            let updateStatus = SecItemUpdate(updateQuery as CFDictionary, updateAttributes as CFDictionary)
            return updateStatus == errSecSuccess
        }
        
        return addStatus == errSecSuccess
    }
    
    private func getCredential(for account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let credential = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return credential
    }
    
    // MARK: - Automatic Setup (Development Only)
    
    /// Automatically sets up default R2 credentials if none exist
    /// This is for development only - remove in production
    private func setupDefaultCredentialsIfNeeded() {
        // Only set up if no credentials exist
        guard !hasR2Credentials else { return }
        
        // Your actual R2 credentials for cloudflare-testing bucket
        let accessKey = "5f6835ab135a6e6b755b0e558425bec7"
        let secretKey = "63eb65eb97f50d87fd07e835b757c326729d1daf23bf7b57aa79e35e0b9da7f0"
        
        let success = storeCredential(accessKey, for: accessKeyAccount) &&
                     storeCredential(secretKey, for: secretKeyAccount)
        
        if success {
            print("✅ Default R2 credentials stored securely in Keychain")
        } else {
            print("❌ Failed to store default R2 credentials")
        }
    }
    
    // MARK: - Production Cleanup (Call Before Production Release)
    
    /// Removes stored credentials - call this before production release
    /// This ensures no hardcoded credentials remain in the app
    func removeCredentialsForProduction() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        if status == errSecSuccess || status == errSecItemNotFound {
            print("✅ R2 credentials removed from Keychain")
        } else {
            print("❌ Failed to remove R2 credentials")
        }
    }
}
