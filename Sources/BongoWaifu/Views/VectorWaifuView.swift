import AppKit
import SwiftUI
import WaifuCore

/// Draws a built-in character in a 240x240 design space, VTuber-style: layered cel-shaded art
/// driven by a `Rig` (eased parameters + hair physics) with parallax between depth layers.
struct VectorWaifuView: View {
    let look: Appearance
    let pose: Pose
    /// Live rig owned by the model; nil for static renders, which settle a fresh rig instead.
    var rig: Rig?

    struct Pose {
        var paw: PawState
        var expression: Mood
        var sleeping: Bool
        var tier: SpeedTier
        var lastTap: Date
        var talkingUntil: Date? = nil
    }

    static let designSize: CGFloat = 240

    var body: some View {
        let palette = Palette(look)
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let now = timeline.date
                let activeRig: Rig
                if let rig {
                    rig.update(pose: pose, now: now)
                    activeRig = rig
                } else {
                    activeRig = Rig()
                    activeRig.settle(pose: pose, now: now)
                }
                let scale = size.width / Self.designSize
                context.scaleBy(x: scale, y: scale)
                context.clip(to: Path(CGRect(x: 0, y: 0, width: Self.designSize, height: Self.designSize)))
                let painter = WaifuPainter(look: look, c: palette, pose: pose, rig: activeRig,
                                           time: now.timeIntervalSinceReferenceDate, now: now)
                painter.draw(in: context)
            }
        }
    }
}

// MARK: - Palette

/// Derived shading colors: anime cel shadows are darker, more saturated and hue-shifted, and line art
/// is a deep tint of the fill rather than black.
struct Palette {
    let skin, skinShadow, skinDeep, skinLine: Color
    let hair, hairShadow, hairDeep, hairLine, hairShine: Color
    let eye, eyeDeep, eyeLight, pupil, lash: Color
    let outfit, outfitShadow, outfitLine, accent, accentShadow: Color
    let accessory, accessoryShadow: Color

    init(_ a: Appearance) {
        skin = a.skin
        skinShadow = a.skinShade
        skinDeep = a.skinShade.adjusted(hue: -0.015, saturation: 1.25, brightness: 0.88)
        skinLine = a.skinShade.adjusted(hue: -0.02, saturation: 1.8, brightness: 0.62)
        hair = a.hair
        hairShadow = a.hairShade
        hairDeep = a.hairShade.adjusted(hue: 0.02, saturation: 1.15, brightness: 0.78)
        hairLine = a.hairShade.adjusted(hue: 0.02, saturation: 1.25, brightness: 0.55)
        hairShine = a.hairShine
        eye = a.eye
        eyeDeep = a.eyeDeep
        eyeLight = a.eye.adjusted(saturation: 0.75, brightness: 1.3)
        pupil = a.eyeDeep.adjusted(brightness: 0.45)
        lash = a.hairShade.adjusted(saturation: 0.9, brightness: 0.3).mixed(with: Color(hex: 0x2A1822), 0.6)
        outfit = a.outfit
        outfitShadow = a.outfitShade
        outfitLine = a.outfitShade.adjusted(saturation: 1.1, brightness: 0.6)
        accent = a.outfitAccent
        accentShadow = a.outfitAccent.adjusted(saturation: 1.1, brightness: 0.75)
        accessory = a.accessoryColor
        accessoryShadow = a.accessoryColor.adjusted(saturation: 1.1, brightness: 0.75)
    }
}

extension Color {
    func adjusted(hue dh: Double = 0, saturation ds: Double = 1, brightness db: Double = 1) -> Color {
        let ns = NSColor(self).usingColorSpace(.deviceRGB) ?? .gray
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, alpha: CGFloat = 0
        ns.getHue(&h, saturation: &s, brightness: &b, alpha: &alpha)
        let hue = ((h + dh).truncatingRemainder(dividingBy: 1) + 1).truncatingRemainder(dividingBy: 1)
        return Color(hue: hue, saturation: min(s * ds, 1), brightness: min(b * db, 1))
    }

    func mixed(with other: Color, _ t: Double) -> Color {
        let a = NSColor(self).usingColorSpace(.deviceRGB) ?? .gray
        let b = NSColor(other).usingColorSpace(.deviceRGB) ?? .gray
        return Color(red: a.redComponent + (b.redComponent - a.redComponent) * t,
                     green: a.greenComponent + (b.greenComponent - a.greenComponent) * t,
                     blue: a.blueComponent + (b.blueComponent - a.blueComponent) * t)
    }
}

// MARK: - Geometry helpers

private func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }

/// A tapered hair lock: wide at the root, pointed at the tip, bowed sideways by `bend`.
private func strandPath(_ root: CGPoint, _ tip: CGPoint, width w: CGFloat, bend: CGFloat) -> Path {
    let dx = tip.x - root.x, dy = tip.y - root.y
    let len = max(hypot(dx, dy), 0.01)
    let ux = dx / len, uy = dy / len
    let nx = -uy, ny = ux
    let mid = pt(root.x + dx * 0.5 + nx * bend, root.y + dy * 0.5 + ny * bend)
    var p = Path()
    p.move(to: pt(root.x + nx * w / 2, root.y + ny * w / 2))
    p.addQuadCurve(to: tip, control: pt(mid.x + nx * w * 0.42, mid.y + ny * w * 0.42))
    p.addQuadCurve(to: pt(root.x - nx * w / 2, root.y - ny * w / 2), control: pt(mid.x - nx * w * 0.42, mid.y - ny * w * 0.42))
    p.addQuadCurve(to: pt(root.x + nx * w / 2, root.y + ny * w / 2), control: pt(root.x - ux * w * 0.4, root.y - uy * w * 0.4))
    p.closeSubpath()
    return p
}

private let mouthDark = Color(hex: 0x4E1220)
private let mouthMid = Color(hex: 0x9A2E45)
private let tongueColor = Color(hex: 0xF27D93)
private let blushColor = Color(hex: 0xFF6F95)
private let toothColor = Color(hex: 0xFFFDFB)

// MARK: - Painter

private struct WaifuPainter {
    let look: Appearance
    let c: Palette
    let pose: VectorWaifuView.Pose
    let rig: Rig
    let time: Double
    let now: Date

    var ax: CGFloat { CGFloat(rig.angleX) }
    var ay: CGFloat { CGFloat(rig.angleY) }
    var sinceTap: Double { now.timeIntervalSince(pose.lastTap) }

    func draw(in base: GraphicsContext) {
        let breath = CGFloat(sin(time * 2.1))
        let bodyOffset = pt(CGFloat(rig.bodyX) * 3, breath * 0.9 + (pose.sleeping ? 2 : 0))
        var body = base
        body.translateBy(x: bodyOffset.x, y: bodyOffset.y)

        var head = body
        head.translateBy(x: 120 + ax * 3, y: 100 + ay * 3 + CGFloat(rig.tapDip) * 1.4)
        head.rotate(by: .radians(rig.angleZ))

        if look.accessories.contains(.tail) { drawTail(body) }
        if look.hairStyle == .twinTails {
            drawTwinTail(layer(head, -0.35), side: -1)
            drawTwinTail(layer(head, -0.35), side: 1)
        }
        drawBackHair(layer(head, -0.5))
        if look.outfitStyle == .hoodie || look.outfitStyle == .catHoodie { drawHood(body) }
        drawNeck(body)
        drawTorso(body)

        drawFace(layer(head, 0))
        drawBlush(layer(head, 0.45))
        drawEye(layer(head, 0.55), side: -1)
        drawEye(layer(head, 0.55), side: 1)
        drawNose(layer(head, 0.9))
        drawMouth(layer(head, 0.6))
        if look.accessories.contains(.catEars) { drawCatEars(layer(head, -0.1)) }
        drawSideLocks(layer(head, 0.15))
        drawCapAndBangs(layer(head, 0.3), bangs: layer(head, 0.75))
        drawBrow(layer(head, 0.6), side: -1)
        drawBrow(layer(head, 0.6), side: 1)
        drawAccessories(head)

        drawDesk(base)
        drawArm(base, side: -1, bodyOffset: bodyOffset)
        drawArm(base, side: 1, bodyOffset: bodyOffset)
    }

