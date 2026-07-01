import SwiftUI

// MARK: - Colours

extension Color {
    // Brand primaries
    static let muckGreen    = Color("MuckGreen")      // Deep vivid green — primary action
    static let muckAmber    = Color("MuckAmber")      // Warm amber — nav accents, urgency
    static let muckRed      = Color("MuckRed")        // Alert red — hazard

    // Surfaces
    static let muckSurface  = Color("MuckSurface")    // Card background
    static let muckBg       = Color("MuckBg")         // App background (off-white / near-black)
    static let muckNearBlack = Color("MuckNearBlack") // Primary text
}

extension Color {
    // Muck type colours
    static func muckTypeColor(_ type: MuckType) -> Color {
        switch type {
        case .cleanup: return .muckGreen
        case .hazard:  return .muckRed
        case .repair:  return .muckAmber
        }
    }

    // Help category colours — warmer, "neighbourly" palette distinct from muck types
    static func helpCategoryColor(_ category: HelpCategory) -> Color {
        switch category {
        case .yardWork:      return .muckGreen
        case .moving:        return Color(hex: "6366F1") // indigo
        case .repairs:       return .muckAmber
        case .companionship: return Color(hex: "EC4899") // pink
        case .other:         return Color(hex: "64748B") // slate
        }
    }

    // Partner source colours
    static func partnerColor(_ source: PartnerSource) -> Color {
        switch source {
        case .trashmob:           return Color(hex: "7C3AED") // purple
        case .wcd:                return Color(hex: "2563EB") // blue
        case .justserve:          return Color(hex: "0D9488") // teal
        case .volunteerconnector: return Color(hex: "4F46E5") // indigo
        case .openlittermap:      return Color(hex: "EA580C") // orange
        case .epa:                return Color(hex: "DC2626") // red
        }
    }

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8)  & 0xFF) / 255
        let b = Double(int         & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Typography

extension Font {
    // Display — heavy condensed for headers
    static let muckDisplay  = Font.system(size: 28, weight: .black, design: .default)
    static let muckTitle    = Font.system(size: 17, weight: .bold,  design: .default)
    static let muckHeadline = Font.system(size: 15, weight: .semibold)
    static let muckBody     = Font.system(size: 13, weight: .regular)
    static let muckCaption  = Font.system(size: 11, weight: .semibold)
    static let muckMicro    = Font.system(size: 10, weight: .medium)
}

// MARK: - Spacing

enum Spacing {
    static let xxxs: CGFloat = 2
    static let xxs:  CGFloat = 4
    static let xs:   CGFloat = 8
    static let sm:   CGFloat = 12
    static let md:   CGFloat = 16
    static let lg:   CGFloat = 20
    static let xl:   CGFloat = 24
    static let xxl:  CGFloat = 32
    static let xxxl: CGFloat = 48
}

// MARK: - Radius

enum Radius {
    static let xs:  CGFloat = 4
    static let sm:  CGFloat = 8
    static let md:  CGFloat = 12
    static let lg:  CGFloat = 16
    static let xl:  CGFloat = 24
    static let full: CGFloat = 999
}

// MARK: - Shadow

extension View {
    func muckCardShadow() -> some View {
        self.shadow(color: .black.opacity(0.07), radius: 8, x: 0, y: 2)
    }

    func muckFloatShadow() -> some View {
        self.shadow(color: .black.opacity(0.18), radius: 16, x: 0, y: 6)
    }
}
