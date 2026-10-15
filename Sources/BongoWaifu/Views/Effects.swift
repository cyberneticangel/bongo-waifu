import SwiftUI
import WaifuCore

/// Particles and overlays drawn above the character in the same 240x240 design space.
struct EffectsLayer: View {
    let effect: ActiveEffect?
    let sleeping: Bool
    let tier: SpeedTier

    static let durations: [Effect: Double] = [
        .sparkles: 1.2, .hearts: 1.8, .sweat: 1.6, .anger: 1.3, .question: 1.6, .notes: 1.6,
    ]

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let scale = size.width / VectorWaifuView.designSize
                context.scaleBy(x: scale, y: scale)
                let now = timeline.date
                let t = now.timeIntervalSinceReferenceDate

                if sleeping { drawZzz(context, time: t) }
                if tier == .blazing && !sleeping { drawSpeedLines(context, time: t) }

                if let effect {
                    let duration = Self.durations[effect.effect] ?? 1.5
                    let p = now.timeIntervalSince(effect.start) / duration
                    if p >= 0 && p < 1 { draw(effect.effect, progress: p, in: context) }
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func draw(_ effect: Effect, progress p: Double, in ctx: GraphicsContext) {
        let fade = p < 0.8 ? 1 : (1 - p) / 0.2
        switch effect {
        case .sparkles:
            let spots: [CGPoint] = [CGPoint(x: 56, y: 60), CGPoint(x: 186, y: 50), CGPoint(x: 196, y: 112),
                                    CGPoint(x: 44, y: 124), CGPoint(x: 120, y: 18)]
            for (i, spot) in spots.enumerated() {
                let local = min(max(p * 1.6 - Double(i) * 0.12, 0), 1)
                let r = sin(local * .pi) * 9
                guard r > 0.2 else { continue }
                ctx.fill(sparkle(center: spot, radius: r), with: .color(Color(hex: 0xFFD54A).opacity(fade)))
            }
        case .hearts:
            for i in 0..<4 {
                let local = min(max(p * 1.3 - Double(i) * 0.1, 0), 1)
                let x = 92 + Double(i) * 18 + sin(local * 6 + Double(i)) * 6
                let y = 70 - local * 60
                ctx.fill(heart(center: CGPoint(x: x, y: y), size: 9 + Double(i % 2) * 3),
                         with: .color(Color(hex: 0xFF5C8A).opacity((1 - local) * fade)))
            }
        case .sweat:
            let y = 64 + p * 22
            var drop = Path()
            drop.move(to: CGPoint(x: 168, y: y - 9))
            drop.addQuadCurve(to: CGPoint(x: 168, y: y + 6), control: CGPoint(x: 176, y: y + 6))
            drop.addQuadCurve(to: CGPoint(x: 168, y: y - 9), control: CGPoint(x: 160, y: y + 6))
            ctx.fill(drop, with: .color(Color(hex: 0x8ED0FF).opacity(fade)))
            ctx.stroke(drop, with: .color(Color(hex: 0x3D8FD1).opacity(fade)), lineWidth: 1)
        case .anger:
            let pulse = 1 + sin(p * .pi * 6) * 0.15
            let c = CGPoint(x: 158, y: 54)
            for angle in stride(from: 0.0, to: 360, by: 90) {
                var mark = Path()
                let a = Angle.degrees(angle + 45).radians
                mark.move(to: CGPoint(x: c.x + cos(a) * 3 * pulse, y: c.y + sin(a) * 3 * pulse))
                mark.addQuadCurve(to: CGPoint(x: c.x + cos(a + 0.8) * 9 * pulse, y: c.y + sin(a + 0.8) * 9 * pulse),
                                  control: CGPoint(x: c.x + cos(a) * 9 * pulse, y: c.y + sin(a) * 9 * pulse))
                ctx.stroke(mark, with: .color(Color(hex: 0xE23A4D).opacity(fade)), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
            }
        case .question:
            let bob = sin(p * .pi * 4) * 3
            ctx.draw(Text("?").font(.system(size: 26, weight: .black, design: .rounded))
                .foregroundStyle(Color(hex: 0x5A6BD8).opacity(fade)),
                     at: CGPoint(x: 172, y: 44 + bob))
        case .notes:
            for i in 0..<3 {
                let local = min(max(p * 1.4 - Double(i) * 0.2, 0), 1)
                let x = 176 + Double(i) * 12 + sin(local * 5) * 5
                let y = 110 - local * 70
                ctx.draw(Text(i.isMultiple(of: 2) ? "♪" : "♫").font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color(hex: 0x9B6BE0).opacity((1 - local) * fade)),
                         at: CGPoint(x: x, y: y))
            }
        }
    }

    private func drawZzz(_ ctx: GraphicsContext, time: Double) {
        for i in 0..<3 {
            let phase = (time * 0.35 + Double(i) / 3).truncatingRemainder(dividingBy: 1)
            let size = 10 + phase * 10
            let x = 166 + phase * 26 + sin(phase * 6) * 3
            let y = 66 - phase * 52
            ctx.draw(Text("Z").font(.system(size: size, weight: .heavy, design: .rounded))
                .foregroundStyle(Color(hex: 0x7A86C8).opacity(sin(phase * .pi))),
                     at: CGPoint(x: x, y: y))
        }
    }

    private func drawSpeedLines(_ ctx: GraphicsContext, time: Double) {
        for i in 0..<6 {
            let phase = (time * 3 + Double(i) * 0.37).truncatingRemainder(dividingBy: 1)
            let left = i.isMultiple(of: 2)
            let y = 60 + Double(i) * 18
            let x = left ? 40 - phase * 30 : 200 + phase * 30
            var line = Path()
            line.move(to: CGPoint(x: x, y: y))
            line.addLine(to: CGPoint(x: x + (left ? -22 : 22), y: y))
            ctx.stroke(line, with: .color(Color(hex: 0x9AA3C0).opacity(0.7 * (1 - phase))),
                       style: StrokeStyle(lineWidth: 2, lineCap: .round))
        }
    }

    private func heart(center c: CGPoint, size s: Double) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: c.x, y: c.y + s * 0.6))
        p.addCurve(to: CGPoint(x: c.x - s * 0.6, y: c.y - s * 0.2),
                   control1: CGPoint(x: c.x - s * 0.3, y: c.y + s * 0.35), control2: CGPoint(x: c.x - s * 0.6, y: c.y + s * 0.1))
        p.addArc(center: CGPoint(x: c.x - s * 0.3, y: c.y - s * 0.2), radius: s * 0.3,
                 startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        p.addArc(center: CGPoint(x: c.x + s * 0.3, y: c.y - s * 0.2), radius: s * 0.3,
                 startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        p.addCurve(to: CGPoint(x: c.x, y: c.y + s * 0.6),
                   control1: CGPoint(x: c.x + s * 0.6, y: c.y + s * 0.1), control2: CGPoint(x: c.x + s * 0.3, y: c.y + s * 0.35))
        p.closeSubpath()
        return p
    }
}
