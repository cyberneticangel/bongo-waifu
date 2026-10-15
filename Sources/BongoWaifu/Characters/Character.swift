import AppKit
import SwiftUI
import WaifuCore

enum HairStyle {
    case long, twinTails, bob, fluffy
}

enum OutfitStyle {
    case sailor, sweater, hoodie, catHoodie
}

enum Accessory: Hashable {
    case ahoge
    case catEars
    case tail
    case ribbons
    case starClip
    case snowflakeClip
    case headset
}

/// Parameters for the shared vector renderer.
struct Appearance {
    var skin: Color
    var skinShade: Color
    var hair: Color
    var hairShade: Color
    var hairShine: Color
    var eye: Color
    var eyeDeep: Color
    var outfit: Color
    var outfitShade: Color
    var outfitAccent: Color
    var hairStyle: HairStyle
    var outfitStyle: OutfitStyle
    var accessories: Set<Accessory> = []
    var accessoryColor: Color = .white
    var fang = false
}

/// PNG frames for a custom character pack.
struct SpriteSet {
    var idle: NSImage
    var left: NSImage
    var right: NSImage
    var both: NSImage?
    var sleep: NSImage?
    var blink: NSImage?
    var expressions: [Mood: NSImage] = [:]
}

/// A Live2D (Cubism 3/4) model inside a character pack, plus how to frame and drive it.
struct Live2DModelRef: Equatable {
    var directory: URL
    /// The .model3.json, relative to `directory`.
    var modelPath: String
    /// Visible artwork height as a multiple of the view height; larger shows less of the body.
    /// nil fits the artwork's width to the view instead, which frames most models well.
    var zoom: Double?
    var offsetX: Double = 0
    var offsetY: Double = 0
    /// Mood name → expression name from the model3.json.
    var expressions: [String: String] = [:]
    var tapMotion: String?
    var desk = true
    var sleeve = Color(hex: 0xFFFFFF)
    var hand = Color(hex: 0xFFE6D8)
    var catPaws = false
}

enum CharacterArt {
    case vector(Appearance)
    case sprites(SpriteSet)
    case live2d(Live2DModelRef)
}

struct WaifuCharacter: Identifiable {
    var id: String
    var name: String
    var tagline: String
    var art: CharacterArt
    var bank: LineBank
    var accent: Color
    var bubble: Color = .white
    var scale: Double = 1
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }

    init?(hexString: String) {
        let cleaned = hexString.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "#", with: "")
        guard cleaned.count == 6, let value = UInt32(cleaned, radix: 16) else { return nil }
        self.init(hex: value)
    }
}