    /// Parallax: layers with more depth slide further with the head turn, which reads as 3D rotation.
    func layer(_ head: GraphicsContext, _ depth: CGFloat) -> GraphicsContext {
        var ctx = head
        ctx.translateBy(x: ax * depth * 8, y: ay * depth * 5)
        return ctx
    }

    func fillStrand(_ ctx: GraphicsContext, _ root: CGPoint, _ tip: CGPoint, width: CGFloat, bend: CGFloat,
                    top: Color? = nil, bottom: Color? = nil, texture: Bool = true) {
        let path = strandPath(root, tip, width: width, bend: bend)
        let topColor = top ?? c.hair
        ctx.fill(path, with: .linearGradient(Gradient(colors: [topColor, topColor, bottom ?? c.hairShadow]),
                                             startPoint: root, endPoint: tip))
        ctx.stroke(path, with: .color(c.hairLine.opacity(0.75)), lineWidth: 0.7)
        guard texture else { return }
        let dx = tip.x - root.x, dy = tip.y - root.y
        let len = max(hypot(dx, dy), 0.01)
        let nx = -dy / len, ny = dx / len
        var line = Path()
        line.move(to: pt(root.x + dx * 0.15 + nx * width * 0.12, root.y + dy * 0.15 + ny * width * 0.12))
        line.addQuadCurve(to: pt(root.x + dx * 0.72, root.y + dy * 0.72),
                          control: pt(root.x + dx * 0.45 + nx * bend * 0.6, root.y + dy * 0.45 + ny * bend * 0.6))
        ctx.stroke(line, with: .color(c.hairShadow.opacity(0.75)), style: StrokeStyle(lineWidth: 0.8, lineCap: .round))
    }

    // MARK: Hair

    func drawBackHair(_ ctx: GraphicsContext) {
        let sway = CGFloat(rig.hairBack.x) * 10
        func swayed(_ x: CGFloat, _ y: CGFloat) -> CGPoint { pt(x + sway * max(0, y) / 130, y) }

        let bottom: [CGPoint]
        let sideDepth: CGFloat
        switch look.hairStyle {
        case .long:
            sideDepth = 118
            bottom = [swayed(-50, 132), swayed(-42, 118), swayed(-28, 134), swayed(-16, 120), swayed(0, 136),
                      swayed(14, 120), swayed(28, 134), swayed(42, 118), swayed(52, 132)]
        case .bob:
            sideDepth = 40
            bottom = [swayed(-46, 58), swayed(-36, 46), swayed(-24, 56), swayed(0, 50), swayed(24, 56),
                      swayed(36, 46), swayed(46, 58)]
        case .twinTails:
            sideDepth = 26
            bottom = [swayed(-44, 40), swayed(-30, 30), swayed(0, 36), swayed(30, 30), swayed(44, 40)]
        case .fluffy:
            sideDepth = 34
            bottom = [swayed(-60, 48), swayed(-46, 40), swayed(-38, 54), swayed(-24, 42), swayed(0, 50),
                      swayed(24, 42), swayed(38, 54), swayed(46, 40), swayed(60, 48)]
        }
        let wide: CGFloat = look.hairStyle == .fluffy ? 58 : 55

        var p = Path()
        p.move(to: pt(0, -58))
        p.addCurve(to: pt(-wide, -6), control1: pt(-38, -60), control2: pt(-wide - 2, -36))
        p.addCurve(to: swayed(-wide - 3, sideDepth), control1: pt(-wide - 1, 20), control2: swayed(-wide - 4, sideDepth * 0.7))
        var previous = swayed(-wide - 3, sideDepth)
        for point in bottom {
            p.addQuadCurve(to: point, control: pt((previous.x + point.x) / 2, max(previous.y, point.y) - 6))
            previous = point
        }
        p.addQuadCurve(to: swayed(wide + 3, sideDepth), control: pt((previous.x + wide + 3) / 2, previous.y))
        p.addCurve(to: pt(wide, -6), control1: swayed(wide + 4, sideDepth * 0.7), control2: pt(wide + 1, 20))
        p.addCurve(to: pt(0, -58), control1: pt(wide + 2, -36), control2: pt(38, -60))
        p.closeSubpath()
        ctx.fill(p, with: .linearGradient(Gradient(colors: [c.hair.mixed(with: c.hairShadow, 0.45), c.hairShadow]),
                                          startPoint: pt(0, -40), endPoint: pt(0, sideDepth + 10)))
        ctx.stroke(p, with: .color(c.hairLine.opacity(0.55)), lineWidth: 0.9)

        if look.hairStyle == .long {
            for s in [-1.0, 1.0] as [CGFloat] {
                fillStrand(ctx, pt(s * 48, -10), swayed(s * 56, 112), width: 16, bend: -s * 5, top: c.hairShadow, bottom: c.hairDeep)
                fillStrand(ctx, pt(s * 40, 0), swayed(s * 44, 126), width: 12, bend: -s * 3, top: c.hairShadow, bottom: c.hairDeep)
            }
        }
    }

    func drawTwinTail(_ base: GraphicsContext, side s: CGFloat) {
        var ctx = base
        ctx.translateBy(x: s * 46, y: -44)
        // Mirrored for the left tail; gravity counters head roll, physics swings it.
        let swing = CGFloat(rig.hairBack.x) * 0.3 * s - CGFloat(rig.angleZ) * 0.8 * s
        ctx.scaleBy(x: s, y: 1)
        ctx.rotate(by: .radians(Double(-swing)))
        fillStrand(ctx, pt(2, -2), pt(30, 104), width: 24, bend: -12)
        fillStrand(ctx, pt(-2, 2), pt(14, 128), width: 30, bend: -13)
        fillStrand(ctx, pt(-4, 4), pt(2, 118), width: 18, bend: -6)
        fillStrand(ctx, pt(0, 6), pt(20, 120), width: 8, bend: -10, top: c.hairShadow, bottom: c.hairDeep, texture: false)
        var shine = Path()
        shine.move(to: pt(10, 18))
        shine.addQuadCurve(to: pt(20, 70), control: pt(24, 40))
        ctx.stroke(shine, with: .color(c.hairShine.opacity(0.7)), style: StrokeStyle(lineWidth: 3, lineCap: .round))
    }

