import SwiftUI
import WebKit

struct BrowserView: View {
    @ObservedObject var webViewModel: WebViewModel
    @EnvironmentObject var appViewModel: AppViewModel
    @FocusState private var addressFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            browserToolbar

            ZStack {
                WebView(viewModel: webViewModel)
                    .background(AppTheme.bgDeep)

                if let error = webViewModel.loadingError {
                    VStack(spacing: 14) {
                        Image(systemName: "wifi.exclamationmark")
                            .font(.system(size: 36, weight: .medium))
                            .foregroundStyle(AppTheme.accent)
                        Text(error)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(AppTheme.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        HStack(spacing: 10) {
                            Button("Retry") { webViewModel.reload() }
                                .buttonStyle(SplicePrimaryButtonStyle())
                            Button("Edit URL") { addressFieldFocused = true }
                                .buttonStyle(SpliceGhostButtonStyle())
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppTheme.bgBase.opacity(0.96))
                }
            }
        }
        .background(AppTheme.bgBase)
        .overlay(alignment: .bottom) {
            if webViewModel.isDownloading {
                downloadBanner
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: webViewModel.isDownloading)
        .onChange(of: addressFieldFocused) { _, focused in
            webViewModel.setAddressEditing(focused)
        }
    }

    private var downloadBanner: some View {
        HStack(spacing: 12) {
            ProgressView()
                .controlSize(.small)
                .tint(AppTheme.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text("Downloading sample…")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                if let name = webViewModel.downloadFileName {
                    Text(name)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppTheme.textTertiary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppTheme.bgElevated)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(AppTheme.borderMedium, lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.4), radius: 16, y: 6)
        )
        .padding(.bottom, 90)
    }

    private var browserToolbar: some View {
        HStack(spacing: 10) {
            toolbarIconButton(
                "chevron.left",
                enabled: webViewModel.canGoBack,
                action: webViewModel.goBack
            )
            toolbarIconButton(
                "chevron.right",
                enabled: webViewModel.canGoForward,
                action: webViewModel.goForward
            )
            toolbarIconButton(
                "arrow.clockwise",
                enabled: true,
                action: webViewModel.reload
            )

            addressBar

            if webViewModel.isLoading {
                ProgressView()
                    .controlSize(.small)
                    .tint(AppTheme.accent)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(AppTheme.bgRaised)
        .overlay(alignment: .bottom) { SpliceDivider() }
    }

    private func toolbarIconButton(_ systemName: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(enabled ? AppTheme.textPrimary : AppTheme.textMuted)
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(AppTheme.bgElevated)
                )
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    private var addressBar: some View {
        HStack(spacing: 8) {
            Image(systemName: addressBarIcon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppTheme.textTertiary)
                .frame(width: 14)

            TextField("Search or enter URL…", text: $webViewModel.addressBarText)
                .textFieldStyle(.plain)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppTheme.textPrimary)
                .focused($addressFieldFocused)
                .onSubmit {
                    _ = webViewModel.submitAddressBar()
                    addressFieldFocused = false
                }
                .disableAutocorrection(true)

            if addressFieldFocused && !webViewModel.addressBarText.isEmpty {
                Button("Go") {
                    _ = webViewModel.submitAddressBar()
                    addressFieldFocused = false
                }
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(AppTheme.bgDeep)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(AppTheme.accent))
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(AppTheme.bgElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(
                    addressFieldFocused ? AppTheme.accent.opacity(0.5) : AppTheme.borderSubtle,
                    lineWidth: 1
                )
        )
    }

    private var addressBarIcon: String {
        let text = webViewModel.addressBarText.lowercased()
        if text.hasPrefix("https://") { return "lock.fill" }
        if text.isEmpty { return "magnifyingglass" }
        return "globe"
    }
}

// MARK: - Button styles

struct SplicePrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(AppTheme.bgDeep)
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(
                Capsule(style: .continuous)
                    .fill(AppTheme.accent.opacity(configuration.isPressed ? 0.8 : 1))
            )
    }
}

struct SpliceGhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(AppTheme.textSecondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(
                Capsule(style: .continuous)
                    .fill(AppTheme.bgElevated.opacity(configuration.isPressed ? 0.7 : 1))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(AppTheme.borderMedium, lineWidth: 1)
            )
    }
}
