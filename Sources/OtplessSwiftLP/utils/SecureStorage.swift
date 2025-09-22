//
//  SecureStorage.swift
//  OtplessSwiftLP
//
//  Created by Sparsh on 19/03/25.
//

import Foundation
import Security
import CryptoKit

internal final class SecureStorage: @unchecked Sendable {
    static let shared = SecureStorage()
    private let service = "com.otpless.connect.secure"
    private let encryptionKeyAccount = "com.otpless.connect.secure.encryption-key"
    private let defaults: UserDefaults
    private var cachedEncryptionKey: SymmetricKey?
    
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }
    
    func save(key: String, value: String) {
        guard let data = value.data(using: .utf8),
              let encryptionKey = loadEncryptionKey(),
              let sealedData = try? AES.GCM.seal(data, using: encryptionKey).combined else {
            return
        }
        DLog("storing encrypted value for \(key): success")
        defaults.set(sealedData, forKey: key)
    }
    
    func retrieve(key: String) -> String? {
        let storageKey = key
        guard let encryptionKey = loadEncryptionKey(),
              let storedData = defaults.data(forKey: storageKey),
              let sealedBox = try? AES.GCM.SealedBox(combined: storedData),
              let decryptedData = try? AES.GCM.open(sealedBox, using: encryptionKey),
              let value = String(data: decryptedData, encoding: .utf8) else {
            return nil
        }
        DLog("retrieving encrypted value for \(key): success")
        return value
    }
    
    func delete(key: String) {
        defaults.removeObject(forKey: key)
    }
    
    func saveToUserDefaults<T>(key: String, value: T) {
        defaults.set(value, forKey: key)
    }
    
    func getFromUserDefaults<T>(key: String, defaultValue: T) -> T {
        return defaults.object(forKey: key) as? T ?? defaultValue
    }
    
    func deleteGeneratedKeys() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: encryptionKeyAccount
        ]
        DLog("keys deleted from keychain")
        SecItemDelete(query as CFDictionary)
        cachedEncryptionKey = nil
    }
    
    private func loadEncryptionKey() -> SymmetricKey? {
        if let cachedEncryptionKey {
            DLog("cached key returned")
            return cachedEncryptionKey
        }
        
        if let data = readEncryptionKeyData() {
            let key = SymmetricKey(data: data)
            cachedEncryptionKey = key
            DLog( "key read from keychain and returned")
            return key
        }
        
        let key = SymmetricKey(size: .bits256)
        guard storeEncryptionKey(key) else {
            return nil
        }
        DLog("new key created")
        cachedEncryptionKey = key
        return key
    }
    
    private func readEncryptionKeyData() -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: encryptionKeyAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            DLog("error in loading key from key chain")
            return nil
        }
        return data
    }
    
    @discardableResult
    private func storeEncryptionKey(_ key: SymmetricKey) -> Bool {
        let keyData = key.withUnsafeBytes { Data($0) }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: encryptionKeyAccount,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        DLog("stored new key in key chain")
        return status == errSecSuccess
    }
}
