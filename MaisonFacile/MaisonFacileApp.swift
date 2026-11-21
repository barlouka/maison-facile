import SwiftUI

@main
struct MaisonFacileApp: App {
    @StateObject private var model = AppModel()
    @StateObject private var idle = IdleController()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(model)
                .overlay {
                    if idle.isResting {
                        ClockView(style: model.config.clockStyle ?? .digital, nowPlaying: model.nowPlaying)
                            .transition(.opacity)
                    }
                }
                .onAppear {
                    idle.configure(with: model.config)
                    idle.start()
                }
                .onChange(of: model.config) { _, c in idle.configure(with: c) }
        }
    }
}
