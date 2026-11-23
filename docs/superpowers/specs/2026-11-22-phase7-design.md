# Phase 7: device feedback

The owner's comments from the first iPhone run, through Phase 4. Five comments; four become changes, one is by design.

## Decisions (2026-11-22)

The owner asked for plans to proceed without a stop, so these calls are mine. Each can be changed.

| Comment | Decision |
| --- | --- |
| 1. Give "Your interests" its own onboarding screen | Onboarding becomes 6 steps: Welcome, Screen Time, Apps, Focus time, **Your interests**, Pair your first tag. Interests come before pairing, because pairing (or "Not now") finishes onboarding. Continue works with nothing picked. The pairing step keeps only the tag graphic and its two lines. |
| 2. Change the text to "Name this Tag" | The only place Tapout says "Name this …" is the label above the name field in the pair sheet ("Name this place"). It becomes **"Name this Tag"**, in onboarding and in Places. The button ("Save place"), the Places tab and the rest of the "place" wording stay as they are; say so if you want those renamed too. |
| 3. Sealed screen looks unpolished | iOS only lets a shield set its colours, one icon, a title, a subtitle and a button, so the polish is in those: (a) the icon is the app's real glass orb (the `OrbView`: glow, glass, gloss, seal ring), pre-rendered to a PNG, instead of four flat circles; (b) the button is an ember pill with the on-ember label, as every primary button is while locked; (c) the background stays solid `bg`. The system font is the only one a shield can use. A Lab page shows a mock of the screen with the real icon, so the look can be judged in the simulator; the real screen is checked on the iPhone. |
| 3.1 Achievement screen too | The milestone cover gets an ember glow wash, a sealing sequence (the rings fade in one by one while the seal ring sweeps closed), a larger Fraunces title and tidier spacing, with a crossfade instead of motion under Reduce Motion. Same copy, same buttons. |
| 4. "Allow Screen Time" screen flashes on every launch | iOS reports access as not approved for a moment at launch and on return to the foreground, before the real status arrives; the page opens on that first read and closes when the real one lands. The page now opens only once access has stayed missing for 1.5 seconds. A genuinely revoked access shows the page 1.5 seconds late instead of at once. A DEBUG launch argument reproduces the stale read in the simulator. |
| 5. Deleting the app repeats onboarding, but the pass count stays | **Unchanged, by design.** Your answer in Phase 4 was Keychain: the pass count outlives a delete so five lifetime passes can't be refilled by reinstalling. Onboarding repeats because your modes, places and history live in the app's own storage, which deleting removes. Debug builds have Lab → Reset passes; Release builds have no reset. |

## Not in Phase 7

- Anything from your Phase 5 and 6 comments (you said through Phase 4).
- Renaming "places" to "tags" everywhere.
- Showing the mode or place name on the Sealed screen. The shield extension can't read the shared store (it has no App Group), and adding one means new signing work.
