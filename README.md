# SocialiteClone

An iOS app (SwiftUI) that lets you use Instagram and YouTube without Reels and Shorts.
It works like SocialLite: each platform runs as its **website** inside the app (WKWebView).
A script injected into every page hides short-form content, and the app catches navigations
to blocked URLs and redirects them.

## Run it
1. Open `SocialiteClone.xcodeproj` in Xcode 16 or later.
2. Select the **SocialiteClone** target > Signing & Capabilities > pick your Team.
3. Run on a simulator or an iPhone (iOS 17+).

## How blocking works
| Layer | File | What it does |
|---|---|---|
| CSS/JS injected at document start | `ContentScript.swift` | Hides the Reels tab, Shorts shelves, Explore grid, etc. Re-checks every 400 ms so SPA re-renders can't bring them back. |
| URL redirects | `RedirectPolicy.swift` | `/reels/...` goes to home. `/shorts/ID` goes to `/watch?v=ID` (no swipe feed). Catches both full loads and pushState navigations (KVO on `webView.url`). |
| No escape hatch | `BrowserModel.swift` | Cancels `instagram://` / `youtube://` links so the page can't bounce you into the native apps. |
| Settings | `BlockConfig.swift`, `SettingsView.swift` | Toggles are saved to UserDefaults and pushed live into open pages. |

## When something stops getting hidden
Instagram and YouTube change their markup often. Every selector is in `ContentScript.swift`.
In Debug builds the web views are inspectable: connect the device and use
Safari > Develop > [your device] > the page, then find the new element and update the selector.

## Roadmap
- [ ] Screen Time shielding of the native apps (FamilyControls + ManagedSettings + ShieldConfiguration extension). Needs the Family Controls entitlement from Apple to ship. Requires a real device.
- [ ] Timed "post mode" unlock (DeviceActivity monitor extension)
- [ ] More platforms (Facebook, X, Reddit, Snapchat)
- [ ] Background audio for YouTube (UIBackgroundModes `audio` + AVAudioSession)
