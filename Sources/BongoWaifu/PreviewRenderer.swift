import AppKit
import SwiftUI
import WaifuCore

/// `BongoWaifu --render-previews <dir>` writes a contact sheet per character (every mood and paw pose)
/// so the art can be checked without watching the live overlay.
@MainActor
enum PreviewRenderer {
    static func run(outputDirectory: String) {
        let dir = URL(fileURLWithPath: outputDirectory, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let longAgo = Date.distantPast
        for character in CharacterStore().characters {
            let poses: [(String, VectorWaifuView.Pose)] =
                Mood.allCases.map { ($0.rawValue, .init(paw: .up, expression: $0, sleeping: false, tier: .normal, lastTap: longAgo)) }
                + [
                    ("left paw", .init(paw: .left, expression: .happy, sleeping: false, tier: .fast, lastTap: Date())),
                    ("both paws", .init(paw: .both, expression: .excited, sleeping: false, tier: .blazing, lastTap: Date())),
                    ("asleep", .init(paw: .up, expression: .sleepy, sleeping: true, tier: .slow, lastTap: longAgo)),
                ]
            let sheet = VStack(alignment: .leading, spacing: 8) {
                Text("\(character.name) — \(character.tagline)").font(.title2.bold())
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(240)), count: 4), spacing: 8) {
                    ForEach(poses.indices, id: \.self) { i in
                        VStack(spacing: 2) {
                            artView(character, poses[i].1).frame(width: 240, height: 240)
                            Text(poses[i].0).font(.caption)
                        }
                    }
                }
            }
            .padding(16)
            .background(Color(hex: 0xEEF0F5))

            let renderer = ImageRenderer(content: sheet)
            renderer.scale = 1.5
            guard let image = renderer.nsImage, let tiff = image.tiffRepresentation,
                  let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) else { continue }
            let file = dir.appendingPathComponent("\(character.id).png")
            try? png.write(to: file)
            print(file.path)
        }

        // A full companion with a speech bubble, as it appears on screen.
        let settings = Settings()
        let model = CompanionModel(character: .rin, settings: settings)
        model.greet()
        let renderer = ImageRenderer(content: CompanionView(model: model).background(Color(hex: 0x6A7FA8)))
        renderer.scale = 2
        if let image = renderer.nsImage, let tiff = image.tiffRepresentation,
           let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) {
            let file = dir.appendingPathComponent("companion.png")
            try? png.write(to: file)
            print(file.path)
        }
    }

    /// `BongoWaifu --export-pack <dir>` writes a built-in character as a ready-to-edit custom pack:
    /// PNG frames plus character.json. Handy as a template for drawing your own.
    static func exportPack(to outputDirectory: String, characterID: String = WaifuCharacter.mochi.id) {
        let dir = URL(fileURLWithPath: outputDirectory, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let character = CharacterStore.builtIns.first { $0.id == characterID } ?? .mochi
        guard case .vector(let look) = character.art else { return }
        let still = Date.distantPast

        func pose(_ paw: PawState, _ mood: Mood = .neutral, sleeping: Bool = false) -> VectorWaifuView.Pose {
            .init(paw: paw, expression: mood, sleeping: sleeping, tier: .normal, lastTap: still)
        }
        var frames: [(String, VectorWaifuView.Pose)] = [
            ("idle", pose(.up)), ("left", pose(.left)), ("right", pose(.right)), ("both", pose(.both)),
            ("sleep", pose(.up, .sleepy, sleeping: true)),
        ]
        frames += Mood.allCases.filter { $0 != .neutral }.map { ("expr_\($0.rawValue)", pose(.up, $0)) }

        for (name, pose) in frames {
            let renderer = ImageRenderer(content: VectorWaifuView(look: look, pose: pose).frame(width: 240, height: 240))
            renderer.scale = 2
            guard let image = renderer.nsImage, let tiff = image.tiffRepresentation,
                  let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) else { continue }
            try? png.write(to: dir.appendingPathComponent("\(name).png"))
        }

        var lines: [String: [String]] = [:]
        for (category, values) in character.bank.lines { lines[category.rawValue] = values }
        let manifest: [String: Any] = [
            "name": "\(character.name) (Pack)",
            "tagline": "Exported template — edit me!",
            "accent": "#C48A3C",
            "bubble": "#FFFBF2",
            "funFactIntros": character.bank.funFactIntros,
            "lines": lines,
        ]
        if let json = try? JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys]) {
            try? json.write(to: dir.appendingPathComponent("character.json"))
        }
        print(dir.path)
    }

    @ViewBuilder
    private static func artView(_ c: WaifuCharacter, _ pose: VectorWaifuView.Pose) -> some View {
        ZStack {
            switch c.art {
            case .vector(let look): VectorWaifuView(look: look, pose: pose)
            case .sprites(let sprites): SpriteWaifuView(sprites: sprites, pose: pose)
            }
            EffectsLayer(effect: nil, sleeping: pose.sleeping, tier: pose.tier)
        }
    }
}
