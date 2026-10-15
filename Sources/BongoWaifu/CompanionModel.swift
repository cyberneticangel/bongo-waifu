import Foundation
import SwiftUI
import WaifuCore

struct Bubble: Equatable {
    let id = UUID()
    let text: String
    let start: Date
}

struct ActiveEffect: Equatable {
    let id = UUID()
    let effect: Effect
    let start: Date
}

/// All live state for the on-screen companion. Input and timers feed in; views observe.
@MainActor
final class CompanionModel: ObservableObject {
    @Published private(set) var character: WaifuCharacter
    @Published var size: CompanionSize { didSet { settings.size = size } }
    @Published private(set) var paw: PawState = .up
    @Published private(set) var lastTap = Date.distantPast
    @Published private(set) var expression: Mood = .neutral
    @Published private(set) var isSleeping = false
    @Published private(set) var tier: SpeedTier = .slow
    @Published private(set) var bubble: Bubble?
    @Published private(set) var effect: ActiveEffect?

    private(set) var stats = TypingStats()
    /// Live2D-style animation state for the vector renderer (head angles, physics, gaze).
    let rig = Rig()
    private let engine: ReactionEngine
    private let settings: Settings
    private var nextPawLeft = true
    private var pawReset: DispatchWorkItem?
    private var expressionReset: DispatchWorkItem?
    private var bubbleReset: DispatchWorkItem?
    private var unsavedKeys = 0

    var totalKeys: Int { settings.totalKeys + unsavedKeys }
    var todayKeys: Int { settings.todayKeys + unsavedKeys }
    var currentWPM: Int { Int(stats.wpm(at: Date()).rounded()) }

    init(character: WaifuCharacter, settings: Settings, random: @escaping () -> Double = { Double.random(in: 0..<1) }) {
        self.character = character
        self.settings = settings
        self.size = settings.size
        self.engine = ReactionEngine(bank: character.bank, chattiness: settings.chattiness,
                                     funFactsEnabled: settings.funFacts, random: random)
    }

    // MARK: - Configuration

    var chattiness: Chattiness {
        get { engine.chattiness }
        set {
            engine.chattiness = newValue
            settings.chattiness = newValue
            if newValue == .silent { dismissBubble() }
        }
    }

    var funFacts: Bool {
        get { engine.funFactsEnabled }
        set { engine.funFactsEnabled = newValue; settings.funFacts = newValue }
    }

    /// Demo-only knobs: faster conversation and a shorter wait before dozing off.
    func useDemoPacing(_ pacing: Double, idleAfter: TimeInterval) {
        engine.pacing = pacing
        stats.idleAfter = idleAfter
    }

    func setCharacter(_ new: WaifuCharacter) {
        character = new
        engine.bank = new.bank
        settings.characterID = new.id
        dismissBubble()
        greet()
    }

    // MARK: - Input

    func greet() {
        apply(engine.greet(now: Date()))
    }

    func keyPressed(_ kind: KeyKind, isRepeat: Bool) {
        let now = Date()
        tap(kind == .enter ? .both : alternatePaw())
        // Held keys still animate, but only count for stats when it's Backspace being held.
        guard !isRepeat || kind == .backspace else { return }

        unsavedKeys += 1
        if unsavedKeys >= 25 { saveStats() }

        for event in stats.record(kind, at: now) {
            if event == .wake { isSleeping = false }
            apply(engine.react(to: event, now: now))
        }
        tier = stats.tier
    }

    func mouseClicked() {
        tap(.both)
    }

    func petted() {
        if isSleeping {
            isSleeping = false
        }
        apply(engine.petted(now: Date()))
    }

    /// Called about once a second.
    func tick() {
        let now = Date()
        for event in stats.tick(at: now) {
            if event == .idle { isSleeping = true }
            apply(engine.react(to: event, now: now))
        }
        tier = stats.tier
        if let reaction = engine.ambient(now: now, isTyping: stats.isTyping(at: now)) {
            apply(reaction)
        }
    }

    func dismissBubble() {
        bubbleReset?.cancel()
        withAnimation(.easeIn(duration: 0.15)) { bubble = nil }
    }

    func saveStats() {
        guard unsavedKeys > 0 else { return }
        settings.totalKeys += unsavedKeys
        settings.todayKeys += unsavedKeys
        unsavedKeys = 0
    }

    // MARK: - Reactions

    private func alternatePaw() -> PawState {
        defer { nextPawLeft.toggle() }
        return nextPawLeft ? .left : .right
    }

    private func tap(_ state: PawState) {
        paw = state
        lastTap = Date()
        pawReset?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.paw = .up }
        pawReset = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: work)
    }

    private func apply(_ reaction: Reaction) {
        if let new = reaction.expression {
            setExpression(new, for: reaction.expressionDuration)
        }
        if let effect = reaction.effect {
            self.effect = ActiveEffect(effect: effect, start: Date())
        }
        if let line = reaction.line {
            say(line)
        }
    }

    private func setExpression(_ new: Mood, for duration: TimeInterval) {
        expressionReset?.cancel()
        expression = new
        // Zero duration means "stay until something else happens" (used for falling asleep).
        guard duration > 0 else { return }
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.expression = self.isSleeping ? .sleepy : .neutral
        }
        expressionReset = work
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: work)
    }

    private func say(_ line: String) {
        bubbleReset?.cancel()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
            bubble = Bubble(text: line, start: Date())
        }
        let readingTime = max(3.5, Double(line.count) * 0.065 + 2.5)
        let work = DispatchWorkItem { [weak self] in self?.dismissBubble() }
        bubbleReset = work
        DispatchQueue.main.asyncAfter(deadline: .now() + readingTime, execute: work)
    }
}
