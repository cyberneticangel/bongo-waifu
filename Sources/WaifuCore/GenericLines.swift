import Foundation

/// Fallback lines for characters (usually custom packs) that don't define a category.
public enum GenericLines {
    public static let funFactIntros = ["Fun fact!", "Did you know?", "Random trivia:", "Hey, fun fact:"]

    public static let lines: [LineCategory: [String]] = [
        .greeting: [
            "Hi! I'll keep you company while you type~",
            "Ready when you are!",
            "Let's get some work done together!",
        ],
        .encouragement: [
            "You're doing great!",
            "Keep going, I believe in you!",
            "Nice rhythm!",
            "Don't forget to stretch your wrists!",
            "Remember to drink some water~",
            "This is going well, I can tell.",
        ],
        .fast: [
            "Whoa, so fast!",
            "My paws can barely keep up!",
            "You're on fire!",
        ],
        .streak100: ["100 keys without stopping!", "Nice streak!"],
        .streak500: ["500 key streak! Amazing!", "You're in the zone!"],
        .streak1000: ["A THOUSAND keys?! Legendary!", "Unstoppable!"],
        .backspaceSpree: [
            "Backspace, backspace, backspace...",
            "Rewriting history?",
            "It's okay, first drafts are allowed to be bad!",
        ],
        .enterSpam: ["So many new lines!", "Enter, enter, enter!"],
        .idle: ["I'll just rest my eyes...", "Taking a break? Me too...", "Zzz..."],
        .wakeUp: ["Oh! You're back!", "Welcome back!", "I wasn't sleeping! ...okay maybe a little."],
        .lateNight: [
            "It's really late... don't stay up too long, okay?",
            "Night owl mode activated.",
            "Sleep is important too, you know!",
        ],
        .petted: ["Ehehe~", "That tickles!", "Hehe, thanks!", "*happy noises*"],
    ]
}
