import AppKit
import Foundation

extension Notification.Name {
    static let live2DCoreInstalled = Notification.Name("BongoWaifu.live2DCoreInstalled")
}

/// Live2D Cubism Core is proprietary (Live2D Inc.) and isn't shipped with the app.
/// The user downloads it from Live2D's official site after agreeing to the license.
enum Live2DCore {
    static let downloadURL = URL(string: "https://cubism.live2d.com/sdk-web/cubismcore/live2dcubismcore.min.js")!
    static let licenseURL = URL(string: "https://www.live2d.com/eula/live2d-proprietary-software-license-agreement_en.html")!

    static var fileURL: URL {
        if let override = ProcessInfo.processInfo.environment["BONGOWAIFU_LIVE2D_CORE"] {
            return URL(fileURLWithPath: override)
        }
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("BongoWaifu/Live2D/live2dcubismcore.min.js")
    }

    static var isInstalled: Bool { FileManager.default.fileExists(atPath: fileURL.path) }

    struct InstallError: LocalizedError {
        var errorDescription: String?
    }

    static func install(completion: @escaping @MainActor (Result<Void, Error>) -> Void) {
        URLSession.shared.dataTask(with: downloadURL) { data, response, error in
            let result: Result<Void, Error> = {
                if let error { return .failure(error) }
                guard let data, (response as? HTTPURLResponse)?.statusCode == 200,
                      let text = String(data: data, encoding: .utf8), text.contains("Live2DCubismCore") else {
                    return .failure(InstallError(errorDescription: "The download didn't look like Live2D Cubism Core."))
                }
                do {
                    try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                    try data.write(to: fileURL, options: .atomic)
                    return .success(())
                } catch {
                    return .failure(error)
                }
            }()
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    if case .success = result { NotificationCenter.default.post(name: .live2DCoreInstalled, object: nil) }
                    completion(result)
                }
            }
        }.resume()
    }

    /// Shows the license notice and installs on agreement.
    @MainActor
    static func promptInstall() {
        let alert = NSAlert()
        alert.messageText = "Install Live2D Cubism Core?"
        alert.informativeText = """
            Live2D models need Live2D Cubism Core, a runtime from Live2D Inc. It's proprietary and licensed \
            separately from Bongo Waifu: personal use and small businesses are generally free, but read the \
            license for the exact terms.

            Bongo Waifu will download live2dcubismcore.min.js from Live2D's official site (cubism.live2d.com) \
            into Application Support. By choosing "Agree & Download" you accept the Live2D Proprietary Software \
            License Agreement.
            """
        alert.addButton(withTitle: "Agree & Download")
        alert.addButton(withTitle: "View License")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        switch alert.runModal() {
        case .alertFirstButtonReturn:
            install { result in
                let done = NSAlert()
                switch result {
                case .success:
                    done.messageText = "Live2D Cubism Core installed"
                    done.informativeText = "Live2D characters in your Characters folder are ready to use."
                case .failure(let error):
                    done.messageText = "Couldn't install Live2D Cubism Core"
                    done.informativeText = error.localizedDescription
                }
                NSApp.activate(ignoringOtherApps: true)
                done.runModal()
            }
        case .alertSecondButtonReturn:
            NSWorkspace.shared.open(licenseURL)
        default:
            break
        }
    }
}

/// Last Live2D load error, shown in the menu and over the character.
@MainActor
final class Live2DStatus: ObservableObject {
    static let shared = Live2DStatus()
    @Published var message: String?
}
