import SwiftUI
import WebKit

/// One platform's page, full screen. The page starts below the status bar
/// (sites like Instagram don't pad for the notch themselves) and runs to the
/// bottom edge; WebKit keeps fixed bars clear of the home indicator.
struct BrowserScreen: View {
    @ObservedObject var model: BrowserModel

    var body: some View {
        WebViewContainer(webView: model.webView)
            .ignoresSafeArea(.container, edges: .bottom)
            .background(Color(uiColor: .systemBackground).ignoresSafeArea())
            .overlay(alignment: .top) {
                if let toast = model.toast {
                    Label(toast, systemImage: "hand.raised.fill")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.spring(duration: 0.3), value: model.toast)
    }
}

struct WebViewContainer: UIViewRepresentable {
    let webView: WKWebView

    func makeUIView(context: Context) -> WKWebView { webView }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

/// Small translucent button. Tap to open the menu; drag to move it.
/// It snaps to the nearest side and remembers where you left it.
struct FloatingMenuButton: View {
    let action: () -> Void

    @AppStorage("menuButtonOnLeft") private var onLeft = false
    @AppStorage("menuButtonY") private var yFraction = 0.6
    @GestureState private var dragOffset: CGSize = .zero

    private let size: CGFloat = 40
    private let margin: CGFloat = 4

    var body: some View {
        GeometryReader { geo in
            let x = onLeft ? size / 2 + margin : geo.size.width - size / 2 - margin
            let y = min(max(yFraction * geo.size.height, size), geo.size.height - size)
            let dragging = dragOffset != .zero

            Image(systemName: "hand.raised.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .background(Circle().fill(.black.opacity(0.45)))
                .opacity(dragging ? 0.95 : 0.5)
                .scaleEffect(dragging ? 1.1 : 1)
                .position(x: x + dragOffset.width, y: y + dragOffset.height)
                .animation(.spring(duration: 0.25), value: onLeft)
                .onTapGesture(perform: action)
                .gesture(
                    DragGesture(minimumDistance: 6)
                        .updating($dragOffset) { value, state, _ in state = value.translation }
                        .onEnded { value in
                            onLeft = (x + value.translation.width) < geo.size.width / 2
                            yFraction = Double((y + value.translation.height) / geo.size.height)
                        }
                )
                .accessibilityLabel("SocialiteClone menu")
                .accessibilityAddTraits(.isButton)
        }
    }
}

struct MenuSheet: View {
    @Binding var current: Platform
    @ObservedObject var settings: SettingsStore
    @ObservedObject var model: BrowserModel
    let onSignOut: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Switch to") {
                    ForEach(Platform.allCases) { platform in
                        Button {
                            current = platform
                            dismiss()
                        } label: {
                            HStack {
                                Label(platform.title, systemImage: platform.systemImage)
                                Spacer()
                                if platform == current {
                                    Image(systemName: "checkmark").foregroundStyle(.tint)
                                }
                            }
                        }
                        .foregroundStyle(.primary)
                    }
                }

                Section(current.title) {
                    Button {
                        model.reloadOrStop()
                        dismiss()
                    } label: {
                        Label("Reload page", systemImage: "arrow.clockwise")
                    }
                    Button {
                        model.goHome()
                        dismiss()
                    } label: {
                        Label("Go to \(current.title) home", systemImage: "house")
                    }
                }
                .foregroundStyle(.primary)

                Section {
                    NavigationLink {
                        SettingsView(settings: settings, onSignOut: onSignOut)
                    } label: {
                        Label("Blocking settings", systemImage: "hand.raised")
                    }
                }
            }
            .navigationTitle("SocialiteClone")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
