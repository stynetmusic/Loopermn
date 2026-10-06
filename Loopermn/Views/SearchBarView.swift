import SwiftUI

struct SearchBarView: View {
    @EnvironmentObject var viewModel: AppViewModel

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.textTertiary)

                TextField("Search samples, BPM, key, tags…", text: $viewModel.searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.textPrimary)
                    .submitLabel(.search)

                if !viewModel.searchText.isEmpty {
                    Button(action: { viewModel.searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(AppTheme.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AppTheme.bgElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(AppTheme.borderSubtle, lineWidth: 1)
            )

            // Grid / List toggle
            HStack(spacing: 0) {
                ForEach(LibraryLayoutMode.allCases) { mode in
                    Button {
                        withAnimation(.easeOut(duration: 0.15)) {
                            viewModel.libraryLayout = mode
                        }
                    } label: {
                        Image(systemName: mode.icon)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(
                                viewModel.libraryLayout == mode ? AppTheme.bgDeep : AppTheme.textSecondary
                            )
                            .frame(width: 34, height: 32)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(
                                        viewModel.libraryLayout == mode
                                            ? AppTheme.accent
                                            : Color.clear
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                    .help(mode.label)
                }
            }
            .padding(3)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(AppTheme.bgElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(AppTheme.borderSubtle, lineWidth: 1)
            )

            Menu {
                Picker("Sort", selection: $viewModel.sortOption) {
                    ForEach(SortOption.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.arrow.down")
                    Text("Sort")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(AppTheme.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(AppTheme.bgElevated)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(AppTheme.borderSubtle, lineWidth: 1)
                )
            }
            .menuStyle(.borderlessButton)

            Button(action: { viewModel.selectFolder() }) {
                HStack(spacing: 6) {
                    Image(systemName: "folder.badge.plus")
                    Text("Import")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(AppTheme.bgDeep)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(AppTheme.accent)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(AppTheme.bgBase)
        .overlay(alignment: .bottom) {
            SpliceDivider()
        }
    }
}
