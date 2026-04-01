@testable import Cadence
import CryptoKit
import XCTest

final class EncryptionServiceTests: XCTestCase {
    private let testUserID = "test-user-00000000-0000-0000-0000-000000000001"
    private let testServerSecret = Data("cadence-test-server-secret-do-not-use-in-prod".utf8)

    override func setUp() async throws {
        try await super.setUp()
        try EncryptionService.shared.initialiseKey(
            serverSecret: testServerSecret,
            userID: testUserID
        )
    }

    override func tearDown() async throws {
        EncryptionService.shared.purgeKey(forUserID: testUserID)
        try await super.tearDown()
    }

    // MARK: - Round Trip

    func testEncryptDecryptRoundTripString() throws {
        let plaintext = "Cramps, headache"
        let ciphertext = try EncryptionService.shared.encrypt(plaintext)
        let decrypted = try EncryptionService.shared.decrypt(ciphertext)
        XCTAssertEqual(decrypted, plaintext)
    }

    func testEncryptDecryptRoundTripEmptyString() throws {
        let plaintext = ""
        let ciphertext = try EncryptionService.shared.encrypt(plaintext)
        let decrypted = try EncryptionService.shared.decrypt(ciphertext)
        XCTAssertEqual(decrypted, plaintext)
    }

    func testEncryptDecryptRoundTripUnicode() throws {
        let plaintext = "energique, \u{00E9}nergie"
        let ciphertext = try EncryptionService.shared.encrypt(plaintext)
        let decrypted = try EncryptionService.shared.decrypt(ciphertext)
        XCTAssertEqual(decrypted, plaintext)
    }

    func testEncryptDecryptRoundTripData() throws {
        let original = Data("raw binary content".utf8)
        let encrypted = try EncryptionService.shared.encryptData(original)
        let decrypted = try EncryptionService.shared.decryptData(encrypted)
        XCTAssertEqual(decrypted, original)
    }

    // MARK: - Ciphertext Is Not Plaintext

    func testCiphertextDoesNotEqualPlaintext() throws {
        let plaintext = "Heavy"
        let ciphertext = try EncryptionService.shared.encrypt(plaintext)
        XCTAssertNotEqual(ciphertext, plaintext)
    }

    func testCiphertextIsValidBase64() throws {
        let ciphertext = try EncryptionService.shared.encrypt("spotting")
        XCTAssertNotNil(
            Data(base64Encoded: ciphertext),
            "Ciphertext should be valid base64."
        )
    }

    // MARK: - Nonce Uniqueness

    func testSamePlaintextProducesDifferentCiphertexts() throws {
        let plaintext = "Medium"
        let cipher1 = try EncryptionService.shared.encrypt(plaintext)
        let cipher2 = try EncryptionService.shared.encrypt(plaintext)
        XCTAssertNotEqual(
            cipher1,
            cipher2,
            "Two encryptions of the same value must differ (random nonce)."
        )
    }

    // MARK: - Wrong Key

    func testDecryptWithWrongKeyThrows() throws {
        let plaintext = "Mood: anxious"
        let ciphertext = try EncryptionService.shared.encrypt(plaintext)

        let wrongKey = try EncryptionService.shared.deriveKey(
            from: testServerSecret,
            userID: "different-user-id"
        )

        XCTAssertThrowsError(
            try EncryptionService.shared.decrypt(ciphertext, using: wrongKey)
        ) { error in
            guard let encError = error as? EncryptionError else {
                XCTFail("Expected EncryptionError, got \(error)")
                return
            }
            if case .decryptionFailure = encError { /* expected */ } else {
                XCTFail("Expected .decryptionFailure, got \(encError)")
            }
        }
    }

    // MARK: - Tampered Ciphertext

    func testDecryptTamperedCiphertextThrows() throws {
        let ciphertext = try EncryptionService.shared.encrypt("Low")

        var blobData = try XCTUnwrap(Data(base64Encoded: ciphertext))
        blobData[blobData.count - 1] ^= 0xFF

        XCTAssertThrowsError(
            try EncryptionService.shared.decryptData(blobData)
        )
    }

    // MARK: - Invalid Input

    func testDecryptInvalidBase64Throws() throws {
        XCTAssertThrowsError(
            try EncryptionService.shared.decrypt("this-is-not-base64-!!!!")
        ) { error in
            guard let encError = error as? EncryptionError else {
                XCTFail("Expected EncryptionError")
                return
            }
            if case .invalidCiphertextData = encError { /* expected */ } else {
                XCTFail("Expected .invalidCiphertextData, got \(encError)")
            }
        }
    }

    // MARK: - Missing Key

    func testEncryptWithNoKeyThrows() throws {
        EncryptionService.shared.clearKey()
        XCTAssertThrowsError(
            try EncryptionService.shared.encrypt("test")
        ) { error in
            guard let encError = error as? EncryptionError else {
                XCTFail("Expected EncryptionError")
                return
            }
            if case .missingKey = encError { /* expected */ } else {
                XCTFail("Expected .missingKey, got \(encError)")
            }
        }
    }

    // MARK: - Key Derivation Determinism

    func testKeyDerivationIsDeterministic() throws {
        let key1 = try EncryptionService.shared.deriveKey(
            from: testServerSecret, userID: testUserID
        )
        let key2 = try EncryptionService.shared.deriveKey(
            from: testServerSecret, userID: testUserID
        )
        let key1Bytes = key1.withUnsafeBytes { Data($0) }
        let key2Bytes = key2.withUnsafeBytes { Data($0) }
        XCTAssertEqual(key1Bytes, key2Bytes)
    }

    func testDifferentUserIDsProduceDifferentKeys() throws {
        let keyA = try EncryptionService.shared.deriveKey(
            from: testServerSecret, userID: "user-a"
        )
        let keyB = try EncryptionService.shared.deriveKey(
            from: testServerSecret, userID: "user-b"
        )
        let keyABytes = keyA.withUnsafeBytes { Data($0) }
        let keyBBytes = keyB.withUnsafeBytes { Data($0) }
        XCTAssertNotEqual(keyABytes, keyBBytes)
    }

    // MARK: - Partner Decryption

    func testPartnerCanDecryptTrackerCiphertext() throws {
        let plaintext = "Spotting"
        let ciphertext = try EncryptionService.shared.encrypt(plaintext)

        let partnerDerivedKey = try EncryptionService.shared.deriveKey(
            from: testServerSecret,
            userID: testUserID
        )

        let decrypted = try EncryptionService.shared.decrypt(
            ciphertext,
            using: partnerDerivedKey
        )
        XCTAssertEqual(decrypted, plaintext)
    }

    // MARK: - Keychain Persistence

    func testKeychainPersistenceAcrossInstances() throws {
        let plaintext = "Period: Heavy"
        let ciphertext = try EncryptionService.shared.encrypt(plaintext)

        EncryptionService.shared.clearKey()

        try EncryptionService.shared.loadKey(forUserID: testUserID)

        let decrypted = try EncryptionService.shared.decrypt(ciphertext)
        XCTAssertEqual(decrypted, plaintext)
    }
}
