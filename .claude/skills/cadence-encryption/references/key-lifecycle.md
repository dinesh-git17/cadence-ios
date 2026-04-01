# Key Initialisation Lifecycle — Swift Reference

---

## New User (Account Creation Flow)

```swift
// In AuthService or AccountCreationViewModel, immediately after Supabase sign-up succeeds:

func onAccountCreated(userID: String) async throws {
    // 1. Fetch master secret from Edge Function. Must be called with the new session JWT.
    let masterSecret = try await fetchMasterSecret()

    // 2. Derive and persist the user's key. This is the only time we touch masterSecret.
    try EncryptionService.shared.initialiseKey(masterSecret: masterSecret, userID: userID)

    // 3. masterSecret goes out of scope here. It is not stored anywhere.

    // 4. Continue to onboarding.
}
```

---

## Returning User (App Launch)

```swift
// In AppDelegate or the root SwiftUI App struct, after Supabase auth restores a session:

func onSessionRestored(userID: String) async throws {
    do {
        // Happy path: key is in Keychain from the previous session.
        try EncryptionService.shared.loadKey(forUserID: userID)
    } catch EncryptionError.missingKey {
        // Recovery path: Keychain miss (device restore, reinstall, Keychain corruption).
        // Re-derive the key from the master secret.
        let masterSecret = try await fetchMasterSecret()
        try EncryptionService.shared.loadKey(forUserID: userID, masterSecret: masterSecret)
    }
    // Any other EncryptionError (Keychain permission failure etc.) propagates up.
}
```

---

## Sign Out

```swift
func onSignOut() {
    // Clear the in-memory key. The Keychain entry survives for the next sign-in.
    EncryptionService.shared.clearKey()
    // Clear Supabase session.
    supabase.auth.signOut()
}
```

---

## Master Secret Delivery (Edge Function Contract)

The Edge Function at `/vault/master-secret` must:

1. Validate the caller's Supabase JWT (`Authorization: Bearer <jwt>`).
2. Return the master secret as a hex or base64 string in the response body.
3. Return `401 Unauthorized` for unauthenticated or expired requests.
4. Set no-cache headers on the response.

```swift
// Cadence/Services/AuthService.swift

private func fetchMasterSecret() async throws -> Data {
    let response = try await supabase.functions.invoke(
        "vault/master-secret",
        options: FunctionInvokeOptions(method: .get)
    )
    // Response body is a JSON object: { "secret": "<hex string>" }
    guard let secretHex = response["secret"] as? String,
          let secretData = Data(hexString: secretHex) else {
        throw EncryptionError.keyDerivationFailure(
            "Master secret response from Edge Function is malformed."
        )
    }
    return secretData
}
```
