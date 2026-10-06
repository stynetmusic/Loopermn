import SwiftUI

struct MainView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @StateObject private var webViewModel = WebViewModel()

    var body: some View {
        HStack(spacing: 0) {
            ModeSidebarView()

            ZStack {
                if viewModel.currentMode == .library {
                    LibraryView()
                }

                if viewModel.currentMode == .browser {
                    BrowserView(webViewModel: webViewModel)
                }

                if viewModel.currentMode == .studio {
                    StudioView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(AppTheme.bgDeep)
        .preferredColorScheme(.dark)
        .overlay(alignment: .top) {
            if let message = webViewModel.downloadMessage {
                downloadToast(message: message, isError: webViewModel.downloadMessageIsError)
                    .padding(.top, 18)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: webViewModel.downloadMessage)
        .overlay(alignment: .bottom) {
            if let playerItem = viewModel.currentPlayerItem, viewModel.currentMode != .studio {
                PlayerBarView(playerItem: playerItem)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .overlay(alignment: .top) {
            if viewModel.isLoading {
                HStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.small)
                        .tint(AppTheme.accent)
                    Text("Scanning folder…")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(AppTheme.bgElevated)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(AppTheme.borderMedium, lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.35), radius: 12, y: 4)
                )
                .padding(.top, 72)
            }
        }
        .task {
            await observeDownloadEvents()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
            viewModel.saveLibrary()
            StudioViewModel.shared.stop()
        }
    }

    private func downloadToast(message: String, isError: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .foregroundStyle(isError ? Color.white : AppTheme.bgDeep)
            Text(message)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isError ? Color.white : AppTheme.bgDeep)
                .lineLimit(2)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .background {
            Capsule(style: .continuous)
                .fill(isError ? AppTheme.danger : AppTheme.accent)
        }
        .shadow(color: .black.opacity(0.3), radius: 10, y: 4)
    }

    private func observeDownloadEvents() async {
        for await event in webViewModel.downloadMessages() {
            switch event {
            case .completed(let url):
                await MainActor.run {
                    webViewModel.showDownloadMessage("Adding to library…")
                }
                do {
                    let item = try await viewModel.addLoopItem(from: url, switchToLibrary: true)
                    await MainActor.run {
                        webViewModel.showDownloadMessage("“\(item.displayName)” added to library")
                    }
                } catch {
                    try? FileManager.default.removeItem(at: url)
                    await MainActor.run {
                        webViewModel.showDownloadMessage(friendlyErrorMessage(error), isError: true)
                    }
                }
                await clearMessageLater(seconds: 3)

            case .failed(let error):
                await MainActor.run {
                    webViewModel.showDownloadMessage(error, isError: true)
                }
                await clearMessageLater(seconds: 4)
            }
        }
    }

    private func friendlyErrorMessage(_ error: Error) -> String {
        if let meta = error as? MetadataError {
            return meta.errorDescription ?? "File processing error"
        }
        return "Could not add loop: \(error.localizedDescription)"
    }

    private func clearMessageLater(seconds: Double) async {
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
        await MainActor.run {
            webViewModel.clearDownloadMessage()
        }
    }
}
