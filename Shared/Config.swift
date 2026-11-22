import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

/// Identifiant du groupe d'apps partagé entre l'app et le widget (à adapter à ton Team).
enum AppGroup {
    static let id = "group.ch.barlouka.maisonfacile"
    static var defaults: UserDefaults { UserDefaults(suiteName: id) ?? .standard }
}

/// Un gros bouton de l'écran d'accueil qui lance un Flow Homey.
struct Tile: Codable, Identifiable, Hashable {
    var id = UUID()
    var title: String
    var symbol: String
    /// Référence du Flow : "flow/<id>" ou "advancedflow/<id>"
    var flowRef: String?
    /// URL ouverte après le Flow (ex. l'app Qobuz), optionnelle
    var openURL: String?
}

struct RadioStation: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var streamURL: String
}

struct PodcastFeed: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var feedURL: String
}

/// Appareil qui lit la radio et les podcasts.
enum ClockStyle: String, Codable, CaseIterable, Identifiable {
    case digital = "Grands chiffres"
    case analog = "Aiguilles"
    var id: String { rawValue }
}

enum PlayerKind: String, Codable, CaseIterable, Identifiable {
    case denon = "Denon (HEOS)"
    case wiim = "WiiM Ultra"
    var id: String { rawValue }
}

struct Config: Codable, Equatable {
    var homeyIP = ""
    var homeyToken = ""          // clé API Homey (à terme : Trousseau)
    var denonIP = ""
    var wiimIP = ""
    var player: PlayerKind = .denon
    /// Flow lancé avant la radio/podcast (ex. allumer le Denon sur la bonne entrée). Optionnel.
    var listenFlowRef: String?
    var scenes: [Tile] = Tile.defaults
    var stations: [RadioStation] = RadioStation.defaults
    var podcasts: [PodcastFeed] = []
    /// Mode télécommande : l'écran ne se met jamais en veille (optionnel pour rester compatible avec les anciens réglages)
    var keepAwake: Bool?
    // Repos de l'iPad (horloge + luminosité basse)
    var restClock: Bool?
    var restDelay: Int?          // secondes
    var restBrightness: Double?  // 0…1
    var clockStyle: ClockStyle?
    var sleepAtNight: Bool?      // 23 h – 6 h : l'iPad se met en veille normalement

    private static let key = "MaisonFacile.config"

    /// Les réglages vivent dans le groupe d'apps pour que le widget et Siri les lisent.
    static func load() -> Config {
        let data = AppGroup.defaults.data(forKey: key)
            ?? UserDefaults.standard.data(forKey: key)   // anciens réglages (avant le widget)
        guard let data, var c = try? JSONDecoder().decode(Config.self, from: data) else { return Config() }
        // Anciens réglages : le bouton Apple TV ouvre désormais le raccourci (réveil + télécommande).
        for i in c.scenes.indices where c.scenes[i].title == "Apple TV" && c.scenes[i].openURL == nil {
            c.scenes[i].openURL = Tile.appleTVShortcutURL
        }
        return c
    }

    static func save(_ c: Config) {
        guard let data = try? JSONEncoder().encode(c) else { return }
        AppGroup.defaults.set(data, forKey: key)
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    var homeyClient: HomeyClient? { HomeyClient(ip: homeyIP, token: homeyToken) }

    /// Nouveau client pour le lecteur choisi (utilisé par le widget et Siri).
    func makePlayer() -> AudioPlayer? {
        switch player {
        case .denon: return denonIP.isEmpty ? nil : HeosClient(host: denonIP)
        case .wiim: return wiimIP.isEmpty ? nil : WiimClient(host: wiimIP)
        }
    }
}

extension Tile {
    /// Raccourci iOS « Maison Apple TV » : réveille l'Apple TV puis affiche la télécommande.
    static let appleTVShortcutURL = "shortcuts://run-shortcut?name=Maison%20Apple%20TV"

    static let defaults: [Tile] = [
        Tile(title: "Qobuz", symbol: "music.note", openURL: "https://open.qobuz.com/"),
        Tile(title: "Apple TV", symbol: "appletv.fill", openURL: Tile.appleTVShortcutURL),
        Tile(title: "Soirée", symbol: "lamp.floor.fill"),
        Tile(title: "Tout éteindre", symbol: "power"),
    ]
}

extension RadioStation {
    // Flux SRG SSR – à vérifier / adapter dans les Réglages
    static let defaults: [RadioStation] = [
        RadioStation(name: "La 1ère", streamURL: "https://stream.srg-ssr.ch/m/la-1ere/mp3_128"),
        RadioStation(name: "Couleur 3", streamURL: "https://stream.srg-ssr.ch/m/couleur3/mp3_128"),
        RadioStation(name: "Option Musique", streamURL: "https://stream.srg-ssr.ch/m/option-musique/mp3_128"),
        RadioStation(name: "Espace 2", streamURL: "https://stream.srg-ssr.ch/m/espace-2/mp3_128"),
    ]
}
