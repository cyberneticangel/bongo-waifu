# Bongo Waifu

A Bongo Cat–style desktop companion for macOS. An anime girl sits on your desktop behind a tiny keyboard and taps along as you type. She changes expression, falls asleep when you stop, and pops up speech bubbles with comments and fun facts.

![Mochi typing along, grumbling at a typo, sharing a fun fact, dozing off and getting headpats](docs/demo-mochi.gif)

(Higher quality: [docs/demo-mochi.mp4](docs/demo-mochi.mp4) · Rin: [docs/demo-rin.mp4](docs/demo-rin.mp4))

The built-in characters are rigged like VTuber models:

- Their head and eyes follow your cursor.
- Layers shift with depth as the head turns.
- Hair, ears, ahoge and tail move with spring physics.
- They blink, ease between expressions, glance at the keyboard while you type, and lip-sync while talking.

## Build & run

```sh
./build.sh
open build/BongoWaifu.app
```

You need macOS 14+ and the Xcode Command Line Tools. The app lives in the menu bar (paw icon) and has no Dock icon.

**Accessibility permission:** macOS requires it to see global key presses. Grant it in System Settings → Privacy & Security → Accessibility. The app picks it up within a couple of seconds, with no relaunch needed. Ad-hoc–signed rebuilds can make macOS forget the grant. To keep it across rebuilds, toggle it off and on again, or build with a real certificate: `SIGN_IDENTITY="Apple Development: …" ./build.sh`.

**Privacy:** only the *kind* of key is used (Backspace / Enter / other) plus timing. Typed characters are never read, stored, or sent anywhere. Everything is offline.

## Using it

- **Drag** her anywhere. Her position is remembered.
- **Click** her for headpats. **Click the bubble** to dismiss it.
- **Right-click** her, or use the menu-bar paw, for:
  - Character
  - Size
  - Chattiness (Silent / Quiet / Normal / Chatty)
  - Fun Facts
  - Click-Through
  - Hide
  - Reset Position
  - Launch at Login
  - typing stats
- Transparent areas of the window never block clicks.

## Characters

| | Personality |
|---|---|
| **Sakura** | Genki cheerleader: pink hair, sailor uniform, ahoge |
| **Yuki** | Deadpan kuudere: silver bob, delivers trivia like a librarian |
| **Rin** | Tsundere gamer: red twin-tails, *n-not* impressed |
| **Mochi** | Sleepy catgirl: ears, tail, purrs at headpats |

She reacts to:

- typing speed
- streaks (100 / 250 / 500 / 1000+ keys)
- Backspace sprees
- Enter mashing
- going idle (she falls asleep) and coming back
- late-night sessions
- headpats

She also shares fun facts now and then while you type.

## Custom characters

Drop a folder into `~/Library/Application Support/BongoWaifu/Characters/` (menu → *Open Characters Folder…*), then choose *Reload Characters*.

```
MyWaifu/
  character.json      required
  idle.png            required: paws up
  left.png right.png  left / right paw down (fall back to idle)
  both.png            both paws (Enter, mouse clicks)
  sleep.png  blink.png
  expr_happy.png expr_excited.png expr_surprised.png expr_annoyed.png
  expr_sleepy.png expr_smug.png expr_blush.png
```

Frames are square-ish, bottom-aligned images (480×480 works well). `character.json`:

```json
{
  "name": "My Waifu",
  "tagline": "Custom character",
  "accent": "#E85A93",
  "bubble": "#FFFFFF",
  "scale": 1.0,
  "funFactIntros": ["Fun fact!"],
  "lines": {
    "greeting": ["Hi!"],
    "petted": ["Ehehe~"]
  }
}
```

Line categories:

- `greeting`
- `encouragement`
- `fast`
- `streak100`
- `streak500`
- `streak1000`
- `backspaceSpree`
- `enterSpam`
- `idle`
- `wakeUp`
- `lateNight`
- `petted`
- `funFact`

Any category you leave out falls back to a generic set.

`Examples/ExamplePack` is a complete pack you can copy and paint over. To export any built-in as a fresh template:

