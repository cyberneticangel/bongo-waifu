import AppKit
import SwiftUI
import WaifuCore

/// Built-in characters plus any custom packs in ~/Library/Application Support/BongoWaifu/Characters.
final class CharacterStore {
    static let builtIns: [WaifuCharacter] = [.sakura, .yuki, .rin, .mochi]

    private(set) var characters: [WaifuCharacter] = CharacterStore.builtIns
    private(set) var loadErrors: [String] = []

    static var packsDirectory: URL {
        if let override = ProcessInfo.processInfo.environment["BONGOWAIFU_PACKS_DIR"] {
            return URL(fileURLWithPath: override, isDirectory: true)
        }
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("BongoWaifu/Characters", isDirectory: true)
    }

    init() { reload() }

    func reload() {
        let fm = FileManager.default
        let dir = Self.packsDirectory
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)

        var custom: [WaifuCharacter] = []
        var errors: [String] = []
        let folders = (try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.isDirectoryKey])) ?? []
        for folder in folders.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            guard (try? folder.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true else { continue }
            do {
                custom.append(try Self.loadPack(at: folder))
            } catch {
                errors.append("\(folder.lastPathComponent): \(error.localizedDescription)")
            }
        }
        characters = Self.builtIns + custom
        loadErrors = errors
    }

    func character(id: String?) -> WaifuCharacter {
        characters.first { $0.id == id } ?? characters[0]
    }

    // MARK: - Pack loading

    struct PackManifest: Decodable {
        var name: String
        var tagline: String?
        var accent: String?
        var bubble: String?
        var scale: Double?
        var funFactIntros: [String]?
        var lines: [String: [String]]?
        var live2d: Live2DManifest?
    }

    struct Live2DManifest: Decodable {
        var model: String?
        var zoom: Double?
        var offsetX: Double?
        var offsetY: Double?
        var expressions: [String: String]?
        var tapMotion: String?
        var desk: Bool?
        var sleeve: String?
        var hand: String?
        var catPaws: Bool?
    }

    struct PackError: LocalizedError {
        var errorDescription: String?
    }

    static func loadPack(at folder: URL) throws -> WaifuCharacter {
        let manifestURL = folder.appendingPathComponent("character.json")
        var manifest = PackManifest(name: folder.lastPathComponent)
        let hasManifest = FileManager.default.fileExists(atPath: manifestURL.path)
        if hasManifest {
            manifest = try JSONDecoder().decode(PackManifest.self, from: Data(contentsOf: manifestURL))
        }
        let art: CharacterArt
        if let modelPath = manifest.live2d?.model ?? findModel3(in: folder) {
            art = .live2d(live2DRef(folder: folder, modelPath: modelPath, manifest.live2d))
        } else {
            guard hasManifest else { throw PackError(errorDescription: "missing character.json (or a Live2D .model3.json)") }
            art = .sprites(try loadSprites(folder))
        }

        var lines: [LineCategory: [String]] = [:]
        for (key, values) in manifest.lines ?? [:] {
            if let category = LineCategory(rawValue: key) { lines[category] = values }
        }

        let isLive2D: Bool = { if case .live2d = art { return true } else { return false } }()
        return WaifuCharacter(
            id: "pack.\(folder.lastPathComponent)",
            name: manifest.name,
            tagline: manifest.tagline ?? (isLive2D ? "Live2D model" : "Custom character"),
            art: art,
            bank: LineBank(lines: lines, funFactIntros: manifest.funFactIntros ?? []),
            accent: manifest.accent.flatMap(Color.init(hexString:)) ?? .pink,
            bubble: manifest.bubble.flatMap(Color.init(hexString:)) ?? .white,
            scale: manifest.scale ?? 1
        )
    }

    /// The first .model3.json at the top of the pack or one folder down (VTube Studio exports nest it).
    static func findModel3(in folder: URL) -> String? {
        let fm = FileManager.default
        let top = (try? fm.contentsOfDirectory(atPath: folder.path)) ?? []
        if let file = top.sorted().first(where: { $0.hasSuffix(".model3.json") }) { return file }
        for sub in top.sorted() {
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: folder.appendingPathComponent(sub).path, isDirectory: &isDir), isDir.boolValue else { continue }
            let inner = (try? fm.contentsOfDirectory(atPath: folder.appendingPathComponent(sub).path)) ?? []
            if let file = inner.sorted().first(where: { $0.hasSuffix(".model3.json") }) { return "\(sub)/\(file)" }
        }
        return nil
    }

    static func live2DRef(folder: URL, modelPath: String, _ m: Live2DManifest?) -> Live2DModelRef {
        var ref = Live2DModelRef(directory: folder, modelPath: modelPath)
        if let zoom = m?.zoom { ref.zoom = zoom }
        if let x = m?.offsetX { ref.offsetX = x }
        if let y = m?.offsetY { ref.offsetY = y }
        ref.expressions = m?.expressions ?? [:]
        ref.tapMotion = m?.tapMotion
        if let desk = m?.desk { ref.desk = desk }
        if let sleeve = m?.sleeve.flatMap(Color.init(hexString:)) { ref.sleeve = sleeve }
        if let hand = m?.hand.flatMap(Color.init(hexString:)) { ref.hand = hand }
        ref.catPaws = m?.catPaws ?? false
        return ref
    }

    static func loadSprites(_ folder: URL) throws -> SpriteSet {
        func image(_ name: String) -> NSImage? {
            NSImage(contentsOf: folder.appendingPathComponent("\(name).png"))
        }
        guard let idle = image("idle") else { throw PackError(errorDescription: "missing idle.png") }

        var expressions: [Mood: NSImage] = [:]
        for expression in Mood.allCases {
            if let img = image("expr_\(expression.rawValue)") { expressions[expression] = img }
        }
        return SpriteSet(
            idle: idle,
            left: image("left") ?? idle,
            right: image("right") ?? image("left") ?? idle,
            both: image("both"),
            sleep: image("sleep"),
            blink: image("blink"),
            expressions: expressions
        )
    }
}