    func drawSideLocks(_ ctx: GraphicsContext) {
        let sway = CGFloat(rig.hairSide.x) * 8
        let (outerTip, innerTip): (CGFloat, CGFloat) = {
            switch look.hairStyle {
            case .long: return (66, 50)
            case .bob: return (52, 40)
            case .twinTails: return (38, 28)
            case .fluffy: return (34, 24)
            }
        }()
        for s in [-1.0, 1.0] as [CGFloat] {
            fillStrand(ctx, pt(s * 41, -32), pt(s * 49 + sway, outerTip), width: 17, bend: -s * 5)
            fillStrand(ctx, pt(s * 37, -30), pt(s * 41 + sway * 0.8, innerTip), width: 9, bend: -s * 3)
            if look.hairStyle == .fluffy {
                fillStrand(ctx, pt(s * 46, 10), pt(s * 60 + sway, 22), width: 9, bend: s * 4)
            }
        }
    }

    typealias Lock = (root: CGPoint, tip: CGPoint, width: CGFloat, bend: CGFloat)

    var bangLocks: [Lock] {
        var locks: [Lock] = [
            (pt(-38, -32), pt(-44, 8), 12, 5), (pt(39, -32), pt(45, 8), 12, -5),
            (pt(-28, -40), pt(-31, -2), 14, 4), (pt(29, -40), pt(32, -1), 14, -4),
            (pt(-22, -42), pt(-23, -6), 7, 2), (pt(23, -42), pt(25, -5), 7, -2),
            (pt(-15, -45), pt(-16, -7), 14, 3), (pt(16, -45), pt(18, -6), 14, -3),
            (pt(-6, -47), pt(-4, -9), 14, 2), (pt(6, -47), pt(7, -10), 13, -2),
            (pt(-1, -45), pt(1, -3), 6, 0),
        ]
        switch look.hairStyle {
        case .bob:
            // Side-swept toward the clip.
            locks = locks.map { (pt($0.root.x - 4, $0.root.y), pt($0.tip.x + 9, $0.tip.y - 2), $0.width, $0.bend - 4) }
        case .fluffy:
            locks = locks.enumerated().map { i, l in
                (l.root, pt(l.tip.x, l.tip.y - 5), l.width + 1, l.bend + (i.isMultiple(of: 2) ? 5 : -5))
            }
        case .twinTails:
            locks = locks.map { ($0.root, $0.tip, $0.width * 0.92, $0.bend) }
        case .long:
            break
        }
        let sway = CGFloat(rig.hairFront.x) * 5
        return locks.map { l in
            let reach = (l.tip.y - l.root.y) / 50
            return (l.root, pt(l.tip.x + sway * reach, l.tip.y), l.width, l.bend + sway * 0.4)
        }
    }

    var capPath: Path {
        var p = Path()
        p.move(to: pt(-51, 4))
        p.addCurve(to: pt(0, -68), control1: pt(-55, -38), control2: pt(-32, -68))
        p.addCurve(to: pt(51, 4), control1: pt(32, -68), control2: pt(55, -38))
        p.addLine(to: pt(42, -24))
        p.addQuadCurve(to: pt(-42, -24), control: pt(0, -42))
        p.closeSubpath()
        return p
    }

    func drawCapAndBangs(_ cap: GraphicsContext, bangs: GraphicsContext) {
        cap.fill(capPath, with: .linearGradient(Gradient(colors: [c.hair, c.hairShadow]),
                                                startPoint: pt(0, -66), endPoint: pt(0, 0)))
        cap.stroke(capPath, with: .color(c.hairLine), lineWidth: 1)

        if look.accessories.contains(.ahoge) { drawAhoge(cap) }

        for lock in bangLocks {
            fillStrand(bangs, lock.root, lock.tip, width: lock.width, bend: lock.bend)
        }

        // Angel-ring highlight across the crown.
        var ring = Path()
        ring.move(to: pt(-40, -38))
        ring.addQuadCurve(to: pt(40, -38), control: pt(0, -62))
        let jag: [CGPoint] = [pt(35, -35), pt(29, -30), pt(23, -36), pt(15, -31), pt(7, -37), pt(-1, -31),
                              pt(-9, -37), pt(-17, -31), pt(-25, -36), pt(-33, -32)]
        for point in jag { ring.addLine(to: point) }
        ring.closeSubpath()
        cap.fill(ring, with: .linearGradient(Gradient(colors: [c.hairShine.opacity(0.95), c.hairShine.opacity(0.35)]),
                                             startPoint: pt(0, -50), endPoint: pt(0, -30)))
    }

    func drawAhoge(_ ctx: GraphicsContext) {
        var a = ctx
        a.translateBy(x: -3, y: -64)
        a.rotate(by: .radians(rig.ahoge.x * 0.35 + sin(time * 2.2) * 0.05))
        fillStrand(a, pt(0, 2), pt(18, -30), width: 8, bend: -8, texture: false)
        fillStrand(a, pt(2, 2), pt(-8, -20), width: 5, bend: 5, texture: false)
    }

    func drawCatEars(_ ctx: GraphicsContext) {
        for s in [-1.0, 1.0] as [CGFloat] {
            var ear = ctx
            ear.translateBy(x: s * 30, y: -46)
            let twitch = CGFloat(rig.ears.x) * (s < 0 ? 0.25 : 0.08)
            ear.rotate(by: .radians(Double(-s * twitch)))
            ear.scaleBy(x: s, y: 1)
            // Drawn as the right ear around its base, mirrored for the left.
            var outer = Path()
            outer.move(to: pt(-18, -10))
            outer.addQuadCurve(to: pt(10, -42), control: pt(-8, -34))
            outer.addQuadCurve(to: pt(19, 12), control: pt(22, -16))
            outer.closeSubpath()
            ear.fill(outer, with: .linearGradient(Gradient(colors: [c.hair, c.hairShadow]),
                                                  startPoint: pt(0, -40), endPoint: pt(0, 10)))
            ear.stroke(outer, with: .color(c.hairLine), style: StrokeStyle(lineWidth: 1, lineJoin: .round))
            var inner = Path()
            inner.move(to: pt(-11, -8))
            inner.addQuadCurve(to: pt(8, -34), control: pt(-3, -28))
            inner.addQuadCurve(to: pt(13, 4), control: pt(16, -14))
            inner.closeSubpath()
            ear.fill(inner, with: .linearGradient(Gradient(colors: [c.accessory.adjusted(brightness: 1.1), c.accessoryShadow]),
                                                  startPoint: pt(0, -30), endPoint: pt(0, 4)))
            for (root, tip) in [(pt(0, 2), pt(4, -22)), (pt(5, 2), pt(10, -16)), (pt(-4, 0), pt(-1, -14))] {
                ear.fill(strandPath(root, tip, width: 4, bend: 1), with: .color(.white.opacity(0.85)))
            }
        }
    }

    // MARK: Face

    var faceOutline: Path {
        let chin = ax * 6
        let l = -46 + ax * 2, r = 46 + ax * 2
        var p = Path()
        p.move(to: pt(l, -30))
        p.addCurve(to: pt(l + 1, 14), control1: pt(l - 1, -12), control2: pt(l - 1, 2))
        p.addCurve(to: pt(chin, 50), control1: pt(l + 4, 32), control2: pt(chin - 15, 47))
        p.addCurve(to: pt(r - 1, 14), control1: pt(chin + 15, 47), control2: pt(r - 4, 32))
        p.addCurve(to: pt(r, -30), control1: pt(r + 1, 2), control2: pt(r + 1, -12))
        p.addCurve(to: pt(l, -30), control1: pt(r, -64), control2: pt(l, -64))
        p.closeSubpath()
        return p
    }

