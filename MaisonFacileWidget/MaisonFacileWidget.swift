import AppIntents
import SwiftUI
import WidgetKit

// Widget interactif (iOS 17+) : chaque bouton agit directement, sans ouvrir l'app.
// Cible « Widget Extension » ; le dossier MaisonFacile/Shared doit aussi en faire partie.

struct HomeEntry: TimelineEntry {
    let date: Date
    let scenes: [Tile]
    let stations: [RadioStation]
}

struct Provider: TimelineProvider {
    private func entry() -> HomeEntry {
        let c = Config.load()
        return HomeEntry(date: .now, scenes: c.scenes, stations: c.stations)
    }

    func placeholder(in context: Context) -> HomeEntry {
        HomeEntry(date: .now, scenes: Tile.defaults, stations: RadioStation.defaults)
    }
    func getSnapshot(in context: Context, completion: @escaping (HomeEntry) -> Void) { completion(entry()) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<HomeEntry>) -> Void) {
        // L'app recharge le widget à chaque changement de réglages.
        completion(Timeline(entries: [entry()], policy: .never))
    }
}

@main
struct MaisonFacileWidgets: WidgetBundle {
    var body: some Widget {
        MaisonWidget()
        PauseLockWidget()
    }
}

struct MaisonWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "MaisonWidget", provider: Provider()) { entry in
            MaisonWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Maison")
        .description("Les boutons de la maison et la radio.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct MaisonWidgetView: View {
    let entry: HomeEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .systemSmall:
            grid(Array(entry.scenes.prefix(4)), columns: 2, showTitles: false)
        case .systemMedium:
            VStack(spacing: 8) {
                grid(Array(entry.scenes.prefix(4)), columns: 4, showTitles: true)
                HStack(spacing: 8) {
                    ForEach(entry.stations.prefix(2)) { radioButton($0) }
                    WidgetButton(intent: PauseIntent(), symbol: "pause.fill", title: nil, tint: .gray)
                }
            }
        default:
            VStack(spacing: 10) {
                grid(Array(entry.scenes.prefix(6)), columns: 3, showTitles: true)
                Divider()
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2), spacing: 8) {
                    ForEach(entry.stations.prefix(4)) { radioButton($0) }
                }
                HStack(spacing: 8) {
                    WidgetButton(intent: VolumeIntent(step: -5), symbol: "speaker.minus.fill", title: nil, tint: .gray)
                    WidgetButton(intent: PauseIntent(), symbol: "pause.fill", title: nil, tint: .gray)
                    WidgetButton(intent: ResumeIntent(), symbol: "play.fill", title: nil, tint: .gray)
                    WidgetButton(intent: VolumeIntent(step: 5), symbol: "speaker.plus.fill", title: nil, tint: .gray)
                }
            }
        }
    }

    private func grid(_ tiles: [Tile], columns: Int, showTitles: Bool) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: columns), spacing: 8) {
            ForEach(tiles) { t in
                WidgetButton(intent: RunSceneIntent(scene: SceneEntity(t)), symbol: t.symbol,
                             title: showTitles ? t.title : nil, tint: .accentColor)
            }
        }
    }

    private func radioButton(_ s: RadioStation) -> some View {
        WidgetButton(intent: PlayRadioIntent(station: StationEntity(s)), symbol: "radio.fill",
                     title: s.name, tint: .orange)
    }
}

struct WidgetButton<I: AppIntent>: View {
    let intent: I
    let symbol: String
    let title: String?
    let tint: Color

    var body: some View {
        Button(intent: intent) {
            VStack(spacing: 4) {
                Image(systemName: symbol).font(.title3.weight(.semibold))
                if let title { Text(title).font(.caption2.bold()).lineLimit(1).minimumScaleFactor(0.7) }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .foregroundStyle(.white)
            .background(tint.gradient, in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}

/// Petit bouton « pause » pour l'écran verrouillé.
struct PauseLockWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "PauseLockWidget", provider: Provider()) { _ in
            Button(intent: PauseIntent()) {
                Image(systemName: "pause.fill").font(.title2)
            }
            .buttonStyle(.plain)
            .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Pause musique")
        .description("Met la musique en pause.")
        .supportedFamilies([.accessoryCircular])
    }
}
