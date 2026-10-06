import SwiftUI
import WebKit
import AppKit
import Combine

// MARK: - Configuration

enum SafariIdentity {
    /// Installed Safari marketing version, e.g. "26.6".
    static var version: String {
        (Bundle(path: "/Applications/Safari.app")?
            .object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)
            ?? "26.6"
    }

    /// Same frozen platform token real Safari still sends on macOS 26.
    static var userAgent: String {
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/\(version) Safari/605.1.15"
    }

    static var applicationName: String {
        "Version/\(version) Safari/605.1.15"
    }
}

enum WebKitBootstrap {
    static let processPool = WKProcessPool()
    static let dataStore = WKWebsiteDataStore.default()

    static func makeConfiguration() -> WKWebViewConfiguration {
        let config = WKWebViewConfiguration()
        config.processPool = processPool
        config.websiteDataStore = dataStore
        config.suppressesIncrementalRendering = false
        config.preferences.javaScriptCanOpenWindowsAutomatically = true
        config.applicationNameForUserAgent = SafariIdentity.applicationName
        config.userContentController.removeAllContentRuleLists()
        config.userContentController.removeAllScriptMessageHandlers()

        let page = WKWebpagePreferences()
        page.allowsContentJavaScript = true
        config.defaultWebpagePreferences = page
        return config
    }
}

// MARK: - Host NSView (loads only after it is in a window)

/// Owns a single WKWebView and notifies when it first joins a window.
final class WebViewHostView: NSView {
    let webView: WKWebView
    var onReady: ((WKWebView) -> Void)?
    private var didFireReady = false

    init(configuration: WKWebViewConfiguration) {
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor(white: 0.08, alpha: 1).cgColor

        webView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(webView)
        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: trailingAnchor),
            webView.topAnchor.constraint(equalTo: topAnchor),
            webView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        if #available(macOS 12.0, *) {
            webView.underPageBackgroundColor = NSColor(white: 0.08, alpha: 1)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard window != nil, !didFireReady else { return }
        didFireReady = true
        // Defer past the current layout / SwiftUI update pass.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.onReady?(self.webView)
        }
    }
}

// MARK: - SwiftUI Representable

