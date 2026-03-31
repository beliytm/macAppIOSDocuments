import Foundation
import Security

enum KeychainHelper {

    private static let service = Bundle.main.bundleIdentifier ?? "com.app.default"

    static func save(_ value: String, forKey key: String) {
        guard let data = value.data(using: .utf8) else { return }

        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key
        ]

        // try update first
        let status = SecItemUpdate(query as CFDictionary, [kSecValueData: data] as CFDictionary)

        if status == errSecItemNotFound {
            var addQuery = query
            addQuery[kSecValueData] = data
            SecItemAdd(addQuery as CFDictionary, nil)
        }
    }

    static func load(forKey key: String) -> String? {
        let query: [CFString: Any] = [
            kSecClass:            kSecClassGenericPassword,
            kSecAttrService:      service,
            kSecAttrAccount:      key,
            kSecReturnData:       true,
            kSecMatchLimit:       kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else { return nil }
        return string
    }

    static func delete(forKey key: String) {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key
        ]
        SecItemDelete(query as CFDictionary)
    }

    // migrates a value from UserDefaults to Keychain once, then removes it
    static func migrateFromUserDefaults(udKey: String, keychainKey: String) {
        guard let existing = UserDefaults.standard.string(forKey: udKey), !existing.isEmpty else { return }
        if load(forKey: keychainKey) == nil {
            save(existing, forKey: keychainKey)
        }
        UserDefaults.standard.removeObject(forKey: udKey)
    }
}
