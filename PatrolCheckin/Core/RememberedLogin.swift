import Foundation
import Security

enum RememberedLogin {
    private struct Credential: Codable {
        let user: String
        let password: String
    }

    private static var query: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.patrol.checkin.login",
            kSecAttrAccount as String: Net.shared.base
        ]
    }

    static func password(for user: String) -> String? {
        var request = query
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(request as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let credential = try? JSONDecoder().decode(Credential.self, from: data),
              credential.user == user else { return nil }
        return credential.password
    }

    @discardableResult
    static func save(user: String, password: String) -> Bool {
        guard let data = try? JSONEncoder().encode(Credential(user: user, password: password))
        else { return false }
        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecSuccess { return true }
        guard status == errSecItemNotFound else { return false }
        var item = query
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        return SecItemAdd(item as CFDictionary, nil) == errSecSuccess
    }

    static func clear() {
        SecItemDelete(query as CFDictionary)
    }
}
