import Foundation
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    @Published var config: Config {
        didSet {
            Config.save(config)
            if oldValue.denonIP != config.denonIP { heosStore = nil }
            if oldValue.wiimIP != config.wiimIP { wiimStore = nil }
        }
    }
    @Published var toast: String?
    @Published var volume: Double = 30
    @Published var isPlaying = false

    private var heosStore: HeosClient?
    private var wiimStore: WiimClient?

    init() { config = Config.load() }

    var homey: HomeyClient? { HomeyClient(ip: config.homeyIP, token: config.homeyToken) }

    var heos: HeosClient? {
        guard !config.denonIP.isEmpty else { return nil }
        if heosStore == nil { heosStore = HeosClient(host: config.denonIP) }
        return heosStore
    }

    var wiim: WiimClient? {
        guard !config.wiimIP.isEmpty else { return nil }
        if wiimStore == nil { wiimStore = WiimClient(host: config.wiimIP) }
        return wiimStore
    }

    /// Lecteur choisi pour la radio et les podcasts.
    var player: AudioPlayer? {
        switch config.player {
        case .denon: return heos
        case .wiim: return wiim
        }
    }

    // MARK: Actions

    /// Lance le Flow d'un bouton. Renvoie true si ça a marché.
    @discardableResult
    func run(_ tile: Tile) async -> Bool {
        guard let ref = tile.flowRef, let homey else {
            show("« \(tile.title) » n'est pas encore réglé")
            return false
        }
        do {
            try await homey.trigger(ref)
            show("✓ \(tile.title)")
            return true
        } catch {
            show("Homey ne répond pas")
            return false
        }
    }

    func play(url: String, title: String) async {
        guard let player else { show("Lecteur non configuré"); return }
        if let ref = config.listenFlowRef, let homey { try? await homey.trigger(ref) }
        do {
            try await player.playURL(url)
            isPlaying = true
            show("▶︎ \(title)")
        } catch {
            show("Le lecteur ne répond pas")
        }
    }

    func togglePause() async {
        guard let player else { return }
        do {
            if isPlaying { try await player.pause() } else { try await player.resume() }
            isPlaying.toggle()
        } catch { show("Le lecteur ne répond pas") }
    }

    func refreshVolume() async {
        if let v = try? await player?.volume() { volume = Double(v) }
    }

    func applyVolume() async {
        do { try await player?.setVolume(Int(volume)) } catch { show("Volume : pas de réponse") }
    }

    func nudgeVolume(_ delta: Double) async {
        volume = min(100, max(0, volume + delta))
        await applyVolume()
    }

    func show(_ message: String) {
        toast = message
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            if toast == message { toast = nil }
        }
    }
}
