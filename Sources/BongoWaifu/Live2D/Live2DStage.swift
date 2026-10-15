import AppKit
import SwiftUI
import WaifuCore
import WebKit

enum AppResources {
    /// stage.html, bridge.js and the vendored JS libraries.
    static var live2DDirectory: URL? {
        if let bundled = Bundle.main.resourceURL?.appendingPathComponent("Live2D"),
           FileManager.default.fileExists(atPath: bundled.appendingPathComponent("stage.html").path) {
            return bundled
        }
        // `swift run` and debug builds: fall back to the source tree.
        let source = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Resources/Live2D")
        return FileManager.default.fileExists(atPath: source.appendingPathComponent("stage.html").path) ? source : nil
    }
}

/// Serves everything to the web view from one origin, `bongo://local`:
/// `/app/…` (bundled page and libraries), `/model/…` (the character pack), `/core/…` (Cubism Core).
final class Live2DSchemeHandler: NSObject, WKURLSchemeHandler {
    var modelDirectory: URL?

    func webView(_ webView: WKWebView, start task: WKURLSchemeTask) {
        guard let url = task.request.url, let file = resolve(url),
              let data = try? Data(contentsOf: file) else {
            let missing = HTTPURLResponse(url: task.request.url ?? URL(string: "bongo://local")!, statusCode: 404,
                                          httpVersion: "HTTP/1.1", headerFields: nil)!
            task.didReceive(missing)
            task.didReceive(Data())
            task.didFinish()
            return
        }
        let headers = ["Content-Type": Self.mimeType(for: file.pathExtension), "Access-Control-Allow-Origin": "*",
                       "Content-Length": String(data.count)]
        task.didReceive(HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: headers)!)
        task.didReceive(data)
        task.didFinish()
    }

    func webView(_ webView: WKWebView, stop task: WKURLSchemeTask) {}

    private func resolve(_ url: URL) -> URL? {
        let parts = url.path.split(separator: "/", maxSplits: 1).map(String.init)
        guard parts.count == 2, let relative = parts[1].removingPercentEncoding else { return nil }
        let base: URL?
        switch parts[0] {
        case "app": base = AppResources.live2DDirectory
        case "model": base = modelDirectory
        case "core": return relative == "live2dcubismcore.min.js" ? Live2DCore.fileURL : nil
        default: base = nil
        }
        guard let base else { return nil }
        let file = base.appendingPathComponent(relative).standardizedFileURL
        // Never serve anything outside the folder (no ../ escapes).
        return file.path.hasPrefix(base.standardizedFileURL.path + "/") ? file : nil
    }

    private static func mimeType(for ext: String) -> String {
        switch ext.lowercased() {
        case "html": return "text/html; charset=utf-8"
        case "js": return "application/javascript; charset=utf-8"
        case "json": return "application/json"
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        default: return "application/octet-stream"
        }
    }
}

/// Mouse events go to the companion window (drag, pet, menu), never to the web content.
final class PassthroughWebView: WKWebView {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

/// Avoids the retain cycle WKUserContentController creates with its handlers.
private final class WeakMessageHandler: NSObject, WKScriptMessageHandler {
    weak var target: WKScriptMessageHandler?
    init(_ target: WKScriptMessageHandler) { self.target = target }
    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        target?.userContentController(controller, didReceive: message)
    }
}

