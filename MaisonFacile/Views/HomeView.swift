import SwiftUI

enum Destination: Hashable { case radio, podcasts, lightsBlinds, settings }

struct HomeView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.openURL) private var openURL
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var path: [Destination] = []

    private var isTablet: Bool { sizeClass == .regular }
    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: isTablet ? 200 : 150), spacing: isTablet ? 24 : 16)]
    }

    var body: some View {
        NavigationStack(path: $path) {
            HStack(spacing: 0) {
                tiles
                if isTablet {
                    Divider()
                    // Sur iPad : stores et lumières toujours visibles à droite
                    LightsBlindsView(showsTitle: false)
                        .frame(width: 400)
                }
            }
            .safeAreaInset(edge: .bottom) { VolumeBar() }
            .navigationTitle("Maison")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { path.append(.settings) } label: { Image(systemName: "gearshape") }
                        .foregroundStyle(.secondary)
                }
            }
            .navigationDestination(for: Destination.self) { d in
                switch d {
                case .radio: RadioView()
                case .podcasts: PodcastsView()
                case .lightsBlinds: LightsBlindsView()
                case .settings: SettingsView()
                }
            }
        }
        .overlay(alignment: .top) { ToastView(text: model.toast) }
        .task { await model.refreshVolume() }
        .task { await model.pollNowPlaying() }
    }

    private var tiles: some View {
            ScrollView {
                LazyVGrid(columns: columns, spacing: isTablet ? 24 : 16) {
                    ForEach(model.config.scenes) { tile in
                        BigTile(title: tile.title, symbol: tile.symbol, color: .accentColor, large: isTablet) {
                            Task {
                                let ok = await model.run(tile)
                                if ok, let s = tile.openURL, let u = URL(string: s) { openURL(u) }
                            }
                        }
                    }
                    BigTile(title: "Radio", symbol: "radio.fill", color: .orange, large: isTablet) { path.append(.radio) }
                    BigTile(title: "Podcasts", symbol: "mic.fill", color: .purple, large: isTablet) { path.append(.podcasts) }
                    if !isTablet {
                        BigTile(title: "Lumières & stores", symbol: "blinds.horizontal.closed", color: .teal) {
                            path.append(.lightsBlinds)
                        }
                    }
                }
                .padding(isTablet ? 24 : 16)
            }
    }
}

struct BigTile: View {
    let title: String
    let symbol: String
    let color: Color
    var large = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: symbol).font(.system(size: large ? 56 : 40, weight: .semibold))
                Text(title).font(large ? .title.bold() : .title3.bold()).multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: large ? 180 : 130)
            .foregroundStyle(.white)
            .background(color.gradient, in: RoundedRectangle(cornerRadius: 24))
        }
        .buttonStyle(.plain)
    }
}

struct VolumeBar: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        VStack(spacing: 10) {
            if let np = model.nowPlaying { NowPlayingRow(np: np) }
            controls
        }
        .padding()
        .background(.ultraThinMaterial)
    }

    private var controls: some View {
        HStack(spacing: 14) {
            Button { Task { await model.togglePause() } } label: {
                Image(systemName: model.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title2).frame(width: 44, height: 44)
            }
            Button { Task { await model.nudgeVolume(-5) } } label: {
                Image(systemName: "speaker.minus.fill").font(.title2)
            }
            Slider(value: $model.volume, in: 0...100, step: 1, onEditingChanged: { editing in
                if !editing { Task { await model.applyVolume() } }
            })
            Button { Task { await model.nudgeVolume(5) } } label: {
                Image(systemName: "speaker.plus.fill").font(.title2)
            }
        }
    }
}

struct NowPlayingRow: View {
    let np: NowPlaying
    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: np.artworkURL) { img in
                img.resizable().scaledToFill()
            } placeholder: {
                Image(systemName: "music.note").font(.title2).foregroundStyle(.secondary)
            }
            .frame(width: 52, height: 52)
            .background(.quaternary)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 2) {
                Text(np.title).font(.headline).lineLimit(1)
                if !np.artist.isEmpty {
                    Text(np.artist).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer()
            if np.isPlaying {
                Image(systemName: "waveform").symbolEffect(.variableColor.iterative).foregroundStyle(.tint)
            }
        }
    }
}

struct ToastView: View {
    let text: String?
    var body: some View {
        if let text {
            Text(text)
                .font(.headline)
                .padding(.horizontal, 20).padding(.vertical, 12)
                .background(.regularMaterial, in: Capsule())
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}
