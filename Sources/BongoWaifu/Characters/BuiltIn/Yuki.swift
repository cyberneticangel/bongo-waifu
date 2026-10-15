import SwiftUI
import WaifuCore

extension WaifuCharacter {
    /// Kuudere librarian. Calm, deadpan, quietly impressed.
    static let yuki = WaifuCharacter(
        id: "builtin.yuki",
        name: "Yuki",
        tagline: "Deadpan kuudere",
        art: .vector(Appearance(
            skin: Color(hex: 0xFCEDE6), skinShade: Color(hex: 0xEACFC6),
            hair: Color(hex: 0xC9CFE8), hairShade: Color(hex: 0x8E95BE), hairShine: Color(hex: 0xEEF1FF),
            eye: Color(hex: 0x5AA9E6), eyeDeep: Color(hex: 0x23497A),
            outfit: Color(hex: 0x2E3557), outfitShade: Color(hex: 0x1E2340), outfitAccent: Color(hex: 0xE9EEFF),
            hairStyle: .bob, outfitStyle: .sweater,
            accessories: [.snowflakeClip], accessoryColor: Color(hex: 0x9FD3FF)
        )),
        bank: LineBank(lines: [
            .greeting: [
                "...Oh. You're here. Good.",
                "I'll be observing. Proceed.",
                "Hello. Let's be productive.",
            ],
            .encouragement: [
                "Your efficiency is... acceptable. Good.",
                "Continue. I'm watching. Supportively.",
                "Posture. Check it.",
                "You haven't had water in a while. Probably.",
                "...Not bad.",
                "Steady pace. I approve.",
            ],
            .fast: [
                "...Fast. Noted.",
                "Your WPM is rising. Interesting.",
                "I am, statistically, impressed.",
            ],
            .streak100: ["100 consecutive keystrokes. Logged.", "A streak. Continue."],
            .streak500: ["500. ...That's actually good.", "Flow state detected."],
            .streak1000: [
                "1000 keys. I am... genuinely impressed.",
                "Remarkable. Don't let it go to your head.",
            ],
            .backspaceSpree: [
                "Backspace count: high. Thought quality: improving, hopefully.",
                "Deleting is also writing.",
                "...Rough sentence?",
            ],
            .enterSpam: ["Vertical whitespace. Bold choice.", "Many newlines. Why."],
            .idle: ["...I'll read a book.", "Silence. Pleasant.", "Resting. Wake me if needed."],
            .wakeUp: ["Welcome back.", "...You returned. Good.", "I wasn't asleep. I was thinking with my eyes closed."],
            .lateNight: [
                "It's past 1 AM. Sleep is non-negotiable.",
                "Late. Your cognition drops ~25% when tired. Fact.",
                "Night. Quiet. Finish soon.",
            ],
            .petted: [
                "...Mm. Acceptable.",
                "...Do that again. For science.",
                "W-why. ...Fine.",
                "...Hm.",
            ],
            .funFact: [
                "Trivia. Libraries in ancient Alexandria may have held hundreds of thousands of scrolls.",
                "Fact. Snowflakes are usually six-sided because of how water molecules bond.",
            ],
        ], funFactIntros: ["Trivia.", "Fact.", "Relevant information:", "You may find this interesting."]),
        accent: Color(hex: 0x4A78C0),
        bubble: Color(hex: 0xF4F7FF)
    )
}
