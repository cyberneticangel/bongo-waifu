import SwiftUI
import WaifuCore

extension WaifuCharacter {
    /// Sleepy catgirl. Fluffy cream hair, cat ears and tail, oversized hoodie, permanently cozy.
    static let mochi = WaifuCharacter(
        id: "builtin.mochi",
        name: "Mochi",
        tagline: "Sleepy catgirl",
        art: .vector(Appearance(
            skin: Color(hex: 0xFFEDE0), skinShade: Color(hex: 0xF3CDBA),
            hair: Color(hex: 0xF4DDB0), hairShade: Color(hex: 0xC9A777), hairShine: Color(hex: 0xFFF5DE),
            eye: Color(hex: 0xE0A33B), eyeDeep: Color(hex: 0x7A4A12),
            outfit: Color(hex: 0xB9D8F2), outfitShade: Color(hex: 0x8DB6D9), outfitAccent: Color(hex: 0xFFFFFF),
            hairStyle: .fluffy, outfitStyle: .catHoodie,
            accessories: [.catEars, .tail], accessoryColor: Color(hex: 0xFFB7C5), fang: true
        )),
        bank: LineBank(lines: [
            .greeting: [
                "*yawn* ...oh, hi nya~",
                "Mrrp. I'll sit on your desk. It's warm here.",
                "Hi hi... I'll help. From here. Lying down.",
            ],
            .encouragement: [
                "Tap tap tap... it's like rain. Cozy nya~",
                "You're doing good... *purr*",
                "Remember to stretch. Like a cat. Big streeetch.",
                "Snack break soon? ...for me too?",
                "Mrrp. Nice typing sounds.",
                "Water... you should drink some. I'll watch.",
            ],
            .fast: [
                "Nya?! So fast... my tail is all poofed up!",
                "Whoa... zoomies typing...",
                "Too fast... I'm getting dizzy nya~",
            ],
            .streak100: ["100 keys... that's a lot of taps. *purr*", "Nya~ combo!"],
            .streak500: ["500?! I'm awake now. Wow.", "You're like a cat chasing a laser. Impressive."],
            .streak1000: [
                "1000 keys... I've never been this awake in my life.",
                "Legendary... you deserve a fish. A big one.",
            ],
            .backspaceSpree: [
                "Nya... knocking all the letters off the table?",
                "Backspace backspace... I do that to cups.",
                "Oopsie... it's okay. Try again~",
            ],
            .enterSpam: ["So many lines... like a yarn ball unrolling.", "Nya? What's with all the Enters?"],
            .idle: ["Nap time... finally... zzz", "*curls up* ...wake me for snacks.", "Mrrrrp... zzz"],
            .wakeUp: ["Nya! I'm up! I'm up!", "*stretches* ...welcome back~", "Mm... five more minutes... oh, you're typing."],
            .lateNight: [
                "Cats are nocturnal... but you're not. Sleep soon, nya.",
                "It's so late... let's both nap...",
            ],
            .petted: [
                "*purrrrr*",
                "Nya~ right behind the ears... perfect...",
                "Mrrp! More please...",
                "*headbutts your hand*",
                "Purr... you're my favorite human.",
            ],
            .funFact: [
                "*yawn* Fun fact... cats sleep 12 to 16 hours a day. Goals.",
                "Nya... a cat's purr vibrates around 25 to 150 hertz. Healing frequencies, probably.",
            ],
        ], funFactIntros: ["*yawn* ...fun fact...", "Nya, did you know...", "Mrrp. Trivia:", "Sleepy fact:"]),
        accent: Color(hex: 0xC48A3C),
        bubble: Color(hex: 0xFFFBF2)
    )
}
