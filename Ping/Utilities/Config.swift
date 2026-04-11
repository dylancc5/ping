import Foundation

enum Config {
    // Read from Info.plist (injected via xcconfig or Xcode build settings)
    static let supabaseURL = Bundle.main.infoDictionary?["SUPABASE_URL"] as? String ?? ""
    static let supabaseAnonKey = Bundle.main.infoDictionary?["SUPABASE_ANON_KEY"] as? String ?? ""
    static let googleClientID = Bundle.main.infoDictionary?["GOOGLE_CLIENT_ID"] as? String ?? ""

    // Gemini API key stored in Keychain (never in plist or source)
    static var geminiAPIKey: String {
        KeychainHelper.get("GEMINI_API_KEY") ?? ""
    }
}
