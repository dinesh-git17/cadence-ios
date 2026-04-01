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
            case let .keyDerivationFailure(reason):
                "Key derivation failed: \(reason)"
            case let .encryptionFailure(reason):
                "Encryption failed: \(reason)"
            case let .decryptionFailure(reason):
                "Decryption failed: \(reason)"
            case let .keychainError(status):
                "Keychain error (OSStatus \(status))"
            case .missingKey:
                "Encryption key not initialised. Call loadKey() or initialiseKey() first."
            case .invalidCiphertextData:
                "Ciphertext is not valid base64 or has wrong structure."
        }
    }
}

/// Manages the per-user AES-256-GCM encryption key for Cadence.
///
/// Lifecycle:
/// - New user: call `initialiseKey(serverSecret:userID:)` after account creation.
/// - Returning user: call `loadKey(forUserID:)` on app launch after auth restores.
/// - Sign out: call `clearKey()`.
///
/// All encrypt/decrypt methods use the in-memory cached key and throw
/// `EncryptionError.missingKey` if called before the key is loaded.
final class EncryptionService {
    // MARK: - Singleton

    static let shared = EncryptionService()

    // MARK: - Private State

    private var cachedKey: SymmetricKey?

    private let keychainService = "com.cadence.encryption"

    /// Domain-separation string. NEVER change after shipping — doing so
    /// silently rotates all keys and makes existing encrypted data unreadable.
    private let hkdfInfo = "cadence-v1-user-key"

    private init() {}

    // MARK: - Key Lifecycle

    /// Derives the user's symmetric key from serverSecret + userID, persists to Keychain.
    /// Call once after account creation, before writing any logs.
    func initialiseKey(serverSecret: Data, userID: String) throws {
        let key = try deriveKey(from: serverSecret, userID: userID)
        try storeKeyInKeychain(key, forUserID: userID)
        cachedKey = key
    }

    /// Loads the user's derived key from Keychain into memory.
    /// Falls back to re-derivation if Keychain entry is missing (reinstall/restore).
    func loadKey(forUserID userID: String, serverSecret: Data? = nil) throws {
        if let key = try? readKeyFromKeychain(forUserID: userID) {
            cachedKey = key
            return
        }

        guard let secret = serverSecret else {
            throw EncryptionError.missingKey
        }
        try initialiseKey(serverSecret: secret, userID: userID)
    }

    /// Clears the in-memory key cache. Does NOT delete the Keychain entry.
    func clearKey() {
        cachedKey = nil
    }

    /// Permanently deletes the Keychain entry and clears the in-memory cache.
    func purgeKey(forUserID userID: String) {
        deleteKeyFromKeychain(forUserID: userID)
        cachedKey = nil
    }

    // MARK: - Key Derivation

    /// Derives a SymmetricKey for the given user via HKDF-SHA256.
    /// Used internally for own key, and by partners to derive the tracker's key.
    func deriveKey(from serverSecret: Data, userID: String) throws -> SymmetricKey {
        guard let saltData = userID.data(using: .utf8),
              let infoData = hkdfInfo.data(using: .utf8)
        else {
            let message = "Failed to encode HKDF parameters as UTF-8."
            throw EncryptionError.keyDerivationFailure(message)
        }

        return HKDF<SHA256>.deriveKey(
            inputKeyMaterial: SymmetricKey(data: serverSecret),
            salt: saltData,
            info: infoData,
            outputByteCount: 32
        )
    }

    // MARK: - Encrypt / Decrypt (String <-> base64 String)

    /// Encrypts a plaintext string. Returns a base64-encoded AES-GCM sealed box.
    func encrypt(_ plaintext: String) throws -> String {
        guard let data = plaintext.data(using: .utf8) else {
            let message = "Could not encode plaintext as UTF-8."
            throw EncryptionError.encryptionFailure(message)
        }
        return try encryptData(data).base64EncodedString()
    }

    /// Decrypts a base64-encoded AES-GCM sealed box back to the original plaintext.
    func decrypt(_ ciphertext: String) throws -> String {
        guard let data = Data(base64Encoded: ciphertext) else {
            throw EncryptionError.invalidCiphertextData
        }
        let plainData = try decryptData(data)
        guard let plaintext = String(data: plainData, encoding: .utf8) else {
            let message = "Decrypted bytes are not valid UTF-8 — data may be corrupt."
            throw EncryptionError.decryptionFailure(message)
        }
        return plaintext
    }

    // MARK: - Encrypt / Decrypt (Data <-> combined blob)

    /// Encrypts raw Data. Returns [12B nonce][ciphertext][16B tag].
    func encryptData(_ data: Data) throws -> Data {
        let key = try requireCachedKey()
        do {
            let sealedBox = try AES.GCM.seal(data, using: key)
            guard let combined = sealedBox.combined else {
                let message = "SealedBox.combined was nil."
                throw EncryptionError.encryptionFailure(message)
            }
            return combined
        } catch let error as EncryptionError {
            throw error
        } catch {
            throw EncryptionError.encryptionFailure(error.localizedDescription)
        }
    }

    /// Decrypts AES-GCM combined blob. Auth tag verified automatically.
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

    // MARK: - Partner Decryption

    /// Decrypts using an explicit key (not the cached key).
    /// Used by partners to decrypt tracker's shared_logs with the tracker's derived key.
    func decrypt(_ ciphertext: String, using key: SymmetricKey) throws -> String {
        guard let data = Data(base64Encoded: ciphertext) else {
            throw EncryptionError.invalidCiphertextData
        }
        do {
            let sealedBox = try AES.GCM.SealedBox(combined: data)
            let plainData = try AES.GCM.open(sealedBox, using: key)
            guard let plaintext = String(data: plainData, encoding: .utf8) else {
                let message = "Decrypted bytes are not valid UTF-8."
                throw EncryptionError.decryptionFailure(message)
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

    // MARK: - Keychain

    private func keychainAccount(forUserID userID: String) -> String {
        "userEncryptionKey.\(userID)"
    }

    func storeKeyInKeychain(_ key: SymmetricKey, forUserID userID: String) throws {
        let keyData = key.withUnsafeBytes { Data($0) }
        let account = keychainAccount(forUserID: userID)

        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecValueData as String: keyData,
        ]

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw EncryptionError.keychainError(status)
        }
    }

    func readKeyFromKeychain(forUserID userID: String) throws -> SymmetricKey {
        let account = keychainAccount(forUserID: userID)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
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
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount(forUserID: userID),
        ]
        SecItemDelete(query as CFDictionary)
    }
}
