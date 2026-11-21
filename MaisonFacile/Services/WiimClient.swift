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
