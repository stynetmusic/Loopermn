import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var viewModel: AppViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("LIBRARY")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.textTertiary)
                .tracking(1.2)
                .padding(.horizontal, 16)
                .padding(.top, 18)
                .padding(.bottom, 12)

            VStack(spacing: 2) {
                ForEach(SidebarTab.allCases) { tab in
                    Button {
                        viewModel.selectTab(tab)
                    } label: {
                        SidebarRow(
                            tab: tab,
                            count: countFor(tab: tab),
                            isSelected: viewModel.selectedTab == tab
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)

            SpliceDivider()
                .padding(.vertical, 14)

            Text("KEY")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.textTertiary)
                .tracking(1.2)
                .padding(.horizontal, 16)
                .padding(.bottom, 10)

            ScrollView {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 40), spacing: 6)],
                    spacing: 6
                ) {
                    keyChip(nil, label: "All", color: AppTheme.accent)
                    ForEach(LoopKey.allCases.filter { $0 != .unknown }) { key in
                        keyChip(key, label: key.rawValue, color: AppTheme.color(for: key))
                    }
                }
                .padding(.horizontal, 12)
            }

            Spacer(minLength: 0)

            Button(action: { viewModel.selectedKey = nil }) {
                HStack(spacing: 6) {
                    Image(systemName: "xmark.circle")
                    Text("Reset filters")
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppTheme.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.cornerSm, style: .continuous)
                        .fill(AppTheme.bgElevated)
                )
            }
            .buttonStyle(.plain)
            .padding(12)
        }
        .frame(width: AppTheme.sidebarWidth)
        .background(AppTheme.bgBase)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(AppTheme.borderSubtle)
                .frame(width: 1)
        }
    }

    private func keyChip(_ key: LoopKey?, label: String, color: Color) -> some View {
        let selected = (key == nil && viewModel.selectedKey == nil)
            || (key != nil && viewModel.selectedKey == key)
        return Button(action: {
            viewModel.selectedKey = key
        }) {
            Text(label)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(selected ? color : AppTheme.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(selected ? color.opacity(0.16) : AppTheme.bgElevated)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(selected ? color.opacity(0.5) : AppTheme.borderSubtle, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func countFor(tab: SidebarTab) -> Int {
        switch tab {
        case .collections: return 0
        case .allLoops: return viewModel.loops.count
        case .recent: return min(viewModel.loops.count, LoopFileDrag.recentLimit)
        case .favorites: return viewModel.loops.filter { $0.isFavorite }.count
        }
    }
}

struct SidebarRow: View {
    let tab: SidebarTab
    let count: Int
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: tab.icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(isSelected ? AppTheme.accent : AppTheme.textSecondary)
                .frame(width: 18)

            Text(tab.rawValue)
                .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                .foregroundStyle(isSelected ? AppTheme.textPrimary : AppTheme.textSecondary)

            Spacer()

            Text("\(count)")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(isSelected ? AppTheme.accent : AppTheme.textTertiary)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(isSelected ? AppTheme.accentSoft : AppTheme.bgElevated)
                )
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isSelected ? AppTheme.accentSoft : Color.clear)
        )
        .contentShape(Rectangle())
    }
}
