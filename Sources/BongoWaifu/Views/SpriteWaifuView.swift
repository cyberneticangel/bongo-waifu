import SwiftUI
import WaifuCore

/// Renders a custom character pack from its PNG frames.
struct SpriteWaifuView: View {
    let sprites: SpriteSet
    let pose: VectorWaifuView.Pose

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Image(nsImage: frame(time: t))
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .scaleEffect(x: 1, y: 1 + sin(t * 2.1) * 0.008, anchor: .bottom)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
    }

    private func frame(time: Double) -> NSImage {
        switch pose.paw {
        case .left: return sprites.left
        case .right: return sprites.right
        case .both: return sprites.both ?? sprites.left
        case .up: break
        }
        if pose.sleeping { return sprites.sleep ?? sprites.expressions[.sleepy] ?? sprites.idle }
        if let image = sprites.expressions[pose.expression] { return image }
        let blinking = time.truncatingRemainder(dividingBy: 4.3) < 0.12
        if blinking, let blink = sprites.blink { return blink }
        return sprites.idle
    }
}
