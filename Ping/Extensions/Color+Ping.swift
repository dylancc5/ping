import SwiftUI

extension Color {
    // Backgrounds
    static let pingBackground   = Color(hex: "FAFAF7")
    static let pingSurface      = Color(hex: "FFFFFF")
    static let pingSurface2     = Color(hex: "F5F4F0")
    static let pingSurface3     = Color(hex: "EEECE8")

    // Text
    static let pingTextPrimary   = Color(hex: "1A1A1A")
    static let pingTextSecondary = Color(hex: "6B6B6B")
    static let pingTextMuted     = Color(hex: "9B9B9B")
    static let pingTextSubtle    = Color(hex: "C5C5C5")

    // Accent
    static let pingAccent        = Color(hex: "E8845A")
    static let pingAccentLight   = Color(hex: "F5D0BC")
    static let pingAccent2       = Color(hex: "D4A96A")
    static let pingAccent2Light  = Color(hex: "F0DFC0")

    // Semantic
    static let pingSuccess       = Color(hex: "6DBF8F")
    static let pingSuccessLight  = Color(hex: "D4F0E2")
    static let pingDestructive   = Color(hex: "E05252")
    static let pingDestructiveLight = Color(hex: "FADADD")

    // Warmth spectrum
    static let pingWarmthHot     = Color(hex: "E8845A")
    static let pingWarmthWarm    = Color(hex: "D4A96A")
    static let pingWarmthCool    = Color(hex: "B8C5D6")
    static let pingWarmthCold    = Color(hex: "D4D4D4")
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
