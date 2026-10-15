import Foundation

/// A character's voice: lines per category, falling back to the generic bank for anything missing.
public struct LineBank: Sendable {
    public var lines: [LineCategory: [String]]
    /// In-character lead-ins for the shared fun-fact pool ("Fun fact!", "Trivia.", ...).
    public var funFactIntros: [String]

    public init(lines: [LineCategory: [String]] = [:], funFactIntros: [String] = []) {
        self.lines = lines
        self.funFactIntros = funFactIntros
    }

    public func candidates(for category: LineCategory) -> [String] {
        if let own = lines[category], !own.isEmpty { return own }
        return GenericLines.lines[category] ?? []
    }

    public var intros: [String] {
        funFactIntros.isEmpty ? GenericLines.funFactIntros : funFactIntros
    }
}
