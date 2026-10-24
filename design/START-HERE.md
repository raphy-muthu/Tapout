# Start here

## 1. Put the files in your project

1. Make a folder for the app, for example `~/Developer/Tapout`.
2. Inside it, make a folder called `design` and put everything from this package in it, **except** `CLAUDE.md`.
3. Put `CLAUDE.md` in the app folder itself (`~/Developer/Tapout/CLAUDE.md`). Claude Code reads it automatically every session.

You should end up with:

```
Tapout/
├── CLAUDE.md
└── design/
    ├── START-HERE.md
    ├── SCREENS.md
    ├── design-system/   (README.md, tokens.json, components/)
    └── screens/         (17 .dc.html files + canvas.json)
```

## 2. Open Claude Code in that folder

In Terminal: `cd ~/Developer/Tapout` then `claude`.

## 3. Paste this as your first message

> Read CLAUDE.md, design/design-system/README.md, design/design-system/tokens.json and design/SCREENS.md. Then create a new SwiftUI iOS app called Tapout in this folder. Do build-order steps 1–3 only: the design tokens (colour assets for light and dark, fonts, spacing, radius, motion, haptics), the glass OrbView and tab bar, then the Home screen in its unlocked, locked and emergency states, using mock data. Match design/screens/Home.dc.html and Orb.dc.html closely. Show me a plan before writing code.

After that works, ask for one screen at a time, e.g. "Now build onboarding from design/screens/Main.dc.html, steps 1–4."

## Tips

- Run on a real iPhone for anything NFC or Screen Time. The simulator can't do either.
- If a screen looks off, send Claude Code a screenshot from the Claude Design canvas next to a simulator screenshot.
- If you change the designs later, re-download them and replace the files in `design/`.
