import Foundation

public enum TypingEvent: Equatable, Sendable {
    case streak(Int)
    case speedUp(SpeedTier)
    case backspaceSpree
    case enterSpam
    case idle
    case wake
}

/// Tracks typing rhythm (never content) and turns it into higher-level events.
public struct TypingStats: Sendable {
    public static let streakThresholds = [100, 250, 500, 1000]
    public static let wpmWindow: TimeInterval = 6
    public static let streakBreak: TimeInterval = 5
    public static let backspaceSpreeLength = 8
    public static let enterSpamCount = 4
    public static let enterSpamWindow: TimeInterval = 2.5
    public static let speedUpRepeat: TimeInterval = 25

    public var idleAfter: TimeInterval
    public private(set) var sessionKeys = 0
    public private(set) var streak = 0
    public private(set) var tier: SpeedTier = .slow
    public private(set) var isIdle = false
    public private(set) var lastKey: Date?

    private var recent: [Date] = []
    private var enters: [Date] = []
    private var backspaceRun = 0
    private var lastSpeedUp: [SpeedTier: Date] = [:]

    public init(idleAfter: TimeInterval = 60) {
        self.idleAfter = idleAfter
    }

    /// Approximate words per minute over the last few seconds (5 keystrokes = 1 word).
    public func wpm(at now: Date) -> Double {
        let count = recent.filter { now.timeIntervalSince($0) <= Self.wpmWindow }.count
        return Double(count) / Self.wpmWindow * 60 / 5
    }

    public func isTyping(at now: Date) -> Bool {
        guard let lastKey else { return false }
        return now.timeIntervalSince(lastKey) < 8
    }

    public mutating func record(_ kind: KeyKind, at now: Date) -> [TypingEvent] {
        var events: [TypingEvent] = []

        if isIdle {
            isIdle = false
            events.append(.wake)
        }
        if let lastKey, now.timeIntervalSince(lastKey) > Self.streakBreak {
            streak = 0
        }
        lastKey = now
        sessionKeys += 1
        streak += 1

        if let milestone = Self.milestone(for: streak) {
            events.append(.streak(milestone))
        }

        switch kind {
        case .backspace:
            backspaceRun += 1
            if backspaceRun == Self.backspaceSpreeLength { events.append(.backspaceSpree) }
        case .enter:
            backspaceRun = 0
            enters.append(now)
            enters.removeAll { now.timeIntervalSince($0) > Self.enterSpamWindow }
            if enters.count == Self.enterSpamCount { events.append(.enterSpam) }
        case .normal:
            backspaceRun = 0
        }

        recent.append(now)
        recent.removeAll { now.timeIntervalSince($0) > Self.wpmWindow }
        events += updateTier(at: now)
        return events
    }

    /// Call periodically (about once a second) so idle and speed decay are noticed without keystrokes.
    public mutating func tick(at now: Date) -> [TypingEvent] {
        recent.removeAll { now.timeIntervalSince($0) > Self.wpmWindow }
        _ = updateTier(at: now)
        if !isIdle, let lastKey, now.timeIntervalSince(lastKey) >= idleAfter {
            isIdle = true
            return [.idle]
        }
        return []
    }

    static func milestone(for streak: Int) -> Int? {
        if streakThresholds.contains(streak) { return streak }
        if streak > 1000, streak % 1000 == 0 { return streak }
        return nil
    }

    private mutating func updateTier(at now: Date) -> [TypingEvent] {
        let newTier = SpeedTier.forWPM(wpm(at: now))
        defer { tier = newTier }
        guard newTier > tier, newTier >= .fast else { return [] }
        if let last = lastSpeedUp[newTier], now.timeIntervalSince(last) < Self.speedUpRepeat { return [] }
        lastSpeedUp[newTier] = now
        return [.speedUp(newTier)]
    }
}
