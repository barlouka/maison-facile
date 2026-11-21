import Foundation

/// Ce qui est en cours de lecture.
struct NowPlaying: Equatable, Sendable {
    var title: String
    var artist: String
    var artworkURL: URL?
    var isPlaying: Bool
}

/// Ce que l'app demande à l'appareil qui joue (Denon ou WiiM).
protocol AudioPlayer: Sendable {
    func playURL(_ url: String) async throws
    func pause() async throws
    func resume() async throws
    func setVolume(_ level: Int) async throws      // 0…100
    func volume() async throws -> Int
    func nowPlaying() async throws -> NowPlaying?
}

extension String {
    /// Encodage d'une valeur passée dans une commande (& = ? % etc.)
    var commandEncoded: String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&=?+%#")
        return addingPercentEncoding(withAllowedCharacters: allowed) ?? self
    }
}
