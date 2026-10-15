import SwiftUI
import WaifuCore

extension WaifuCharacter {
    /// Genki cheerleader. Pink hair, sailor uniform, endless energy.
    static let sakura = WaifuCharacter(
        id: "builtin.sakura",
        name: "Sakura",
        tagline: "Genki cheerleader",
        art: .vector(Appearance(
            skin: Color(hex: 0xFFE6D8), skinShade: Color(hex: 0xF5C6B4),
            hair: Color(hex: 0xF7A1C4), hairShade: Color(hex: 0xD9729E), hairShine: Color(hex: 0xFFD3E6),
            eye: Color(hex: 0x3CC4B4), eyeDeep: Color(hex: 0x146B6E),
            outfit: Color(hex: 0xFAFAFF), outfitShade: Color(hex: 0xDCDDEB), outfitAccent: Color(hex: 0x2B3A67),
            hairStyle: .long, outfitStyle: .sailor,
            accessories: [.ahoge, .starClip], accessoryColor: Color(hex: 0xFFD54A)
        )),
        bank: LineBank(lines: [
            .greeting: [
                "Yaaay, you're here! Let's do our best today!",
                "Sakura, reporting for typing duty! ✿",
                "Ganbatte! I'll cheer for every single key!",
                "Good to see you! Let's make today amazing!",
            ],
            .encouragement: [
                "Fight-o! You've got this!",
                "Every key you press makes me so proud!",
                "Wah, you look so cool when you're focused!",
                "Go, go, go! ✿",
                "Hydration check! Drink some water, okay?",
                "Don't forget to blink! Hehe.",
                "Sit up straight~ good posture, good vibes!",
                "You're doing super duper great!",
            ],
            .fast: [
                "Waaah, so fast! My paws are on fire!",
                "Speed mode! Speeeeed!",
                "Kyaa, I can't keep up! Don't stop though!",
                "You're like a typing ninja!",
            ],
            .streak100: [
                "100 keys in a row! Yatta!",
                "Combo x100! ✿",
                "Hundred-key streak! Keep the rhythm!",
            ],
            .streak500: [
                "500 keys! You're totally in the zone!",
                "Five hundred! I'm gonna make you a medal!",
                "Super combo! 500 and counting!",
            ],
            .streak1000: [
                "ONE THOUSAND KEYS?! You're a legend!",
                "1000 streak! I'm crying, I'm so proud!",
                "Unstoppable! Ultimate typing form achieved!",
            ],
            .backspaceSpree: [
                "Backspace party! It's okay, mistakes are how we grow!",
                "Delete, delete~ fresh start! You've got this!",
                "Ehehe, rewriting is part of the magic!",
            ],
            .enterSpam: [
                "New line! New line! New liiine!",
                "So much space! Room for big ideas!",
            ],
            .idle: [
                "Hmm? Are you taking a break? I'll wait...",
                "I'll just close my eyes for a sec... zzz",
                "Break time is important too~",
            ],
            .wakeUp: [
                "Ah! You're back! Hi hi hi!",
                "Welcome back! I totally wasn't napping!",
                "Yay, typing time again!",
            ],
            .lateNight: [
                "It's super late! Promise you'll sleep soon, okay?",
                "Night owl mode! I'll stay up with you... *yawn*",
                "The stars are out! Don't overwork yourself~",
            ],
            .petted: [
                "Ehehe~ that tickles!",
                "Kyaa! Headpats! More, more!",
                "W-wah, you're making me blush!",
                "Hehe, thank you! ✿",
                "Headpat power: absorbed!",
            ],
            .funFact: [
                "Fun fact! Cheering for someone actually helps them perform better. So I'm basically helping! ✿",
                "Did you know cherry blossom season only lasts about a week? That's why it's so special!",
            ],
        ], funFactIntros: ["Ooh ooh! Fun fact!", "Did you know?!", "Sakura's trivia corner!", "Wah, listen to this!"]),
        accent: Color(hex: 0xE85A93)
    )
}
