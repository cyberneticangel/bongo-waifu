import SwiftUI

/// Speech bubble with a typewriter reveal and a tail pointing down at the character.
struct SpeechBubble: View {
    let bubble: Bubble
    let name: String
    let accent: Color
    let background: Color
    let scale: CGFloat

    static let tail: CGFloat = 10
    private static let textColor = Color(hex: 0x2B2B33)

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
            let revealed = Int(timeline.date.timeIntervalSince(bubble.start) / 0.03)
            VStack(alignment: .leading, spacing: 2 * scale) {
                Text(name)
                    .font(.system(size: 10 * scale, weight: .heavy, design: .rounded))
                    .foregroundStyle(accent)
                ZStack(alignment: .topLeading) {
                    // Invisible full text reserves the final size so the bubble doesn't grow as it types.
                    Text(bubble.text).opacity(0)
                    Text(String(bubble.text.prefix(max(revealed, 0))))
                }
                .font(.system(size: 13 * scale, weight: .medium, design: .rounded))
                .foregroundStyle(Self.textColor)
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 12 * scale)
            .padding(.top, 8 * scale)
            .padding(.bottom, 8 * scale + Self.tail * scale)
            .background {
                BubbleShape(tail: Self.tail * scale, radius: 14 * scale)
                    .fill(background)
                    .shadow(color: .black.opacity(0.18), radius: 4 * scale, y: 2 * scale)
            }
            .overlay {
                BubbleShape(tail: Self.tail * scale, radius: 14 * scale)
                    .stroke(accent.opacity(0.55), lineWidth: 1.5 * scale)
            }
        }
        .frame(maxWidth: 270 * scale)
    }
}

struct BubbleShape: Shape {
    let tail: CGFloat
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        let body = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height - tail)
        var p = Path(roundedRect: body, cornerRadius: radius)
        var t = Path()
        t.move(to: CGPoint(x: body.midX - tail, y: body.maxY - 1))
        t.addLine(to: CGPoint(x: body.midX - tail * 0.2, y: rect.maxY))
        t.addLine(to: CGPoint(x: body.midX + tail * 0.8, y: body.maxY - 1))
        t.closeSubpath()
        p.addPath(t)
        return p
    }
}
