import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var model: AppModel
    @State private var flows: [HomeyFlow] = []
    @State private var status = ""

    var body: some View {
        Form {
            Section("Homey Pro") {
                TextField("Adresse IP (ex. 192.168.1.20)", text: $model.config.homeyIP)
                    .keyboardType(.numbersAndPunctuation).textInputAutocapitalization(.never)
                SecureField("Clé API", text: $model.config.homeyToken)
                Button("Charger les Flows") { Task { await loadFlows() } }
            }

            Section("Audio") {
                TextField("IP du Denon AVR-X3800H", text: $model.config.denonIP)
                    .keyboardType(.numbersAndPunctuation)
                TextField("IP du WiiM Ultra", text: $model.config.wiimIP)
                    .keyboardType(.numbersAndPunctuation)
                Picker("Radio et podcasts sur", selection: $model.config.player) {
                    ForEach(PlayerKind.allCases) { Text($0.rawValue).tag($0) }
                }
                flowPicker("Flow avant d'écouter", ref: $model.config.listenFlowRef)
                Button("Tester le lecteur") { Task { await testPlayer() } }
            }

            Section("Boutons de l'accueil") {
                ForEach($model.config.scenes) { $tile in
                    VStack(alignment: .leading) {
                        TextField("Nom", text: $tile.title).font(.headline)
                        TextField("Symbole SF", text: $tile.symbol).foregroundStyle(.secondary)
                        flowPicker("Flow", ref: $tile.flowRef)
                    }
                }
                .onDelete { model.config.scenes.remove(atOffsets: $0) }
                .onMove { model.config.scenes.move(fromOffsets: $0, toOffset: $1) }
                Button("Ajouter un bouton") {
                    model.config.scenes.append(Tile(title: "Nouveau", symbol: "star.fill"))
                }
            }

            Section("Radios") {
                ForEach($model.config.stations) { $s in
                    VStack(alignment: .leading) {
                        TextField("Nom", text: $s.name).font(.headline)
                        TextField("URL du flux", text: $s.streamURL)
                            .textInputAutocapitalization(.never).font(.caption)
                    }
                }
                .onDelete { model.config.stations.remove(atOffsets: $0) }
                Button("Ajouter une radio") {
                    model.config.stations.append(RadioStation(name: "Radio", streamURL: "https://"))
                }
            }

            Section {
                ForEach($model.config.podcasts) { $p in
                    VStack(alignment: .leading) {
                        TextField("Nom", text: $p.name).font(.headline)
                        TextField("URL du flux RSS", text: $p.feedURL)
                            .textInputAutocapitalization(.never).font(.caption)
                    }
                }
                .onDelete { model.config.podcasts.remove(atOffsets: $0) }
                Button("Ajouter un podcast") {
                    model.config.podcasts.append(PodcastFeed(name: "Podcast", feedURL: "https://"))
                }
            } header: { Text("Podcasts") } footer: {
                Text("L'adresse RSS se trouve sur la page du podcast (ou via podcastindex.org).")
            }

            if !status.isEmpty { Section { Text(status).foregroundStyle(.secondary) } }
        }
        .navigationTitle("Réglages")
        .toolbar { EditButton() }
        .task { await loadFlows() }
    }

    private func flowPicker(_ label: String, ref: Binding<String?>) -> some View {
        Picker(label, selection: ref) {
            Text("Aucun").tag(String?.none)
            ForEach(flows) { Text($0.name).tag(Optional($0.ref)) }
            // Garde l'entrée actuelle visible même si les Flows ne sont pas chargés
            if let r = ref.wrappedValue, !flows.contains(where: { $0.ref == r }) {
                Text("(Flow enregistré)").tag(Optional(r))
            }
        }
    }

    private func loadFlows() async {
        guard let homey = model.homey else { status = "Renseigne l'IP et la clé du Homey."; return }
        do {
            flows = try await homey.flows()
            status = "\(flows.count) Flows trouvés sur le Homey."
        } catch {
            status = "Homey : \(error.localizedDescription)"
        }
    }

    private func testPlayer() async {
        guard let player = model.player else { status = "Renseigne l'IP du lecteur."; return }
        do {
            let v = try await player.volume()
            status = "\(model.config.player.rawValue) OK — volume \(v)"
        } catch {
            status = "\(model.config.player.rawValue) : \(error.localizedDescription)"
        }
    }
}
