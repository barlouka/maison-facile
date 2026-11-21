import SwiftUI

struct RadioView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        List(model.config.stations) { station in
            Button {
                Task { await model.play(url: station.streamURL, title: station.name) }
            } label: {
                Label(station.name, systemImage: "dot.radiowaves.left.and.right")
                    .font(.title2)
                    .padding(.vertical, 10)
            }
        }
        .navigationTitle("Radio")
        .safeAreaInset(edge: .bottom) { VolumeBar() }
    }
}
