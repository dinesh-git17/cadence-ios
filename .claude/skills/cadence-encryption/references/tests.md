# Encryption Unit Tests — Swift Reference

Place these in `CadenceTests/EncryptionServiceTests.swift`.

Note: `EncryptionService.shared` uses Keychain internally. Tests call `initialiseKey`
directly with a deterministic test secret rather than mocking the Keychain. This is an
integration test of the real Keychain path, which is correct — Keychain reads and writes
do work in the test host process.

```swift
import XCTest
import CryptoKit
@testable import Cadence

final class EncryptionServiceTests: XCTestCase {

    private let testUserID = "test-user-00000000-0000-0000-0000-000000000001"
    private let testMasterSecret = "cadence-test-master-secret-do-not-use-in-prod"
        .data(using: .utf8)!

    override func setUp() async throws {
        try await super.setUp()
        try EncryptionService.shared.initialiseKey(
            masterSecret: testMasterSecret,
            userID: testUserID
        )
    }

    override func tearDown() async throws {
        EncryptionService.shared.purgeKey(forUserID: testUserID)
        try await super.tearDown()
    }

    // MARK: - Round trip

    func testEncryptDecryptRoundTrip_string() throws {
        let plaintext = "Cramps, headache"
        let ciphertext = try EncryptionService.shared.encrypt(plaintext)
        let decrypted = try EncryptionService.shared.decrypt(ciphertext)
        XCTAssertEqual(decrypted, plaintext)
    }

    func testEncryptDecryptRoundTrip_emptyString() throws {
        let plaintext = ""
        let ciphertext = try EncryptionService.shared.encrypt(plaintext)
        let decrypted = try EncryptionService.shared.decrypt(ciphertext)
        XCTAssertEqual(decrypted, plaintext)
    }

    func testEncryptDecryptRoundTrip_unicodeString() throws {
        let plaintext = "今日の気分: 😊 énergique"
        let ciphertext = try EncryptionService.shared.encrypt(plaintext)
        let decrypted = try EncryptionService.shared.decrypt(ciphertext)
        XCTAssertEqual(decrypted, plaintext)
    }

    func testEncryptDecryptRoundTrip_data() throws {
        let original = Data("raw binary content".utf8)
        let encrypted = try EncryptionService.shared.encryptData(original)
        let decrypted = try EncryptionService.shared.decryptData(encrypted)
        XCTAssertEqual(decrypted, original)
    }

    // MARK: - Ciphertext is not plaintext

    func testCiphertextDoesNotEqualPlaintext() throws {
        let plaintext = "Heavy"
        let ciphertext = try EncryptionService.shared.encrypt(plaintext)
        XCTAssertNotEqual(ciphertext, plaintext)
    }

    func testCiphertextIsBase64() throws {
        let ciphertext = try EncryptionService.shared.encrypt("spotting")
        XCTAssertNotNil(Data(base64Encoded: ciphertext), "Ciphertext should be valid base64.")
    }

    // MARK: - Nonce uniqueness

    func testSamePlaintextProducesDifferentCiphertexts() throws {
        let plaintext = "Medium"
        let cipher1 = try EncryptionService.shared.encrypt(plaintext)
        let cipher2 = try EncryptionService.shared.encrypt(plaintext)
        XCTAssertNotEqual(cipher1, cipher2,
            "Two encryptions of the same value must produce different ciphertexts (random nonce).")
    }

    // MARK: - Wrong key decryption

    func testDecryptWithWrongKeyThrows() throws {
        let plaintext = "Mood: anxious"
        let ciphertext = try EncryptionService.shared.encrypt(plaintext)

        let wrongKey = try EncryptionService.shared.deriveKey(
            from: testMasterSecret,
            userID: "different-user-id"
        )

        XCTAssertThrowsError(
            try EncryptionService.shared.decrypt(ciphertext, using: wrongKey)
        ) { error in
            guard let encryptionError = error as? EncryptionError else {
                XCTFail("Expected EncryptionError, got \(error)")
                return
            }
            if case .decryptionFailure = encryptionError {
                // Expected — authentication tag verification failed.
            } else {
                XCTFail("Expected .decryptionFailure, got \(encryptionError)")
            }
        }
    }

    // MARK: - Tampered ciphertext

    func testDecryptTamperedCiphertextThrows() throws {
        let plaintext = "Low"
        let ciphertext = try EncryptionService.shared.encrypt(plaintext)

        var blobData = Data(base64Encoded: ciphertext)!
        blobData[blobData.count - 1] ^= 0xFF

        XCTAssertThrowsError(
            try EncryptionService.shared.decryptData(blobData)
        )
    }

    // MARK: - Invalid base64

    func testDecryptInvalidBase64Throws() throws {
        XCTAssertThrowsError(
            try EncryptionService.shared.decrypt("this-is-not-base64-!!!!")
        ) { error in
            guard let encryptionError = error as? EncryptionError else {
                XCTFail("Expected EncryptionError")
                return
            }
            if case .invalidCiphertextData = encryptionError { } else {
                XCTFail("Expected .invalidCiphertextData, got \(encryptionError)")
            }
        }
    }

    // MARK: - Missing key

    func testEncryptWithNoKeyThrows() throws {
        EncryptionService.shared.clearKey()
        XCTAssertThrowsError(
            try EncryptionService.shared.encrypt("test")
        ) { error in
            guard let encryptionError = error as? EncryptionError else {
                XCTFail("Expected EncryptionError")
                return
            }
            if case .missingKey = encryptionError { } else {
                XCTFail("Expected .missingKey, got \(encryptionError)")
            }
        }
    }

    // MARK: - Key derivation determinism

    func testKeyDerivationIsDeterministic() throws {
        let key1 = try EncryptionService.shared.deriveKey(
            from: testMasterSecret, userID: testUserID
        )
        let key2 = try EncryptionService.shared.deriveKey(
            from: testMasterSecret, userID: testUserID
        )
        let key1Bytes = key1.withUnsafeBytes { Data($0) }
        let key2Bytes = key2.withUnsafeBytes { Data($0) }
        XCTAssertEqual(key1Bytes, key2Bytes)
    }

    func testDifferentUserIDsProduceDifferentKeys() throws {
        let keyA = try EncryptionService.shared.deriveKey(
            from: testMasterSecret, userID: "user-a"
        )
        let keyB = try EncryptionService.shared.deriveKey(
            from: testMasterSecret, userID: "user-b"
        )
        let keyABytes = keyA.withUnsafeBytes { Data($0) }
        let keyBBytes = keyB.withUnsafeBytes { Data($0) }
        XCTAssertNotEqual(keyABytes, keyBBytes)
    }

    // MARK: - Partner decryption (shared log pattern)

    func testPartnerCanDecryptTrackerCiphertext() throws {
        let trackerUserID = testUserID
        let plaintext = "Spotting"

        let ciphertext = try EncryptionService.shared.encrypt(plaintext)

        let partnerDerivedKey = try EncryptionService.shared.deriveKey(
            from: testMasterSecret,
            userID: trackerUserID
        )

        let decrypted = try EncryptionService.shared.decrypt(ciphertext, using: partnerDerivedKey)
        XCTAssertEqual(decrypted, plaintext)
    }
}
```
