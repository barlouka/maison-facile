import SwiftUI

enum Destination: Hashable { case radio, podcasts, lightsBlinds, settings }

struct HomeView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.openURL) private var openURL
    @State private var path: [Destination] = []

    private let columns = [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(model.config.scenes) { tile in
                        BigTile(title: tile.title, symbol: tile.symbol, color: .accentColor) {
                            Task {
                                let ok = await model.run(tile)
                                if ok, let s = tile.openURL, let u = URL(string: s) { openURL(u) }
                            }
                        }
                    }
                    BigTile(title: "Radio", symbol: "radio.fill", color: .orange) { path.append(.radio) }
                    BigTile(title: "Podcasts", symbol: "mic.fill", color: .purple) { path.append(.podcasts) }
                    BigTile(title: "Lumières & stores", symbol: "blinds.horizontal.closed", color: .teal) {
                        path.append(.lightsBlinds)
                    }
                }
                .padding()
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
    }
}

struct BigTile: View {
    let title: String
    let symbol: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: symbol).font(.system(size: 40, weight: .semibold))
                Text(title).font(.title3.bold()).multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: 130)
            .foregroundStyle(.white)
            .background(color.gradient, in: RoundedRectangle(cornerRadius: 24))
        }
        .buttonStyle(.plain)
    }
}

struct VolumeBar: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
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
        .padding()
        .background(.ultraThinMaterial)
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
