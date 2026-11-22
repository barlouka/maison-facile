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

            Section {
                Toggle("Mode télécommande (écran toujours allumé)", isOn: Binding(
                    get: { model.config.keepAwake ?? false },
                    set: { model.config.keepAwake = $0 }))
                if model.config.keepAwake ?? false {
                    Toggle("Horloge au repos", isOn: Binding(
                        get: { model.config.restClock ?? true },
                        set: { model.config.restClock = $0 }))
                    Picker("Après", selection: Binding(
                        get: { model.config.restDelay ?? 60 },
                        set: { model.config.restDelay = $0 })) {
                        Text("30 secondes").tag(30)
                        Text("1 minute").tag(60)
                        Text("2 minutes").tag(120)
                        Text("5 minutes").tag(300)
                    }
                    Picker("Cadran", selection: Binding(
                        get: { model.config.clockStyle ?? .digital },
                        set: { model.config.clockStyle = $0 })) {
                        ForEach(ClockStyle.allCases) { Text($0.rawValue).tag($0) }
                    }
                    VStack(alignment: .leading) {
                        Text("Luminosité au repos")
                        Slider(value: Binding(
                            get: { model.config.restBrightness ?? 0.15 },
                            set: { model.config.restBrightness = $0 }), in: 0...0.6)
                    }
                    Toggle("Éteindre la nuit (23 h – 6 h)", isOn: Binding(
                        get: { model.config.sleepAtNight ?? true },
                        set: { model.config.sleepAtNight = $0 }))
                }
            } header: { Text("iPad du salon") } footer: {
                Text("Au repos, l'iPad affiche l'heure sur fond noir avec une luminosité basse ; un toucher le réveille. La nuit, il se met en veille comme d'habitude. Avec l'Accès guidé (Réglages iPad → Accessibilité), il reste sur l'app.")
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
                        TextField("Ouvrir ensuite (URL ou raccourci)", text: Binding(
                            get: { tile.openURL ?? "" },
                            set: { tile.openURL = $0.isEmpty ? nil : $0 }))
                            .textInputAutocapitalization(.never)
                            .font(.caption)
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