    func drawFace(_ ctx: GraphicsContext) {
        let face = faceOutline
        ctx.fill(face, with: .linearGradient(Gradient(colors: [c.skin, c.skin, c.skinShadow.mixed(with: c.skin, 0.5)]),
                                             startPoint: pt(0, -20), endPoint: pt(0, 50)))
        var inside = ctx
        inside.clip(to: face)
        // Soft inner rim shading, heavier on the side away from the light.
        inside.stroke(face, with: .color(c.skinShadow.opacity(0.45)), lineWidth: 7)
        inside.fill(Path(ellipseIn: CGRect(x: 26 + ax * 4, y: -20, width: 40, height: 80)), with: .color(c.skinShadow.opacity(0.35)))
        // Shadow cast by the bangs: the same locks, nudged down.
        var shadow = inside
        shadow.translateBy(x: ax * 2.5 + 1, y: ay * 2 + 5)
        for lock in bangLocks {
            shadow.fill(strandPath(lock.root, lock.tip, width: lock.width, bend: lock.bend), with: .color(c.skinShadow.opacity(0.55)))
        }
        shadow.fill(capPath, with: .color(c.skinShadow.opacity(0.55)))
        ctx.stroke(face, with: .color(c.skinLine.opacity(0.8)), lineWidth: 1)
    }

    func drawBlush(_ ctx: GraphicsContext) {
        let amount = CGFloat(rig.blush)
        for s in [-1.0, 1.0] as [CGFloat] {
            let center = pt(s * 27, 21)
            var b = ctx
            b.translateBy(x: center.x, y: center.y)
            b.scaleBy(x: 1, y: 0.5)
            b.fill(Path(ellipseIn: CGRect(x: -14, y: -14, width: 28, height: 28)),
                   with: .radialGradient(Gradient(colors: [blushColor.opacity(0.75 * amount), blushColor.opacity(0)]),
                                         center: .zero, startRadius: 0, endRadius: 14))
            guard amount > 0.6 else { continue }
            for i in 0..<3 {
                var hatch = Path()
                let x = center.x - 6 + CGFloat(i) * 5
                hatch.move(to: pt(x + 2.5, center.y - 3))
                hatch.addLine(to: pt(x - 1, center.y + 3))
                ctx.stroke(hatch, with: .color(blushColor.opacity(Double(amount - 0.4))),
                           style: StrokeStyle(lineWidth: 1.1, lineCap: .round))
            }
        }
    }

    // MARK: Eyes

