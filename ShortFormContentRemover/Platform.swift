import Foundation

/// A social platform that the app wraps in its own web view.
/// To add a platform: add a case here, then add CSS rules in ContentScript
/// and URL rules in RedirectPolicy.
enum Platform: String, CaseIterable, Identifiable {
    case instagram
    case youtube

    var id: String { rawValue }

    var title: String {
        switch self {
        case .instagram: "Instagram"
        case .youtube: "YouTube"
        }
    }

    var systemImage: String {
        switch self {
        case .instagram: "camera"
        case .youtube: "play.rectangle"
        }
    }

    var homeURL: URL {
        switch self {
        case .instagram: URL(string: "https://www.instagram.com/")!
        case .youtube: URL(string: "https://m.youtube.com/")!
        }
    }
}
