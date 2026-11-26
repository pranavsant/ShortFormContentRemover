import SwiftUI

@main
struct SocialiteCloneApp: App {
    @StateObject private var settings = SettingsStore()

    var body: some Scene {
        WindowGroup {
            RootView(settings: settings)
        }
    }
}

/// Full-screen: only the current platform's page is visible. The only UI of
/// our own is a small floating button that opens the menu.
struct RootView: View {
    @ObservedObject var settings: SettingsStore
    @StateObject private var registry: BrowserRegistry
    @AppStorage("currentPlatform") private var current: Platform = .instagram
    @State private var showingMenu = false

    init(settings: SettingsStore) {
        self.settings = settings
        _registry = StateObject(wrappedValue: BrowserRegistry(settings: settings))
    }

    var body: some View {
        ZStack {
            // Every platform's page stays alive so switching is instant and
            // keeps your place; only the current one is visible.
            ForEach(Platform.allCases) { platform in
                BrowserScreen(model: registry.model(for: platform))
                    .opacity(platform == current ? 1 : 0)
                    .allowsHitTesting(platform == current)
            }
        }
        .overlay {
            FloatingMenuButton { showingMenu = true }
        }
        .sheet(isPresented: $showingMenu) {
            MenuSheet(
                current: $current,
                settings: settings,
                model: registry.model(for: current),
                onSignOut: registry.signOutAll
            )
            .presentationDetents([.medium, .large])
        }
        .onAppear { registry.model(for: current).loadIfNeeded() }
        .onChange(of: current) { _, newValue in
            for platform in Platform.allCases where platform != newValue {
                registry.model(for: platform).pauseMedia()
            }
            registry.model(for: newValue).loadIfNeeded()
        }
    }
}
