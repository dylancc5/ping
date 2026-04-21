import Foundation

enum Config {
    // Read from Info.plist (injected via Config.xcconfig — see Config.xcconfig.example)
    static let supabaseURL: String = {
        let host = required("SUPABASE_HOST")
        validateSupabaseHost(host)
        return "https://\(host)"
    }()
    static let supabaseAnonKey: String = {
        let key = required("SUPABASE_ANON_KEY")
        validateSupabaseAnonKey(key)
        return key
    }()
    static let googleClientID: String = required("GOOGLE_CLIENT_ID")

    private static func required(_ key: String) -> String {
        guard let value = Bundle.main.infoDictionary?[key] as? String, !value.isEmpty else {
            preconditionFailure("Missing required config key '\(key)' — copy Config.xcconfig.example to Config.xcconfig and fill in your values.")
        }
        return value
    }

    private static func validateSupabaseHost(_ host: String) {
        guard !host.contains("://") else {
            preconditionFailure("SUPABASE_HOST must be the hostname only (e.g. abc.supabase.co), not a full URL.")
        }
        guard host.contains("supabase.co") else {
            preconditionFailure("SUPABASE_HOST should look like your-project-ref.supabase.co from Dashboard → Settings → API.")
        }
        if isPlaceholder(host) {
            preconditionFailure("Replace placeholder SUPABASE_HOST in Config.xcconfig with your project hostname.")
        }
    }

    private static func validateSupabaseAnonKey(_ key: String) {
        let segments = key.split(separator: ".")
        guard segments.count == 3 else {
            preconditionFailure("SUPABASE_ANON_KEY must be the full anon JWT from Dashboard → Settings → API (three dot-separated segments).")
        }
        if isPlaceholder(key) {
            preconditionFailure("Replace placeholder SUPABASE_ANON_KEY in Config.xcconfig with the anon public key from the Supabase dashboard.")
        }
    }

    private static func isPlaceholder(_ value: String) -> Bool {
        let lower = value.lowercased()
        return lower.contains("your-supabase") || lower.contains("your-project") || lower == "your-supabase-anon-key"
    }

}
