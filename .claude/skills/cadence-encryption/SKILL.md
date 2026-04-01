---
name: cadence-encryption
description: >
  Client-side encryption layer for the Cadence iOS app. Read this skill before writing
  any code that touches EncryptionService, AES-GCM encryption/decryption, key derivation,
  Keychain storage, encrypted cycle_logs or shared_logs fields, or the /vault/master-secret
  Edge Function. Triggers on any Swift code involving CryptoKit, SymmetricKey, HKDF,
  AES.GCM, sealed boxes, ciphertext encoding, or partner key exchange in this project.
---

# Cadence — Encryption Layer Skill

Read this file **in full** before writing any encryption-related code in this project.
No exceptions. Every section is load-bearing.

---

## Reference Files — Load Before Coding

| File                                     | Load when...                                               |
| ---------------------------------------- | ---------------------------------------------------------- |
| `references/encryption-service.md`       | Implementing or modifying EncryptionService                |
| `references/cycle-log-integration.md`    | Encrypting before insert or decrypting after fetch         |
| `references/shared-log-encryption.md`    | Building SharedLogRow, partner key derivation/decryption   |
| `references/key-lifecycle.md`            | Key init on account creation, load on launch, sign out     |
| `references/tests.md`                    | Writing or reviewing encryption unit tests                 |

Always load the relevant reference file(s) before writing implementation code.
Never write encryption logic, key derivation, or Keychain code from memory.

---

## Orientation

This skill governs the client-side encryption layer for Cadence. Cadence stores
menstrual health data in Supabase. Supabase must never hold plaintext health data —
not in transit, not at rest in the rows, not in logs. All sensitive fields are encrypted
on-device before every write and decrypted on-device after every read.

This is not optional complexity. It is the core trust differentiator of the product,
stated explicitly in the PRD and privacy policy.

---

## Architecture Overview

### Mental model

```
User's device                           Supabase
─────────────────────────────           ────────────────────────────────
Plaintext health data (in memory)       Only encrypted blobs live here.
        │                               Never plaintext. Not even partially.
        ▼
 EncryptionService.encrypt()
        │
        ▼
 AES-256-GCM sealed box
 (base64 encoded for Supabase)
        │──────────────────────────────▶  cycle_logs.period_flow = "abc123..."
                                          cycle_logs.mood        = "def456..."
                                          ...
```

### Key derivation

Each user has a per-user 256-bit symmetric key derived (not randomly generated)
using HKDF-SHA256:

```
UserKey = HKDF<SHA256>(
    inputKeyMaterial : masterSecret,            // fetched from Edge Function post-auth
    salt             : userID.utf8Data,         // the user's Supabase UUID
    info             : "cadence-v1-user-key",   // domain-separation string — NEVER change
    outputByteCount  : 32                       // 256-bit key for AES-256-GCM
)
```

**masterSecret** — app-level secret stored as a Supabase Edge Function environment
variable. Delivered to authenticated clients via `/vault/master-secret` with the
user's JWT. Not stored in Keychain, UserDefaults, or app bundle.

**Derived key** — stored in iOS Keychain under
`kSecAttrAccessibleWhenUnlockedThisDeviceOnly`. Loaded into memory on app launch.

### Why HKDF and not random key generation

The key is deterministic from (masterSecret + userID). A partner derives the tracker's
key locally — `HKDF(masterSecret, trackerUserID)` — without any explicit key exchange.
This is how partners decrypt `shared_logs` rows.

### AES-256-GCM properties

- CryptoKit `AES.GCM.seal` generates a **random 12-byte nonce per call**. Never pass
  a nonce manually. Never reuse a nonce.
- `.combined` packs `[12B nonce][ciphertext][16B auth tag]` into a single `Data` blob.
- This blob is base64-encoded for storage as a `String` in Supabase.
- The auth tag is verified automatically by `AES.GCM.open`. If tampered, decryption
  throws. Do not swallow this error.

---

## Encrypted Fields

| Field | Swift type before encryption | Encoding before encryption |
|---|---|---|
| `period_flow` | `PeriodFlow?` (enum) | `.rawValue` -> String |
| `mood` | `[Mood]` | JSON-encode array -> String |
| `energy` | `EnergyLevel?` (enum) | `.rawValue` -> String |
| `symptoms` | `[Symptom]` | JSON-encode array -> String |
| `sleep_quality` | `SleepQuality?` (enum) | `.rawValue` -> String |
| `intimacy_logged` | `Bool` | `"true"` or `"false"` |
| `intimacy_protected` | `Bool?` | `"true"` or `"false"` |
| `notes` | `String?` | as-is |

**Non-encrypted in `cycle_logs`:** `id`, `user_id`, `log_date`.
**Non-encrypted in `shared_logs`:** `id`, `tracker_user_id`, `partner_user_id`,
`log_date`, `cycle_day`, `cycle_phase`, `predicted_next_period`.

