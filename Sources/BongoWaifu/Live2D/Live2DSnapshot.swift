import AppKit
import WaifuCore
import WebKit

/// `BongoWaifu --snapshot-live2d <packDir> <outDir>` loads a Live2D pack off-screen, drives it through
/// several poses with the real rig, and saves PNG snapshots. Useful for checking a pack's framing and
/// expression mapping without watching the overlay.
@MainActor
enum Live2DSnapshot {
    static func run(pack: String, outputDirectory: String, onScreen: Bool = false) -> Int32 {
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.accessory)
        NSApp.finishLaunching()
        let out = URL(fileURLWithPath: outputDirectory, isDirectory: true)
        try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

        let character: WaifuCharacter
        do {
            character = try CharacterStore.loadPack(at: URL(fileURLWithPath: pack, isDirectory: true))
        } catch {
            print("Couldn't load pack: \(error.localizedDescription)")
            return 1
        }
        guard case .live2d(let ref) = character.art else {
            print("\(character.name) isn't a Live2D pack")
            return 1
        }

        let size = NSSize(width: 480, height: 480)
        // Off-screen by default (frames driven by hand); --onscreen shows it in the screen corner like the
        // real overlay, to check that WebKit keeps animating a non-key floating window.
        let origin = onScreen ? NSPoint(x: (NSScreen.main?.visibleFrame.minX ?? 0) + 20, y: (NSScreen.main?.visibleFrame.minY ?? 0) + 20)
                              : NSPoint(x: -4000, y: -4000)
        let window = NSPanel(contentRect: NSRect(origin: origin, size: size),
                             styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .floating
        // Same as the real overlay, so it's visible even over full-screen apps.
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        window.ignoresMouseEvents = true
        let stage = Live2DStage()
        let rig = Rig()
        stage.rig = rig
        stage.manualFrames = !onScreen
        stage.webView.frame = NSRect(origin: .zero, size: size)
        window.contentView?.addSubview(stage.webView)
        window.orderFrontRegardless()

        func pose(_ mood: Mood, sleeping: Bool = false, talking: Bool = false) -> VectorWaifuView.Pose {
            .init(paw: .up, expression: mood, sleeping: sleeping, tier: .normal, lastTap: .distantPast,
                  talkingUntil: talking ? Date().addingTimeInterval(60) : nil)
        }
        func wait(_ seconds: TimeInterval, until done: () -> Bool = { false }) {
            let end = Date().addingTimeInterval(seconds)
            while Date() < end && !done() { RunLoop.main.run(until: Date().addingTimeInterval(0.05)) }
        }

        var loaded: Bool?
        stage.onLoad = { loaded = $0 }
        stage.pose = pose(.neutral)
        stage.show(ref)
        wait(30) { loaded != nil }
        if ProcessInfo.processInfo.environment["BONGOWAIFU_DEBUG"] != nil {
            print("window visible=\(window.isVisible) occlusionVisible=\(window.occlusionState.contains(.visible)) frame=\(window.frame) screen=\(window.screen?.frame ?? .zero)")
        }
        guard loaded == true else {
            print(Live2DStatus.shared.message ?? "Timed out loading the model")
            return 1
        }

        let shots: [(String, VectorWaifuView.Pose, CGPoint, Bool)] = [
            ("1-neutral", pose(.neutral), .zero, false),
            ("2-look-left", pose(.neutral), CGPoint(x: -1, y: 0.1), false),
            ("3-look-right-up", pose(.neutral), CGPoint(x: 1, y: -0.8), false),
            ("4-happy-talking", pose(.happy, talking: true), .zero, false),
            ("5-surprised", pose(.surprised), .zero, false),
            ("6-annoyed", pose(.annoyed), CGPoint(x: -0.4, y: 0), false),
            ("7-asleep", pose(.sleepy, sleeping: true), .zero, false),
            ("8-blush-tap", pose(.blush), .zero, true),
        ]
        for (name, shotPose, gaze, tap) in shots {
            stage.pose = shotPose
            rig.gaze = gaze
            if tap { stage.tap() }
            wait(1.6)
            var data: Data?
            var finished = false
            stage.snapshotPNG { data = $0; finished = true }
            wait(5) { finished }
            guard let png = data else {
                print("snapshot failed: \(name)")
                continue
            }
            let file = out.appendingPathComponent("\(name).png")
            try? png.write(to: file)
            print(file.path)
        }
        stage.stop()
        return 0
    }
}
