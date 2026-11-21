import Foundation
import Network

enum HeosError: LocalizedError {
    case closed, noPlayer, failed(String)
    var errorDescription: String? {
        switch self {
        case .closed: return "Connexion au Denon perdue"
        case .noPlayer: return "Aucun lecteur HEOS trouvé"
        case .failed(let m): return "Denon : \(m)"
        }
    }
}

/// Petit client du protocole HEOS CLI (TCP 1255) du Denon AVR-X3800H.
/// Astuce : régler l'ampli sur « Contrôle réseau : Toujours actif » pour qu'il réponde en veille.
actor HeosClient: AudioPlayer {
    private let host: String
    private var connection: NWConnection?
    private var buffer = Data()
    private var pid: Int?

    // Une commande à la fois
    private var busy = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(host: String) { self.host = host }

    // MARK: API AudioPlayer

    func playURL(_ url: String) async throws {
        let p = try await playerID()
        try await command("browse/play_stream", ["pid": "\(p)", "url": url])
    }

    func pause() async throws { try await setState("pause") }
    func resume() async throws { try await setState("play") }

    func setVolume(_ level: Int) async throws {
        let p = try await playerID()
        try await command("player/set_volume", ["pid": "\(p)", "level": "\(max(0, min(100, level)))"])
    }

    func volume() async throws -> Int {
        let p = try await playerID()
        let r = try await command("player/get_volume", ["pid": "\(p)"])
        // message : "pid=123&level=40"
        let level = r.message.split(separator: "&")
            .first { $0.hasPrefix("level=") }
            .flatMap { Int($0.dropFirst(6)) }
        return level ?? 0
    }

    func playPreset(_ n: Int) async throws {
        let p = try await playerID()
        try await command("browse/play_preset", ["pid": "\(p)", "preset": "\(n)"])
    }

    // MARK: Interne

    private func setState(_ state: String) async throws {
        let p = try await playerID()
        try await command("player/set_play_state", ["pid": "\(p)", "state": state])
    }

    func playerID() async throws -> Int {
        if let pid { return pid }
        let r = try await command("player/get_players")
        guard let data = r.payload,
              let arr = try JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              let first = arr.first?["pid"] as? Int else { throw HeosError.noPlayer }
        pid = first
        return first
    }

    struct Response: Sendable {
        let result: String
        let message: String
        let payload: Data?
    }

    @discardableResult
    private func command(_ path: String, _ params: [String: String] = [:]) async throws -> Response {
        await lock()
        defer { unlock() }
        do {
            let c = try await connect()
            let query = params.map { "\($0.key)=\($0.value.commandEncoded)" }.joined(separator: "&")
            let line = "heos://\(path)" + (query.isEmpty ? "" : "?\(query)") + "\r\n"
            try await send(c, line)

            while true {
                let text = try await receiveLine(c)
                guard let obj = try? JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any],
                      let heos = obj["heos"] as? [String: Any],
                      let cmd = heos["command"] as? String, cmd == path else { continue }
                let message = heos["message"] as? String ?? ""
                if message.contains("command under process") { continue }
                let result = heos["result"] as? String ?? ""
                let payload = obj["payload"].flatMap { try? JSONSerialization.data(withJSONObject: $0) }
                guard result == "success" else { throw HeosError.failed(message) }
                return Response(result: result, message: message, payload: payload)
            }
        } catch {
            connection?.cancel()
            connection = nil
            throw error
        }
    }

    private func lock() async {
        if busy { await withCheckedContinuation { waiters.append($0) } } else { busy = true }
    }

    private func unlock() {
        if waiters.isEmpty { busy = false } else { waiters.removeFirst().resume() }
    }

    private final class Once: @unchecked Sendable {
        private let lock = NSLock()
        private var done = false
        func run(_ f: () -> Void) { lock.lock(); defer { lock.unlock() }; if !done { done = true; f() } }
    }

    private func connect() async throws -> NWConnection {
        if let c = connection, case .ready = c.state { return c }
        let c = NWConnection(host: NWEndpoint.Host(host), port: 1255, using: .tcp)
        let once = Once()
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            c.stateUpdateHandler = { state in
                switch state {
                case .ready: once.run { cont.resume() }
                case .failed(let e), .waiting(let e): once.run { cont.resume(throwing: e) }
                case .cancelled: once.run { cont.resume(throwing: HeosError.closed) }
                default: break
                }
            }
            c.start(queue: .global())
        }
        connection = c
        buffer = Data()
        return c
    }

    private func send(_ c: NWConnection, _ s: String) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            c.send(content: Data(s.utf8), completion: .contentProcessed { err in
                if let err { cont.resume(throwing: err) } else { cont.resume() }
            })
        }
    }

    private func receiveLine(_ c: NWConnection) async throws -> String {
        let sep = Data("\r\n".utf8)
        while true {
            if let r = buffer.firstRange(of: sep) {
                let line = buffer[buffer.startIndex..<r.lowerBound]
                buffer = Data(buffer[r.upperBound...])
                return String(decoding: line, as: UTF8.self)
            }
            let chunk: Data = try await withCheckedThrowingContinuation { cont in
                c.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { data, _, isComplete, err in
                    if let err { cont.resume(throwing: err) }
                    else if let data, !data.isEmpty { cont.resume(returning: data) }
                    else if isComplete { cont.resume(throwing: HeosError.closed) }
                    else { cont.resume(returning: Data()) }
                }
            }
            buffer.append(chunk)
        }
    }
}