---

## Key Lifecycle Summary

See `references/key-lifecycle.md` for full implementations.

| Event | Action |
|---|---|
| Account creation | Fetch master secret from Edge Function, call `initialiseKey(masterSecret:userID:)` |
| App launch (session restored) | Call `loadKey(forUserID:)` — reads from Keychain |
| Keychain miss (reinstall/restore) | Re-fetch master secret, call `loadKey(forUserID:masterSecret:)` |
| Sign out | Call `clearKey()` — clears memory, keeps Keychain entry |
| Account deletion | Call `purgeKey(forUserID:)` — deletes Keychain entry |

---

## Partner Key Exchange Summary

See `references/shared-log-encryption.md` for full implementations.

The key exchange is implicit — not a separate protocol step:

1. Both tracker and partner authenticate with Supabase.
2. Both call `/vault/master-secret` and receive the same master secret.
3. Tracker's user ID is in `partner_connections` — partner already has it.
4. Partner calls `deriveKey(from: masterSecret, userID: trackerUserID)`.
5. This produces the exact same key the tracker uses for `shared_logs`.

**Security note**: The master secret is the trust anchor. Whoever holds it can derive
any user's key. It must be delivered only to authenticated sessions, never logged,
never cached to disk, never included in crash reports.

---

## What NOT to Do

These are hard rules. Violating any of them breaks the encryption model.

### Never hardcode the master secret
```swift
// WRONG — secret is in the binary
let masterSecret = "a1b2c3d4e5f6...".data(using: .utf8)!
```
The master secret must come from the Edge Function over authenticated HTTPS.

### Never store the master secret in UserDefaults
```swift
// WRONG — UserDefaults is unencrypted and readable from backups
UserDefaults.standard.set(masterSecretData, forKey: "masterSecret")
```
Derive the user key, store derived key in Keychain, discard master secret.

### Never store the derived key in UserDefaults
```swift
// WRONG — same problem
UserDefaults.standard.set(derivedKeyData, forKey: "userKey")
```
Derived keys live in Keychain under `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` only.

### Never use CommonCrypto instead of CryptoKit
```swift
// WRONG — CommonCrypto is the C-level API
import CommonCrypto
CCCrypt(kCCEncrypt, kCCAlgorithmAES, ...)
```
CryptoKit is available from iOS 13. Use it exclusively.

### Never provide a custom nonce to AES.GCM.seal
```swift
// WRONG — nonce reuse with the same key is catastrophic
let nonce = try AES.GCM.Nonce(data: someData)
let sealedBox = try AES.GCM.seal(data, using: key, nonce: nonce)
```
Always call `AES.GCM.seal(data, using: key)` without a nonce argument.

### Never silently ignore decryption errors
```swift
// WRONG — hides data integrity violations
let plaintext = try? enc.decrypt(ciphertext) ?? ""
```
Decryption errors must propagate. Show an error state, never silently substitute.

### Never encrypt nil optionals as the string "nil"
```swift
// WRONG — stores encrypted "nil" string
periodFlow = try enc.encrypt(String(describing: log.periodFlow))
```
If a field is nil, write nil to Supabase. Only encrypt non-nil values.

### Never change `hkdfInfo` after shipping
The info string `"cadence-v1-user-key"` is baked into every derived key. Changing it
silently rotates all keys — existing encrypted data becomes unreadable.

---

## Encryption Checklist for Code Review

Before approving any PR that touches encryption or Supabase writes:

- [ ] All fields in the encrypted fields list are encrypted before insert/upsert
- [ ] No health field is written as plaintext to any Supabase table
- [ ] Master secret fetched from Edge Function — not hardcoded, not from UserDefaults
- [ ] Derived key stored in Keychain under `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`
- [ ] `AES.GCM.seal` called without a custom nonce
- [ ] Decryption errors propagate — not swallowed
- [ ] `nil` optionals stored as SQL `NULL`, not encrypted `"nil"` string
- [ ] `shared_logs` encrypted with tracker's key, not partner's key
- [ ] Partner decryption uses `decrypt(_:using:)` with tracker's derived key
- [ ] `hkdfInfo` constant `"cadence-v1-user-key"` has not been modified

---

## File Placement

```
Cadence/
  Services/
    EncryptionService.swift          <- singleton, key lifecycle, encrypt/decrypt
    AuthService.swift                <- fetchMasterSecret(), onAccountCreated()
    SharedLogService.swift           <- buildSharedLogRow(), decryptSharedLog()
  Models/
    CycleLog.swift                   <- CycleLog (domain) + CycleLogRow (Supabase)
    SharedLogRow.swift               <- SharedLogRow (Supabase) + DecryptedSharedLog
CadenceTests/
    EncryptionServiceTests.swift     <- round trip, nonce uniqueness, wrong key, tamper
```
