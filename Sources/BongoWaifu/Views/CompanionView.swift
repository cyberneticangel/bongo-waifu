import SwiftUI
import WaifuCore

/// Fixed layout shared by the view and the window (which needs the same numbers for hit-testing).
enum CompanionLayout {
    static let width: CGFloat = 300
    static let bubbleArea: CGFloat = 110
    static let character: CGFloat = 240

    static func windowSize(scale: CGFloat) -> CGSize {
        CGSize(width: width * scale, height: (bubbleArea + character) * scale)
    }
}

struct CompanionView: View {
    @ObservedObject var model: CompanionModel

    var body: some View {
        let s = model.size.scale
        let c = model.character
        VStack(spacing: 0) {
            ZStack(alignment: .bottom) {
                if let bubble = model.bubble {
                    SpeechBubble(bubble: bubble, name: c.name, accent: c.accent, background: c.bubble, scale: s)
                        .id(bubble.id)
                        .transition(.scale(scale: 0.6, anchor: .bottom).combined(with: .opacity))
                }
            }
            .frame(width: CompanionLayout.width * s, height: CompanionLayout.bubbleArea * s, alignment: .bottom)
            .offset(y: 26 * s) // tuck the bubble tail just above her head

            ZStack {
                character(c)
                    .scaleEffect(c.scale, anchor: .bottom)
                EffectsLayer(effect: model.effect, sleeping: model.isSleeping, tier: model.tier)
            }
            .frame(width: CompanionLayout.character * s, height: CompanionLayout.character * s)
        }
        .frame(width: CompanionLayout.width * s, height: (CompanionLayout.bubbleArea + CompanionLayout.character) * s)
    }

    @ViewBuilder
    private func character(_ c: WaifuCharacter) -> some View {
        // Lip-sync runs while the bubble's typewriter is still revealing text.
        let talking = model.bubble.map { $0.start.addingTimeInterval(Double($0.text.count) * 0.03) }
        let pose = VectorWaifuView.Pose(paw: model.paw, expression: model.expression, sleeping: model.isSleeping,
                                        tier: model.tier, lastTap: model.lastTap, talkingUntil: talking)
        switch c.art {
        case .vector(let look): VectorWaifuView(look: look, pose: pose, rig: model.rig)
        case .sprites(let sprites): SpriteWaifuView(sprites: sprites, pose: pose)
        }
    }
}
