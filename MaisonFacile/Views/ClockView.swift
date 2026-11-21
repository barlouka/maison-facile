import SwiftUI

/// Écran de repos façon Apple Watch : fond noir, heure en grand.
/// La position bouge légèrement chaque minute pour ménager l'écran.
struct ClockView: View {
    let style: ClockStyle
    var nowPlaying: NowPlaying?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { ctx in
            let date = ctx.date
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(spacing: 40) {
                    switch style {
                    case .digital: DigitalFace(date: date)
                    case .analog: AnalogFace(date: date).frame(width: 420, height: 420)
                    }
                    if let np = nowPlaying, np.isPlaying {
                        Label(np.artist.isEmpty ? np.title : "\(np.title) · \(np.artist)",
                              systemImage: "music.note")
                            .font(.system(size: 26, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.6))
                            .lineLimit(1)
                            .frame(maxWidth: 700)
                    }
                }
                .offset(drift(for: date))
                .animation(.easeInOut(duration: 2), value: Calendar.current.component(.minute, from: date))
            }
        }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
    }

    /// Petit décalage pseudo-aléatoire, constant pendant une minute.
    private func drift(for date: Date) -> CGSize {
        let m = Int(date.timeIntervalSince1970 / 60)
        let x = Double((m * 37) % 41) - 20
        let y = Double((m * 53) % 41) - 20
        return CGSize(width: x, height: y)
    }
}

private struct DigitalFace: View {
    let date: Date

    var body: some View {
        VStack(spacing: 8) {
            Text(date, format: .dateTime.weekday(.wide).day().month(.wide))
                .font(.system(size: 34, weight: .semibold, design: .rounded))
                .foregroundStyle(.orange)
                .textCase(.uppercase)
            Text(date, format: .dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
                .font(.system(size: 220, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .contentTransition(.numericText())
        }
    }
}

private struct AnalogFace: View {
    let date: Date

    var body: some View {
        Canvas { ctx, size in
            let r = min(size.width, size.height) / 2
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            let cal = Calendar.current
            let h = Double(cal.component(.hour, from: date) % 12)
            let m = Double(cal.component(.minute, from: date))
            let s = Double(cal.component(.second, from: date))

            // Graduations
            for i in 0..<60 {
                let a = Double(i) / 60 * 2 * .pi
                let long = i % 5 == 0
                let inner = r * (long ? 0.86 : 0.92)
                var p = Path()
                p.move(to: point(c, a, inner))
                p.addLine(to: point(c, a, r * 0.97))
                ctx.stroke(p, with: .color(.white.opacity(long ? 0.9 : 0.35)), lineWidth: long ? 5 : 2)
            }

            func hand(_ angle: Double, _ length: Double, _ width: Double, _ color: Color) {
                var p = Path()
                p.move(to: point(c, angle + .pi, r * 0.08))
                p.addLine(to: point(c, angle, r * length))
                ctx.stroke(p, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round))
            }

            hand((h + m / 60) / 12 * 2 * .pi, 0.5, 14, .white)
            hand((m + s / 60) / 60 * 2 * .pi, 0.78, 10, .white)
            hand(s / 60 * 2 * .pi, 0.85, 3, .orange)

            ctx.fill(Path(ellipseIn: CGRect(x: c.x - 9, y: c.y - 9, width: 18, height: 18)), with: .color(.orange))
            ctx.fill(Path(ellipseIn: CGRect(x: c.x - 4, y: c.y - 4, width: 8, height: 8)), with: .color(.black))
        }
    }

    /// Angle 0 = midi, sens horaire.
    private func point(_ c: CGPoint, _ angle: Double, _ radius: Double) -> CGPoint {
        CGPoint(x: c.x + sin(angle) * radius, y: c.y - cos(angle) * radius)
    }
}
