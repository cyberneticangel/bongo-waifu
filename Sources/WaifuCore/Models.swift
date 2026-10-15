import Foundation

/// The only thing the app ever learns about a keystroke. Typed characters are never read or stored.
public enum KeyKind: Sendable {
    case normal, backspace, enter
}

public enum PawState: Sendable {
    case up, left, right, both
}

public enum Mood: String, CaseIterable, Codable, Sendable {
    case neutral, happy, excited, surprised, annoyed, sleepy, smug, blush
}

public enum Effect: String, CaseIterable, Codable, Sendable {
    case sparkles, hearts, sweat, anger, question, notes
}

public enum SpeedTier: Int, Comparable, Sendable {
    case slow, normal, fast, blazing

    public static func < (a: SpeedTier, b: SpeedTier) -> Bool { a.rawValue < b.rawValue }

    public static func forWPM(_ wpm: Double) -> SpeedTier {
        switch wpm {
        case ..<10: return .slow
        case ..<45: return .normal
        case ..<80: return .fast
        default: return .blazing
        }
    }
}

public enum LineCategory: String, CaseIterable, Codable, Sendable {
    case greeting
    case encouragement
    case fast
    case streak100
    case streak500
    case streak1000
    case backspaceSpree
    case enterSpam
    case idle
    case wakeUp
    case lateNight
    case petted
    case funFact
}

public enum Chattiness: String, CaseIterable, Codable, Sendable {
    case silent, quiet, normal, chatty

    /// Minimum seconds between unprompted speech bubbles.
    public var cooldown: TimeInterval {
        switch self {
        case .silent: return .infinity
        case .quiet: return 150
        case .normal: return 50
        case .chatty: return 18
        }
    }

    public var label: String { rawValue.capitalized }
}

public struct Reaction: Equatable, Sendable {
    public var expression: Mood?
    public var expressionDuration: TimeInterval
    public var line: String?
    public var effect: Effect?

    public init(expression: Mood? = nil, expressionDuration: TimeInterval = 1.6, line: String? = nil, effect: Effect? = nil) {
        self.expression = expression
        self.expressionDuration = expressionDuration
        self.line = line
        self.effect = effect
    }
}
