# EncryptionService — Full Swift Implementation

Place this file at `Cadence/Services/EncryptionService.swift`.

---

## Error Types

```swift
import CryptoKit
import Foundation
import Security

enum EncryptionError: LocalizedError {
    case keyDerivationFailure(String)
    case encryptionFailure(String)
    case decryptionFailure(String)
    case keychainError(OSStatus)
    case missingKey
    case invalidCiphertextData

    var errorDescription: String? {
        switch self {
        case .keyDerivationFailure(let reason):
            return "Key derivation failed: \(reason)"
        case .encryptionFailure(let reason):
            return "Encryption failed: \(reason)"
        case .decryptionFailure(let reason):
            return "Decryption failed: \(reason)"
        case .keychainError(let status):
            return "Keychain error (OSStatus \(status))"
        case .missingKey:
            return "Encryption key not initialised. Call loadKey() or initialiseKey() first."
        case .invalidCiphertextData:
            return "Ciphertext is not valid base64 or has wrong structure."
        }
    }
}
```

---

## EncryptionService

```swift
/// Manages the per-user AES-256-GCM encryption key for Cadence.
///
/// Lifecycle:
/// - New user: call `initialiseKey(masterSecret:userID:)` immediately after account creation.
/// - Returning user: call `loadKey(forUserID:)` on app launch after auth restores.
/// - Sign out: call `clearKey()`.
///
/// All public encrypt/decrypt methods use the in-memory cached key. They will throw
/// `EncryptionError.missingKey` if called before the key is initialised.
final class EncryptionService {

    // MARK: - Singleton

    static let shared = EncryptionService()

    // MARK: - Private state

    private var cachedKey: SymmetricKey?

    private let keychainService = "com.cadence.encryption"

    // Domain-separation string. NEVER change this after shipping.
    // Changing it invalidates all existing encrypted data.
    private let hkdfInfo = "cadence-v1-user-key"

    private init() {}

    // MARK: - Key Lifecycle

    /// Derives the user's symmetric key from masterSecret + userID and persists it to Keychain.
    /// Call this once, immediately after account creation, before writing any logs.
    func initialiseKey(masterSecret: Data, userID: String) throws {
        let key = try deriveKey(from: masterSecret, userID: userID)
        try storeKeyInKeychain(key, forUserID: userID)
        cachedKey = key
    }

    /// Loads the user's derived key from Keychain into memory.
    /// Call this on app launch, after Supabase auth confirms an active session.
    func loadKey(forUserID userID: String, masterSecret: Data? = nil) throws {
        // Happy path: key is already in Keychain from a previous session.
        if let key = try? readKeyFromKeychain(forUserID: userID) {
            cachedKey = key
            return
        }

        // Recovery path: Keychain entry is missing (device restore, reinstall, etc.).
        guard let secret = masterSecret else {
            throw EncryptionError.missingKey
        }
        try initialiseKey(masterSecret: secret, userID: userID)
    }

    /// Clears the in-memory key cache. Call on sign-out.
    /// Does NOT delete the Keychain entry — that persists for the next sign-in.
    func clearKey() {
        cachedKey = nil
    }

    /// Permanently deletes the Keychain entry and clears the in-memory cache.
    /// Use for account deletion or when issuing a fresh key.
    func purgeKey(forUserID userID: String) {
        deleteKeyFromKeychain(forUserID: userID)
        cachedKey = nil
    }

    // MARK: - Key Derivation (internal + partner use)

    /// Derives a SymmetricKey for the given user.
    /// Used internally for own key, and by partners to derive the tracker's key.
    func deriveKey(from masterSecret: Data, userID: String) throws -> SymmetricKey {
        guard let saltData = userID.data(using: .utf8),
              let infoData = hkdfInfo.data(using: .utf8) else {
            throw EncryptionError.keyDerivationFailure(
                "Failed to encode HKDF parameters as UTF-8 — this should never happen."
            )
        }

        return HKDF<SHA256>.deriveKey(
            inputKeyMaterial: masterSecret,
            salt: saltData,
            info: infoData,
            outputByteCount: 32   // 256-bit key for AES-256-GCM
        )
    }

    // MARK: - Encrypt / Decrypt (String -> String, base64 output)

    /// Encrypts a plaintext string. Returns a base64-encoded AES-GCM sealed box.
    func encrypt(_ plaintext: String) throws -> String {
        guard let data = plaintext.data(using: .utf8) else {
            throw EncryptionError.encryptionFailure("Could not encode plaintext as UTF-8.")
        }
        return try encryptData(data).base64EncodedString()
    }

    /// Decrypts a base64-encoded AES-GCM sealed box. Returns the original plaintext string.
    func decrypt(_ ciphertext: String) throws -> String {
        guard let data = Data(base64Encoded: ciphertext) else {
            throw EncryptionError.invalidCiphertextData
        }
        let plainData = try decryptData(data)
        guard let plaintext = String(data: plainData, encoding: .utf8) else {
            throw EncryptionError.decryptionFailure(
                "Decrypted bytes are not valid UTF-8 — data may be corrupt."
            )
        }
        return plaintext
    }

    // MARK: - Encrypt / Decrypt (Data -> Data, raw combined blob)

    /// Encrypts raw Data. Returns AES-GCM combined blob: [12B nonce][ciphertext][16B tag].
    func encryptData(_ data: Data) throws -> Data {
        let key = try requireCachedKey()
        do {
            let sealedBox = try AES.GCM.seal(data, using: key)
            guard let combined = sealedBox.combined else {
                throw EncryptionError.encryptionFailure(
                    "SealedBox.combined was nil — this should never happen with a default nonce."
                )
            }
            return combined
        } catch let error as EncryptionError {
            throw error
        } catch {
            throw EncryptionError.encryptionFailure(error.localizedDescription)
        }
    }

    /// Decrypts AES-GCM combined blob. Verifies authentication tag automatically.
    func decryptData(_ data: Data) throws -> Data {
        let key = try requireCachedKey()
        do {
            let sealedBox = try AES.GCM.SealedBox(combined: data)
            return try AES.GCM.open(sealedBox, using: key)
        } catch let error as EncryptionError {
            throw error
        } catch {
            throw EncryptionError.decryptionFailure(error.localizedDescription)
        }
    }

    // MARK: - Partner Decryption (decrypt with an explicit key, not the cached key)

    /// Decrypts a base64-encoded ciphertext using an explicit SymmetricKey.
    /// Used by partners to decrypt tracker's shared_logs fields using the tracker's derived key.
    func decrypt(_ ciphertext: String, using key: SymmetricKey) throws -> String {
        guard let data = Data(base64Encoded: ciphertext) else {
            throw EncryptionError.invalidCiphertextData
        }
        do {
            let sealedBox = try AES.GCM.SealedBox(combined: data)
            let plainData = try AES.GCM.open(sealedBox, using: key)
            guard let plaintext = String(data: plainData, encoding: .utf8) else {
                throw EncryptionError.decryptionFailure(
                    "Decrypted bytes are not valid UTF-8."
                )
            }
            return plaintext
        } catch let error as EncryptionError {
            throw error
        } catch {
            throw EncryptionError.decryptionFailure(error.localizedDescription)
        }
    }

    // MARK: - Private Helpers

    private func requireCachedKey() throws -> SymmetricKey {
        guard let key = cachedKey else { throw EncryptionError.missingKey }
        return key
    }

    // MARK: - Keychain Read / Write

    private func keychainAccount(forUserID userID: String) -> String {
        "userEncryptionKey.\(userID)"
    }

    func storeKeyInKeychain(_ key: SymmetricKey, forUserID userID: String) throws {
        let keyData = key.withUnsafeBytes { Data($0) }
        let account = keychainAccount(forUserID: userID)

        // Always delete before add to avoid errSecDuplicateItem.
        let deleteQuery: [String: Any] = [
            kSecClass as String:        kSecClassGenericPassword,
            kSecAttrService as String:  keychainService,
            kSecAttrAccount as String:  account
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let addQuery: [String: Any] = [
            kSecClass as String:            kSecClassGenericPassword,
            kSecAttrService as String:      keychainService,
            kSecAttrAccount as String:      account,
            kSecAttrAccessible as String:   kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecValueData as String:        keyData
        ]

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw EncryptionError.keychainError(status)
        }
    }

    func readKeyFromKeychain(forUserID userID: String) throws -> SymmetricKey {
        let account = keychainAccount(forUserID: userID)

        let query: [String: Any] = [
            kSecClass as String:        kSecClassGenericPassword,
            kSecAttrService as String:  keychainService,
            kSecAttrAccount as String:  account,
            kSecReturnData as String:   true,
            kSecMatchLimit as String:   kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let keyData = result as? Data else {
            throw EncryptionError.keychainError(status)
        }

        return SymmetricKey(data: keyData)
    }

    private func deleteKeyFromKeychain(forUserID userID: String) {
        let query: [String: Any] = [
            kSecClass as String:        kSecClassGenericPassword,
            kSecAttrService as String:  keychainService,
            kSecAttrAccount as String:  keychainAccount(forUserID: userID)
        ]
        SecItemDelete(query as CFDictionary)
    }
}
```
