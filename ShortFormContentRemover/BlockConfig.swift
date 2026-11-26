import Foundation
import Combine

/// Everything the user can switch on or off. Encoded to JSON and handed to the
/// injected page script, so property names here must match `cfg.*` in ContentScript.
struct BlockConfig: Codable, Equatable {
    // Instagram
    var igBlockReelsFeed = true      // the Reels tab / endless reels feed
    var igAllowSharedReels = true    // single reels opened from a DM or profile
    var igHideVideoPosts = false     // video posts in the home feed
    var igHideExploreGrid = true     // Explore grid (search still works)
    var igHideHomeFeed = false       // whole home feed (stories stay)

    // YouTube
    var ytBlockShorts = true         // Shorts shelves, tab, and the Shorts player
    var ytHideHomeFeed = false       // recommendations on the home page
}

final class SettingsStore: ObservableObject {
    private static let key = "blockConfig.v1"

    @Published var config: BlockConfig {
        didSet { save() }
    }

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.key),
           let saved = try? JSONDecoder().decode(BlockConfig.self, from: data) {
            config = saved
        } else {
            config = BlockConfig()
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }
}
