import Foundation
import WaifuCore

/// Damped spring used for hair, tail and ahoge physics.
struct Spring {
    var x = 0.0
    var v = 0.0

    mutating func step(drive: Double, stiffness k: Double, damping c: Double, dt: Double) {
        let a = -k * x - c * v + drive
        v += a * dt
        x = min(max(x + v * dt, -1.6), 1.6)
    }
}

/// Live2D-style parameter rig. Every value eases toward a target derived from the model's state,
/// so expressions blend instead of snapping, and hair reacts to head motion with spring physics.
final class Rig {
    // Head (x/y normalized -1...1, z in radians).
    var angleX = 0.0, angleY = 0.0, angleZ = 0.0
    var bodyX = 0.0
    var tapDip = 0.0

    // Face.
    var eyeOpen = 1.0, eyeSmile = 0.0, irisScale = 1.0, lidTilt = 0.0
    var eyeBallX = 0.0, eyeBallY = 0.0
    var browY = 0.0, browAngle = 0.0, browRaiseRight = 0.0
    var mouthOpen = 0.0, mouthForm = 0.3, mouthWidth = 1.0
    var blush = 0.25
    var blink = 0.0

    // Physics.
    var hairFront = Spring(), hairSide = Spring(), hairBack = Spring(), tail = Spring(), ahoge = Spring(), ears = Spring()

    /// Where the viewer's cursor is relative to the face, normalized (-1...1, +y = below). Set externally.
    var gaze = CGPoint.zero

    private var lastTime: Double?
    private var lastTap = Date.distantPast
    private var nextBlink = 0.0
    private var blinkStart = -10.0
    private var doubleBlink = false

    struct Targets {
        var angleX = 0.0, angleY = 0.0, angleZ = 0.0
        var eyeOpen = 1.0, eyeSmile = 0.0, irisScale = 1.0, lidTilt = 0.0
        var eyeBallX = 0.0, eyeBallY = 0.0
        var browY = 0.0, browAngle = 0.0, browRaiseRight = 0.0
        var mouthOpen = 0.0, mouthForm = 0.3, mouthWidth = 1.0
        var blush = 0.25
    }

    // MARK: - Targets

    func targets(for pose: VectorWaifuView.Pose, time t: Double, now: Date) -> Targets {
        var g = Targets()
        let mood: Mood = pose.sleeping ? .sleepy : pose.expression
        switch mood {
        case .neutral:
            break
        case .happy:
            g.eyeSmile = 1; g.mouthForm = 1; g.mouthOpen = 0.5; g.browY = -2; g.blush = 0.4
        case .excited:
            g.eyeOpen = 1.12; g.mouthForm = 1; g.mouthOpen = 0.75; g.browY = -3; g.blush = 0.5
        case .surprised:
            g.eyeOpen = 1.15; g.irisScale = 0.78; g.mouthOpen = 0.55; g.mouthForm = 0; g.mouthWidth = 0.55
            g.browY = -6; g.blush = 0.2
        case .annoyed:
            g.eyeOpen = 0.6; g.lidTilt = 1; g.mouthForm = -0.7; g.browAngle = 0.45; g.browY = 2; g.blush = 0.3
        case .sleepy:
            g.eyeOpen = 0; g.mouthOpen = 0.12; g.mouthForm = 0; g.mouthWidth = 0.6; g.browAngle = -0.2; g.blush = 0.3
        case .smug:
            g.eyeOpen = 0.62; g.mouthForm = 0.7; g.browRaiseRight = 1; g.blush = 0.35; g.eyeBallX = 0.8
        case .blush:
            g.eyeSmile = 1; g.mouthForm = 0.8; g.mouthOpen = 0.15; g.browAngle = -0.25; g.blush = 1
        }

        // Head follows the cursor, with a slow idle wander layered on top.
        let gx = Double(max(-1, min(1, gaze.x)))
        let gy = Double(max(-1, min(1, gaze.y)))
        g.angleX = gx * 0.85 + sin(t * 0.37) * 0.1 + sin(t * 0.23 + 1) * 0.06
        g.angleY = gy * 0.6 + sin(t * 0.29) * 0.05
        g.angleZ = -gx * 0.04 + sin(t * 0.31 + 2) * 0.02
        if mood != .smug { g.eyeBallX = gx; g.eyeBallY = gy * 0.8 }

        // Typing: glance down at the keyboard.
        let sinceTap = now.timeIntervalSince(pose.lastTap)
        let typing = sinceTap < 1.2 ? 1 : max(0, 1 - (sinceTap - 1.2) / 0.8)
        if typing > 0 {
            g.angleY += (0.45 - g.angleY) * typing
            g.angleX *= 1 - 0.6 * typing
            g.eyeBallY += (0.85 - g.eyeBallY) * typing
            if pose.tier >= .blazing { g.angleX += sin(t * 9) * 0.06 * typing }
        }

        // Lip-sync while a speech bubble is still typing out.
        if let until = pose.talkingUntil, now < until {
            let flap = abs(sin(t * 13)) * (0.6 + 0.4 * sin(t * 5.3))
            g.mouthOpen = max(g.mouthOpen, 0.12 + 0.5 * flap)
            g.angleY *= 0.5
        }

        if pose.sleeping {
            g.angleX = 0.1; g.angleY = 0.55 + sin(t * 1.1) * 0.04; g.angleZ = 0.18
            g.eyeBallX = 0; g.eyeBallY = 0
        }
        return g
    }

