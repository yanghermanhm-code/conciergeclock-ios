# Concierge Clock

**A Greater Good Software product.** A 100% offline, talking alarm clock for iPhone: your
concierge — Charles, a slightly snobbish British butler, unless you rename him — wakes you, tells
you the time and what your day holds from your own calendar and reminders, listens for "snooze
10 minutes" or "I'm awake", and tracks how well you wake up. Pay once, own it — no accounts, no
subscriptions, no tracking.

> Status: **Phase 1a – Foundation** in review on branch `phase-1a-foundation`.
> See [docs/ROADMAP.md](docs/ROADMAP.md).

## Requirements

- Xcode 26 or newer (folder-synced project format, iOS 26 SDK)
- iOS 26.0+ (iPhone) — needed for AlarmKit's real alarms
- An Apple ID signed into Xcode. A free account is enough to run Phase 1a; App Groups (shared
  offline AI model, widgets) need a paid Apple Developer account (see below).
- Optional **offline AI** (Google's Gemma 4, the same model and setup as PrepPilot and FocusFound):
  an iPhone with 6 GB of memory (Gemma 4 E2B) or 8 GB (Gemma 4 E4B, iPhone 15 Pro or newer).

## Run it

1. Open `ConciergeClock.xcodeproj`.
2. Wait for Xcode to resolve packages: [GRDB](https://github.com/groue/GRDB.swift) and the
   prebuilt runtime of Google's [LiteRT-LM](https://github.com/google-ai-edge/LiteRT-LM)
   (v0.20.0, a 95 MB download; its Swift wrapper is vendored in `Packages/LiteRTLM`). If Xcode
   shows "Missing package product", choose File › Packages › Reset Package Caches.
3. Select the **ConciergeClock** target → **Signing & Capabilities** → choose your Team.
   If Xcode says the bundle ID is taken, change `com.greatergoodsoftware.conciergeclock` to
   something unique for now, such as `com.yourname.conciergeclock`.
4. **Free (Personal Team) account?** Remove **App Groups** under Signing & Capabilities (and
   **Increased Memory Limit** if Xcode refuses it). Everything in Phase 1a still works; the
   offline AI model is then stored for Concierge Clock only and Settings › Offline AI says why.
5. Pick an iPhone simulator (or your iPhone) and press **⌘R**.

### What to look at in Phase 1a

- The launch animation (the butler's mesh connecting) and the new icon (Home Screen; Settings ›
  Appearance › App icon switches to the light variant).
- The four tabs and the top bar: butler logo (opens About Greater Good Software, now listing all
  four apps), "Concierge Clock" centred, Settings gear.
- **Concierge** tab → *Customize Your Concierge*: rename Charles/Charlie, pick one of 8 accents,
  4 tones (Unhinged shows its notice first), Quick/Standard/Full, spoken language.
- **Settings**: the orange *Set up offline AI* card (same as the siblings), Snooze (5 min
  default), Mornings (all agreed features, wake score rules), Backup & Export (JSON backup,
  restore, daily automatic backup to a folder you choose, CSV).
- Switch the language (Settings › Language) to Arabic, Hebrew or Urdu for right-to-left.

### Offline AI (Gemma) — same setup as PrepPilot and FocusFound

Settings › **Offline AI** (or the orange *Set up offline AI* card) › **Show me how, step by
step**. The model lives in the App Group `group.com.greatergoodsoftware.models`, shared with
PrepPilot, FocusFound and FotoPhilter: if one of them already downloaded it, it is ready here.
Test on a real iPhone; the Simulator cannot run the model at a useful speed. Full guide:
[docs/OFFLINE_AI_SETUP.md](docs/OFFLINE_AI_SETUP.md).

## Run the tests

- Choose the **ConciergeKit-Package** scheme (top bar, next to the run button), pick an iPhone
  simulator and press **⌘U** — settings, persona, alarms' next ring, wake score, backups, CSV,
  database migrations, stores and restore.
- Or in Terminal: `cd Packages/ConciergeKit && swift test`

## Project layout

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md). In short: `ConciergeClock/` is the SwiftUI app,
`Packages/ConciergeKit` holds the models and the database, `Packages/GGSBrand`,
`GGSModelKit` and `LiteRTLM` are shared with the sibling apps.

## Regenerating strings and icons

```bash
python3 tools/generate_strings.py   # after editing tools/translations/*.txt
python3 tools/generate_icons.py     # after editing tools/butler_geometry.py (needs Node + Playwright for PNGs)
```

## Documentation

- [Product decisions](docs/DECISIONS.md)
- [Architecture](docs/ARCHITECTURE.md)
- [Data schema & backup format](docs/DATA_SCHEMA.md) — also the contract for a future Android app
- [Roadmap](docs/ROADMAP.md)
- [Offline AI setup](docs/OFFLINE_AI_SETUP.md) · [Model licences](docs/model-licenses.md)
- [Master prompt](docs/MASTER_PROMPT.md) — the original specification and the agreed answers
