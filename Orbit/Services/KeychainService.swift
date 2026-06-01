//
//  KeychainService.swift
//  Orbit
//

import Foundation
import Security

final class KeychainService {
    static let shared = KeychainService()
    private let service = "com.orbit.app"
    private init() {}

    func set(_ value: String, forKey key: String) {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
        if value.isEmpty { return }
        let attributes: [String: Any] = query.merging([kSecValueData as String: data]) { $1 }
        SecItemAdd(attributes as CFDictionary, nil)
    }

    func get(forKey key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8),
              !string.isEmpty else { return nil }
        return string
    }

    func delete(forKey key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - Keychain-backed UserDefaults migration

extension KeychainService {
    /// Migrate a key from UserDefaults to Keychain if not yet migrated.
    func migrateFromUserDefaults(key: String) {
        if get(forKey: key) == nil,
           let existing = UserDefaults.standard.string(forKey: key),
           !existing.isEmpty {
            set(existing, forKey: key)
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
}
