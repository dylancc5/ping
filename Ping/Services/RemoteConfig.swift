import Foundation

// MARK: - Config struct

struct RemoteConfig: Codable, Sendable {
    var coolingWarmthThreshold: Double = 0.5
    var coolingIdleDays: Double = 7
    var warmthHotThreshold: Double = 0.8
    var warmthWarmThreshold: Double = 0.5
    var warmthCoolThreshold: Double = 0.2
    var geminiGenerationModel: String = "gemini-2.0-flash"
    var geminiEmbeddingModel: String = "gemini-embedding-2-preview"
    var geminiDraftTemperature: Double = 0.7
    var geminiDraftMaxTokens: Int = 200
    var contactMatchThreshold: Double = 0.5
    var goalMatchThreshold: Double = 0.45

    static let defaults = RemoteConfig()

    enum CodingKeys: String, CodingKey {
        case coolingWarmthThreshold = "cooling_warmth_threshold"
        case coolingIdleDays        = "cooling_idle_days"
        case warmthHotThreshold     = "warmth_hot_threshold"
        case warmthWarmThreshold    = "warmth_warm_threshold"
        case warmthCoolThreshold    = "warmth_cool_threshold"
        case geminiGenerationModel  = "gemini_generation_model"
        case geminiEmbeddingModel   = "gemini_embedding_model"
        case geminiDraftTemperature = "gemini_draft_temperature"
        case geminiDraftMaxTokens   = "gemini_draft_max_tokens"
        case contactMatchThreshold  = "contact_match_threshold"
        case goalMatchThreshold     = "goal_match_threshold"
    }

    init() {}

    // Partial-decode: missing keys fall back to defaults rather than throwing.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Self.defaults
        coolingWarmthThreshold = (try? c.decode(Double.self, forKey: .coolingWarmthThreshold)) ?? d.coolingWarmthThreshold
        coolingIdleDays        = (try? c.decode(Double.self, forKey: .coolingIdleDays))        ?? d.coolingIdleDays
        warmthHotThreshold     = (try? c.decode(Double.self, forKey: .warmthHotThreshold))     ?? d.warmthHotThreshold
        warmthWarmThreshold    = (try? c.decode(Double.self, forKey: .warmthWarmThreshold))    ?? d.warmthWarmThreshold
        warmthCoolThreshold    = (try? c.decode(Double.self, forKey: .warmthCoolThreshold))    ?? d.warmthCoolThreshold
        geminiGenerationModel  = (try? c.decode(String.self, forKey: .geminiGenerationModel))  ?? d.geminiGenerationModel
        geminiEmbeddingModel   = (try? c.decode(String.self, forKey: .geminiEmbeddingModel))   ?? d.geminiEmbeddingModel
        geminiDraftTemperature = (try? c.decode(Double.self, forKey: .geminiDraftTemperature)) ?? d.geminiDraftTemperature
        geminiDraftMaxTokens   = (try? c.decode(Int.self,    forKey: .geminiDraftMaxTokens))   ?? d.geminiDraftMaxTokens
        contactMatchThreshold  = (try? c.decode(Double.self, forKey: .contactMatchThreshold))  ?? d.contactMatchThreshold
        goalMatchThreshold     = (try? c.decode(Double.self, forKey: .goalMatchThreshold))     ?? d.goalMatchThreshold
    }
}

// MARK: - Service

@Observable
@MainActor
final class RemoteConfigService {
    static let shared = RemoteConfigService()

    private(set) var config: RemoteConfig = .defaults
    private(set) var version: Int = 0

    private let cacheURL: URL = {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        return caches.appendingPathComponent("remote_config.json")
    }()

    private init() {
        loadFromDiskCache()
    }

    /// Fire-and-forget on app launch. Returns immediately; fetch updates
    /// the cache in the background. App is never blocked on this.
    func refresh() async {
        do {
            let row = try await SupabaseService.shared.fetchAppConfig()
            guard row.version != version else { return }
            config = row.data
            version = row.version
            saveToDiskCache(row)
        } catch {
            // Silent — defaults + cached values keep the app working.
        }
    }

    private func loadFromDiskCache() {
        guard let data = try? Data(contentsOf: cacheURL),
              let row = try? JSONDecoder().decode(ConfigRow.self, from: data) else { return }
        config = row.data
        version = row.version
    }

    private func saveToDiskCache(_ row: ConfigRow) {
        guard let data = try? JSONEncoder().encode(row) else { return }
        try? data.write(to: cacheURL, options: .atomic)
    }

    struct ConfigRow: Codable, Sendable {
        let version: Int
        let data: RemoteConfig
    }
}
