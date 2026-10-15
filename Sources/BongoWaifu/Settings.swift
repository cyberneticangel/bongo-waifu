import AppKit
import WaifuCore

enum CompanionSize: String, CaseIterable {
    case small, medium, large

    var scale: CGFloat {
        switch self {
        case .small: return 0.75
        case .medium: return 1
        case .large: return 1.35
        }
    }

    var label: String { rawValue.capitalized }
}

/// Thin typed wrapper over UserDefaults.
final class Settings {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var characterID: String? {
        get { defaults.string(forKey: "characterID") }
        set { defaults.set(newValue, forKey: "characterID") }
    }

    var size: CompanionSize {
        get { defaults.string(forKey: "size").flatMap(CompanionSize.init) ?? .medium }
        set { defaults.set(newValue.rawValue, forKey: "size") }
    }

    var chattiness: Chattiness {
        get { defaults.string(forKey: "chattiness").flatMap(Chattiness.init) ?? .normal }
        set { defaults.set(newValue.rawValue, forKey: "chattiness") }
    }

    var funFacts: Bool {
        get { defaults.object(forKey: "funFacts") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "funFacts") }
    }

    var clickThrough: Bool {
        get { defaults.bool(forKey: "clickThrough") }
        set { defaults.set(newValue, forKey: "clickThrough") }
    }

    /// Per-character "Show Desk" choices from the menu, keyed by character ID.
    var deskOverrides: [String: Bool] {
        get { defaults.dictionary(forKey: "deskOverrides") as? [String: Bool] ?? [:] }
        set { defaults.set(newValue, forKey: "deskOverrides") }
    }

    var windowOrigin: NSPoint? {
        get { defaults.string(forKey: "windowOrigin").map(NSPointFromString) }
        set { defaults.set(newValue.map(NSStringFromPoint), forKey: "windowOrigin") }
    }

    var totalKeys: Int {
        get { defaults.integer(forKey: "totalKeys") }
        set { defaults.set(newValue, forKey: "totalKeys") }
    }

    /// Keys typed today; resets when the stored day changes.
    var todayKeys: Int {
        get { defaults.string(forKey: "todayDate") == Self.today ? defaults.integer(forKey: "todayKeys") : 0 }
        set {
            defaults.set(Self.today, forKey: "todayDate")
            defaults.set(newValue, forKey: "todayKeys")
        }
    }

    private static var today: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }
}
