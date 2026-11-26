import SwiftUI
import WebKit
import Combine

/// Owns one long-lived WKWebView per platform, so each tab keeps its page and
/// login while you switch tabs. Cookies persist in the default data store.
@MainActor
final class BrowserModel: NSObject, ObservableObject {
    let platform: Platform
    let webView: WKWebView

    @Published private(set) var canGoBack = false
    @Published private(set) var isLoading = false
    @Published private(set) var toast: String?

    private var config: BlockConfig
    private var observations: [NSKeyValueObservation] = []
    private var toastTask: Task<Void, Never>?
    private var didLoad = false

    init(platform: Platform, config: BlockConfig) {
        self.platform = platform
        self.config = config

        let wk = WKWebViewConfiguration()
        wk.websiteDataStore = .default()
        wk.allowsInlineMediaPlayback = true
        wk.allowsPictureInPictureMediaPlayback = true
        // Makes the user agent look like mobile Safari. Without it Google
        // sign-in (YouTube) refuses embedded web views.
        wk.applicationNameForUserAgent = "Version/18.0 Mobile/15E148 Safari/604.1"

        webView = WKWebView(frame: .zero, configuration: wk)
        super.init()

        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        #if DEBUG
        webView.isInspectable = true   // Safari > Develop > [device] to debug selectors
        #endif

        installScript()

        observations = [
            webView.observe(\.url, options: [.new]) { [weak self] webView, _ in
                MainActor.assumeIsolated { self?.check(webView.url) }
            },
            webView.observe(\.canGoBack, options: [.new]) { [weak self] webView, _ in
                MainActor.assumeIsolated { self?.canGoBack = webView.canGoBack }
            },
            webView.observe(\.isLoading, options: [.new]) { [weak self] webView, _ in
                MainActor.assumeIsolated { self?.isLoading = webView.isLoading }
            },
        ]
    }

    // MARK: Actions

    func loadIfNeeded() {
        guard !didLoad else { return }
        didLoad = true
        goHome()
    }

    func goHome() {
        webView.load(URLRequest(url: platform.homeURL))
    }

    func goBack() {
        webView.goBack()
    }

    func reloadOrStop() {
        if webView.isLoading { webView.stopLoading() } else { webView.reload() }
    }

    /// Stop audio/video when this platform is switched away from.
    func pauseMedia() {
        webView.pauseAllMediaPlayback()
    }

    func apply(_ newConfig: BlockConfig) {
        config = newConfig
        installScript()   // for future page loads
        webView.evaluateJavaScript("window.__SL_apply && window.__SL_apply(\(ContentScript.json(newConfig)))")
        check(webView.url)
    }

    // MARK: Internals

    private func installScript() {
        let ucc = webView.configuration.userContentController
        ucc.removeAllUserScripts()
        ucc.addUserScript(WKUserScript(
            source: ContentScript.source(config: config),
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        ))
    }

    /// Catches in-page navigations (pushState) that never hit decidePolicyFor.
    private func check(_ url: URL?) {
        log("url \(url?.absoluteString ?? "nil")")
        guard let redirect = RedirectPolicy.redirect(for: url, config: config) else { return }
        log("redirect -> \(redirect.url.absoluteString) (\(redirect.message))")
        webView.stopLoading()
        webView.load(URLRequest(url: redirect.url))
        showToast(redirect.message)
    }

    private func log(_ message: String) {
        #if DEBUG
        print("[SL \(platform.rawValue)] \(message)")
        #endif
    }

    private func showToast(_ text: String) {
        toast = text
        toastTask?.cancel()
        toastTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            self?.toast = nil
        }
    }
}

extension BrowserModel: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
        guard let url = navigationAction.request.url else { return .allow }

        // Never hand off to the native apps (instagram://, youtube://, intent:// ...).
        let scheme = url.scheme?.lowercased() ?? ""
        guard ["http", "https", "about", "blob", "data"].contains(scheme) else {
            log("blocked app link \(url.absoluteString)")
            return .cancel
        }

        let isMainFrame = navigationAction.targetFrame?.isMainFrame ?? true
        if isMainFrame, let redirect = RedirectPolicy.redirect(for: url, config: config) {
            webView.load(URLRequest(url: redirect.url))
            showToast(redirect.message)
            return .cancel
        }
        return .allow
    }

    /// The page's web process can be killed (memory pressure, crash). WebKit then
    /// leaves a blank view forever unless we reload.
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        log("web content process terminated, reloading")
        if webView.url != nil { webView.reload() } else { goHome() }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        log("navigation failed: \(error.localizedDescription)")
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        log("load failed: \(error.localizedDescription)")
    }
}

extension BrowserModel: WKUIDelegate {
    /// target="_blank" links: open in the same view instead of nowhere.
    func webView(_ webView: WKWebView,
                 createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction,
                 windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil {
            webView.load(navigationAction.request)
        }
        return nil
    }
}

/// Holds one BrowserModel per platform and pushes settings changes to them.
@MainActor
final class BrowserRegistry: ObservableObject {
    private let models: [Platform: BrowserModel]
    private var cancellable: AnyCancellable?

    init(settings: SettingsStore) {
        var models: [Platform: BrowserModel] = [:]
        for platform in Platform.allCases {
            models[platform] = BrowserModel(platform: platform, config: settings.config)
        }
        self.models = models

        cancellable = settings.$config
            .dropFirst()
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] config in
                MainActor.assumeIsolated {
                    self?.models.values.forEach { $0.apply(config) }
                }
            }
    }

    func model(for platform: Platform) -> BrowserModel {
        models[platform]!
    }

    func signOutAll() {
        Task {
            let store = WKWebsiteDataStore.default()
            await store.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: .distantPast)
            models.values.forEach { $0.goHome() }
        }
    }
}
