import SwiftUI
import UIKit
import UIKit.UIGestureRecognizerSubclass

/// Gère le « repos » de l'iPad : après un délai sans toucher l'écran, on affiche
/// l'horloge et on baisse la luminosité (façon écran toujours allumé).
/// Le moindre toucher réveille l'app et rétablit la luminosité.
@MainActor
final class IdleController: ObservableObject {
    @Published private(set) var isResting = false

    // Réglages (mis à jour depuis Config)
    private var keepAwake = false
    private var clockEnabled = true
    private var delay: TimeInterval = 60
    private var restBrightness: CGFloat = 0.15
    private var sleepAtNight = true

    private var lastTouch = Date()
    private var savedBrightness: CGFloat?
    private var timer: Timer?
    private weak var window: UIWindow?
    private var spy: TouchSpy?

    /// Nuit : 23 h – 6 h. L'iPad peut alors se mettre en veille normalement.
    private var isNight: Bool {
        let h = Calendar.current.component(.hour, from: .now)
        return h >= 23 || h < 6
    }

    func configure(with c: Config) {
        keepAwake = c.keepAwake ?? false
        clockEnabled = c.restClock ?? true
        delay = TimeInterval(c.restDelay ?? 60)
        restBrightness = CGFloat(c.restBrightness ?? 0.15)
        sleepAtNight = c.sleepAtNight ?? true
        if isResting { screen?.brightness = restBrightness }
        tick()
    }

    func start() {
        installTouchSpy()
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        NotificationCenter.default.addObserver(forName: UIApplication.willResignActiveNotification,
                                               object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.wake() }
        }
    }

    func touched() {
        lastTouch = .now
        if isResting { wake() }
    }

    func wake() {
        guard isResting else { return }
        if let b = savedBrightness { screen?.brightness = b }
        savedBrightness = nil
        withAnimation(.easeOut(duration: 0.3)) { isResting = false }
        lastTouch = .now
    }

    // MARK: Interne

    private var screen: UIScreen? { window?.windowScene?.screen }

    private func tick() {
        let night = sleepAtNight && isNight
        // La nuit, on rend la main à iOS : l'iPad s'éteint après son délai habituel.
        UIApplication.shared.isIdleTimerDisabled = keepAwake && !night
        if night, isResting { wake() }

        guard keepAwake, clockEnabled, !night, !isResting,
              Date().timeIntervalSince(lastTouch) >= delay else { return }
        rest()
    }

    private func rest() {
        savedBrightness = screen?.brightness
        screen?.brightness = restBrightness
        withAnimation(.easeIn(duration: 0.8)) { isResting = true }
    }

    private func installTouchSpy() {
        guard spy == nil else { return }
        guard let w = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .flatMap(\.windows)
                .first(where: \.isKeyWindow) ?? UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene }).first?.windows.first
        else {
            // La fenêtre n'est pas encore prête : on réessaie un peu plus tard.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in self?.installTouchSpy() }
            return
        }
        let s = TouchSpy { [weak self] in self?.touched() }
        w.addGestureRecognizer(s)
        spy = s
        window = w
    }
}

/// Repère chaque toucher sans jamais bloquer les boutons de l'app.
private final class TouchSpy: UIGestureRecognizer, UIGestureRecognizerDelegate {
    private let onTouch: @MainActor () -> Void

    init(onTouch: @escaping @MainActor () -> Void) {
        self.onTouch = onTouch
        super.init(target: nil, action: nil)
        cancelsTouchesInView = false
        delaysTouchesBegan = false
        delaysTouchesEnded = false
        delegate = self
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        MainActor.assumeIsolated { onTouch() }
        state = .failed
    }

    func gestureRecognizer(_ g: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }
}
