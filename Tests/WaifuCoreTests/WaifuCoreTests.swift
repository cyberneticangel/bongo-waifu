import Foundation
import Testing
@testable import WaifuCore

private let t0 = Date(timeIntervalSince1970: 1_700_000_000)

@Suite struct TypingStatsTests {
    @Test func wpmCountsKeysInWindow() {
        var stats = TypingStats()
        // 30 keys over 3 seconds -> 30 keys / 6s window * 60 / 5 = 60 WPM
        for i in 0..<30 { _ = stats.record(.normal, at: t0.addingTimeInterval(Double(i) * 0.1)) }
        #expect(stats.wpm(at: t0.addingTimeInterval(3)) == 60)
        #expect(stats.wpm(at: t0.addingTimeInterval(20)) == 0)
    }

    @Test func streakMilestonesFireOnce() {
        var stats = TypingStats()
        var events: [TypingEvent] = []
        for i in 0..<1000 { events += stats.record(.normal, at: t0.addingTimeInterval(Double(i) * 0.2)) }
        let streaks = events.compactMap { if case .streak(let n) = $0 { n } else { nil } }
        #expect(streaks == [100, 250, 500, 1000])
    }

    @Test func pauseResetsStreak() {
        var stats = TypingStats()
        for i in 0..<50 { _ = stats.record(.normal, at: t0.addingTimeInterval(Double(i) * 0.2)) }
        _ = stats.record(.normal, at: t0.addingTimeInterval(100))
        #expect(stats.streak == 1)
        #expect(stats.sessionKeys == 51)
    }

    @Test func backspaceSpree() {
        var stats = TypingStats()
        var events: [TypingEvent] = []
        for i in 0..<12 { events += stats.record(.backspace, at: t0.addingTimeInterval(Double(i))) }
        #expect(events.filter { $0 == .backspaceSpree }.count == 1)
    }

    @Test func enterSpam() {
        var stats = TypingStats()
        var events: [TypingEvent] = []
        for i in 0..<4 { events += stats.record(.enter, at: t0.addingTimeInterval(Double(i) * 0.3)) }
        #expect(events.contains(.enterSpam))
    }

    @Test func idleAndWake() {
        var stats = TypingStats(idleAfter: 60)
        _ = stats.record(.normal, at: t0)
        #expect(stats.tick(at: t0.addingTimeInterval(30)).isEmpty)
        #expect(stats.tick(at: t0.addingTimeInterval(61)) == [.idle])
        #expect(stats.tick(at: t0.addingTimeInterval(70)).isEmpty)
        #expect(stats.record(.normal, at: t0.addingTimeInterval(80)).contains(.wake))
    }

    @Test func speedUpEvents() {
        var stats = TypingStats()
        var events: [TypingEvent] = []
        // 10 keys/second = 120 WPM once the window fills
        for i in 0..<80 { events += stats.record(.normal, at: t0.addingTimeInterval(Double(i) * 0.1)) }
        #expect(events.contains(.speedUp(.fast)))
        #expect(events.contains(.speedUp(.blazing)))
        #expect(stats.tier == .blazing)
    }
}

@Suite struct ReactionEngineTests {
    func engine(_ chattiness: Chattiness = .normal, random: @escaping () -> Double = { 0 }) -> ReactionEngine {
        ReactionEngine(
            bank: LineBank(lines: [.petted: ["a", "b", "c"], .fast: ["zoom"]]),
            chattiness: chattiness,
            calendar: Calendar(identifier: .gregorian),
            random: random
        )
    }

    @Test func cooldownLimitsNormalLines() {
        let e = engine()
        #expect(e.react(to: .speedUp(.fast), now: t0).line == "zoom")
        #expect(e.react(to: .speedUp(.fast), now: t0.addingTimeInterval(10)).line == nil)
        #expect(e.react(to: .speedUp(.fast), now: t0.addingTimeInterval(10)).expression == .excited)
        #expect(e.react(to: .speedUp(.fast), now: t0.addingTimeInterval(60)).line == "zoom")
    }

    @Test func importantLinesUseShortGap() {
        let e = engine()
        _ = e.react(to: .speedUp(.fast), now: t0)
        #expect(e.react(to: .streak(100), now: t0.addingTimeInterval(2)).line == nil)
        #expect(e.react(to: .streak(100), now: t0.addingTimeInterval(7)).line != nil)
    }

    @Test func silentNeverSpeaks() {
        let e = engine(.silent)
        #expect(e.greet(now: t0).line == nil)
        #expect(e.petted(now: t0).line == nil)
        #expect(e.petted(now: t0).expression == .blush)
    }

    @Test func avoidsRecentRepeats() {
        let e = engine()
        var seen: [String] = []
        for i in 0..<3 {
            if let line = e.petted(now: t0.addingTimeInterval(Double(i) * 10)).line { seen.append(line) }
        }
        #expect(Set(seen).count == 3)
    }

    @Test func fallsBackToGenericLines() {
        let e = engine()
        #expect(GenericLines.lines[.wakeUp]!.contains(e.react(to: .wake, now: t0).line!))
    }

    @Test func ambientWaitsThenSharesFact() {
        let e = engine(.chatty)
        #expect(e.ambient(now: t0, isTyping: true) == nil)
        #expect(e.ambient(now: t0.addingTimeInterval(5), isTyping: true) == nil)
        let r = e.ambient(now: t0.addingTimeInterval(60), isTyping: true)
        #expect(r?.line?.hasPrefix(GenericLines.funFactIntros[0]) == true)
        #expect(e.ambient(now: t0.addingTimeInterval(200), isTyping: false) == nil)
    }
}
