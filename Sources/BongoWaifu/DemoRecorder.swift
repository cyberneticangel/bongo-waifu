import AppKit
import ImageIO
import SwiftUI
import UniformTypeIdentifiers
import WaifuCore

/// `BongoWaifu --record-demo <dir> [characterID]` plays a scripted typing session against the real
/// model and views on a mock desktop, rendering each frame offscreen (no Screen Recording permission needed).
/// Frames land in <dir> with an ffmpeg concat list carrying their real timestamps.
@MainActor
enum DemoRecorder {
    static let sceneSize = CGSize(width: 900, height: 560)
    static let fps: Double = 15
    static let length: TimeInterval = 31

    enum Step {
        case type(Character)
        case backspace
        case cursor(CGPoint)
        case pet
    }

    static func run(outputDirectory: String, characterID: String) {
        let dir = URL(fileURLWithPath: outputDirectory, isDirectory: true)
        try? FileManager.default.removeItem(at: dir)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        // Throwaway defaults so the demo never touches the real app's settings or stats.
        let suite = "dev.bongowaifu.demo"
        UserDefaults().removePersistentDomain(forName: suite)
        let settings = Settings(defaults: UserDefaults(suiteName: suite)!)
        let character = CharacterStore.builtIns.first { $0.id == characterID } ?? .mochi
        // Seeded so every recording says the same lines.
        var seed = UInt64(ProcessInfo.processInfo.environment["DEMO_SEED"] ?? "") ?? 7
        let model = CompanionModel(character: character, settings: settings, random: {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return Double(seed >> 11) / Double(1 << 53)
        })
        model.useDemoPacing(0.08, idleAfter: 3)
        let desk = DemoDesk()

        let start = Date()
        var schedule = script()
        var frames: [(String, Date)] = []
        let writer = DispatchQueue(label: "demo.writer")
        var nextGreet = true

        // The once-a-second tick drives ambient chatter and dozing off; holding it until the typing
        // burst ends keeps the story in order (grumble at the typo, fun fact after, then a nap).
        let ticker = Timer(fire: start.addingTimeInterval(18.5), interval: 1, repeats: true) { _ in
            MainActor.assumeIsolated { model.tick() }
        }
        RunLoop.main.add(ticker, forMode: .common)
        let frameTimer = Timer(timeInterval: 1 / fps, repeats: true) { _ in
            MainActor.assumeIsolated {
                let now = Date()
                let t = now.timeIntervalSince(start)
                if nextGreet && t > 0.3 { model.greet(); nextGreet = false }
                while let first = schedule.first, first.0 <= t {
                    schedule.removeFirst()
                    perform(first.1, model: model, desk: desk)
                }
                desk.caretOn = Int(t * 2.5).isMultiple(of: 2)
                desk.moveCursor(now: now)
                // She watches the cursor, like on a real desktop.
                let head = CGPoint(x: 710, y: 418)
                model.rig.gaze = CGPoint(x: (desk.cursor.x - head.x) / 450, y: (desk.cursor.y - head.y) / 450)
                // A fresh renderer per frame: ImageRenderer pins TimelineView's clock to its creation time.
                let renderer = ImageRenderer(content: DemoScene(model: model, desk: desk))
                renderer.scale = 2
                guard let image = renderer.cgImage else { return }
                let name = String(format: "f%05d.png", frames.count)
                frames.append((name, now))
                writer.async { writePNG(image, to: dir.appendingPathComponent(name)) }
            }
        }
        RunLoop.main.add(frameTimer, forMode: .common)
        RunLoop.main.run(until: start.addingTimeInterval(length))
        frameTimer.invalidate()
        ticker.invalidate()
        writer.sync {}

        // Concat list with each frame's real on-screen duration.
        var list = ""
        for (i, frame) in frames.enumerated() {
            let next = i + 1 < frames.count ? frames[i + 1].1 : frame.1.addingTimeInterval(1 / fps)
            list += "file '\(frame.0)'\nduration \(String(format: "%.4f", next.timeIntervalSince(frame.1)))\n"
        }
        if let last = frames.last { list += "file '\(last.0)'\n" }
        try? list.write(to: dir.appendingPathComponent("frames.txt"), atomically: true, encoding: .utf8)
        UserDefaults().removePersistentDomain(forName: suite)
        print("\(frames.count) frames → \(dir.path)")
    }

    private static func perform(_ step: Step, model: CompanionModel, desk: DemoDesk) {
        switch step {
        case .type(let ch):
            desk.text.append(ch)
            model.keyPressed(ch == "\n" ? .enter : .normal, isRepeat: false)
        case .backspace:
            if !desk.text.isEmpty { desk.text.removeLast() }
            model.keyPressed(.backspace, isRepeat: false)
        case .cursor(let point):
            desk.cursorFrom = desk.cursor
            desk.cursorTo = point
            desk.cursorStart = Date()
        case .pet:
            model.mouseClicked()
            model.petted()
        }
    }

