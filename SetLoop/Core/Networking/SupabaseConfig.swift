import Foundation

struct SupabaseConfig {
    let projectURL: URL
    let publishableKey: String

    var isConfigured: Bool {
        !projectURL.absoluteString.contains("YOUR_PROJECT_ID") &&
        !publishableKey.contains("YOUR_SUPABASE_PUBLISHABLE_KEY") &&
        !publishableKey.isEmpty
    }

    static var live: SupabaseConfig {
        let bundle = Bundle.main
        let urlString = bundle.object(forInfoDictionaryKey: "SUPABASE_URL") as? String
            ?? ProcessInfo.processInfo.environment["SUPABASE_URL"]
            ?? "https://YOUR_PROJECT_ID.supabase.co"

        let key = bundle.object(forInfoDictionaryKey: "SUPABASE_PUBLISHABLE_KEY") as? String
            ?? ProcessInfo.processInfo.environment["SUPABASE_PUBLISHABLE_KEY"]
            ?? "YOUR_SUPABASE_PUBLISHABLE_KEY"

        return SupabaseConfig(
            projectURL: URL(string: urlString) ?? URL(string: "https://YOUR_PROJECT_ID.supabase.co")!,
            publishableKey: key
        )
    }
}
