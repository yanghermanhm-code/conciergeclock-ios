# Concierge Clock

**A Greater Good Software product.** A 100% offline, talking alarm clock for iPhone: your
concierge — Charles, a slightly snobbish British butler, unless you rename him — wakes you, tells
you the time and what your day holds from your own calendar and reminders, listens for "snooze
10 minutes" or "I'm awake", and tracks how well you wake up. Pay once, own it — no accounts, no
subscriptions, no tracking.

> Status: **Phase 1a** merged into `main`. **Phase 1b** (alarms, calendars, widgets) on
> `phase-1b-alarms`, awaiting device test. **Phase 2 – The spoken briefing** in review on
> `phase-2-briefing` (built on top of 1b).
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
3. Select the **ConciergeClock** target → **Signing & Capabilities** → choose your Team. Do the
   same for the **ConciergeClockWidgets** target. With a paid Apple Developer account, keep both
   App Groups (`group.com.greatergoodsoftware.conciergeclock` for the widgets and
   `group.com.greatergoodsoftware.models` for the offline AI shared with your other apps); Xcode
   registers them. If Xcode says a bundle ID is taken, change `com.greatergoodsoftware.conciergeclock`
   (and the widget's `.widgets` ID) to something unique.
4. **Alarms need a real iPhone** for a true test (AlarmKit rings on the Lock Screen and Dynamic
   Island; the Simulator shows them but cannot be relied on for sound and timing).
5. Pick your iPhone (or a simulator) and press **⌘R**.

### What to try in Phase 2

- **Concierge tab › Brief Me Now:** Charles reads today — the time, your next event with where,
  how long and how soon, whether it looks important, more events and due reminders — with the
  text on screen as he speaks. Tap again to stop. Pull down to refresh.
- **Today** card: today's events and reminders with **Important** badges; it says whether the
  offline AI (Gemma) or the built-in rules judged them.
- **Concierge › Customize** (or Settings › Your Concierge): **Preview Voice**, **Hear Every Voice**
  (all 8 accents and 4 tones), **Preview My Briefing**, the voice in use and its quality, and
  **Get Better Voices** (free Enhanced / Premium voices from iOS Settings).
- Change the spoken language (e.g. French) or the length (Quick / Standard / Full) and brief again.
- Turn off "Read event titles aloud": events become "a private event".

### What to try in Phase 1b

- **Alarms tab:** add an alarm two minutes ahead, lock the iPhone, switch on silent mode: it rings
  on the Lock Screen with **Stop** and **Snooze** (your snooze length, 5 minutes by default) and
  shows a countdown in the Dynamic Island while snoozing. After Stop, Trends shows "Mornings
  logged: 1".
- Swipe an alarm for **Skip Next**; switch alarms on and off; edit repeat days, snooze and the
  butler's voice per alarm.
- **Settings › Calendars & Reminders** (or the Calendars card on the Concierge tab): allow access
  and see every account on the iPhone — iCloud, Google, Outlook / Exchange, Yahoo, On My iPhone,
  subscribed — with each calendar's switch. "Add Google, Outlook or another account" explains the
  one-time setup in iOS Settings.
- Add an all-day event called "Vacation" tomorrow: alarms with **Skip days off** skip that day.
- Long-press the Home Screen or Lock Screen › add the **Next Alarm** widget.

### What to look at from Phase 1a

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