/// One transparent web view rendering a Live2D model, driven ~30 times a second from the shared `Rig`.
@MainActor
final class Live2DStage: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
    let webView: WKWebView
    var rig: Rig?
    var pose: VectorWaifuView.Pose?
    var lastPetCount = 0
    /// Drive frames from Swift instead of requestAnimationFrame (off-screen rendering).
    var manualFrames = false
    /// Called with true once a model has loaded, false on failure.
    var onLoad: ((Bool) -> Void)?

    private let schemes = Live2DSchemeHandler()
    private var current: Live2DModelRef?
    private var pageReady = false
    private var timer: Timer?
    private var coreObserver: NSObjectProtocol?

    override init() {
        let config = WKWebViewConfiguration()
        config.setURLSchemeHandler(schemes, forURLScheme: "bongo")
        // The overlay panel never becomes key; keep animating anyway.
        config.preferences.inactiveSchedulingPolicy = .none
        webView = PassthroughWebView(frame: NSRect(x: 0, y: 0, width: 240, height: 240), configuration: config)
        super.init()
        webView.configuration.userContentController.add(WeakMessageHandler(self), name: "bongo")
        webView.setValue(false, forKey: "drawsBackground")
        webView.navigationDelegate = self
        coreObserver = NotificationCenter.default.addObserver(forName: .live2DCoreInstalled, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.reloadPage() }
        }
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
    }

    func show(_ model: Live2DModelRef) {
        guard model != current else { return }
        current = model
        schemes.modelDirectory = model.directory
        if pageReady { sendLoad() } else { reloadPage() }
    }

    func tap() {
        call("bongo.tap()")
    }

    /// PNG of the current frame, rendered inside the page (independent of window compositing).
    func snapshotPNG(completion: @escaping (Data?) -> Void) {
        webView.evaluateJavaScript("bongo.snapshot()") { result, _ in
            let base64 = (result as? String)?.components(separatedBy: ",").last
            completion(base64.flatMap { Data(base64Encoded: $0) })
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        if let coreObserver { NotificationCenter.default.removeObserver(coreObserver) }
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "bongo")
    }

    private func reloadPage() {
        pageReady = false
        guard AppResources.live2DDirectory != nil else {
            report("Live2D runtime files are missing from the app bundle.")
            return
        }
        webView.load(URLRequest(url: URL(string: "bongo://local/app/stage.html")!))
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        pageReady = true
        sendLoad()
    }

    private func sendLoad() {
        guard let model = current, Live2DCore.isInstalled else { return }
        let path = model.modelPath.split(separator: "/").map {
            String($0).addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? String($0)
        }.joined(separator: "/")
        let config: [String: Any] = [
            "zoom": model.zoom ?? NSNull(), "offsetX": model.offsetX, "offsetY": model.offsetY,
            "expressions": model.expressions, "tapMotion": model.tapMotion ?? NSNull(),
            "debug": ProcessInfo.processInfo.environment["BONGOWAIFU_DEBUG"] != nil,
        ]
        call("bongo.load(\(json("bongo://local/model/" + path)), \(json(config)))")
    }

    private func tick() {
        guard pageReady, let rig, let pose else { return }
        rig.update(pose: pose, now: Date())
        // The model blinks on its own, so only the rig's slower eye changes (sleep, smiles, surprise) are sent.
        let state: [String: Any] = [
            "angleX": rig.angleX, "angleY": rig.angleY, "angleZ": rig.angleZ, "tapDip": rig.tapDip,
            "eyeBallX": rig.eyeBallX, "eyeBallY": rig.eyeBallY,
            "eyeOpen": min(rig.eyeOpen, 1.3) * (1 - rig.eyeSmile), "eyeSmile": rig.eyeSmile,
            "browY": rig.browY, "browAngle": rig.browAngle,
            "mouthOpen": rig.mouthOpen, "mouthForm": rig.mouthForm, "blush": rig.blush,
            "mood": pose.sleeping ? Mood.sleepy.rawValue : pose.expression.rawValue,
        ]
        let windowVisible = webView.window?.occlusionState.contains(.visible) ?? false
        let frame = manualFrames ? "; bongo.step()" : (windowVisible ? "; bongo.stepIfHidden()" : "")
        call("bongo.update(\(json(state)))" + frame)
    }

    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any], let type = body["type"] as? String else { return }
        switch type {
        case "loaded":
            Live2DStatus.shared.message = nil
            onLoad?(true)
        case "error":
            let text = body["message"] as? String ?? "unknown error"
            if body["code"] as? String == "core-missing" {
                report("Live2D Cubism Core isn't installed. Use the menu: Install Live2D Cubism Core…")
            } else {
                report("Live2D: \(text)")
            }
            onLoad?(false)
        case "log":
            if ProcessInfo.processInfo.environment["BONGOWAIFU_DEBUG"] != nil {
                print("live2d:", body["message"] as? String ?? "")
            }
        default:
            break
        }
    }

    private func report(_ text: String) {
        Live2DStatus.shared.message = text
        FileHandle.standardError.write(Data((text + "\n").utf8))
    }

    private func call(_ script: String) {
        guard pageReady else { return }
        webView.evaluateJavaScript(script, completionHandler: nil)
    }

    private func json(_ value: Any) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: value, options: [.fragmentsAllowed]) else { return "null" }
        return String(decoding: data, as: UTF8.self)
    }
}

/// SwiftUI wrapper; the stage lives in the coordinator so it survives view updates.
struct Live2DView: NSViewRepresentable {
    let model: Live2DModelRef
    let pose: VectorWaifuView.Pose
    let rig: Rig
    let petCount: Int

    func makeCoordinator() -> Live2DStage {
        let stage = Live2DStage()
        stage.lastPetCount = petCount
        return stage
    }

    func makeNSView(context: Context) -> WKWebView {
        context.coordinator.webView
    }

    func updateNSView(_ view: WKWebView, context: Context) {
        let stage = context.coordinator
        stage.rig = rig
        stage.pose = pose
        stage.show(model)
        if petCount != stage.lastPetCount {
            stage.lastPetCount = petCount
            stage.tap()
        }
    }

    static func dismantleNSView(_ view: WKWebView, coordinator: Live2DStage) {
        coordinator.stop()
    }
}
