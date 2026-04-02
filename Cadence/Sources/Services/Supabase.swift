import Foundation
import Supabase

let supabase = SupabaseClient(
    supabaseURL: Secrets.supabaseURL,
    supabaseKey: Secrets.supabaseAnonKey,
    options: SupabaseClientOptions(
        auth: SupabaseClientOptions.AuthOptions(
            flowType: .pkce,
            emitLocalSessionAsInitialSession: true
        )
    )
)

enum Secrets {
    static var supabaseURL: URL {
        guard
            let urlString = Bundle.main.infoDictionary?["SUPABASE_URL"] as? String,
            let url = URL(string: urlString)
        else {
            fatalError("SUPABASE_URL not found in Info.plist. Check xcconfig configuration.")
        }
        return url
    }

    static var supabaseAnonKey: String {
        guard let key = Bundle.main.infoDictionary?["SUPABASE_ANON_KEY"] as? String else {
            fatalError("SUPABASE_ANON_KEY not found in Info.plist. Check xcconfig configuration.")
        }
        return key
    }

    static var encryptionSecret: Data {
        guard let encoded = Bundle.main.infoDictionary?["ENCRYPTION_SECRET"] as? String,
              let data = Data(base64Encoded: encoded)
        else {
            fatalError("ENCRYPTION_SECRET not found or invalid in Info.plist. Check xcconfig configuration.")
        }
        return data
    }
}
