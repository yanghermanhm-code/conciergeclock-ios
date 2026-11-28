# Product decisions

Agreed during planning (November 2026). Implementation decisions per phase follow below.

| Topic | Decision |
|---|---|
| Name | **ConciergeClock** (the spec's working name "JeevesWake" is superseded). No "Jeeves" anywhere: "Ask Jeeves" is a trademark and Jeeves is a Wodehouse character. |
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
| Voices | **Final (Nov 2026): voices are bundled inside the app** — no downloads, no setup on the iPhone. ConciergeClock's own offline voice engine, brought forward to Phase 2b, because iOS gives apps no way to download Apple's Premium voices (only iPhone Settings can). Apple's voices remain the fallback. *(Earlier decision, superseded: bundle every voice in the app.)* Licences checked before anything is added (avoid GPL parts). Southern US and Canadian are approximated (closest voice + regional wording): no offline voice has those exact accents. |
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
| Languages | The same 11 as the siblings, switchable in the app, right-to-left for Arabic, Hebrew and Urdu. "ConciergeClock" and "Greater Good Software" are never translated. |
| Calendars | **Phone, Google and Outlook calendars (and Exchange / Microsoft 365, Yahoo, iCloud, subscribed)** are read through the iPhone's own accounts with EventKit: the person adds Google or Outlook once in iOS Settings › Apps › Calendar › Calendar Accounts, and ConciergeClock reads it offline. The app never signs in to Google or Microsoft and never goes online for this (product principles: no accounts, no network). Settings › Calendars & Reminders shows every account and calendar, with on/off per calendar and a step-by-step guide. Calendars only in the Outlook app (not added to iOS) and Google Tasks cannot be read by any app. |
| Speakerphone | **Every wake-up announcement plays on the loudspeaker**, never the earpiece: AlarmKit alarms always use the speaker; the spoken briefing and conversation (Phases 2–3) use an audio session routed to the speaker (`.playback`, and `.playAndRecord` with `.defaultToSpeaker` while listening), also when headphones are not connected. |
| Previews | **Preview everything on the phone** (Phase 2): "Preview voice" for each of the 8 accents and every tone, and "Preview my briefing" that speaks the real announcement for today's calendar in the chosen voice, tone, length and language, plus a preview of each alarm's sound. |
| Wake-up safety call | **Dropped (product owner, Nov 2026).** Requirement: after a user-chosen delay without waking, call a preset number on speakerphone, entirely from within ConciergeClock with no manual step after setup. iOS does not allow this: every phone or FaceTime call started by an app needs the person's confirmation tap, WhatsApp offers apps no way to start a call, apps cannot open other apps while locked or in the background, and the alternatives (a calling server, or a Shortcuts automation the person builds) need an account / external setup. A version with a final tap is not useful, so the feature is not built. Revisit only if Apple adds an API for it. |
| Alarms vs. events and reminders | **Separate behaviour** (product owner, Nov 2026). An *alarm session* wakes the person (briefing, snooze / dismiss, "Are you really up?"). A *reminder session* is about one event or reminder: the butler reads it, **pauses for a spoken reply**, and the **offline AI (Gemma)** works out the conversation — acknowledged ("OK, I understand", "Yes, I'll go"), dismissed, "remind me in 5 minutes / at 3 o'clock", "set an alarm for 6", "mark it done" — and whether to remind again at the next step, add a future reminder or add an alarm. The butler always says back what it will do. Built in Phase 3, with a deterministic parser for common phrases and iPhones without Gemma. |
| Branches | Each phase on its own branch (`phase-1a-foundation`, …). Nothing is merged into `main` until the product owner says so. |

## Phase 1a — foundation

| Topic | Decision | Why |
|---|---|---|
| Template | Project layout, settings store, localizer, About screens, Offline AI screen and string tool adapted from PrepPilot's latest branch (`phase-3h-write-more`). | PrepPilot already targets iOS 26 and has the newest `GGSModelKit`. |
| Shared packages | `GGSBrand`, `GGSModelKit` and `LiteRTLM` copied unchanged from PrepPilot, plus one **additive** file `GGSBrand/ButlerMark.swift` (butler mark, animated mark, bell badge, brass/teal colours). | Copying the package back into another app changes nothing there. |
| Shared guide strings | `GGSModelUI/Resources` is regenerated from this repo's translations, so "One download serves all Greater Good Software apps" now lists ConciergeClock first. | The other apps can take the new text when they next copy the package. |
| App colours | The shared Calm navy theme, with ConciergeClock's own **teal tint** (`#0B7470` light / `#3FCFC6` dark, ≥ 4.5:1) for controls and **brass** for decoration (`ConciergeStyle`). | Matches the icon; keeps contrast accessible. |
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

## Phase 1b — alarms, calendars, widgets

| Topic | Decision | Why |
|---|---|---|
| AlarmKit scheduling | Each alarm's **next two rings** within 8 days are scheduled as one-off AlarmKit alarms (`AlarmPlanner`), not as AlarmKit repeating schedules. Every Stop, every change and every app launch re-plans. | One-off rings let ConciergeClock apply "skip next", calendar days off and per-day logic exactly, and give every ring its own id for the wake log. Two rings ahead keep tomorrow covered even if the app does not run. |
| Ring ids | A stable UUID derived from the alarm id and the ring time (`AlarmPlanner.occurrenceID`). | Planning twice gives the same id, so the scheduler compares wanted and scheduled rings without storing extra state. |
| Snooze | AlarmKit's own Snooze (countdown) with the alarm's snooze length (default 5 minutes). Snoozes are counted from the Snooze button when iOS reports it, otherwise inferred from when Stop was pressed (each snooze adds exactly the snooze length). | The system snooze works with the app closed; the count stays right either way. |
| Snooze limit | Stored and shown in Settings; enforced in the spoken conversation (Phase 3). | AlarmKit's Lock Screen buttons are fixed when the ring is scheduled and cannot count. |
| Wake log | Written when a ring is stopped (Stop button intent, running in the app's process, or seen disappearing while the app runs). A ring never stopped 3 hours after it was due is logged as missed (score 0). Rings are kept in table `alarmOccurrence` (this iPhone only, not in backups). | Every morning is logged once, even if the Stop report and the app's own observation both arrive. |
| Days off | Optional per alarm (on by default): public-holiday calendars and all-day events whose title contains a day-off word (whole words for Latin scripts: "PTO" does not match "Crypto"). Read from the included calendars only, never stored. | The agreed "skip days off" feature. |
| Widgets | New target `ConciergeClockWidgets`: next-alarm widget (Home Screen small, Lock Screen rectangular / circular / inline, StandBy) and the alarm's Live Activity (Lock Screen and Dynamic Island while ringing or snoozing). The app writes a small snapshot to App Group `group.com.greatergoodsoftware.conciergeclock`. | Agreed widgets; AlarmKit's countdown (snooze) needs a Live Activity. |
| Permissions | Alarms: asked when the first alarm is saved. Calendars and Reminders: asked from Settings › Calendars & Reminders (or the Concierge tab card), never at launch. Reminders access is "full" because Phase 2 can mark a reminder done by voice. | Ask only when the person sees why. |

## Phase 2 — the spoken briefing

| Topic | Decision | Why |
|---|---|---|
| Script | Built deterministically by `BriefingBuilder` (ConciergeCore) from phrase templates `brief.<tone>.<part>` in 11 languages × 4 tones, stored as ConciergeCore resources. Times are formatted and durations spelled out by the system for the briefing language ("2 hours, 15 minutes"). | Facts (titles, times, counts) can never be invented; every language and tone is reviewable text. |
| Event summary | Place, length and number of other people, when known ("At Dr. Smith, for 45 minutes, with 3 others."). Free-text summaries by Gemma come in Phase 6. | Short, factual, works on every iPhone. |
| Importance | Rules at once (keywords in all app languages, invitees, reminder priority, overdue, very early starts, all-day markers low); Gemma re-judges in the background when ready and the list updates (`ModelImportanceRanker`, JSON reply, tolerant parsing). Gemma only says important / not important per item id; it never adds or changes items. Results are cached while the day's items are unchanged. "Brief Me Now" never waits for the model. | The agreed Gemma importance, without making the briefing slow. |
| Lengths | Quick: next event + counts. Standard: next + the 2 most important of the rest (spoken in time order) + up to 3 reminders. Full: everything with summaries. | "Top three" including the next event. |
| Private mode | "Read event titles aloud" off: titles become "a private event" and places are not read. | Briefings may be heard by others. |
| Tones | Professional is a crisp, slightly snobbish British butler; Unhinged adds one mild-swearing line only when allowed; Southern US / Canadian English add a regional closing line outside the Professional tone. | Agreed persona. |
| Voices | Apple's voices for now: the accent's locale (English) or the briefing language, the persona's gender where available, best quality installed (Premium > Enhanced > default); novelty and Personal Voices excluded. Settings shows which voice is used, its quality, and a guide to download better ones. Prosody (speed, pitch) per tone. Bundled engine: Phase 7. | Works offline on every iPhone today. |
| Previews | Preview Voice (a short sample: greeting, time, "the dentist at 9:15", the snooze question), Hear Every Voice (all 8 accents and 4 tones), Preview My Briefing (today's real script). | Agreed: preview everything on the phone. |
| Audio | `.playback` + spoken-audio mode + duck others: plays on the loudspeaker unless headphones are connected. Wake-up announcements (Phase 3) will force the loudspeaker. | Previews respect headphones; wake-ups must be heard. |

## Phase 2 — additions from device testing

| Topic | Decision | Why |
|---|---|---|
| Exact-date alarms | The alarm editor offers **Repeat** (weekdays) or **On a date** (calendar picker, from today). A dated alarm rings once on that date, is scheduled with AlarmKit however far ahead it is, ignores "skip days off", and shows "Done" once the date has passed. Database version 3 adds `alarm.date`; backups from older versions open unchanged. | Product owner: the time could be set but not the exact date. |
| Audio session | Activation and deactivation run on a background queue. Gemma ranking stops when the app goes to the background (iOS forbids GPU work there). | Xcode's hang-risk warning and GPU errors seen on device. |
| Alarm editor | The time wheel is always first. With only a time set, the alarm rings at the next instance of that time (today if still ahead, otherwise tomorrow) — shown in words under the wheel ("Rings once: Tuesday 2 December at 7:00"). Repeat days and "On a specific date" (a plain date picker, from today) are optional extras below. | Product owner: date selection was clumsy; a time alone must just work. |
| Alarm sounds | Ten sounds, chosen per alarm with a preview: Concierge Bell (default), Grandfather Clock (Westminster chimes, public-domain melody), Chimes, Gentle Rise, Acoustic Bell, Singing Bowl, Marimba, Music Box, Classic Beeps, and the iPhone's own alarm. All but the last are synthesised on the iPhone (`AlarmToneSynthesizer`, instrument models from FocusFound) into 28-second WAV files in `Library/Sounds/`, where AlarmKit can ring them with the app closed. No audio files ship with the app. | Product owner: alarms only used the iPhone default sound. |
| Alarm conversation | Every alarm ends by asking whether to dismiss or remind again; the reply is understood by on-device speech recognition and Gemma (Phase 3). | Product owner, Nov 2026. |

## Phase 3a — the alarm conversation

| Topic | Decision | Why |
|---|---|---|
| Talking with the app closed | iOS does not let an app speak or listen while it is closed, so each ring's AlarmKit sound is a **recording of the announcement** made on the iPhone ahead of time (`Library/Sounds/ccring-<ring>.wav`, re-recorded at most hourly so "what's next" stays current, and always when the alarm changes). The alarm's own sound plays under and after the voice for the full 28 seconds. The alert has two buttons: **Stop** and **Respond**; Respond opens the app (`RespondToAlarmIntent`, `openAppWhenRun`). | The product owner wants every alarm to ask, in audio, dismiss or remind again. |
| Listening | Apple speech recognition **on the iPhone only** (`requiresOnDeviceRecognition`); nothing said is stored or sent. Microphone and speech recognition are asked for the first time an alarm conversation starts. Without permission, or for a language the iPhone cannot recognise on-device, the screen offers buttons only. | Privacy principles: 100 % local. |
| Understanding | Rules first (instant, deterministic, all 11 languages for the common phrases, clock times in English, French, Spanish, Portuguese, Indonesian), Gemma only for replies the rules do not recognise. "At 6" said after 6 means 18:00; a past time means tomorrow. Reminders are limited to the snooze range (1–120 min). | Same "rules, then offline AI" pattern as the importance ranking. |
| No answer | Two silences, or three replies not understood, = remind again after the snooze length. Closing the screen = dismiss. | A sleeper must never be left without an alarm. |
| Wake log | A "remind again" ring is a follow-up of the morning's first ring (`alarmOccurrence.originID`) and counts as a snooze. Dismissing writes **one** wake-log entry for the morning, scored from the first ring's time and the number of reminders. | Wake score definition (Phase 1a). |
| Loudspeaker | The conversation uses play-and-record with the loudspeaker forced on. | Product owner: all wake announcements on speakerphone. |

## Greater Good Software family

| Topic | Decision | Why |
|---|---|---|
| NoteNook | NoteNook (offline reader and voice notes for dyslexic readers, repository `yanghermanhm-code-notenook-ios`) joins the family: listed in About › Our apps with its icon, and named wherever the shared Gemma download is explained (it uses the same App Group, `group.com.greatergoodsoftware.models`). Until NoteNook has its own icon, `Design/notenook-product-icon.svg` is an open-book mesh in the family style, following NoteNook's master prompt (§2.2); replace the PNG when NoteNook's icon generator exists. | Product owner, Nov 2026. |
