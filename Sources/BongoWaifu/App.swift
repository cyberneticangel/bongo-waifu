import AppKit

@main
@MainActor
enum BongoWaifuApp {
    static func main() {
        let args = CommandLine.arguments
        if let flag = args.firstIndex(of: "--render-previews") {
            PreviewRenderer.run(outputDirectory: args.indices.contains(flag + 1) ? args[flag + 1] : "previews")
            return
        }
        if let flag = args.firstIndex(of: "--record-demo") {
            let rest = args.dropFirst(flag + 1)
            DemoRecorder.run(outputDirectory: rest.first ?? "demo",
                             characterID: rest.dropFirst().first ?? WaifuCharacter.mochi.id)
            return
        }
        if let flag = args.firstIndex(of: "--snapshot-live2d"), args.count > flag + 2 {
            exit(Live2DSnapshot.run(pack: args[flag + 1], outputDirectory: args[flag + 2], onScreen: args.contains("--onscreen")))
        }
        if let flag = args.firstIndex(of: "--export-pack") {
            PreviewRenderer.exportPack(to: args.indices.contains(flag + 1) ? args[flag + 1] : "ExportedPack")
            return
        }
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = Settings()
    private let store = CharacterStore()
    private let input = InputMonitor()
    private var model: CompanionModel!
    private var overlay: OverlayController!
    private var menu: StatusMenuController!
    private var ticker: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        model = CompanionModel(character: store.character(id: settings.characterID), settings: settings)
        overlay = OverlayController(model: model, settings: settings)
        menu = StatusMenuController(model: model, store: store, overlay: overlay, input: input)
        overlay.hostingView.menuProvider = { [unowned self] in self.menu.makeMenu() }

        input.onKey = { [unowned self] kind, isRepeat in model.keyPressed(kind, isRepeat: isRepeat) }
        input.onClick = { [unowned self] in model.mouseClicked() }
        input.onTrustChanged = { [unowned self] _ in model.greet() }
        input.start()

        ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [unowned self] _ in
            MainActor.assumeIsolated { model.tick() }
        }

        overlay.show()
        model.greet()
        if !input.isTrusted { input.requestAccess() }
    }

    func applicationWillTerminate(_ notification: Notification) {
        model.saveStats()
    }
}
