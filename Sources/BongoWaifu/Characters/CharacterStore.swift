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
    }

    struct PackError: LocalizedError {
        var errorDescription: String?
    }

    static func loadPack(at folder: URL) throws -> WaifuCharacter {
        let manifestURL = folder.appendingPathComponent("character.json")
        guard let data = try? Data(contentsOf: manifestURL) else {
            throw PackError(errorDescription: "missing character.json")
        }
        let manifest = try JSONDecoder().decode(PackManifest.self, from: data)

        func image(_ name: String) -> NSImage? {
            NSImage(contentsOf: folder.appendingPathComponent("\(name).png"))
        }
        guard let idle = image("idle") else { throw PackError(errorDescription: "missing idle.png") }

        var expressions: [Mood: NSImage] = [:]
        for expression in Mood.allCases {
            if let img = image("expr_\(expression.rawValue)") { expressions[expression] = img }
        }
        let sprites = SpriteSet(
            idle: idle,
            left: image("left") ?? idle,
            right: image("right") ?? image("left") ?? idle,
            both: image("both"),
            sleep: image("sleep"),
            blink: image("blink"),
            expressions: expressions
        )

        var lines: [LineCategory: [String]] = [:]
        for (key, values) in manifest.lines ?? [:] {
            if let category = LineCategory(rawValue: key) { lines[category] = values }
        }

        return WaifuCharacter(
            id: "pack.\(folder.lastPathComponent)",
            name: manifest.name,
            tagline: manifest.tagline ?? "Custom character",
            art: .sprites(sprites),
            bank: LineBank(lines: lines, funFactIntros: manifest.funFactIntros ?? []),
            accent: manifest.accent.flatMap(Color.init(hexString:)) ?? .pink,
            bubble: manifest.bubble.flatMap(Color.init(hexString:)) ?? .white,
            scale: manifest.scale ?? 1
        )
    }
}