struct WebView: NSViewRepresentable {
    @ObservedObject var viewModel: WebViewModel

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }

    func makeNSView(context: Context) -> WebViewHostView {
        let host = WebViewHostView(configuration: WebKitBootstrap.makeConfiguration())
        let webView = host.webView

        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.allowsMagnification = true
        webView.customUserAgent = SafariIdentity.userAgent

        context.coordinator.webView = webView
        // Silent attach — no @Published writes here.
        viewModel.attachWebView(webView)

        host.onReady = { [weak viewModel] readyWebView in
            viewModel?.startInitialLoadIfNeeded(in: readyWebView)
        }

        return host
    }

    /// CRITICAL: must not write any @Published / @State here.
    func updateNSView(_ host: WebViewHostView, context: Context) {
        context.coordinator.viewModel = viewModel
        context.coordinator.webView = host.webView
        viewModel.attachWebView(host.webView)

        // Apply pending navigation outside the current view-update transaction.
        if viewModel.consumePendingNavigationRequest() {
            let webView = host.webView
            DispatchQueue.main.async {
                self.viewModel.performPendingLoad(in: webView)
            }
        }
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKDownloadDelegate {
        var viewModel: WebViewModel
        weak var webView: WKWebView?

        init(viewModel: WebViewModel) {
            self.viewModel = viewModel
        }

        /// Always hop to next main-queue turn so we never publish during a SwiftUI update.
        private func publish(_ block: @escaping () -> Void) {
            DispatchQueue.main.async(execute: block)
        }

        // MARK: Navigation lifecycle

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            publish {
                self.viewModel.applyNavigationStarted(webView)
            }
        }

        func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
            publish { self.viewModel.applyURLSync(from: webView) }
        }

        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            publish {
                self.viewModel.applyURLSync(from: webView)
                self.viewModel.applyNavigationChrome(from: webView)
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            publish { self.viewModel.applyNavigationFinished(webView) }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            handleLoadFailure(error)
        }

        func webView(
            _ webView: WKWebView,
            didFailProvisionalNavigation navigation: WKNavigation!,
            withError error: Error
        ) {
            handleLoadFailure(error)
        }

        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            publish {
                self.viewModel.applyLoadFailure("Процесс WebKit завершился. Нажмите «Повторить».")
            }
        }

        func webView(
            _ webView: WKWebView,
            didReceive challenge: URLAuthenticationChallenge,
            completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
        ) {
            completionHandler(.performDefaultHandling, nil)
        }

        private func handleLoadFailure(_ error: Error) {
            let nsError = error as NSError
            if Self.shouldIgnoreNavigationFailure(nsError) {
                publish {
                    self.viewModel.applyNavigationChrome(from: self.webView)
                    self.viewModel.isLoading = false
                }
                return
            }
            publish {
                self.viewModel.applyLoadFailure(Self.friendlyNavigationError(nsError))
            }
        }

        private static func shouldIgnoreNavigationFailure(_ error: NSError) -> Bool {
            if error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled {
                return true
            }
            if error.domain == "WebKitErrorDomain" && (error.code == 102 || error.code == 204) {
                return true
            }
            if let underlying = error.userInfo[NSUnderlyingErrorKey] as? NSError,
               underlying.domain == "WebKitErrorDomain",
               underlying.code == 102 || underlying.code == 204 {
                return true
            }
            let desc = error.localizedDescription.lowercased()
            if desc.contains("frame load interrupted") || desc.contains("загрузка фрейма прервана") {
                return true
            }
            return false
        }

        private static func friendlyNavigationError(_ error: NSError) -> String {
            if error.domain == NSURLErrorDomain {
                switch error.code {
                case NSURLErrorTimedOut:
                    return "Таймаут загрузки (−1001). Сайт недоступен с этой сети или отвечает слишком долго."
                case NSURLErrorNotConnectedToInternet:
                    return "Нет подключения к интернету"
                case NSURLErrorCannotFindHost:
                    return "Сервер не найден"
                case NSURLErrorCannotConnectToHost:
                    return "Не удалось подключиться к серверу"
                case NSURLErrorSecureConnectionFailed:
                    return "Ошибка TLS/HTTPS соединения"
                case NSURLErrorAppTransportSecurityRequiresSecureConnection:
                    return "Блокировка ATS"
                default:
                    break
                }
            }
            return "Ошибка загрузки: \(error.localizedDescription)"
        }

        // MARK: Policy (decisionHandler must stay synchronous)

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            preferences: WKWebpagePreferences,
            decisionHandler: @escaping (WKNavigationActionPolicy, WKWebpagePreferences) -> Void
        ) {
            preferences.allowsContentJavaScript = true

            if navigationAction.shouldPerformDownload,
               isLikelyAudioURL(navigationAction.request.url) {
                publish {
                    self.viewModel.loadingError = nil
                    self.viewModel.startDownload()
                }
                decisionHandler(.download, preferences)
                return
            }

            decisionHandler(.allow, preferences)
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationResponse: WKNavigationResponse,
            decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void
        ) {
            if navigationResponse.isForMainFrame,
               shouldDownloadAsAudio(navigationResponse) {
                publish {
                    self.viewModel.loadingError = nil
                    self.viewModel.startDownload()
                }
                decisionHandler(.download)
                return
            }
            decisionHandler(.allow)
        }

        func webView(
            _ webView: WKWebView,
            navigationResponse: WKNavigationResponse,
            didBecome download: WKDownload
        ) {
            download.delegate = self
        }

        func webView(
            _ webView: WKWebView,
            navigationAction: WKNavigationAction,
            didBecome download: WKDownload
        ) {
            download.delegate = self
        }

        // MARK: UIDelegate

        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            if navigationAction.targetFrame == nil,
               let url = navigationAction.request.url {
                // User gesture path — schedule off the current callback stack.
                publish { self.viewModel.loadURL(url) }
            }
            return nil
        }

        // MARK: Downloads

        func download(
            _ download: WKDownload,
            decideDestinationUsing response: URLResponse,
            suggestedFilename: String,
            completionHandler: @escaping (URL?) -> Void
        ) {
            do {
                let downloadsDir = try PersistenceManager.shared.ensureDownloadsDirectory()
                let destURL = uniqueURL(in: downloadsDir, filename: suggestedFilename)
                publish {
                    self.viewModel.loadingError = nil
                    self.viewModel.currentDownloadURL = destURL
                    self.viewModel.downloadFileName = suggestedFilename
                    self.viewModel.startDownload()
                }
                completionHandler(destURL)
            } catch {
                publish {
                    self.viewModel.failDownload(
                        error: "Не удалось создать папку Downloads: \(error.localizedDescription)"
                    )
                }
                completionHandler(nil)
            }
        }

        func downloadDidFinish(_ download: WKDownload) {
            publish {
                guard let url = self.viewModel.currentDownloadURL else {
                    self.viewModel.failDownload(error: "Файл скачан, но путь назначения неизвестен")
                    return
                }
                self.viewModel.finishDownload(at: url)
            }
        }

        func download(
            _ download: WKDownload,
            didFailWithError error: Error,
            resumeData: Data?
        ) {
            publish {
                if let url = self.viewModel.currentDownloadURL {
                    try? FileManager.default.removeItem(at: url)
                }
                self.viewModel.failDownload(error: self.userFriendlyDownloadError(error))
            }
        }

        private func userFriendlyDownloadError(_ error: Error) -> String {
            let ns = error as NSError
            if ns.domain == NSURLErrorDomain {
                switch ns.code {
                case NSURLErrorNotConnectedToInternet: return "Нет подключения к интернету"
                case NSURLErrorTimedOut: return "Превышено время ожидания скачивания"
                case NSURLErrorCancelled: return "Скачивание отменено"
                default: break
                }
            }
            return "Не удалось скачать файл: \(error.localizedDescription)"
        }

        private func shouldDownloadAsAudio(_ navigationResponse: WKNavigationResponse) -> Bool {
            let response = navigationResponse.response
            let mime = response.mimeType?.lowercased() ?? ""
            if mime.hasPrefix("text/") || mime.contains("html") || mime.contains("javascript") {
                return false
            }
            if mime.hasPrefix("audio/") { return true }
            return isLikelyAudioURL(response.url)
        }

        private func isLikelyAudioURL(_ url: URL?) -> Bool {
            guard let url else { return false }
            let ext = url.pathExtension.lowercased()
            return ["wav", "mp3", "aiff", "aif", "flac", "ogg", "oga", "aac", "m4a", "caf"].contains(ext)
        }

        private func uniqueURL(in dir: URL, filename: String) -> URL {
            let url = dir.appendingPathComponent(filename)
            guard FileManager.default.fileExists(atPath: url.path) else { return url }
            let base = url.deletingPathExtension().lastPathComponent
            let ext = url.pathExtension
            var n = 1
            while true {
                let name = ext.isEmpty ? "\(base) (\(n))" : "\(base) (\(n)).\(ext)"
                let candidate = dir.appendingPathComponent(name)
                if !FileManager.default.fileExists(atPath: candidate.path) { return candidate }
                n += 1
            }
        }
    }
}

