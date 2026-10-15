import SwiftUI
import WaifuCore

extension WaifuCharacter {
    /// Tsundere gamer. Red twin-tails, hoodie, refuses to admit she's impressed.
    static let rin = WaifuCharacter(
        id: "builtin.rin",
        name: "Rin",
        tagline: "Tsundere gamer",
        art: .vector(Appearance(
            skin: Color(hex: 0xFFE3D3), skinShade: Color(hex: 0xF2C1AC),
            hair: Color(hex: 0xD8394A), hairShade: Color(hex: 0x9C1F32), hairShine: Color(hex: 0xFF8A8F),
            eye: Color(hex: 0xF2A93B), eyeDeep: Color(hex: 0x8A4B0C),
            outfit: Color(hex: 0x2A2A33), outfitShade: Color(hex: 0x19191F), outfitAccent: Color(hex: 0xE23A4D),
            hairStyle: .twinTails, outfitStyle: .hoodie,
            accessories: [.ribbons, .headset], accessoryColor: Color(hex: 0x1C1C22), fang: true
        )),
        bank: LineBank(lines: [
            .greeting: [
                "Hmph. Took you long enough.",
                "I-it's not like I was waiting for you or anything!",
                "Fine, I'll keep you company. Just this once.",
            ],
            .encouragement: [
                "Not bad... for you.",
                "Don't get cocky, but you're doing okay.",
                "I guess I can watch a little longer.",
                "Hey. Drink water. Not because I care!",
                "Sit up straight, dummy. Your back will thank me.",
                "...Keep going. I'm not cheering. Shut up.",
            ],
            .fast: [
                "W-whoa! I mean... I could go faster.",
                "Show-off.",
                "Okay, that's kinda fast. KINDA.",
                "Hey! Slow down, my paws can't— I mean, whatever!",
            ],
            .streak100: ["100? Big deal. ...Okay, it's a little cool.", "Hmph. Decent combo."],
            .streak500: ["500?! ...I'm not impressed. At all.", "Fine! You're good! Happy now?!"],
            .streak1000: [
                "A thousand?! N-no way... okay, that's actually awesome.",
                "Don't let this go to your head... but you're amazing. THERE. I said it.",
            ],
            .backspaceSpree: [
                "Ugh, typo much? Baka.",
                "Delete it ALL, why don't you.",
                "Wow. Rewriting your whole life story?",
            ],
            .enterSpam: ["Stop mashing Enter, idiot!", "Are you trying to break the keyboard?!"],
            .idle: ["Hey! Don't just leave me here!", "...Boring. I'm taking a nap.", "Hmph. Fine. Ignore me."],
            .wakeUp: [
                "Finally! Where'd you go?!",
                "I-I wasn't sleeping! I was charging up!",
                "Oh, you're back. Whatever. ...Welcome back.",
            ],
            .lateNight: [
                "It's super late, dummy! Go to sleep!",
                "You're gonna be a zombie tomorrow. Not my problem! ...Just sleep soon.",
            ],
            .petted: [
                "H-hey! Who said you could do that?!",
                "...Don't stop. I-I mean, stop! Hmph.",
                "B-baka! ...Okay, one more.",
                "It's not like I like headpats or anything!",
                "Grr... fine. That was nice.",
            ],
            .funFact: [
                "Not that you asked, but speedrunners frame-count their inputs. You'd never manage.",
                "Hmph. The Konami code is up up down down left right left right B A. Everyone knows that.",
            ],
        ], funFactIntros: ["Not that you asked, but", "Hmph. Bet you didn't know:", "Listen, dummy:", "Ugh, fine, a fun fact:"]),
        accent: Color(hex: 0xD8394A),
        bubble: Color(hex: 0xFFF5F5)
    )
}
