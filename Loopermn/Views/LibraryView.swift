import SwiftUI
import AppKit

struct EmptyStateView: View {
    @EnvironmentObject var viewModel: AppViewModel

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(AppTheme.accentSoft)
                    .frame(width: 88, height: 88)
                Image(systemName: "waveform")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(AppTheme.accent)
            }

            Text("No samples yet")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)

            Text("Import a folder of loops or download samples\nfrom Browser to build your library.")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)

            Button(action: { viewModel.selectFolder() }) {
                HStack(spacing: 8) {
                    Image(systemName: "folder.badge.plus")
                    Text("Import folder")
                        .fontWeight(.semibold)
                }
                .foregroundStyle(AppTheme.bgDeep)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    Capsule(style: .continuous).fill(AppTheme.accent)
                )
            }
            .buttonStyle(.plain)
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.bgBase)
    }
}

struct LibraryView: View {
    @EnvironmentObject var viewModel: AppViewModel

    var body: some View {
        HStack(spacing: 0) {
            SidebarView()

            if viewModel.loops.isEmpty && !viewModel.isLoading {
                EmptyStateView()
            } else {
                LoopGridView()
            }
        }
        .background(AppTheme.bgBase)
        .onDrop(of: ["public.file-url"], isTargeted: nil) { providers in
            handleDroppedItems(providers)
            return true
        }
    }

    private func handleDroppedItems(_ providers: [NSItemProvider]) {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, _ in
                let url: URL? = {
                    if let url = item as? URL { return url }
                    if let data = item as? Data {
                        return URL(dataRepresentation: data, relativeTo: nil)
                    }
                    return nil
                }()
                guard let url else { return }

                var isDirectory: ObjCBool = false
                FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)

                Task { @MainActor in
                    if isDirectory.boolValue {
                        viewModel.scanFolder(at: url)
                    } else {
                        _ = try? await viewModel.addLoopItem(from: url, switchToLibrary: false)
                    }
                }
            }
        }
    }
}
