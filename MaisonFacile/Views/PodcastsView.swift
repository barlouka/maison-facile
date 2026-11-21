import SwiftUI

struct PodcastsView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        List(model.config.podcasts) { feed in
            NavigationLink(feed.name) { EpisodesView(feed: feed) }
                .font(.title2)
                .padding(.vertical, 8)
        }
        .overlay {
            if model.config.podcasts.isEmpty {
                ContentUnavailableView("Aucun podcast", systemImage: "mic",
                                       description: Text("Ajoute-les dans les Réglages."))
            }
        }
        .navigationTitle("Podcasts")
    }
}

struct EpisodesView: View {
    @EnvironmentObject var model: AppModel
    let feed: PodcastFeed
    @State private var episodes: [Episode] = []
    @State private var error: String?

    var body: some View {
        List(episodes) { ep in
            Button {
                Task { await model.play(url: ep.audioURL, title: ep.title) }
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(ep.title).font(.headline)
                    if let d = ep.date {
                        Text(d, format: .dateTime.day().month().year()).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 6)
            }
        }
        .overlay {
            if let error { ContentUnavailableView("Erreur", systemImage: "wifi.slash", description: Text(error)) }
            else if episodes.isEmpty { ProgressView() }
        }
        .navigationTitle(feed.name)
        .safeAreaInset(edge: .bottom) { VolumeBar() }
        .task {
            do { episodes = try await PodcastService.episodes(feedURL: feed.feedURL) }
            catch { self.error = "Impossible de lire ce podcast." }
        }
    }
}
