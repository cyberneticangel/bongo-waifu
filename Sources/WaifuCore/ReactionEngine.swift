import Foundation

/// Decides how the character reacts to typing events: expression and effect right away,
/// speech bubbles rate-limited by chattiness and never repeating recent lines.
public final class ReactionEngine {
    public static let importantGap: TimeInterval = 6
    public static let petGap: TimeInterval = 2.5
    static let recentMemory = 12

    public var bank: LineBank
    public var chattiness: Chattiness
    public var funFactsEnabled: Bool
    /// Multiplies the chattiness cooldowns; below 1 speeds conversation up (used by the demo recorder).
    public var pacing: Double = 1
    public private(set) var lastBubble: Date?

    private var recentLines: [String] = []
    private var lastPetLine: Date?
    private let random: () -> Double
    private let calendar: Calendar

    public init(
        bank: LineBank,
        chattiness: Chattiness = .normal,
        funFactsEnabled: Bool = true,
        calendar: Calendar = .current,
        random: @escaping () -> Double = { Double.random(in: 0..<1) }
    ) {
        self.bank = bank
        self.chattiness = chattiness
        self.funFactsEnabled = funFactsEnabled
        self.calendar = calendar
        self.random = random
    }

    public func greet(now: Date) -> Reaction {
        let category: LineCategory = isLateNight(now) ? .lateNight : .greeting
        return Reaction(expression: .happy, expressionDuration: 2.5,
                        line: speak(category, now: now, priority: .forced), effect: .sparkles)
    }

    public func react(to event: TypingEvent, now: Date) -> Reaction {
        switch event {
        case .streak(let n):
            let category: LineCategory = n >= 1000 ? .streak1000 : n >= 500 ? .streak500 : .streak100
            return Reaction(expression: .excited, expressionDuration: 2.2,
                            line: speak(category, now: now, priority: .important), effect: .sparkles)
        case .speedUp(let tier):
            return Reaction(expression: tier == .blazing ? .surprised : .excited, expressionDuration: 1.5,
                            line: speak(.fast, now: now, priority: .normal(tier == .blazing ? 0.8 : 0.5)),
                            effect: tier == .blazing ? .sweat : .notes)
        case .backspaceSpree:
            return Reaction(expression: .annoyed, expressionDuration: 2,
                            line: speak(.backspaceSpree, now: now, priority: .normal(0.8)), effect: .sweat)
        case .enterSpam:
            return Reaction(expression: .surprised, expressionDuration: 1.5,
                            line: speak(.enterSpam, now: now, priority: .normal(0.7)), effect: .question)
        case .idle:
            return Reaction(expression: .sleepy, expressionDuration: 0,
                            line: speak(.idle, now: now, priority: .normal(0.6)))
        case .wake:
            let category: LineCategory = isLateNight(now) && random() < 0.6 ? .lateNight : .wakeUp
            return Reaction(expression: .surprised, expressionDuration: 1.2,
                            line: speak(category, now: now, priority: .important))
        }
    }

    public func petted(now: Date) -> Reaction {
        var line: String?
        if lastPetLine.map({ now.timeIntervalSince($0) >= Self.petGap }) ?? true {
            line = speak(.petted, now: now, priority: .forced)
            if line != nil { lastPetLine = now }
        }
        return Reaction(expression: .blush, expressionDuration: 2.2, line: line, effect: .hearts)
    }

    /// Occasional unprompted chatter (encouragement or a fun fact) while the user is typing.
    public func ambient(now: Date, isTyping: Bool) -> Reaction? {
        guard isTyping, chattiness != .silent else { return nil }
        let interval = chattiness.cooldown * 1.5 * pacing
        if let lastBubble, now.timeIntervalSince(lastBubble) < interval { return nil }
        if lastBubble == nil {
            // Treat app start as the last bubble so the first ambient line isn't immediate.
            lastBubble = now
            return nil
        }
        if funFactsEnabled && random() < 0.6 {
            guard let fact = funFact() else { return nil }
            lastBubble = now
            remember(fact)
            return Reaction(expression: .smug, expressionDuration: 2, line: fact, effect: .sparkles)
        }
        guard let line = speak(.encouragement, now: now, priority: .forced) else { return nil }
        return Reaction(expression: .happy, expressionDuration: 1.8, line: line)
    }

    // MARK: - Line selection

    enum Priority {
        case forced
        case important
        case normal(Double)
    }

    func speak(_ category: LineCategory, now: Date, priority: Priority) -> String? {
        guard chattiness != .silent else { return nil }
        let elapsed = lastBubble.map { now.timeIntervalSince($0) } ?? .infinity
        switch priority {
        case .forced:
            break
        case .important:
            guard elapsed >= Self.importantGap else { return nil }
        case .normal(let probability):
            guard elapsed >= chattiness.cooldown * pacing, random() < probability else { return nil }
        }
        guard let line = pick(bank.candidates(for: category)) else { return nil }
        lastBubble = now
        remember(line)
        return line
    }

    func funFact() -> String? {
        let own = bank.lines[.funFact] ?? []
        if !own.isEmpty && random() < 0.4, let line = pick(own) { return line }
        guard let fact = pick(FunFacts.all), let intro = pick(bank.intros, avoidRecent: false) else { return nil }
        return "\(intro) \(fact)"
    }

    func pick(_ options: [String], avoidRecent: Bool = true) -> String? {
        guard !options.isEmpty else { return nil }
        let fresh = avoidRecent ? options.filter { line in !recentLines.contains { $0.contains(line) } } : options
        let pool = fresh.isEmpty ? options : fresh
        let index = min(Int(random() * Double(pool.count)), pool.count - 1)
        return pool[index]
    }

    private func remember(_ line: String) {
        recentLines.append(line)
        if recentLines.count > Self.recentMemory { recentLines.removeFirst() }
    }

    private func isLateNight(_ now: Date) -> Bool {
        (1..<5).contains(calendar.component(.hour, from: now))
    }
}
