import SwiftUI
import AppKit

/// Visual language inspired by modern sample browsers (Splice-like).
enum AppTheme {
    // MARK: - Surfaces
    static let bgDeep = Color(red: 0.05, green: 0.05, blue: 0.06)       // #0D0D0F
    static let bgBase = Color(red: 0.08, green: 0.08, blue: 0.09)       // #141416
    static let bgRaised = Color(red: 0.11, green: 0.11, blue: 0.13)     // #1C1C21
    static let bgElevated = Color(red: 0.14, green: 0.14, blue: 0.16)   // #242429
    static let bgHover = Color(red: 0.17, green: 0.17, blue: 0.19)

    // MARK: - Borders
    static let borderSubtle = Color.white.opacity(0.06)
    static let borderMedium = Color.white.opacity(0.10)
    static let borderStrong = Color.white.opacity(0.16)

    // MARK: - Text
    static let textPrimary = Color.white.opacity(0.94)
    static let textSecondary = Color.white.opacity(0.55)
    static let textTertiary = Color.white.opacity(0.35)
    static let textMuted = Color.white.opacity(0.22)

    // MARK: - Accent (Splice-like mint)
    static let accent = Color(red: 0.15, green: 0.88, blue: 0.62)       // #26E09E
    static let accentDim = Color(red: 0.15, green: 0.88, blue: 0.62).opacity(0.18)
    static let accentSoft = Color(red: 0.15, green: 0.88, blue: 0.62).opacity(0.12)
    static let danger = Color(red: 1.0, green: 0.32, blue: 0.32)

    // MARK: - Waveform
    static let waveFill = Color(red: 0.15, green: 0.88, blue: 0.62).opacity(0.75)
    static let waveTrack = Color.white.opacity(0.08)

    // MARK: - Layout
    static let railWidth: CGFloat = 64
    static let sidebarWidth: CGFloat = 220
    static let playerHeight: CGFloat = 72
    static let cornerSm: CGFloat = 8
    static let cornerMd: CGFloat = 12
    static let cornerLg: CGFloat = 16

    static func chipBackground(_ selected: Bool) -> Color {
        selected ? accentDim : bgElevated
    }

    static func chipForeground(_ selected: Bool) -> Color {
        selected ? accent : textSecondary
    }

    // MARK: - Key → color (chromatic ring for waveforms)

    /// Distinct hue per pitch class; unknown falls back to mint accent.
    static func color(for key: LoopKey) -> Color {
        switch key {
        case .c:      return Color(hue: 0.00, saturation: 0.72, brightness: 0.95) // red
        case .cSharp: return Color(hue: 0.05, saturation: 0.75, brightness: 0.95) // orange-red
        case .d:      return Color(hue: 0.10, saturation: 0.78, brightness: 0.96) // orange
        case .dSharp: return Color(hue: 0.14, saturation: 0.80, brightness: 0.95) // amber
        case .e:      return Color(hue: 0.18, saturation: 0.75, brightness: 0.93) // gold
        case .f:      return Color(hue: 0.28, saturation: 0.70, brightness: 0.90) // lime
        case .fSharp: return Color(hue: 0.36, saturation: 0.72, brightness: 0.88) // green
        case .g:      return Color(hue: 0.45, saturation: 0.70, brightness: 0.88) // teal-green
        case .gSharp: return Color(hue: 0.52, saturation: 0.72, brightness: 0.90) // cyan
        case .a:      return Color(hue: 0.58, saturation: 0.70, brightness: 0.95) // sky
        case .aSharp: return Color(hue: 0.70, saturation: 0.65, brightness: 0.95) // indigo
        case .b:      return Color(hue: 0.80, saturation: 0.65, brightness: 0.95) // violet
        case .unknown: return accent
        }
    }

    static func nsColor(for key: LoopKey) -> NSColor {
        NSColor(color(for: key))
    }

    static func waveformGradient(for key: LoopKey) -> [NSColor] {
        let base = nsColor(for: key)
        return [
            base.withAlphaComponent(0.95),
            base.withAlphaComponent(0.45)
        ]
    }
}

enum LibraryLayoutMode: String, CaseIterable, Identifiable {
    case grid
    case list

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .grid: return "square.grid.2x2"
        case .list: return "list.bullet"
        }
    }

    var label: String {
        switch self {
        case .grid: return "Grid"
        case .list: return "List"
        }
    }
}

// MARK: - Shared chrome helpers

struct SpliceDivider: View {
    var body: some View {
        Rectangle()
            .fill(AppTheme.borderSubtle)
            .frame(height: 1)
    }
}

struct SpliceCardBackground: View {
    var isHighlighted: Bool = false
    var isHovered: Bool = false

    var body: some View {
        RoundedRectangle(cornerRadius: AppTheme.cornerMd, style: .continuous)
            .fill(isHovered || isHighlighted ? AppTheme.bgElevated : AppTheme.bgRaised)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerMd, style: .continuous)
                    .stroke(
                        isHighlighted
                            ? AppTheme.accent.opacity(0.7)
                            : (isHovered ? AppTheme.borderMedium : AppTheme.borderSubtle),
                        lineWidth: isHighlighted ? 1.5 : 1
                    )
            )
            .shadow(
                color: isHighlighted ? AppTheme.accent.opacity(0.2) : .black.opacity(0.25),
                radius: isHighlighted ? 12 : 6,
                y: 3
            )
    }
}

struct MetaChip: View {
    let text: String
    var emphasized: Bool = false

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold, design: .rounded))
            .foregroundStyle(emphasized ? AppTheme.accent : AppTheme.textSecondary)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                Capsule(style: .continuous)
                    .fill(emphasized ? AppTheme.accentSoft : AppTheme.bgElevated)
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(emphasized ? AppTheme.accent.opacity(0.35) : AppTheme.borderSubtle, lineWidth: 1)
            )
    }
}
