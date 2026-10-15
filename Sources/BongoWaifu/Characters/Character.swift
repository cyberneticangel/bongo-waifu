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

enum CharacterArt {
    case vector(Appearance)
    case sprites(SpriteSet)
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
