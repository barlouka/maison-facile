import SwiftUI

struct LightsBlindsView: View {
    @EnvironmentObject var model: AppModel
    @State private var devices: [HomeyDevice] = []
    @State private var loading = true

    private var blinds: [HomeyDevice] { devices.filter(\.isBlind) }
    private var lights: [HomeyDevice] { devices.filter(\.isLight) }

    var body: some View {
        List {
            if !blinds.isEmpty {
                Section("Stores") {
                    BlindRow(name: "Tous les stores", devices: blinds)
                    ForEach(blinds) { BlindRow(name: $0.name, devices: [$0]) }
                }
            }
            if !lights.isEmpty {
                Section("Lumières") {
                    ForEach(lights) { LightRow(device: $0) }
                }
            }
        }
        .overlay {
            if loading { ProgressView() }
            else if devices.isEmpty {
                ContentUnavailableView("Homey injoignable", systemImage: "house.slash",
                                       description: Text("Vérifie l'adresse et la clé dans les Réglages."))
            }
        }
        .navigationTitle("Lumières & stores")
        .refreshable { await load() }
        .task { await load() }
    }

    private func load() async {
        defer { loading = false }
        devices = (try? await model.homey?.devices()) ?? []
    }
}

struct BlindRow: View {
    @EnvironmentObject var model: AppModel
    let name: String
    let devices: [HomeyDevice]

    var body: some View {
        HStack {
            Text(name).font(.title3)
            Spacer()
            button("chevron.up.circle.fill", state: "up", position: 1)
            button("stop.circle.fill", state: "idle", position: nil)
            button("chevron.down.circle.fill", state: "down", position: 0)
        }
        .buttonStyle(.borderless)
        .padding(.vertical, 6)
    }

    private func button(_ symbol: String, state: String, position: Double?) -> some View {
        Button {
            Task {
                guard let homey = model.homey else { return }
                for d in devices {
                    if d.capabilities.contains("windowcoverings_state") {
                        try? await homey.set(d.id, "windowcoverings_state", state)
                    } else if let position, d.capabilities.contains("windowcoverings_set") {
                        try? await homey.set(d.id, "windowcoverings_set", position)
                    }
                }
            }
        } label: {
            Image(systemName: symbol).font(.system(size: 34))
        }
    }
}

struct LightRow: View {
    @EnvironmentObject var model: AppModel
    let device: HomeyDevice
    @State private var isOn = false
    @State private var dim: Double = 1
    @State private var loaded = false

    var body: some View {
        VStack(alignment: .leading) {
            Toggle(device.name, isOn: $isOn)
                .font(.title3)
                .onChange(of: isOn) { _, new in
                    guard loaded else { return }
                    Task { try? await model.homey?.set(device.id, "onoff", new) }
                }
            if device.capabilities.contains("dim"), isOn {
                Slider(value: $dim, in: 0.05...1, onEditingChanged: { editing in
                    if !editing { Task { try? await model.homey?.set(device.id, "dim", dim) } }
                })
            }
        }
        .padding(.vertical, 4)
        .onAppear {
            isOn = device.value("onoff")?.bool ?? false
            dim = device.value("dim")?.number ?? 1
            DispatchQueue.main.async { loaded = true }
        }
    }
}
