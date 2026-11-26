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

struct RootView: View {
    @ObservedObject var settings: SettingsStore
    @StateObject private var registry: BrowserRegistry

    init(settings: SettingsStore) {
        self.settings = settings
        _registry = StateObject(wrappedValue: BrowserRegistry(settings: settings))
    }

    var body: some View {
        TabView {
            ForEach(Platform.allCases) { platform in
                BrowserScreen(model: registry.model(for: platform))
                    .tabItem { Label(platform.title, systemImage: platform.systemImage) }
            }
            SettingsView(settings: settings, onSignOut: registry.signOutAll)
                .tabItem { Label("Blocking", systemImage: "hand.raised") }
        }
    }
}
