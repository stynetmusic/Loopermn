import SwiftUI

struct LoopGridView: View {
    @EnvironmentObject var viewModel: AppViewModel

    var body: some View {
        VStack(spacing: 0) {
            SearchBarView()

            HStack {
                Text("\(viewModel.selectedTab.rawValue) · \(viewModel.filteredLoops.count) samples")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppTheme.textTertiary)

                if viewModel.libraryLayout == .list {
                    Text("· List")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppTheme.textMuted)
                }

                Spacer()

                if let key = viewModel.selectedKey {
                    MetaChip(text: "Key: \(key.rawValue)", emphasized: true)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)

            ScrollViewReader { proxy in
                ScrollView {
                    Group {
                        if viewModel.filteredLoops.isEmpty {
                            filteredEmptyState
                        } else {
                            switch viewModel.libraryLayout {
                            case .grid:
                                gridContent
                            case .list:
                                listContent
                            }
                        }
                    }
                    .id(viewModel.selectedTab)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 100)
                    .animation(.easeOut(duration: 0.2), value: viewModel.libraryLayout)
                    .animation(.easeOut(duration: 0.15), value: viewModel.filteredLoops.count)
                }
                .onChange(of: viewModel.highlightedLoopID) { _, id in
                    guard let id else { return }
                    withAnimation(.easeInOut(duration: 0.35)) {
                        proxy.scrollTo(id, anchor: .center)
                    }
                }
            }
        }
        .background(AppTheme.bgBase)
    }

    private var filteredEmptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: emptyIcon)
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(AppTheme.accent)
            Text(emptyTitle)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
            Text(emptySubtitle)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }

    private var emptyIcon: String {
        switch viewModel.selectedTab {
        case .favorites: return "heart"
        case .recent: return "clock"
        case .collections: return "folder"
        case .allLoops: return "waveform.slash"
        }
    }

    private var emptyTitle: String {
        switch viewModel.selectedTab {
        case .favorites: return "No favorites yet"
        case .recent: return "No recent loops"
        case .collections: return "No collections yet"
        case .allLoops: return "No matching samples"
        }
    }

    private var emptySubtitle: String {
        switch viewModel.selectedTab {
        case .favorites: return "Right-click a loop and choose Add to favorites."
        case .recent: return "Imported loops will show up here."
        case .collections: return "Collections are coming later."
        case .allLoops: return "Try clearing search or key filters."
        }
    }

    private var gridContent: some View {
        LazyVGrid(
            columns: [
                GridItem(.adaptive(minimum: 240, maximum: 320), spacing: 14)
            ],
            spacing: 14
        ) {
            ForEach(viewModel.filteredLoops) { item in
                LoopCardView(item: item)
                    .id(item.id)
                    .onTapGesture {
                        viewModel.currentPlayerItem = item
                    }
            }
        }
    }

    private var listContent: some View {
        LazyVStack(spacing: 8) {
            // Column headers
            HStack(spacing: 14) {
                Color.clear.frame(width: 28)
                Text("NAME")
                    .frame(width: 180, alignment: .leading)
                Text("WAVEFORM")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("BPM")
                    .frame(width: 56, alignment: .center)
                Text("KEY")
                    .frame(width: 44, alignment: .center)
                Text("TIME")
                    .frame(width: 48, alignment: .trailing)
                Color.clear.frame(width: 28)
            }
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundStyle(AppTheme.textMuted)
            .padding(.horizontal, 14)
            .padding(.bottom, 4)

            ForEach(viewModel.filteredLoops) { item in
                LoopListRowView(item: item)
                    .id(item.id)
            }
        }
    }
}
