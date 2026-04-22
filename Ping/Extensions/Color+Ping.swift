import SwiftUI

extension Color {
    // Backgrounds
    static let pingBackground   = Color(light: "FAFAF7", dark: "111110")
    static let pingSurface      = Color(light: "FFFFFF", dark: "1C1C1A")
    static let pingSurface2     = Color(light: "F5F4F0", dark: "252522")
    static let pingSurface3     = Color(light: "EEECE8", dark: "2E2E2B")

    // Text
    static let pingTextPrimary   = Color(light: "1A1A1A", dark: "F0EFE9")
    static let pingTextSecondary = Color(light: "6B6B6B", dark: "A8A89E")
    static let pingTextMuted     = Color(light: "9B9B9B", dark: "6E6E66")
    static let pingTextSubtle    = Color(light: "C5C5C5", dark: "484842")

    // Accent — same hue in both modes, slightly lighter in dark
    static let pingAccent        = Color(light: "E8845A", dark: "ED9270")
    static let pingAccentLight   = Color(light: "F5D0BC", dark: "3A2218")
    static let pingAccentBadge   = Color(light: "F5E0D4", dark: "2E1E14")
    static let pingAccent2       = Color(light: "D4A96A", dark: "D9B47A")
    static let pingAccent2Light  = Color(light: "F0DFC0", dark: "2E2410")

    // Semantic
    static let pingSuccess       = Color(light: "6DBF8F", dark: "7ACCA0")
    static let pingSuccessLight  = Color(light: "D4F0E2", dark: "0E2B1B")
    static let pingDestructive   = Color(light: "E05252", dark: "E86666")
    static let pingDestructiveLight = Color(light: "FADADD", dark: "2D0D0F")

    // Warmth spectrum
    static let pingWarmthHot     = Color(light: "E8845A", dark: "ED9270")
    static let pingWarmthWarm    = Color(light: "D4A96A", dark: "D9B47A")
    static let pingWarmthCool    = Color(light: "B8C5D6", dark: "6E8299")
    static let pingWarmthCold    = Color(light: "D4D4D4", dark: "4A4A4A")
}

extension Color {
    init(light lightHex: String, dark darkHex: String) {
        self.init(UIColor(dynamicProvider: { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(hex: darkHex)
                : UIColor(hex: lightHex)
        }))
    }

    init(hex: String) {
        self.init(UIColor(hex: hex))
    }
}

private extension UIColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = CGFloat((int >> 16) & 0xFF) / 255
        let g = CGFloat((int >> 8) & 0xFF) / 255
        let b = CGFloat(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b, alpha: 1)
    }
}

// MARK: - Warmth Category

enum WarmthCategory {
    case hot, warm, cool, cold

    @MainActor
    init(score: Double) {
        self.init(score: score, config: RemoteConfigService.shared.config)
    }

    init(score: Double, config: RemoteConfig) {
        if score >= config.warmthHotThreshold {
            self = .hot
        } else if score >= config.warmthWarmThreshold {
            self = .warm
        } else if score >= config.warmthCoolThreshold {
            self = .cool
        } else {
            self = .cold
        }
    }

    var color: Color {
        switch self {
        case .hot:  return .pingWarmthHot
        case .warm: return .pingWarmthWarm
        case .cool: return .pingWarmthCool
        case .cold: return .pingWarmthCold
        }
    }

    var label: String {
        switch self {
        case .hot:  return "Hot"
        case .warm: return "Warm"
        case .cool: return "Cool"
        case .cold: return "Cold"
        }
    }
}