    func drawEye(_ base: GraphicsContext, side s: CGFloat) {
        var ctx = base
        ctx.translateBy(x: s * 20, y: 6)
        // The eye on the far side of the turn foreshortens.
        ctx.scaleBy(x: 1 - 0.22 * max(0, s * ax), y: 1)

        let open = CGFloat(rig.eyeOpen) * CGFloat(1 - rig.blink)
        if rig.eyeSmile > 0.5 { return drawSmileEye(ctx, side: s) }
        if open < 0.12 { return drawClosedEye(ctx, side: s) }

        // Corners stay put; the upper lid arch scales with openness and its inner end drops when angry.
        let inner = pt(-s * 12, 2), outer = pt(s * 13, -2)
        let apex = 10 - 25 * open
        let tilt = CGFloat(rig.lidTilt) * 5 * min(open, 1)
        let c1 = pt(-s * 8, apex + 1 + tilt), c2 = pt(s * 8, apex - 1)
        var shape = Path()
        shape.move(to: inner)
        shape.addCurve(to: outer, control1: c1, control2: c2)
        shape.addCurve(to: inner, control1: pt(s * 10, 13), control2: pt(-s * 8, 12.5))
        shape.closeSubpath()

        var eye = ctx
        eye.clip(to: shape)
        eye.fill(shape, with: .linearGradient(Gradient(colors: [Color(hex: 0xD6CFE6), .white, .white]),
                                              startPoint: pt(0, apex), endPoint: pt(0, 12)))
        let irisScale = CGFloat(rig.irisScale)
        let iw = 19 * irisScale, ih = 24 * irisScale
        let center = pt(CGFloat(rig.eyeBallX) * 3, 2.5 + CGFloat(rig.eyeBallY) * 2.2)
        let iris = CGRect(x: center.x - iw / 2, y: center.y - ih / 2, width: iw, height: ih)
        eye.fill(Path(ellipseIn: iris), with: .linearGradient(Gradient(colors: [c.eyeDeep, c.eye, c.eyeLight]),
                                                             startPoint: pt(0, iris.minY + 2), endPoint: pt(0, iris.maxY)))
        eye.stroke(Path(ellipseIn: iris.insetBy(dx: 0.6, dy: 0.6)), with: .color(c.eyeDeep), lineWidth: 1.3)
        for i in 0..<7 {
            let a = Double.pi * (0.15 + Double(i) * 0.12)
            var spoke = Path()
            spoke.move(to: pt(center.x + CGFloat(cos(a)) * iw * 0.2, center.y + CGFloat(sin(a)) * ih * 0.2))
            spoke.addLine(to: pt(center.x + CGFloat(cos(a)) * iw * 0.45, center.y + CGFloat(sin(a)) * ih * 0.45))
            eye.stroke(spoke, with: .color(c.eyeLight.opacity(0.35)), lineWidth: 0.7)
        }
        let pupil = CGRect(x: center.x - iw * 0.2, y: center.y - ih * 0.26, width: iw * 0.4, height: ih * 0.46)
        eye.fill(Path(ellipseIn: pupil), with: .linearGradient(Gradient(colors: [c.pupil, c.eyeDeep]),
                                                              startPoint: pt(0, pupil.minY), endPoint: pt(0, pupil.maxY)))
        eye.fill(Path(ellipseIn: iris.insetBy(dx: 2, dy: 2)),
                 with: .radialGradient(Gradient(colors: [c.eyeLight.opacity(0.85), c.eyeLight.opacity(0)]),
                                       center: pt(center.x, iris.maxY - 3), startRadius: 0, endRadius: iw * 0.55))
        // Shadow from the upper lid and lashes.
        eye.fill(shape, with: .linearGradient(Gradient(colors: [c.lash.opacity(0.55), c.lash.opacity(0)]),
                                              startPoint: pt(0, apex - 1), endPoint: pt(0, apex + 8)))
        // Catchlights sit on the same side in both eyes (one light source).
        eye.fill(Path(ellipseIn: CGRect(x: center.x + 1.5, y: iris.minY + 3.5, width: 6, height: 7.5)), with: .color(.white))
        eye.fill(Path(ellipseIn: CGRect(x: center.x - 5.5, y: iris.maxY - 8, width: 3.2, height: 3.2)), with: .color(.white.opacity(0.9)))
        eye.fill(Path(ellipseIn: CGRect(x: center.x + 6, y: center.y + 2, width: 1.6, height: 1.6)), with: .color(.white.opacity(0.8)))
        if pose.expression == .excited && !pose.sleeping {
            eye.fill(sparkle(center: pt(center.x - 2, center.y + 3), radius: 5.5), with: .color(.white))
        }

        // Upper lash line: thin at the inner corner, heavy at the outer one, finished with a wing.
        var lash = Path()
        lash.move(to: inner)
        lash.addCurve(to: outer, control1: c1, control2: c2)
        lash.addLine(to: pt(s * 18, -7))
        lash.addLine(to: pt(s * 14, -5.5))
        lash.addCurve(to: pt(-s * 12.5, 0.6), control1: pt(s * 8, apex - 4.5), control2: pt(-s * 8, apex - 1.5 + tilt))
        lash.closeSubpath()
        ctx.fill(lash, with: .color(c.lash))
        for (from, to) in [(pt(s * 9, apex - 2), pt(s * 15, apex - 6)), (pt(s * 12, apex), pt(s * 17.5, apex - 2.5))] {
            var spike = Path()
            spike.move(to: from)
            spike.addLine(to: to)
            ctx.stroke(spike, with: .color(c.lash), style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
        }
        var lower = Path()
        lower.move(to: pt(s * 12.5, 1))
        lower.addQuadCurve(to: pt(s * 1, 12.8), control: pt(s * 10, 12))
        ctx.stroke(lower, with: .color(c.lash.opacity(0.6)), style: StrokeStyle(lineWidth: 0.9, lineCap: .round))
        if open > 0.6 {
            var crease = Path()
            crease.move(to: pt(-s * 5, apex - 4))
            crease.addQuadCurve(to: pt(s * 11, apex - 3), control: pt(s * 3, apex - 7.5))
            ctx.stroke(crease, with: .color(c.skinLine.opacity(0.5)), style: StrokeStyle(lineWidth: 0.8, lineCap: .round))
        }
    }

    func drawClosedEye(_ ctx: GraphicsContext, side s: CGFloat) {
        var p = Path()
        p.move(to: pt(-s * 12, 5))
        p.addQuadCurve(to: pt(s * 13, 4), control: pt(s * 1, 12))
        p.addQuadCurve(to: pt(-s * 12, 4.2), control: pt(s * 1, 9))
        p.closeSubpath()
        ctx.fill(p, with: .color(c.lash))
        for i in 0..<2 {
            var flick = Path()
            let x = s * (8 + CGFloat(i) * 4)
            flick.move(to: pt(x, 7.5 - CGFloat(i) * 1.6))
            flick.addLine(to: pt(x + s * 2.5, 10.5 - CGFloat(i) * 1.6))
            ctx.stroke(flick, with: .color(c.lash), style: StrokeStyle(lineWidth: 1.1, lineCap: .round))
        }
    }

    func drawSmileEye(_ ctx: GraphicsContext, side s: CGFloat) {
        var p = Path()
        p.move(to: pt(-s * 12, 7))
        p.addQuadCurve(to: pt(s * 13, 6), control: pt(0, -10))
        p.addQuadCurve(to: pt(-s * 12, 7), control: pt(0, -6.5))
        p.closeSubpath()
        ctx.fill(p, with: .color(c.lash))
        var flick = Path()
        flick.move(to: pt(s * 12, 5))
        flick.addLine(to: pt(s * 16, 2.5))
        ctx.stroke(flick, with: .color(c.lash), style: StrokeStyle(lineWidth: 1.3, lineCap: .round))
    }

    func drawBrow(_ ctx: GraphicsContext, side s: CGFloat) {
        let raise = s > 0 ? CGFloat(rig.browRaiseRight) * -4 : 0
        let angle = CGFloat(rig.browAngle)
        let y = -17 + CGFloat(rig.browY) + raise
        let inner = pt(s * 11, y + angle * 5)
        let outer = pt(s * 29, y - 1 - angle * 2)
        var p = Path()
        p.move(to: inner)
        p.addQuadCurve(to: outer, control: pt(s * 20, y - 3.5))
        p.addQuadCurve(to: pt(inner.x, inner.y - 2.2), control: pt(s * 19, y - 5))
        p.closeSubpath()
        ctx.fill(p, with: .color(c.hairLine.opacity(0.85)))
    }

    func drawNose(_ ctx: GraphicsContext) {
        var nose = Path()
        nose.move(to: pt(1.8, 19))
        nose.addQuadCurve(to: pt(0.4, 23), control: pt(2, 21.5))
        ctx.stroke(nose, with: .color(c.skinLine.opacity(0.55)), style: StrokeStyle(lineWidth: 1, lineCap: .round))
        ctx.fill(Path(ellipseIn: CGRect(x: -2.2, y: 19.5, width: 1.8, height: 1.4)), with: .color(.white.opacity(0.7)))
    }

    // MARK: Mouth

    func drawMouth(_ base: GraphicsContext) {
        var ctx = base
        ctx.translateBy(x: ax * 1.5, y: 33)
        let open = CGFloat(rig.mouthOpen)
        let form = CGFloat(rig.mouthForm)
        let halfWidth = (5 + 2.5 * max(form, 0)) * CGFloat(rig.mouthWidth)
        let cornerY = -form * 1.8
        let catMouth = look.accessories.contains(.catEars) && form > 0.3

        if open < 0.07 {
            var line = Path()
            if catMouth {
                line.move(to: pt(-halfWidth - 1, cornerY))
                line.addQuadCurve(to: pt(0, 0), control: pt(-halfWidth / 2, 3.5))
                line.addQuadCurve(to: pt(halfWidth + 1, cornerY), control: pt(halfWidth / 2, 3.5))
            } else {
                line.move(to: pt(-halfWidth, cornerY))
                line.addQuadCurve(to: pt(halfWidth, cornerY), control: pt(0, form * 3.5))
            }
            ctx.stroke(line, with: .color(c.skinLine), style: StrokeStyle(lineWidth: 1.3, lineCap: .round, lineJoin: .round))
            if look.fang && form > 0.2 { drawFang(ctx, at: pt(halfWidth * 0.4, form * 1.2)) }
            return
        }

        let depth = 2 + open * 11
        var shape = Path()
        shape.move(to: pt(-halfWidth, cornerY))
        if catMouth {
            shape.addQuadCurve(to: pt(0, 0.8), control: pt(-halfWidth / 2, -1))
            shape.addQuadCurve(to: pt(halfWidth, cornerY), control: pt(halfWidth / 2, -1))
        } else {
            shape.addQuadCurve(to: pt(halfWidth, cornerY), control: pt(0, -1))
        }
        shape.addCurve(to: pt(-halfWidth, cornerY), control1: pt(halfWidth * 0.65, depth), control2: pt(-halfWidth * 0.65, depth))
        shape.closeSubpath()
        ctx.fill(shape, with: .linearGradient(Gradient(colors: [mouthDark, mouthMid]),
                                              startPoint: pt(0, 0), endPoint: pt(0, depth)))
        var inner = ctx
        inner.clip(to: shape)
        inner.fill(Path(ellipseIn: CGRect(x: -halfWidth * 0.7, y: depth * 0.45, width: halfWidth * 1.4, height: depth * 0.8)),
                   with: .linearGradient(Gradient(colors: [tongueColor, tongueColor.adjusted(brightness: 0.85)]),
                                         startPoint: pt(0, depth * 0.45), endPoint: pt(0, depth)))
        if open > 0.25 {
            inner.fill(Path(ellipseIn: CGRect(x: -halfWidth * 0.85, y: -2.5, width: halfWidth * 1.7, height: 4.2)), with: .color(toothColor))
        }
        ctx.stroke(shape, with: .color(c.skinLine.opacity(0.9)), style: StrokeStyle(lineWidth: 1, lineJoin: .round))
        if look.fang { drawFang(ctx, at: pt(halfWidth * 0.45, 0)) }
    }

    func drawFang(_ ctx: GraphicsContext, at p: CGPoint) {
        var fang = Path()
        fang.move(to: pt(p.x - 1.6, p.y - 0.3))
        fang.addLine(to: pt(p.x + 1.6, p.y - 0.3))
        fang.addLine(to: pt(p.x + 0.2, p.y + 3))
        fang.closeSubpath()
        ctx.fill(fang, with: .color(toothColor))
        ctx.stroke(fang, with: .color(c.skinLine.opacity(0.8)), style: StrokeStyle(lineWidth: 0.6, lineJoin: .round))
    }

    // MARK: Body

    func drawHood(_ ctx: GraphicsContext) {
        let hood = Path(roundedRect: CGRect(x: 78, y: 142, width: 84, height: 32), cornerRadius: 16)
        ctx.fill(hood, with: .linearGradient(Gradient(colors: [c.outfitShadow, c.outfit]),
                                             startPoint: pt(0, 142), endPoint: pt(0, 174)))
        ctx.stroke(hood, with: .color(c.outfitLine), lineWidth: 1)
        ctx.fill(Path(roundedRect: CGRect(x: 92, y: 148, width: 56, height: 16), cornerRadius: 8),
                 with: .color(c.outfitShadow.adjusted(brightness: 0.75)))
    }

    func drawNeck(_ ctx: GraphicsContext) {
        var neck = Path()
        neck.move(to: pt(111.5, 128))
        neck.addLine(to: pt(128.5, 128))
        neck.addLine(to: pt(128, 164))
        neck.addQuadCurve(to: pt(112, 164), control: pt(120, 168))
        neck.closeSubpath()
        ctx.fill(neck, with: .color(c.skin))
        var shaded = ctx
        shaded.clip(to: neck)
        shaded.fill(Path(CGRect(x: 100, y: 128, width: 40, height: 26)),
                    with: .linearGradient(Gradient(colors: [c.skinDeep, c.skinShadow.opacity(0)]),
                                          startPoint: pt(0, 140), endPoint: pt(0, 158)))
        ctx.stroke(neck, with: .color(c.skinLine.opacity(0.5)), lineWidth: 0.8)
    }

    var torsoPath: Path {
        var p = Path()
        p.move(to: pt(58, 240))
        p.addLine(to: pt(62, 196))
        p.addCurve(to: pt(100, 160), control1: pt(63, 176), control2: pt(80, 163))
        p.addLine(to: pt(140, 160))
        p.addCurve(to: pt(178, 196), control1: pt(160, 163), control2: pt(177, 176))
        p.addLine(to: pt(182, 240))
        p.closeSubpath()
        return p
    }

    func drawTorso(_ ctx: GraphicsContext) {
        let torso = torsoPath
        ctx.fill(torso, with: .linearGradient(Gradient(colors: [c.outfit, c.outfitShadow]),
                                              startPoint: pt(0, 165), endPoint: pt(0, 235)))
        var inside = ctx
        inside.clip(to: torso)
        inside.fill(Path(ellipseIn: CGRect(x: 146, y: 160, width: 60, height: 100)), with: .color(c.outfitShadow.opacity(0.55)))
        inside.fill(Path(ellipseIn: CGRect(x: 100, y: 152, width: 40, height: 16)), with: .color(c.outfitShadow.opacity(0.7)))

        switch look.outfitStyle {
        case .sailor: drawSailor(ctx)
        case .sweater: drawCardigan(ctx)
        case .hoodie, .catHoodie: drawHoodieFront(ctx)
        }
        ctx.stroke(torso, with: .color(c.outfitLine), lineWidth: 1)
    }

    func drawSailor(_ ctx: GraphicsContext) {
        var skinV = Path()
        skinV.move(to: pt(106, 159))
        skinV.addLine(to: pt(120, 178))
        skinV.addLine(to: pt(134, 159))
        skinV.closeSubpath()
        ctx.fill(skinV, with: .linearGradient(Gradient(colors: [c.skinDeep, c.skin]), startPoint: pt(0, 159), endPoint: pt(0, 176)))

        var collar = Path()
        collar.move(to: pt(84, 161))
        collar.addLine(to: pt(120, 206))
        collar.addLine(to: pt(156, 161))
        collar.addLine(to: pt(137, 158))
        collar.addLine(to: pt(120, 184))
        collar.addLine(to: pt(103, 158))
        collar.closeSubpath()
        ctx.fill(collar, with: .linearGradient(Gradient(colors: [c.accent.adjusted(brightness: 1.25), c.accent]),
                                               startPoint: pt(0, 160), endPoint: pt(0, 205)))
        ctx.stroke(collar, with: .color(c.accentShadow), lineWidth: 0.8)
        for inset in [3.5, 6.0] as [CGFloat] {
            var stripe = Path()
            stripe.move(to: pt(84 + inset * 1.4, 162))
            stripe.addLine(to: pt(120, 206 - inset * 1.8))
            stripe.addLine(to: pt(156 - inset * 1.4, 162))
            ctx.stroke(stripe, with: .color(.white.opacity(0.9)), lineWidth: 0.9)
        }
        drawBow(ctx, at: pt(120, 194), size: 12, color: Color(hex: 0xE23B57), tails: true)
    }

    func drawCardigan(_ ctx: GraphicsContext) {
        var blouse = Path()
        blouse.move(to: pt(100, 159))
        blouse.addLine(to: pt(120, 204))
        blouse.addLine(to: pt(140, 159))
        blouse.closeSubpath()
        ctx.fill(blouse, with: .linearGradient(Gradient(colors: [c.accent.adjusted(brightness: 0.88), c.accent]),
                                               startPoint: pt(0, 159), endPoint: pt(0, 200)))
        ctx.stroke(blouse, with: .color(c.outfitLine), lineWidth: 1.2)
        for s in [-1.0, 1.0] as [CGFloat] {
            var point = Path()
            point.move(to: pt(120 + s * 2, 162))
            point.addLine(to: pt(120 + s * 16, 158))
            point.addLine(to: pt(120 + s * 9, 172))
            point.closeSubpath()
            ctx.fill(point, with: .color(.white))
            ctx.stroke(point, with: .color(c.outfitShadow.opacity(0.6)), lineWidth: 0.7)
        }
        drawBow(ctx, at: pt(120, 171), size: 6, color: c.eye, tails: false)
        for y in [212.0, 228.0] as [CGFloat] {
            ctx.fill(Path(ellipseIn: CGRect(x: 124, y: y, width: 5, height: 5)), with: .color(Color(hex: 0xE8C76A)))
        }
    }

    func drawHoodieFront(_ ctx: GraphicsContext) {
        var neckline = Path()
        neckline.move(to: pt(103, 160))
        neckline.addQuadCurve(to: pt(137, 160), control: pt(120, 172))
        ctx.stroke(neckline, with: .color(c.accent), lineWidth: 2.2)
        for s in [-1.0, 1.0] as [CGFloat] {
            var string = Path()
            string.move(to: pt(120 + s * 9, 166))
            string.addQuadCurve(to: pt(120 + s * 11, 194), control: pt(120 + s * 7, 182))
            ctx.stroke(string, with: .color(c.accent), style: StrokeStyle(lineWidth: 2, lineCap: .round))
            ctx.fill(Path(roundedRect: CGRect(x: 120 + s * 11 - 2, y: 192, width: 4, height: 7), cornerRadius: 1.5),
                     with: .color(Color(hex: 0xC9CDD8)))
        }
        if look.outfitStyle == .catHoodie {
            let center = pt(146, 190)
            ctx.fill(Path(ellipseIn: CGRect(x: center.x - 6, y: center.y - 3, width: 12, height: 10)), with: .color(.white.opacity(0.9)))
            for (dx, dy) in [(-7.0, -7.0), (0.0, -10.0), (7.0, -7.0)] as [(CGFloat, CGFloat)] {
                ctx.fill(Path(ellipseIn: CGRect(x: center.x + dx - 2.6, y: center.y + dy - 2.6, width: 5.2, height: 5.2)),
                         with: .color(.white.opacity(0.9)))
            }
        } else {
            let star = sparkle(center: pt(148, 186), radius: 6, points: 5, inner: 0.45)
            ctx.fill(star, with: .color(c.accent))
            ctx.stroke(star, with: .color(c.accentShadow), lineWidth: 0.7)
        }
    }

    func drawBow(_ ctx: GraphicsContext, at center: CGPoint, size s: CGFloat, color: Color, tails: Bool) {
        let shade = color.adjusted(saturation: 1.1, brightness: 0.72)
        if tails {
            for side in [-1.0, 1.0] as [CGFloat] {
                let tail = strandPath(pt(center.x + side * 2, center.y + 2), pt(center.x + side * 8, center.y + s * 1.7),
                                      width: s * 0.55, bend: side * 1.5)
                ctx.fill(tail, with: .linearGradient(Gradient(colors: [color, shade]), startPoint: center,
                                                     endPoint: pt(center.x, center.y + s * 1.7)))
                ctx.stroke(tail, with: .color(shade), lineWidth: 0.6)
            }
        }
        for side in [-1.0, 1.0] as [CGFloat] {
            var loop = Path()
            loop.move(to: center)
            loop.addCurve(to: pt(center.x + side * s * 1.25, center.y + s * 0.45),
                          control1: pt(center.x + side * s * 0.3, center.y - s * 0.9),
                          control2: pt(center.x + side * s * 1.35, center.y - s * 0.75))
            loop.addQuadCurve(to: center, control: pt(center.x + side * s * 0.6, center.y + s * 0.6))
            loop.closeSubpath()
            ctx.fill(loop, with: .linearGradient(Gradient(colors: [color.adjusted(brightness: 1.15), color, shade]),
                                                 startPoint: pt(center.x, center.y - s), endPoint: pt(center.x, center.y + s * 0.6)))
            ctx.stroke(loop, with: .color(shade), style: StrokeStyle(lineWidth: 0.7, lineJoin: .round))
            var fold = Path()
            fold.move(to: pt(center.x + side * s * 0.25, center.y - s * 0.1))
            fold.addQuadCurve(to: pt(center.x + side * s * 0.9, center.y + s * 0.05), control: pt(center.x + side * s * 0.6, center.y - s * 0.35))
            ctx.stroke(fold, with: .color(shade.opacity(0.8)), lineWidth: 0.7)
        }
        let knot = Path(roundedRect: CGRect(x: center.x - s * 0.3, y: center.y - s * 0.35, width: s * 0.6, height: s * 0.7), cornerRadius: s * 0.2)
        ctx.fill(knot, with: .color(color))
        ctx.stroke(knot, with: .color(shade), lineWidth: 0.7)
    }

    func drawTail(_ ctx: GraphicsContext) {
        let sway = CGFloat(rig.tail.x) * 14
        var p = Path()
        p.move(to: pt(156, 206))
        p.addCurve(to: pt(198 + sway * 1.6, 112), control1: pt(196 + sway * 0.4, 200), control2: pt(212 + sway, 150))
        ctx.stroke(p, with: .color(c.hairLine), style: StrokeStyle(lineWidth: 16, lineCap: .round))
        ctx.stroke(p, with: .linearGradient(Gradient(colors: [c.hairShadow, c.hair]), startPoint: pt(160, 200), endPoint: pt(200, 120)),
                   style: StrokeStyle(lineWidth: 13.5, lineCap: .round))
        ctx.stroke(p.trimmedPath(from: 0.82, to: 1), with: .color(c.hairShine), style: StrokeStyle(lineWidth: 13.5, lineCap: .round))
        ctx.stroke(p.trimmedPath(from: 0.3, to: 0.75).offsetBy(dx: -2.5, dy: 0), with: .color(c.hairShine.opacity(0.55)),
                   style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
    }

    func drawArm(_ ctx: GraphicsContext, side s: CGFloat, bodyOffset o: CGPoint) {
        let down: Bool = {
            switch pose.paw {
            case .both: return true
            case .left: return s < 0
            case .right: return s > 0
            case .up: return false
            }
        }()
        let shoulder = pt(120 + s * 33 + o.x, 170 + o.y)
        let paw = down ? pt(120 + s * 26, 205) : pt(120 + s * 48 + o.x, 183 + o.y)
        let dx = paw.x - shoulder.x, dy = paw.y - shoulder.y
        let len = max(hypot(dx, dy), 1)
        let wrist = pt(paw.x - dx / len * 7, paw.y - dy / len * 7)

        var sleeve = Path()
        sleeve.move(to: shoulder)
        sleeve.addLine(to: wrist)
        ctx.stroke(sleeve, with: .color(c.outfitLine), style: StrokeStyle(lineWidth: 19, lineCap: .round))
        ctx.stroke(sleeve, with: .linearGradient(Gradient(colors: [c.outfit, c.outfitShadow]),
                                                 startPoint: pt(shoulder.x - s * 6, shoulder.y), endPoint: pt(shoulder.x + s * 8, shoulder.y)),
                   style: StrokeStyle(lineWidth: 16.5, lineCap: .round))
        var cuff = Path()
        cuff.move(to: pt(wrist.x - dx / len * 3, wrist.y - dy / len * 3))
        cuff.addLine(to: wrist)
        ctx.stroke(cuff, with: .color(look.outfitStyle == .sweater ? c.outfitShadow : c.accent),
                   style: StrokeStyle(lineWidth: 16.5, lineCap: .butt))

        let size = down ? CGSize(width: 23, height: 15) : CGSize(width: 20, height: 18)
        let handRect = CGRect(x: paw.x - size.width / 2, y: paw.y - size.height / 2 + 1, width: size.width, height: size.height)
        let hand = Path(ellipseIn: handRect)
        ctx.fill(hand, with: .linearGradient(Gradient(colors: [c.skin, c.skinShadow]),
                                             startPoint: pt(paw.x, handRect.minY), endPoint: pt(paw.x, handRect.maxY)))
        ctx.stroke(hand, with: .color(c.skinLine.opacity(0.8)), lineWidth: 0.9)
        if look.accessories.contains(.catEars) {
            ctx.fill(Path(ellipseIn: CGRect(x: paw.x - 3.6, y: paw.y, width: 7.2, height: 5.4)), with: .color(c.accessory))
            for i in -1...1 {
                ctx.fill(Path(ellipseIn: CGRect(x: paw.x + CGFloat(i) * 4.6 - 1.6, y: paw.y - 4.6 + abs(CGFloat(i)) * 1.2,
                                                width: 3.2, height: 3.2)),
                         with: .color(c.accessory))
            }
        } else {
            for i in -1...1 {
                var finger = Path()
                let fx = paw.x + CGFloat(i) * 4.5
                finger.move(to: pt(fx, handRect.maxY - 1))
                finger.addLine(to: pt(fx, handRect.maxY - 4.5))
                ctx.stroke(finger, with: .color(c.skinLine.opacity(0.6)), style: StrokeStyle(lineWidth: 0.8, lineCap: .round))
            }
        }
        if down && sinceTap < 0.12 {
            for i in 0..<3 {
                let angle = Double.pi * (1.15 + Double(i) * 0.35)
                var line = Path()
                line.move(to: pt(paw.x + CGFloat(cos(angle)) * 15, paw.y + CGFloat(sin(angle)) * 12))
                line.addLine(to: pt(paw.x + CGFloat(cos(angle)) * 21, paw.y + CGFloat(sin(angle)) * 17))
                ctx.stroke(line, with: .color(c.lash.opacity(0.45)), style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
            }
        }
    }

    // MARK: Accessories

    func drawAccessories(_ head: GraphicsContext) {
        let front = layer(head, 0.75)
        if look.accessories.contains(.starClip) {
            let star = sparkle(center: pt(30, -28), radius: 8, points: 5, inner: 0.45)
            front.fill(star, with: .linearGradient(Gradient(colors: [Color(hex: 0xFFF0A0), c.accessory, Color(hex: 0xE59B2E)]),
                                                   startPoint: pt(30, -36), endPoint: pt(30, -20)))
            front.stroke(star, with: .color(Color(hex: 0xB9781C)), style: StrokeStyle(lineWidth: 0.9, lineJoin: .round))
            front.fill(Path(ellipseIn: CGRect(x: 27, y: -32, width: 2.6, height: 2.6)), with: .color(.white))
        }
        if look.accessories.contains(.snowflakeClip) {
            let center = pt(31, -27)
            var flake = Path()
            for i in 0..<6 {
                let a = Double(i) * .pi / 3
                flake.move(to: center)
                flake.addLine(to: pt(center.x + CGFloat(cos(a)) * 8, center.y + CGFloat(sin(a)) * 8))
                let branch = pt(center.x + CGFloat(cos(a)) * 5, center.y + CGFloat(sin(a)) * 5)
                for side in [-1.0, 1.0] {
                    flake.move(to: branch)
                    flake.addLine(to: pt(branch.x + CGFloat(cos(a + side * 0.8)) * 2.8, branch.y + CGFloat(sin(a + side * 0.8)) * 2.8))
                }
            }
            front.stroke(flake, with: .color(Color(hex: 0x3E6CB0)), style: StrokeStyle(lineWidth: 2.8, lineCap: .round))
            front.stroke(flake, with: .color(c.accessory), style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
            front.fill(Path(ellipseIn: CGRect(x: center.x - 2.2, y: center.y - 2.2, width: 4.4, height: 4.4)), with: .color(.white))
        }
        if look.accessories.contains(.ribbons) {
            let side = layer(head, 0.1)
            for s in [-1.0, 1.0] as [CGFloat] {
                drawBow(side, at: pt(s * 47, -46), size: 11, color: c.accessory, tails: true)
                side.fill(Path(ellipseIn: CGRect(x: s * 47 - 2, y: -48, width: 4, height: 4)), with: .color(c.accent))
            }
        }
        if look.accessories.contains(.headset) { drawHeadset(layer(head, 0.3)) }
    }

    func drawHeadset(_ ctx: GraphicsContext) {
        let dark = Color(hex: 0x2A2A33)
        var bandPath = Path()
        bandPath.move(to: pt(-50, -6))
        bandPath.addCurve(to: pt(0, -74), control1: pt(-54, -48), control2: pt(-30, -74))
        bandPath.addCurve(to: pt(50, -6), control1: pt(30, -74), control2: pt(54, -48))
        ctx.stroke(bandPath, with: .color(dark), style: StrokeStyle(lineWidth: 5.5, lineCap: .round))
        ctx.stroke(bandPath.trimmedPath(from: 0.2, to: 0.8), with: .color(Color(hex: 0x5C5C6E)),
                   style: StrokeStyle(lineWidth: 1.4, lineCap: .round))

        var mic = Path()
        mic.move(to: pt(-50, 10))
        mic.addQuadCurve(to: pt(-24, 40), control: pt(-50, 38))
        ctx.stroke(mic, with: .color(dark), style: StrokeStyle(lineWidth: 2, lineCap: .round))
        ctx.fill(Path(roundedRect: CGRect(x: -27, y: 37, width: 8, height: 5.5), cornerRadius: 2.7), with: .color(dark))

        let glow = 0.7 + 0.3 * sin(time * 2.5)
        for s in [-1.0, 1.0] as [CGFloat] {
            let cup = Path(roundedRect: CGRect(x: s * 50 - 7, y: -10, width: 14, height: 25), cornerRadius: 7)
            ctx.fill(cup, with: .linearGradient(Gradient(colors: [Color(hex: 0x44444F), dark]),
                                                startPoint: pt(0, -10), endPoint: pt(0, 15)))
            ctx.stroke(cup, with: .color(.black.opacity(0.6)), lineWidth: 0.8)
            ctx.fill(Path(roundedRect: CGRect(x: s * 50 + (s > 0 ? 2.5 : -5), y: -5, width: 2.5, height: 15), cornerRadius: 1.25),
                     with: .color(c.accent.opacity(glow)))
        }
    }

    // MARK: Desk

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
        let pressed: [CGFloat] = {
            switch pose.paw {
            case .left: return [-26]
            case .right: return [26]
            case .both: return [-26, 26]
            case .up: return []
            }
        }()
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
                         with: .color(accentKey ? c.accent.opacity(0.85) : (isPressed ? Color(hex: 0xD3D6E2) : .white)))
            }
        }

        // Mug with steam.
        let mug = Path(roundedRect: CGRect(x: 192, y: 192, width: 20, height: 22), cornerRadius: 4)
        var handle = Path()
        handle.addArc(center: pt(212, 202), radius: 5, startAngle: .degrees(-80), endAngle: .degrees(80), clockwise: false)
        ctx.stroke(handle, with: .color(Color(hex: 0xF2F2F2)), lineWidth: 3)
        ctx.fill(mug, with: .linearGradient(Gradient(colors: [.white, Color(hex: 0xE2E2EA)]), startPoint: pt(192, 0), endPoint: pt(212, 0)))
        ctx.stroke(mug, with: .color(Color(hex: 0xBDBDC8)), lineWidth: 0.8)
        ctx.fill(heart(center: pt(202, 203), size: 8), with: .color(blushColor.opacity(0.8)))
        guard !pose.sleeping else { return }
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

/// A star with `points` tips; the default is a four-point sparkle.
func sparkle(center c: CGPoint, radius r: CGFloat, points: Int = 4, inner: CGFloat = 0.3) -> Path {
    var p = Path()
    for i in 0..<(points * 2) {
        let angle = Double(i) * .pi / Double(points) - .pi / 2
        let radius = i.isMultiple(of: 2) ? r : r * inner
        let point = CGPoint(x: c.x + cos(angle) * radius, y: c.y + sin(angle) * radius)
        if i == 0 { p.move(to: point) } else { p.addLine(to: point) }
    }
    p.closeSubpath()
    return p
}

func heart(center c: CGPoint, size s: Double) -> Path {
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
