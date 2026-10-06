import SwiftUI

struct ModeSidebarView: View {
    @EnvironmentObject var appViewModel: AppViewModel
    @State private var hoveredMode: AppMode? = nil

    var body: some View {
        VStack(spacing: 8) {
            // Brand mark
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [AppTheme.accent, AppTheme.accent.opacity(0.55)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 36, height: 36)
                Text("L")
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(AppTheme.bgDeep)
            }
            .padding(.top, 16)
            .padding(.bottom, 20)

            ModeButton(
                icon: "globe",
                label: "Browse",
                isSelected: appViewModel.currentMode == .browser,
                isHovered: hoveredMode == .browser
            )
            .onTapGesture { appViewModel.currentMode = .browser }
            .onHover { hovering in hoveredMode = hovering ? .browser : nil }

            ModeButton(
                icon: "square.stack.3d.up.fill",
                label: "Library",
                isSelected: appViewModel.currentMode == .library,
                isHovered: hoveredMode == .library
            )
            .onTapGesture { appViewModel.currentMode = .library }
            .onHover { hovering in hoveredMode = hovering ? .library : nil }

            ModeButton(
                icon: "music.note.list",
                label: "Studio",
                isSelected: appViewModel.currentMode == .studio,
                isHovered: hoveredMode == .studio
            )
            .onTapGesture { appViewModel.currentMode = .studio }
            .onHover { hovering in hoveredMode = hovering ? .studio : nil }

            Spacer()

            Text("mn")
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.textMuted)
                .padding(.bottom, 14)
        }
        .frame(width: AppTheme.railWidth)
        .background(AppTheme.bgDeep)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(AppTheme.borderSubtle)
                .frame(width: 1)
        }
    }
}

struct ModeButton: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let isHovered: Bool

    var body: some View {
        VStack(spacing: 5) {
            ZStack {
                if isSelected {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(AppTheme.accentSoft)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(AppTheme.accent.opacity(0.35), lineWidth: 1)
                        )
                } else if isHovered {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(AppTheme.bgHover)
                }

                Image(systemName: icon)
                    .font(.system(size: 18, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? AppTheme.accent : (isHovered ? AppTheme.textPrimary : AppTheme.textTertiary))
            }
            .frame(width: 42, height: 42)

            Text(label)
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundStyle(isSelected ? AppTheme.accent : AppTheme.textTertiary)
        }
        .frame(width: 52)
        .contentShape(Rectangle())
        .animation(.easeOut(duration: 0.15), value: isSelected)
        .animation(.easeOut(duration: 0.12), value: isHovered)
    }
}