// MARK: - Events / ViewModel

enum DownloadEvent {
    case completed(URL)
    case failed(String)
}

/// Not MainActor-isolated: WKWebView Coordinator is a classic NSObject delegate.
/// All UI-facing mutations go through `DispatchQueue.main.async` from Coordinator (`publish`).
final class WebViewModel: ObservableObject {
    static let homeURL = URL(string: "https://www.looperman.com")!

    static var safariUserAgent: String { SafariIdentity.userAgent }

    @Published var url: URL = WebViewModel.homeURL
    @Published var addressBarText: String = WebViewModel.homeURL.absoluteString
    @Published var canGoBack: Bool = false
    @Published var canGoForward: Bool = false
    @Published var isLoading: Bool = false
    @Published var loadingError: String? = nil

    @Published var isDownloading: Bool = false
    @Published var downloadProgress: Double = 0
    @Published var downloadFileName: String?
    @Published var downloadMessage: String?
    @Published var downloadMessageIsError: Bool = false
    @Published var currentDownloadURL: URL?

    private weak var webView: WKWebView?
    private let downloadSubject = PassthroughSubject<DownloadEvent, Never>()
    private var isEditingAddress = false
    private var didStartInitialLoad = false

    /// Non-published flag read from updateNSView without mutating published state there.
    private var pendingNavigation = false
    private var pendingDestination: URL?

    /// Store webView reference only — no @Published writes.
    func attachWebView(_ webView: WKWebView) {
        self.webView = webView
    }

    /// Called when the WKWebView first joins a window. The view is created
    /// only after the user opens Browser — not at app launch.
    func startInitialLoadIfNeeded(in webView: WKWebView) {
        attachWebView(webView)
        if !didStartInitialLoad {
            didStartInitialLoad = true
            loadHomePage(in: webView)
        } else {
            loadCurrentURL(in: webView)
        }
    }

    /// Called from updateNSView — must only read/clear non-published flags.
    func consumePendingNavigationRequest() -> Bool {
        guard pendingNavigation else { return false }
        pendingNavigation = false
        return true
    }

    func performPendingLoad(in webView: WKWebView) {
        attachWebView(webView)
        let destination = pendingDestination ?? url
        pendingDestination = nil
        executeLoad(destination, in: webView)
    }

    func setAddressEditing(_ editing: Bool) {
        isEditingAddress = editing
        if !editing {
            addressBarText = displayString(for: url)
        }
    }

