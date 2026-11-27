# Product decisions

Agreed during planning (November 2026). Implementation decisions per phase follow below.

| Topic | Decision |
|---|---|
| Name | **Concierge Clock** (the spec's working name "JeevesWake" is superseded). No "Jeeves" anywhere: "Ask Jeeves" is a trademark and Jeeves is a Wodehouse character. |
| Company | Greater Good Software — sibling of PrepPilot, FocusFound and FotoPhilter |
| Price | **$1.99 USD** paid upfront. No IAP, no subscription, no account. |
| Tech | Native Swift + SwiftUI, Xcode 26 folder-synced project, SQLite via GRDB |
| Minimum OS | **iOS 26** (for AlarmKit: real alarms that ring through silent mode and Focus) |
| Devices | iPhone |
| Storage | SQLite in Application Support (never `Caches/`), so iOS never purges it |
| Network | None, except the optional offline AI model download the person starts |
| Alarms | **AlarmKit** for every alarm (reliable ring, Lock Screen, Dynamic Island) **plus Nightstand Mode**: started at bedtime on the charger, the app stays alive with ambient sound so it can talk and listen at alarm time with no taps, even locked. AlarmKit is always the safety net. |
| Pre-recorded briefing | The briefing is recorded to a sound file shortly before the alarm and used as the alarm sound, so it is heard even if the app was closed (to be confirmed in Xcode that AlarmKit accepts it). |
| Reminders | Read Calendars and Reminders; **marking a reminder done by voice is allowed** (the only write: completion; nothing is ever deleted or edited otherwise). Calendars stay read-only. |
| Voices | **Bundle an offline voice engine with every voice in the app** (no voice downloads), plus Apple's voices where the bundled engine has none. Licences checked before anything is added (avoid GPL parts). Southern US and Canadian are approximated (closest voice + regional wording): no offline voice has those exact accents. |
| Butler's name | User-editable. Default **Charles** (formal, Professional tone) / **Charlie** (familiar, other tones). |
| Default persona | **British male, Professional tone — crisp, formal and slightly snobbish.** |
| Unhinged tone | Not hidden. **Mild swearing allowed** (switchable), never slurs, hate or abuse. One-time notice before it is first used. Expect an App Store age rating of 12+. |
| Briefing language | **User-selectable among all 11 languages**, default **English**, independent of the on-screen language. Accents apply to English. Voice commands work in the languages Apple recognises on device; others use the big buttons. |
| Event readout | **Title, a short summary, the start time and whether it seems important.** Importance is judged by the **offline AI (Gemma)**, with a rule-based fallback (keywords, invitees, reminder priority, overdue, unusual times) on iPhones without it. Times and titles always come from the calendar, never from the AI. A "read titles" switch offers "a private event" instead. |
| Briefing length | User choice: **Quick / Standard / Full** (default Quick). |
| Tabs | **Alarms · Concierge · Sounds · Trends**, Settings behind the gear. Concierge has its own job: "Brief me now", "Ask me about my day", today's events with importance, the reminder session. |
| Wake score | 0–100 per morning, considering **both lateness and snoozes**: start at 100; −4 per minute late after a 2-minute grace, at most −60; −10 per snooze; −15 if the "Are you really up?" check is missed; **80+ = success**. All numbers editable in Settings; changing them re-scores the whole log. |
| Extra features (all agreed) | 1 calendar-aware alarm suggestion · 2 "Are you really up?" check · 3 bedtime preview · 4 skip days off · 5 Advisor 7-night experiments · 6 snooze escalation + optional limit · 7 Apple Health sleep (opt-in, read-only) · 8 sunrise screen |
| Offline AI | Same as the siblings: Google's Gemma 4 (E2B 6 GB / E4B 8 GB iPhones) with LiteRT-LM, shared package `GGSModelKit`, the same Settings screen, "Start here" card and step-by-step guide, one model shared via App Group `group.com.greatergoodsoftware.models`. Uses: importance ranking, varied lines in every tone, looser commands, "Ask me about my day", weekly wake summary. |
| Branding | Same as the siblings (GGSBrand, Calm navy theme, top bar with logo / name / gear, launch animation, About Greater Good Software). |
| App icon | **Butler carrying a tray with an alarm clock on it** (two bells, hands at ten past ten; changed from a cloche after Phase 1a review), drawn in the Greater Good node-and-edge mesh, on **navy** with a **brass/gold → teal** ring and a white **service-bell badge** at 10 o'clock. Dark (default), dark appearance, tinted and light (alternate) variants. |
| Languages | The same 11 as the siblings, switchable in the app, right-to-left for Arabic, Hebrew and Urdu. "Concierge Clock" and "Greater Good Software" are never translated. |
| Branches | Each phase on its own branch (`phase-1a-foundation`, …). Nothing is merged into `main` until the product owner says so. |

## Phase 1a — foundation

| Topic | Decision | Why |
|---|---|---|
| Template | Project layout, settings store, localizer, About screens, Offline AI screen and string tool adapted from PrepPilot's latest branch (`phase-3h-write-more`). | PrepPilot already targets iOS 26 and has the newest `GGSModelKit`. |
| Shared packages | `GGSBrand`, `GGSModelKit` and `LiteRTLM` copied unchanged from PrepPilot, plus one **additive** file `GGSBrand/ButlerMark.swift` (butler mark, animated mark, bell badge, brass/teal colours). | Copying the package back into another app changes nothing there. |
| Shared guide strings | `GGSModelUI/Resources` is regenerated from this repo's translations, so "One download serves all Greater Good Software apps" now lists Concierge Clock first. | The other apps can take the new text when they next copy the package. |
| App colours | The shared Calm navy theme, with Concierge Clock's own **teal tint** (`#0B7470` light / `#3FCFC6` dark, ≥ 4.5:1) for controls and **brass** for decoration (`ConciergeStyle`). | Matches the icon; keeps contrast accessible. |
| Core module | `ConciergeKit` with `ConciergeCore` (Foundation only, portable to Android) and `ConciergeData` (GRDB). Swift 6 language mode. | Same split as PrepKit / FocusKit. |
| IDs | Uppercase UUID strings (`RecordID`). | Same as the siblings: read the same in SQLite, JSON and CSV. |
| Backup format | **One readable JSON file** (`.conciergeclock`, UTType `com.greatergoodsoftware.conciergeclock.backup` conforming to `public.json`) with `format`, `schemaVersion`, `databaseSchemaVersion`. ISO-8601 UTC dates. `BackupMigrator` upgrades older layouts step by step. | Spec: JSON backup with schemaVersion and migrations. There are no attached files, so no ZIP is needed (unlike PrepPilot). |
| Automatic backup | Optional: once a day (on app open/close) a backup is written to a folder the person picks (security-scoped bookmark, stored outside the settings so it never travels in a backup). Keeps the 7 newest; deletes only files it named. | FocusFound's agreed "auto-backup to a user-chosen folder". |
| CSV | Wake log and alarms, English column names, RFC 4180 quoting, formula-injection guard. | Spreadsheets and scripts can rely on stable columns. |
| Privacy | The wake log stores times and counts only — never calendar text or speech. No permissions are requested in Phase 1a. | Spec: zero telemetry, no recording. |
| Placeholders | Each tab shows what its phase will add ("Coming in Phase …" cards). The Alarms list and "Brief me now" are inert until Phases 1b and 2. | Every screen is meaningful from the first build. |
| Wake score in 1a | Implemented and tested now (`WakeScore`, `WakeEvent.rescore`), with the rules editable in Settings › Mornings. | It is part of the stored shape of every wake log entry. |
| Settings in 1a | Every agreed preference already exists and is stored (butler, snooze, mornings, wake score, offline AI); the features that use them arrive in their phases. | Avoids settings migrations later. |
| Build environment | Phase 1a was written without a Mac (no Swift toolchain available). The first build in Xcode may report small errors; they are fixed in this branch. | Stated openly so nothing is assumed to have compiled. |
