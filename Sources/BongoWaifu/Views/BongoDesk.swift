import SwiftUI
import WaifuCore

private func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }
private let heartColor = Color(hex: 0xFF6F95)

/// The desk, keyboard, mug and tapping paws, in the 240x240 design space.
/// Shared by the vector characters and the Live2D overlay.
struct DeskPainter {
    var paw: PawState
    var lastTap: Date
    var now: Date
    var sleeping: Bool
    var accent: Color
    var sleeve: Color, sleeveShadow: Color, sleeveLine: Color, cuff: Color
    var skin: Color, skinShadow: Color, skinLine: Color
    /// Pink toe beans for cat paws; nil draws fingers instead.
    var pads: Color?
    var ink: Color

    var time: Double { now.timeIntervalSinceReferenceDate }

    func isDown(_ side: CGFloat) -> Bool {
        switch paw {
        case .both: return true
        case .left: return side < 0
        case .right: return side > 0
        case .up: return false
        }
    }

    func drawArm(_ ctx: GraphicsContext, side s: CGFloat, bodyOffset o: CGPoint, shoulderX: CGFloat = 33, shoulderY: CGFloat = 170) {
        let down = isDown(s)
        let shoulder = pt(120 + s * shoulderX + o.x, shoulderY + o.y)
        let paw = down ? pt(120 + s * 26, 205) : pt(120 + s * 48 + o.x, 183 + o.y)
        let dx = paw.x - shoulder.x, dy = paw.y - shoulder.y
        let len = max(hypot(dx, dy), 1)
        let wrist = pt(paw.x - dx / len * 7, paw.y - dy / len * 7)

        var arm = Path()
        arm.move(to: shoulder)
        arm.addLine(to: wrist)
        ctx.stroke(arm, with: .color(sleeveLine), style: StrokeStyle(lineWidth: 19, lineCap: .round))
        ctx.stroke(arm, with: .linearGradient(Gradient(colors: [sleeve, sleeveShadow]),
                                              startPoint: pt(shoulder.x - s * 6, shoulder.y), endPoint: pt(shoulder.x + s * 8, shoulder.y)),
                   style: StrokeStyle(lineWidth: 16.5, lineCap: .round))
        var band = Path()
        band.move(to: pt(wrist.x - dx / len * 3, wrist.y - dy / len * 3))
        band.addLine(to: wrist)
        ctx.stroke(band, with: .color(cuff), style: StrokeStyle(lineWidth: 16.5, lineCap: .butt))

        let size = down ? CGSize(width: 23, height: 15) : CGSize(width: 20, height: 18)
        let handRect = CGRect(x: paw.x - size.width / 2, y: paw.y - size.height / 2 + 1, width: size.width, height: size.height)
        let hand = Path(ellipseIn: handRect)
        ctx.fill(hand, with: .linearGradient(Gradient(colors: [skin, skinShadow]),
                                             startPoint: pt(paw.x, handRect.minY), endPoint: pt(paw.x, handRect.maxY)))
        ctx.stroke(hand, with: .color(skinLine.opacity(0.8)), lineWidth: 0.9)
        if let pads {
            ctx.fill(Path(ellipseIn: CGRect(x: paw.x - 3.6, y: paw.y, width: 7.2, height: 5.4)), with: .color(pads))
            for i in -1...1 {
                let bean = CGRect(x: paw.x + CGFloat(i) * 4.6 - 1.6, y: paw.y - 4.6 + abs(CGFloat(i)) * 1.2, width: 3.2, height: 3.2)
                ctx.fill(Path(ellipseIn: bean), with: .color(pads))
            }
        } else {
            for i in -1...1 {
                var finger = Path()
                let fx = paw.x + CGFloat(i) * 4.5
                finger.move(to: pt(fx, handRect.maxY - 1))
                finger.addLine(to: pt(fx, handRect.maxY - 4.5))
                ctx.stroke(finger, with: .color(skinLine.opacity(0.6)), style: StrokeStyle(lineWidth: 0.8, lineCap: .round))
            }
        }
        if down && now.timeIntervalSince(lastTap) < 0.12 {
            for i in 0..<3 {
                let angle = Double.pi * (1.15 + Double(i) * 0.35)
                var line = Path()
                line.move(to: pt(paw.x + CGFloat(cos(angle)) * 15, paw.y + CGFloat(sin(angle)) * 12))
                line.addLine(to: pt(paw.x + CGFloat(cos(angle)) * 21, paw.y + CGFloat(sin(angle)) * 17))
                ctx.stroke(line, with: .color(ink.opacity(0.45)), style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
            }
        }
    }

    func drawDesk(_ ctx: GraphicsContext) {
        ctx.fill(Path(CGRect(x: 0, y: 190, width: 240, height: 50)),
                 with: .linearGradient(Gradient(colors: [Color(hex: 0xEFD3AC), Color(hex: 0xCFA273)]),
                                       startPoint: pt(0, 190), endPoint: pt(0, 240)))
        for (y, x0, x1) in [(204.0, 6.0, 52.0), (226.0, 178.0, 236.0), (232.0, 20.0, 70.0)] as [(CGFloat, CGFloat, CGFloat)] {
            var grain = Path()
            grain.move(to: pt(x0, y))
            grain.addQuadCurve(to: pt(x1, y + 1), control: pt((x0 + x1) / 2, y - 2))
            ctx.stroke(grain, with: .color(Color(hex: 0xB98A5A).opacity(0.45)), lineWidth: 0.8)
        }
        var edge = Path()
        edge.move(to: pt(0, 190))
        edge.addLine(to: pt(240, 190))
        ctx.stroke(edge, with: .color(Color(hex: 0xFFF1DC)), lineWidth: 1.2)
        ctx.stroke(edge.offsetBy(dx: 0, dy: -1), with: .color(Color(hex: 0xB0814F)), lineWidth: 1)

        // Mechanical keyboard in slight perspective; keys under a lowered paw are pressed in.
        var board = Path()
        board.move(to: pt(68, 194))
        board.addLine(to: pt(172, 194))
        board.addLine(to: pt(178, 218))
        board.addLine(to: pt(62, 218))
        board.closeSubpath()
        ctx.fill(board.offsetBy(dx: 0, dy: 2), with: .color(.black.opacity(0.15)))
        ctx.fill(board, with: .linearGradient(Gradient(colors: [Color(hex: 0xF7F7FB), Color(hex: 0xDDDFE8)]),
                                              startPoint: pt(0, 194), endPoint: pt(0, 218)))
        ctx.stroke(board, with: .color(Color(hex: 0xA9ADBD)), style: StrokeStyle(lineWidth: 1, lineJoin: .round))
        let pressed = [-26.0, 26.0].filter { isDown($0) } as [CGFloat]
        for row in 0..<4 {
            let y = 196.5 + CGFloat(row) * 5.2
            let x0 = 68 - CGFloat(row) * 1.3, x1 = 172 + CGFloat(row) * 1.3
            let count = row == 3 ? 7 : 12
            let keyWidth = (x1 - x0 - 4) / CGFloat(count) - 1.2
            for i in 0..<count {
                let x = x0 + 2 + CGFloat(i) * (keyWidth + 1.2)
                let mid = x + keyWidth / 2 - 120
                let isPressed = row == 2 && pressed.contains { abs($0 - mid) < keyWidth }
                let accentKey = (row == 1 && i == count - 1) || (row == 3 && i == 3)
                let key = CGRect(x: x, y: y + (isPressed ? 0.8 : 0), width: keyWidth, height: 4)
                ctx.fill(Path(roundedRect: key.offsetBy(dx: 0, dy: 0.8), cornerRadius: 1), with: .color(Color(hex: 0xB9BCCB)))
                ctx.fill(Path(roundedRect: key, cornerRadius: 1),
                         with: .color(accentKey ? accent.opacity(0.85) : (isPressed ? Color(hex: 0xD3D6E2) : .white)))
            }
        }

        // Mug with steam.
        let mug = Path(roundedRect: CGRect(x: 192, y: 192, width: 20, height: 22), cornerRadius: 4)
        var handle = Path()
        handle.addArc(center: pt(212, 202), radius: 5, startAngle: .degrees(-80), endAngle: .degrees(80), clockwise: false)
        ctx.stroke(handle, with: .color(Color(hex: 0xF2F2F2)), lineWidth: 3)
        ctx.fill(mug, with: .linearGradient(Gradient(colors: [.white, Color(hex: 0xE2E2EA)]), startPoint: pt(192, 0), endPoint: pt(212, 0)))
        ctx.stroke(mug, with: .color(Color(hex: 0xBDBDC8)), lineWidth: 0.8)
        ctx.fill(heart(center: pt(202, 203), size: 8), with: .color(heartColor.opacity(0.8)))
        guard !sleeping else { return }
        for i in 0..<2 {
            let phase = (time * 0.6 + Double(i) * 0.5).truncatingRemainder(dividingBy: 1)
            var steam = Path()
            let sx = 198 + CGFloat(i) * 8
            let sy = 188 - CGFloat(phase) * 18
            steam.move(to: pt(sx, sy))
            steam.addQuadCurve(to: pt(sx, sy - 8), control: pt(sx + 4, sy - 4))
            ctx.stroke(steam, with: .color(.white.opacity(0.8 * (1 - phase))), lineWidth: 1.5)
        }
    }
}

/// Desk and paws drawn in front of a Live2D model, so it still plays the bongos.
struct BongoDeskView: View {
    let pose: VectorWaifuView.Pose
    let model: Live2DModelRef
    let accent: Color

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let scale = size.width / VectorWaifuView.designSize
                context.scaleBy(x: scale, y: scale)
                context.clip(to: Path(CGRect(x: 0, y: 0, width: VectorWaifuView.designSize, height: VectorWaifuView.designSize)))
                let painter = DeskPainter(
                    paw: pose.paw, lastTap: pose.lastTap, now: timeline.date, sleeping: pose.sleeping, accent: accent,
                    sleeve: model.sleeve, sleeveShadow: model.sleeve.adjusted(brightness: 0.82),
                    sleeveLine: model.sleeve.adjusted(saturation: 1.1, brightness: 0.55), cuff: accent,
                    skin: model.hand, skinShadow: model.hand.adjusted(saturation: 1.3, brightness: 0.93),
                    skinLine: model.hand.adjusted(hue: -0.02, saturation: 2.2, brightness: 0.6),
                    pads: model.catPaws ? Color(hex: 0xFFB7C5) : nil, ink: Color(hex: 0x2A1822))
                painter.drawDesk(context)
                // Forearms only: the model's own shoulders are wherever the artist drew them.
                painter.drawArm(context, side: -1, bodyOffset: .zero, shoulderX: 44, shoulderY: 180)
                painter.drawArm(context, side: 1, bodyOffset: .zero, shoulderX: 44, shoulderY: 180)
            }
        }
        .allowsHitTesting(false)
    }
}