    func loadHomePage(in webView: WKWebView? = nil) {
        isEditingAddress = false
        url = Self.homeURL
        addressBarText = Self.homeURL.absoluteString
        loadCurrentURL(in: webView)
    }

    func loadCurrentURL(in webView: WKWebView? = nil) {
        let destination = isBlankOrEmpty(url) ? Self.homeURL : url
        if let target = webView ?? self.webView {
            executeLoad(destination, in: target)
        } else {
            // WebView not ready yet — queue for updateNSView / onReady.
            pendingDestination = destination
            pendingNavigation = true
            url = destination
            addressBarText = displayString(for: destination)
            isLoading = true
            loadingError = nil
        }
    }

    private func executeLoad(_ destination: URL, in target: WKWebView) {
        url = destination
        loadingError = nil
        isLoading = true
        if !isEditingAddress {
            addressBarText = displayString(for: destination)
        }

        var request = URLRequest(
            url: destination,
            cachePolicy: .useProtocolCachePolicy,
            timeoutInterval: 60
        )
        request.setValue(Self.safariUserAgent, forHTTPHeaderField: "User-Agent")
        _ = target.load(request)
        applyNavigationChrome(from: target)
    }

    // MARK: - State sinks used by Coordinator (already on next main turn)

    func applyNavigationStarted(_ webView: WKWebView) {
        isLoading = true
        loadingError = nil
        applyURLSync(from: webView)
    }

    func applyURLSync(from webView: WKWebView) {
        guard let current = webView.url, current.scheme != "about" else { return }
        url = current
        if !isEditingAddress {
            addressBarText = displayString(for: current)
        }
    }

    func applyNavigationChrome(from webView: WKWebView?) {
        guard let webView else { return }
        canGoBack = webView.canGoBack
        canGoForward = webView.canGoForward
    }

    func applyNavigationFinished(_ webView: WKWebView) {
        self.webView = webView
        applyURLSync(from: webView)
        applyNavigationChrome(from: webView)
        isLoading = false
        loadingError = nil
    }

    func applyLoadFailure(_ message: String) {
        isLoading = false
        loadingError = message
        applyNavigationChrome(from: webView)
    }

    private func isBlankOrEmpty(_ url: URL?) -> Bool {
        guard let url else { return true }
        if url.scheme == "about" { return true }
        if url.absoluteString.isEmpty { return true }
        return false
    }

    private func displayString(for url: URL) -> String {
        if url.scheme == "about" { return "" }
        return url.absoluteString
    }

    @discardableResult
    func submitAddressBar() -> Bool {
        let trimmed = addressBarText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            loadHomePage()
            return true
        }

        let parsed: URL?
        if let url = URL(string: trimmed), url.scheme != nil {
            parsed = url
        } else if let url = URL(string: "https://\(trimmed)") {
            parsed = url
        } else {
            return false
        }

        guard let destination = parsed else { return false }
        isEditingAddress = false
        url = destination
        addressBarText = displayString(for: destination)
        loadCurrentURL()
        return true
    }

    func downloadMessages() -> AsyncStream<DownloadEvent> {
        AsyncStream { continuation in
            let cancellable = downloadSubject.sink { event in
                continuation.yield(event)
            }
            continuation.onTermination = { @Sendable _ in
                cancellable.cancel()
            }
        }
    }

    func goBack() {
        webView?.goBack()
        applyNavigationChrome(from: webView)
    }

    func goForward() {
        webView?.goForward()
        applyNavigationChrome(from: webView)
    }

    func reload() {
        loadCurrentURL()
    }

    func loadURL(_ url: URL) {
        isEditingAddress = false
        if url.scheme == "about" {
            loadHomePage()
            return
        }
        self.url = url
        addressBarText = displayString(for: url)
        loadCurrentURL()
    }

    func startDownload() {
        isDownloading = true
        downloadProgress = 0
        downloadMessage = nil
        downloadMessageIsError = false
        loadingError = nil
        isLoading = false
    }

    func finishDownload(at location: URL) {
        isDownloading = false
        downloadProgress = 1.0
        downloadFileName = location.lastPathComponent
        downloadSubject.send(.completed(location))
    }

    func failDownload(error: String) {
        isDownloading = false
        downloadProgress = 0
        downloadMessageIsError = true
        downloadSubject.send(.failed(error))
    }

    func showDownloadMessage(_ message: String, isError: Bool = false) {
        downloadMessage = message
        downloadMessageIsError = isError
    }

    func clearDownloadMessage() {
        downloadMessage = nil
        downloadMessageIsError = false
        downloadFileName = nil
    }
}