    /// Calm typing with a typo, a Backspace spree, a fast burst, a doze-off, then a headpat.
    private static func script() -> [(TimeInterval, Step)] {
        var steps: [(TimeInterval, Step)] = []
        var t = 2.6
        func type(_ text: String, perSecond rate: Double) {
            for (i, ch) in text.enumerated() {
                steps.append((t, .type(ch)))
                t += 1 / rate * (1 + 0.25 * sin(Double(i) * 1.7))
            }
        }
        type("Dear diary, I made a desktop waifu! She taps along whenevr I tpye", perSecond: 6.5)
        t += 0.5
        for _ in 0..<14 { steps.append((t, .backspace)); t += 0.1 }
        t += 0.4
        type("whenever I type. She tells fun facts and naps when I stop!!", perSecond: 14)
        steps.append((0.4, .cursor(CGPoint(x: 360, y: 230))))
        steps.append((1.5, .cursor(CGPoint(x: 870, y: 260))))
        steps.append((23.6, .cursor(CGPoint(x: 712, y: 372))))
        for i in 0..<3 { steps.append((25.6 + Double(i) * 0.35, .pet)) }
        steps.append((28.5, .cursor(CGPoint(x: 600, y: 520))))
        return steps.sorted { $0.0 < $1.0 }
    }

    nonisolated private static func writePNG(_ image: CGImage, to url: URL) {
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else { return }
        CGImageDestinationAddImage(dest, image, nil)
        CGImageDestinationFinalize(dest)
    }
}

@MainActor
final class DemoDesk: ObservableObject {
    @Published var text = ""
    @Published var caretOn = true
    @Published var cursor = CGPoint(x: 620, y: 140)
    var cursorFrom = CGPoint.zero
    var cursorTo: CGPoint?
    var cursorStart = Date.distantPast

    /// Eased glide toward the latest cursor target.
    func moveCursor(now: Date) {
        guard let target = cursorTo else { return }
        let p = min(now.timeIntervalSince(cursorStart) / 1.1, 1)
        let e = p < 0.5 ? 2 * p * p : 1 - pow(-2 * p + 2, 2) / 2
        cursor = CGPoint(x: cursorFrom.x + (target.x - cursorFrom.x) * e, y: cursorFrom.y + (target.y - cursorFrom.y) * e)
        if p >= 1 { cursorTo = nil }
    }
}

/// Mock desktop: wallpaper, menu bar, a notes window, the companion in the corner and a mouse cursor.
struct DemoScene: View {
    @ObservedObject var model: CompanionModel
    @ObservedObject var desk: DemoDesk

    var body: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(colors: [Color(hex: 0x9BB8F5), Color(hex: 0xD9C2F0), Color(hex: 0xF7D6E0)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            Circle().fill(.white.opacity(0.18)).frame(width: 420).offset(x: 520, y: -160)
            Circle().fill(.white.opacity(0.12)).frame(width: 300).offset(x: -80, y: 360)

            menuBar
            editor.offset(x: 48, y: 70)

            CompanionView(model: model)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(.trailing, 40)

            Image(systemName: "cursorarrow")
                .font(.system(size: 22))
                .foregroundStyle(.black)
                .shadow(color: .white, radius: 0.5)
                .position(x: desk.cursor.x + 6, y: desk.cursor.y + 10)
        }
        .frame(width: DemoRecorder.sceneSize.width, height: DemoRecorder.sceneSize.height)
        .clipped()
        .environment(\.colorScheme, .light)
    }

    private var menuBar: some View {
        HStack(spacing: 16) {
            Image(systemName: "apple.logo")
            Text("Notes").bold()
            Text("File")
            Text("Edit")
            Text("View")
            Spacer()
            Image(systemName: "pawprint.fill")
            Image(systemName: "wifi")
            Text("Wed 10:42")
        }
        .font(.system(size: 12))
        .foregroundStyle(.black.opacity(0.8))
        .padding(.horizontal, 14)
        .frame(width: DemoRecorder.sceneSize.width, height: 26)
        .background(.white.opacity(0.45))
    }

    private var editor: some View {
        VStack(spacing: 0) {
            ZStack {
                HStack(spacing: 7) {
                    Circle().fill(Color(hex: 0xFF5F57)).frame(width: 11)
                    Circle().fill(Color(hex: 0xFEBC2E)).frame(width: 11)
                    Circle().fill(Color(hex: 0x28C840)).frame(width: 11)
                    Spacer()
                }
                Text("diary.md").font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .frame(height: 30)
            .background(Color(hex: 0xF3F3F5))
            Divider()
            (Text(desk.text) + Text("|").foregroundColor(desk.caretOn ? Color(hex: 0x3478F6) : .clear))
                .font(.system(size: 17, design: .monospaced))
                .foregroundStyle(Color(hex: 0x222226))
                .lineSpacing(5)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(18)
        }
        .frame(width: 470, height: 290)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.25), radius: 18, y: 8)
    }
}