    // MARK: - Stepping

    func update(pose: VectorWaifuView.Pose, now: Date) {
        let t = now.timeIntervalSinceReferenceDate
        let dt = min(max(t - (lastTime ?? (t - 1.0 / 60)), 0), 0.1)
        lastTime = t
        guard dt > 0 else { return }
        let g = targets(for: pose, time: t, now: now)

        func ease(_ v: inout Double, _ target: Double, _ speed: Double) {
            v += (target - v) * (1 - exp(-speed * dt))
        }
        let (prevX, prevY, prevZ) = (angleX, angleY, angleZ)
        ease(&angleX, g.angleX, 5)
        ease(&angleY, g.angleY, 5)
        ease(&angleZ, g.angleZ, 4)
        ease(&bodyX, angleX * 0.5, 3)
        ease(&eyeOpen, g.eyeOpen, 14)
        ease(&eyeSmile, g.eyeSmile, 14)
        ease(&irisScale, g.irisScale, 12)
        ease(&lidTilt, g.lidTilt, 10)
        ease(&eyeBallX, g.eyeBallX, 12)
        ease(&eyeBallY, g.eyeBallY, 12)
        ease(&browY, g.browY, 10)
        ease(&browAngle, g.browAngle, 10)
        ease(&browRaiseRight, g.browRaiseRight, 10)
        ease(&mouthOpen, g.mouthOpen, 22)
        ease(&mouthForm, g.mouthForm, 12)
        ease(&mouthWidth, g.mouthWidth, 12)
        ease(&blush, g.blush, 4)

        // Keystrokes give a little nod and a flick of the ahoge.
        if pose.lastTap > lastTap {
            lastTap = pose.lastTap
            tapDip = 1
            ahoge.v += 3
            hairFront.v += 0.6
        }
        ease(&tapDip, 0, 16)

        // Blinking: randomized interval, occasional double blink.
        if !pose.sleeping && t > nextBlink {
            blinkStart = t
            doubleBlink = Double.random(in: 0..<1) < 0.2
            nextBlink = t + Double.random(in: 2.2...5.5)
        }
        let phase = t - blinkStart
        let one = phase < 0.16 ? sin(phase / 0.16 * .pi) : 0
        let two = doubleBlink && phase > 0.22 && phase < 0.38 ? sin((phase - 0.22) / 0.16 * .pi) : 0
        blink = max(one, two)

        // Hair physics, driven by head velocity.
        let vx = (angleX - prevX) / dt
        let vy = (angleY - prevY) / dt
        let vz = (angleZ - prevZ) / dt
        hairFront.step(drive: -vx * 4 - vz * 6, stiffness: 90, damping: 9, dt: dt)
        hairSide.step(drive: -vx * 7 - vz * 10 + sin(t * 1.4) * 1.2, stiffness: 55, damping: 6, dt: dt)
        hairBack.step(drive: -vx * 5 - vz * 8 + sin(t * 1.1) * 1.5, stiffness: 30, damping: 4.5, dt: dt)
        tail.step(drive: sin(t * 1.3) * 18 + sin(t * 3.1) * 4 - vx * 4, stiffness: 25, damping: 3, dt: dt)
        ahoge.step(drive: -vx * 12 - vy * 6, stiffness: 120, damping: 7, dt: dt)
        let twitch = (t.truncatingRemainder(dividingBy: 6.3) < 0.05) ? 60.0 : 0
        ears.step(drive: twitch - vx * 3, stiffness: 160, damping: 10, dt: dt)
    }

    /// Jump straight to the target pose (static renders: previews, exported sprites).
    func settle(pose: VectorWaifuView.Pose, now: Date) {
        let g = targets(for: pose, time: 0, now: now)
        angleX = g.angleX; angleY = g.angleY; angleZ = g.angleZ
        eyeOpen = g.eyeOpen; eyeSmile = g.eyeSmile; irisScale = g.irisScale; lidTilt = g.lidTilt
        eyeBallX = g.eyeBallX; eyeBallY = g.eyeBallY
        browY = g.browY; browAngle = g.browAngle; browRaiseRight = g.browRaiseRight
        mouthOpen = g.mouthOpen; mouthForm = g.mouthForm; mouthWidth = g.mouthWidth
        blush = g.blush
        blink = 0
        lastTime = now.timeIntervalSinceReferenceDate
        lastTap = pose.lastTap
    }
}
