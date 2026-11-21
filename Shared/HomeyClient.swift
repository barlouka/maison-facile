import Foundation

/// Valeur JSON simple (pour les capacités des appareils Homey).
enum JSONValue: Decodable, Hashable {
    case bool(Bool), number(Double), string(String), null

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let b = try? c.decode(Bool.self) { self = .bool(b) }
        else if let n = try? c.decode(Double.self) { self = .number(n) }
        else if let s = try? c.decode(String.self) { self = .string(s) }
        else { self = .null }
    }

    var bool: Bool? { if case .bool(let b) = self { return b }; return nil }
    var number: Double? { if case .number(let n) = self { return n }; return nil }
}

struct HomeyFlow: Identifiable, Hashable {
    let ref: String      // "flow/<id>" ou "advancedflow/<id>"
    let name: String
    var id: String { ref }
}

struct HomeyDevice: Identifiable, Decodable, Hashable {
    struct Capability: Decodable, Hashable { let value: JSONValue? }

    let id: String
    let name: String
    let deviceClass: String
    let capabilities: [String]
    let capabilitiesObj: [String: Capability]?

    enum CodingKeys: String, CodingKey {
        case id, name, capabilities, capabilitiesObj
        case deviceClass = "class"
    }

    func value(_ cap: String) -> JSONValue? { capabilitiesObj?[cap]?.value ?? nil }

    var isLight: Bool { deviceClass == "light" && capabilities.contains("onoff") }
    var isBlind: Bool {
        ["blinds", "curtain", "sunshade", "windowcoverings"].contains(deviceClass)
        || capabilities.contains("windowcoverings_state")
        || capabilities.contains("windowcoverings_set")
    }
}

enum HomeyError: LocalizedError {
    case http(Int)
    var errorDescription: String? {
        switch self { case .http(let c): return "Homey a répondu \(c)" }
    }
}

/// Client de l'API locale du Homey Pro (clé API : Réglages → Clés API dans l'app web Homey).
struct HomeyClient {
    let baseURL: URL
    let token: String

    init?(ip: String, token: String) {
        let ip = ip.trimmingCharacters(in: .whitespaces)
        guard !ip.isEmpty, !token.isEmpty, let url = URL(string: "http://\(ip)") else { return nil }
        self.baseURL = url
        self.token = token
    }

    private func request(_ path: String, method: String = "GET", json: Any? = nil) async throws -> Data {
        var req = URLRequest(url: baseURL.appendingPathComponent(path))
        req.httpMethod = method
        req.timeoutInterval = 8
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let json {
            req.httpBody = try JSONSerialization.data(withJSONObject: json)
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let (data, resp) = try await URLSession.shared.data(for: req)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? -1
        guard (200..<300).contains(code) else { throw HomeyError.http(code) }
        return data
    }

    // MARK: Flows

    func flows() async throws -> [HomeyFlow] {
        struct F: Decodable { let id: String; let name: String }
        let basicData = try await request("api/manager/flow/flow")
        let basic = try JSONDecoder().decode([String: F].self, from: basicData)
        let advData = try? await request("api/manager/flow/advancedflow")
        let adv = advData.flatMap { try? JSONDecoder().decode([String: F].self, from: $0) } ?? [:]

        let all = basic.values.map { HomeyFlow(ref: "flow/\($0.id)", name: $0.name) }
                + adv.values.map { HomeyFlow(ref: "advancedflow/\($0.id)", name: $0.name) }
        return all.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Le Flow doit commencer par la carte « Ce flow est démarré ».
    func trigger(_ ref: String) async throws {
        _ = try await request("api/manager/flow/\(ref)/trigger", method: "POST", json: [String: Any]())
    }

    // MARK: Appareils

    func devices() async throws -> [HomeyDevice] {
        let data = try await request("api/manager/devices/device")
        let dict = try JSONDecoder().decode([String: HomeyDevice].self, from: data)
        return dict.values.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func set(_ deviceID: String, _ capability: String, _ value: Any) async throws {
        _ = try await request("api/manager/devices/device/\(deviceID)/capability/\(capability)",
                              method: "PUT", json: ["value": value])
    }
}
