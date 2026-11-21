import Foundation

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

    static func load() -> Config {
        guard let data = UserDefaults.standard.data(forKey: key),
              let c = try? JSONDecoder().decode(Config.self, from: data) else { return Config() }
        return c
    }

    static func save(_ c: Config) {
        if let data = try? JSONEncoder().encode(c) { UserDefaults.standard.set(data, forKey: key) }
    }
}

extension Tile {
    static let defaults: [Tile] = [
        Tile(title: "Qobuz", symbol: "music.note", openURL: "https://open.qobuz.com/"),
        Tile(title: "Apple TV", symbol: "appletv.fill"),
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
