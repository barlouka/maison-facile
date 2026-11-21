import AppIntents
import Foundation

// Actions utilisables par les widgets, Siri et l'app Raccourcis.
// Ce fichier (et tout le dossier Shared) doit appartenir à l'app ET au widget.

// MARK: Entités (les boutons et les radios configurés dans l'app)

struct SceneEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Bouton"
    static let defaultQuery = SceneQuery()

    let id: String
    let title: String
    let symbol: String

    init(_ t: Tile) { id = t.id.uuidString; title = t.title; symbol = t.symbol }

    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(title)") }
}

struct SceneQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [SceneEntity] {
        Config.load().scenes.filter { identifiers.contains($0.id.uuidString) }.map { SceneEntity($0) }
    }
    func suggestedEntities() async throws -> [SceneEntity] {
        Config.load().scenes.map { SceneEntity($0) }
    }
}

struct StationEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Radio"
    static let defaultQuery = StationQuery()

    let id: String
    let name: String

    init(_ s: RadioStation) { id = s.id.uuidString; name = s.name }

    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
}

struct StationQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [StationEntity] {
        Config.load().stations.filter { identifiers.contains($0.id.uuidString) }.map { StationEntity($0) }
    }
    func suggestedEntities() async throws -> [StationEntity] {
        Config.load().stations.map { StationEntity($0) }
    }
}

enum IntentError: Error, CustomLocalizedStringResourceConvertible {
    case notConfigured
    var localizedStringResource: LocalizedStringResource { "Ouvre Maison Facile pour régler ce bouton." }
}

// MARK: Actions

struct RunSceneIntent: AppIntent {
    static let title: LocalizedStringResource = "Lancer un bouton de la maison"

    @Parameter(title: "Bouton") var scene: SceneEntity

    init() {}
    init(scene: SceneEntity) { self.scene = scene }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let c = Config.load()
        guard let tile = c.scenes.first(where: { $0.id.uuidString == scene.id }),
              let ref = tile.flowRef, let homey = c.homeyClient else { throw IntentError.notConfigured }
        try await homey.trigger(ref)
        return .result(dialog: "\(tile.title) : c'est parti.")
    }
}

struct PlayRadioIntent: AppIntent {
    static let title: LocalizedStringResource = "Écouter une radio"

    @Parameter(title: "Radio") var station: StationEntity

    init() {}
    init(station: StationEntity) { self.station = station }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let c = Config.load()
        guard let s = c.stations.first(where: { $0.id.uuidString == station.id }),
              let player = c.makePlayer() else { throw IntentError.notConfigured }
        if let ref = c.listenFlowRef, let homey = c.homeyClient { try? await homey.trigger(ref) }
        try await player.playURL(s.streamURL)
        return .result(dialog: "\(s.name) en lecture.")
    }
}

struct PauseIntent: AppIntent {
    static let title: LocalizedStringResource = "Mettre la musique en pause"

    func perform() async throws -> some IntentResult {
        guard let player = Config.load().makePlayer() else { throw IntentError.notConfigured }
        try await player.pause()
        return .result()
    }
}

struct ResumeIntent: AppIntent {
    static let title: LocalizedStringResource = "Reprendre la musique"

    func perform() async throws -> some IntentResult {
        guard let player = Config.load().makePlayer() else { throw IntentError.notConfigured }
        try await player.resume()
        return .result()
    }
}

struct VolumeIntent: AppIntent {
    static let title: LocalizedStringResource = "Changer le volume"

    @Parameter(title: "Pas", default: 5) var step: Int

    init() {}
    init(step: Int) { self.step = step }

    func perform() async throws -> some IntentResult {
        guard let player = Config.load().makePlayer() else { throw IntentError.notConfigured }
        let v = try await player.volume()
        try await player.setVolume(v + step)
        return .result()
    }
}
