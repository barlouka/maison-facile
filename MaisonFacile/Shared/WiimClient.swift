import Foundation

/// Client de l'API HTTP du WiiM Ultra (API LinkPlay : https://<ip>/httpapi.asp?command=…).
/// Le WiiM utilise un certificat auto-signé : on l'accepte uniquement pour son adresse locale.
final class WiimClient: NSObject, AudioPlayer, URLSessionDelegate, @unchecked Sendable {
    private let host: String
    private lazy var session = URLSession(configuration: .ephemeral, delegate: self, delegateQueue: nil)

    init(host: String) { self.host = host }

    @discardableResult
    private func send(_ command: String) async throws -> Data {
        guard let url = URL(string: "https://\(host)/httpapi.asp?command=\(command)") else {
            throw URLError(.badURL)
        }
        var req = URLRequest(url: url)
        req.timeoutInterval = 6
        let (data, _) = try await session.data(for: req)
        return data
    }

    func playURL(_ url: String) async throws { try await send("setPlayerCmd:play:\(url.commandEncoded)") }
    func pause() async throws { try await send("setPlayerCmd:pause") }
    func resume() async throws { try await send("setPlayerCmd:resume") }
    func setVolume(_ level: Int) async throws { try await send("setPlayerCmd:vol:\(max(0, min(100, level)))") }

    func volume() async throws -> Int {
        let data = try await send("getPlayerStatus")
        let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        if let s = obj?["vol"] as? String, let v = Int(s) { return v }
        return obj?["vol"] as? Int ?? 0
    }

    func nowPlaying() async throws -> NowPlaying? {
        let statusData = try await send("getPlayerStatus")
        let status = try JSONSerialization.jsonObject(with: statusData) as? [String: Any] ?? [:]
        let playing = (status["status"] as? String) == "play"

        // Firmware récent : getMetaInfo donne titre, artiste et pochette en clair.
        if let metaData = try? await send("getMetaInfo"),
           let meta = (try? JSONSerialization.jsonObject(with: metaData) as? [String: Any])?["metaData"] as? [String: Any],
           let title = meta["title"] as? String, !title.isEmpty, title.lowercased() != "unknow" {
            return NowPlaying(title: title, artist: meta["artist"] as? String ?? "",
                              artworkURL: (meta["albumArtURI"] as? String).flatMap(URL.init(string:)),
                              isPlaying: playing)
        }
        // Sinon : champs encodés en hexadécimal dans getPlayerStatus.
        let title = Self.fromHex(status["Title"] as? String)
        guard !title.isEmpty else { return nil }
        return NowPlaying(title: title, artist: Self.fromHex(status["Artist"] as? String),
                          artworkURL: nil, isPlaying: playing)
    }

    private static func fromHex(_ hex: String?) -> String {
        guard let hex, hex.count % 2 == 0 else { return "" }
        var bytes = [UInt8]()
        var i = hex.startIndex
        while i < hex.endIndex {
            let j = hex.index(i, offsetBy: 2)
            guard let b = UInt8(hex[i..<j], radix: 16) else { return "" }
            bytes.append(b)
            i = j
        }
        return String(decoding: bytes, as: UTF8.self)
    }

    // Accepte le certificat auto-signé du WiiM, et seulement pour son IP.
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
           challenge.protectionSpace.host == host,
           let trust = challenge.protectionSpace.serverTrust {
            completionHandler(.useCredential, URLCredential(trust: trust))
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}