```sh
.build/release/BongoWaifu --export-pack ~/Desktop/MyPack
```

## Live2D models

Bongo Waifu can host Live2D Cubism 3/4 models (`.model3.json` + `.moc3`), the format VTube Studio uses. The model sits at the bongo desk and keeps its own physics, blinking and idle motions. On top of that it gets:

- head and eye tracking that follows your cursor
- glancing at the keyboard while you type
- lip-sync while she talks
- mood expressions
- falling asleep when you're idle
- a tap motion when you give headpats

**1. Install Live2D Cubism Core (one time).** Live2D's runtime is proprietary and licensed by Live2D Inc., so it isn't bundled. In the menu choose **Install Live2D Cubism Core…**, read the license, and choose *Agree & Download*. It's fetched from `cubism.live2d.com` into `~/Library/Application Support/BongoWaifu/Live2D/`.

**2. Add a model.** Copy the model's folder into the Characters folder (menu → *Open Characters Folder…*), then choose *Reload Characters*. The folder needs the `.model3.json` and everything it references. A `.model3.json` one folder down also works, which is common in VTube Studio exports. `character.json` is optional and adds a name, lines and tuning:

```json
{
  "name": "Mao",
  "accent": "#3B3F8F",
  "lines": { "greeting": ["Hi!"] },
  "live2d": {
    "model": "Mao.model3.json",
    "zoom": 2.1,
    "offsetX": 0,
    "offsetY": -0.02,
    "expressions": { "happy": "exp_02", "surprised": "exp_07", "sleepy": "exp_03",
                     "annoyed": "exp_08", "blush": "exp_06", "excited": "exp_04" },
    "tapMotion": "TapBody",
    "desk": true,
    "sleeve": "#2E3270",
    "hand": "#FFE9DD",
    "catPaws": false
  }
}
```

All `live2d` keys are optional:

- **`model`**: picks the model when the folder contains several.
- **`zoom`**: the visible artwork's height as a multiple of the view's height. Leave it out to fit the artwork's width.
- **`offsetX` / `offsetY`**: nudge the model, as fractions of the view.
- **`expressions`**: maps moods (`happy`, `excited`, `surprised`, `annoyed`, `sleepy`, `smug`, `blush`) to expression names from the model3.json. Without it, expressions are matched by name (e.g. one containing "smile" is used for `happy`).
- **`tapMotion`**: the motion group to play on headpats. The default is the first group with "tap" in its name.
- **`desk`**: set to `false` to hide the desk and paws by default. You can also toggle **Show Desk** in the paw menu; that choice is remembered per character and wins over this setting.
- **`sleeve`, `hand`, `catPaws`**: style the tapping paws.

To check a pack's framing and expressions without the overlay:

```sh
.build/release/BongoWaifu --snapshot-live2d ~/path/to/MyModel ~/Desktop/shots
```

Rendering uses [PixiJS](https://github.com/pixijs/pixijs) and [pixi-live2d-display](https://github.com/guansss/pixi-live2d-display) (both MIT, vendored in `Resources/Live2D`) in a transparent web view. Sample models such as Hiyori and Mao from [CubismWebSamples](https://github.com/Live2D/CubismWebSamples) are good for trying it out; they're under Live2D's Free Material License.

## Development

```sh
swift test                                       # typing stats + reaction engine
swift run BongoWaifu --render-previews previews  # contact sheets of every character/mood
swift run BongoWaifu --record-demo frames builtin.mochi  # scripted demo → PNG frames + frames.txt
ffmpeg -f concat -safe 0 -i frames/frames.txt -vf fps=30,format=yuv420p demo.mp4
```

The demo recorder plays a seeded, scripted session (`DEMO_SEED` changes which lines she picks) against the real model and views. It renders offscreen, so it needs no Screen Recording permission.

- `Sources/WaifuCore`: pure logic (`TypingStats`, `ReactionEngine`, line banks, fun facts)
- `Sources/BongoWaifu`: AppKit/SwiftUI app (overlay window, input monitor, menu, vector + sprite renderers)
