import Foundation

struct Episode: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let audioURL: String
    let date: Date?
}

/// Lit un flux RSS de podcast et renvoie les derniers épisodes.
enum PodcastService {
    static func episodes(feedURL: String, limit: Int = 30) async throws -> [Episode] {
        guard let url = URL(string: feedURL) else { throw URLError(.badURL) }
        let (data, _) = try await URLSession.shared.data(from: url)
        let parser = RSSParser()
        let xml = XMLParser(data: data)
        xml.delegate = parser
        xml.parse()
        return Array(parser.episodes.prefix(limit))
    }
}

private final class RSSParser: NSObject, XMLParserDelegate {
    var episodes: [Episode] = []
    private var inItem = false
    private var current = ""
    private var title = ""
    private var audio = ""
    private var pubDate = ""

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        return f
    }()

    func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?,
                qualifiedName qName: String?, attributes: [String: String] = [:]) {
        current = ""
        if name == "item" { inItem = true; title = ""; audio = ""; pubDate = "" }
        if inItem, name == "enclosure", let u = attributes["url"] { audio = u }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) { current += string }

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        current += String(decoding: CDATABlock, as: UTF8.self)
    }

    func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName qName: String?) {
        guard inItem else { return }
        let text = current.trimmingCharacters(in: .whitespacesAndNewlines)
        switch name {
        case "title": if title.isEmpty { title = text }
        case "pubDate": pubDate = text
        case "item":
            inItem = false
            if !audio.isEmpty {
                episodes.append(Episode(title: title, audioURL: audio,
                                        date: Self.dateFormatter.date(from: pubDate)))
            }
        default: break
        }
    }
}
