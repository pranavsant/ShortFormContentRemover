import Foundation

struct Redirect {
    let url: URL
    let message: String
}

/// URL-level blocking. Runs on every navigation, including the in-page
/// (pushState) navigations Instagram and YouTube use, via KVO on webView.url.
enum RedirectPolicy {
    static func redirect(for url: URL?, config: BlockConfig) -> Redirect? {
        guard let url, let host = url.host?.lowercased() else { return nil }
        let parts = url.path.split(separator: "/").map(String.init)

        if host == "instagram.com" || host.hasSuffix(".instagram.com") {
            let home = Platform.instagram.homeURL
            if config.igBlockReelsFeed, parts.first == "reels" {
                return Redirect(url: home, message: "Reels feed blocked")
            }
            if !config.igAllowSharedReels, parts.first == "reel" {
                return Redirect(url: home, message: "Reels blocked")
            }
        }

        if host == "youtube.com" || host.hasSuffix(".youtube.com") {
            if config.ytBlockShorts, parts.first == "shorts" {
                // A specific Short (e.g. one a friend sent): play it in the normal
                // player, which has no swipe-to-next feed.
                if parts.count >= 2 {
                    var c = URLComponents()
                    c.scheme = "https"
                    c.host = host
                    c.path = "/watch"
                    c.queryItems = [URLQueryItem(name: "v", value: parts[1])]
                    if let watch = c.url {
                        return Redirect(url: watch, message: "Opened Short as a regular video")
                    }
                }
                return Redirect(url: Platform.youtube.homeURL, message: "Shorts blocked")
            }
        }

        return nil
    }
}
