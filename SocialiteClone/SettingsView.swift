import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: SettingsStore
    let onSignOut: () -> Void
    @State private var confirmingSignOut = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Block Reels feed", isOn: $settings.config.igBlockReelsFeed)
                    Toggle("Allow single reels (from DMs, profiles)", isOn: $settings.config.igAllowSharedReels)
                    Toggle("Hide video posts in feed", isOn: $settings.config.igHideVideoPosts)
                    Toggle("Hide Explore grid", isOn: $settings.config.igHideExploreGrid)
                    Toggle("Hide home feed", isOn: $settings.config.igHideHomeFeed)
                } header: {
                    Label("Instagram", systemImage: Platform.instagram.systemImage)
                } footer: {
                    Text("Search, stories, profiles and DMs keep working.")
                }

                Section {
                    Toggle("Block Shorts", isOn: $settings.config.ytBlockShorts)
                    Toggle("Hide home recommendations", isOn: $settings.config.ytHideHomeFeed)
                } header: {
                    Label("YouTube", systemImage: Platform.youtube.systemImage)
                } footer: {
                    Text("A Short someone sends you opens in the regular player, without the swipe feed.")
                }

                Section {
                    Button("Sign out of all platforms", role: .destructive) {
                        confirmingSignOut = true
                    }
                } footer: {
                    Text("You sign in on each platform's own website inside this app. Cookies stay on this device.")
                }
            }
            .navigationTitle("Blocking")
            .confirmationDialog("Sign out everywhere?", isPresented: $confirmingSignOut, titleVisibility: .visible) {
                Button("Sign out", role: .destructive, action: onSignOut)
            }
        }
    }
}
