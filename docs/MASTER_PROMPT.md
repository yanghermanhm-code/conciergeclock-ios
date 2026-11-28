# Master prompt — Concierge Clock

This file keeps the product owner's original specification (as received, November 2026) and the
answers agreed during planning. Where they differ, **docs/DECISIONS.md wins** (for example: the
product is called Concierge Clock, not JeevesWake; the tabs are Alarms · Concierge · Sounds ·
Trends; offline AI uses Gemma like the sibling apps).

## Product owner's principles (from the request)

- **One-Time Download, Lifetime Ownership:** fair, flat price with zero recurring subscription
  fees, zero hidden paywalls, and zero rent-seeking.
- **100% Local & Offline-First:** all state persists locally using native SQLite so iOS never
  purges data during low-disk-space cleanup. Works completely in Airplane Mode with zero network
  requests, zero user accounts and zero cloud dependencies.
- **Zero Telemetry:** nothing recorded, stored or transmitted about usage.
- **Zero AI Compute Overhead:** timers, calculations, procedural audio and analytics use
  deterministic client-side logic. (Agreed addition: the optional offline AI, Gemma, shared with
  the sibling apps, with the same setup instructions in Settings.)
- **User-Controlled Portability & Schema Versioning:** one-click full JSON backups and CSV
  exports; every database and export payload carries a `schemaVersion`.
- **Mobile UI:** a 4-tab bottom bar compliant with Apple's Human Interface Guidelines.
- **Branding:** the same as PrepPilot, FocusFound and FotoPhilter, except the icon: a butler in
  the common mesh theme.

## Agreed answers (planning, November 2026)

| # | Question | Answer |
|---|---|---|
| — | Price | $1.99, like the others |
| 1 | Minimum iOS | iOS 26 (AlarmKit) |
| 2 | Nightstand Mode + AlarmKit fallback | Yes |
| 3 | Reminders | Allow marking done by voice |
| 4 | Repository | `conciergeclock-ios`, bundle ID `com.greatergoodsoftware.conciergeclock` |
| 5 | Branches | Phases on branches until told to integrate with `main` |
| 6 | Voices | Bundle an offline voice engine, every voice inside the app |
| 7 | Butler's name | User can name it; default Charlie / Charles |
| 8 | Unhinged | Allow mild swearing; don't hide it |
| 9 | Briefing language | User-selectable among all 11; default English |
| 10 | Event readout | Titles, a brief summary, the start time, and whether it seems important — importance judged by the offline AI (Gemma) |
| 11 | Tabs | 4 tabs; "Concierge" as a tab with its own function |
| 12 | Extra features | All eight suggested features |
| 13 | Briefing length | User choice (Quick / Standard / Full) |
| 14 | Successful wake | Considers both how long it took to wake relative to the alarm and the number of snoozes (score defaults accepted) |
| 15 | Offline AI uses | All: importance, varied tone lines, looser commands, "Ask me about my day", weekly summary |
| 16 | Icon | (b) butler with a service tray; colours: navy with a brass/gold and teal ring |
| 17 | Default voice | Professional, slightly snobbish British |

## Additions after planning (product owner, November 2026)

1. **Calendars:** the phone's own calendars, Google and Outlook (and Exchange / Microsoft 365, iCloud,
   Yahoo) must be available — through the iPhone's accounts, read offline (Phase 1b).
2. **Speakerphone:** every wake-up announcement plays on the loudspeaker.
3. **Previews:** the voices and the announcements can be previewed on the phone (Phase 2).
4. **Wake-up safety call** (call a preset number if not awake after a set time): **dropped** — iOS
   requires a confirmation tap for every call, and anything needing manual steps after setup is not
   useful (see DECISIONS.md).
5. **Alarms behave separately from events and reminders.** Calendar and reminder items are read out
   one at a time, **pausing for a spoken reply** — "OK, I understand", "Yes, I will go", "Dismiss" or
   anything of that nature — to decide whether to remind again at the next step. The **offline AI
   (Gemma)** works out the conversation and whether to add an alarm or a future reminder (for
   example "remind me in 5 minutes"). Phase 3.

## Original specification (as attached)

> The attachment ended mid-sentence at "`Views/` — Alarms"; it is reproduced exactly.

    # MASTER BUILD PROMPT: JeevesWake (iOS Conversational Alarm & Schedule Reader)
    
    ## 1. Product Vision & Greater Good Software Alignment
    Build **JeevesWake**, a native iOS app in **Swift / SwiftUI** that acts as a conversational, "Ask Jeeves"-style alarm clock and schedule briefer for **Greater Good Software**. It announces the time, a quick summary of upcoming calendar events and tasks/reminders, listens for voice commands to dismiss or snooze (defaulting to **5 minutes**), and tracks wake-up consistency over time with smart, optional adjustments to alarm volume and background/ambient sounds.
    
    **Non-Negotiable Architectural Principles:**
    - **One-Time Download, Lifetime Ownership:** Flat one-time purchase model only—zero subscriptions, zero recurring paywalls, zero account gates.
    - **100% Local & Offline-First:** Persist alarms, persona preferences, snooze settings, wake logs, and audio preferences locally using **native SQLite** (stored in `Application Support` / outside `Caches` so iOS low-storage cleanup never purges user data). Must work completely offline with zero app servers or cloud dependencies.
    - **User-Controlled Cloud Sync & Backups:** Support one-click JSON/CSV export and import (with a `schemaVersion` key and migration support) via native iOS file/share pickers so users control their own backups and cloud syncing.
    - **Zero Telemetry & Zero AI Compute Overhead:** Zero analytics SDKs, zero telemetry, zero tracking, and zero external LLM/cloud API calls. Use deterministic local code, `EventKit`, Apple's on-device speech/TTS frameworks, rule-based command/duration parsing, and deterministic local analytics/heuristic rules.
    - **Brand & Visual System:** Match the **Greater Good Software** visual aesthetic, typography, mesh-styled app icon direction, and clean, accessible UI (VoiceOver & Dynamic Type).
    
    ---
    
    ## 2. Core Functional Requirements
    
    ### A. All-Trigger Support & Quick-Summary Schedule Engine
    - Support **all trigger types**: wake-up alarms, pre-event reminders (e.g., coming up in 15 minutes), due/overdue task reminders, and on-demand schedule check-ins.
    - Read iPhone **Calendars** (`EKEventStore`) and iPhone **Reminders/Tasks** (`EKReminder`) in **read-only mode** (`EventKit`). Any Google, Outlook, or iCloud calendars/tasks synced to the iPhone are automatically read locally without modifying or deleting user data.
    - Generate a **Quick Summary** readout: lead with the time and immediate trigger context (e.g., *"Good morning. It's 7:00 AM—you have Dentist at 9:15 AM coming up in 2 hours and 15 minutes."*), followed by a concise count and top highlights of remaining events and due tasks, ending with a prompt such as *"Would you like me to remind you again in 5 minutes?"*
    
    ### B. Spoken Briefing & Voice Command Loop
    - Speak the quick summary and prompt using `AVSpeechSynthesizer` (TTS).
    - Listen for spoken responses using Apple's `Speech` (`SFSpeechRecognizer`, preferring on-device recognition) and `AVAudioEngine`, paired with clear visual state indicators (*Speaking*, *Listening*, *Action Taken*) and large tap fallback buttons (*Snooze*, *Dismiss*, *Repeat*).
    - **Configurable Snooze Duration (Default: 5 Minutes):**
      - Users can select their default snooze interval (defaulting to **5 minutes**) and choose from preset/custom durations.
      - Parse spoken durations such as *"give me 5 minutes"*, *"snooze 10 minutes"*, *"half an hour"*, *"an hour"*, or *"remind me in 15 minutes"*; if no duration is specified (e.g., *"snooze"* or *"give me a bit"*), use the user's configured default (5 minutes).
    - **Clear Dismiss Phrase:**
      - Recognize clear spoken dismiss phrases such as *"dismiss"*, *"stop alarm"*, *"I'm awake"*, or *"turn it off"* to cleanly stop the active alarm/reminder without prompting with "dismiss confirmation" language.
    
    ### C. Voice Accents & Tone / Grammar Modes
    - **Accent Profiles (8 options):**
      - Canadian Male, Canadian Female, Southern US Male, Southern US Female, British Male, British Female, Indian Male, Indian Female.
      - Map each to the closest matching iOS `AVSpeechSynthesisVoice` locale/voice, provide a **Preview Voice** button, and guide the user if an optional regional voice isn't yet downloaded on their iPhone.
    - **Grammar & Politeness Modes (4 options):**
      - **Moderate:** Natural, clear, helpful concierge tone.
      - **Professional:** Crisp, polished, formal butler/assistant phrasing.
      - **Speaking to a Child:** Warm, simple, gentle, easy-to-follow phrasing.
      - **Unhinged:** Blunt, dramatic, demanding/impatient comedic attitude (kept within standard safe boundaries—no slurs, hate speech, or severe abuse—with a clear toggle notice).
    
    ### D. Wake Trends Dashboard & Adaptive Audio/Sound Recommendations
    - **Wake Event Logging:** Automatically log each alarm/wake cycle locally in SQLite: scheduled alarm timestamp, actual dismiss/wake timestamp, variance in minutes (`actualWake - scheduledAlarm`), snooze count, total snoozed minutes, alarm volume level used, and background/ambient sound active (if any).
    - **Wake Trends & Dashboard:**
      - Visualize **Scheduled Alarm Time vs. Actual Wake Time over time** (e.g., 7-day, 14-day, 30-day, and all-time trend charts/comparisons using Swift Charts or clean native SwiftUI views).
      - Surface key metrics: average wake variance (e.g., `+8 min late` or `on time`), on-time / first-ring dismiss success rate, snooze frequency, and weekday vs. weekend wake patterns.
    - **Preference- & Success-Rate-Driven Suggestions (User-Approved Only):**
      - Build a deterministic local **Wake Optimization Advisor** that inspects historical wake variance, snooze count, and success rate alongside user preferences, and **offers non-intrusive, one-tap suggestions** (never silently overriding settings without user consent):
        - *High snooze / late wake rate:* Offer to slightly increase alarm volume, enable gradual volume ramp-up, or switch from gentle/calming background audio to a clearer wake cue/chime.
        - *Consistent early/on-time wake with low snoozes:* Offer to keep current settings or optionally soften peak alarm volume / keep preferred ambient sound.
        - *Background sound impact:* Track whether specific background/ambient sounds (e.g., white/pink/brown noise, rain, gentle chime/pad, or none) correlate with smoother or delayed wake-ups, and let the user test, apply, or dismiss recommendations with one tap.
      - Include bundled or procedurally synthesized offline background/wake audio options (such as synthesized white/pink/brown noise or gentle ambient tones via `AVAudioEngine` / local audio assets) with independent volume controls.
    
    ### E. Siri / App Intents Integration
    - Implement `AppIntent` and `AppShortcutsProvider` so users can trigger a schedule/task quick summary, start a reminder session, or ask for their wake-up trend summary via Siri.
    
    ---
    
    ## 3. Suggested Structure & Execution Plan
    Organize into clean, modular Swift/SwiftUI layers:
    - `App/` — Entry point, navigation, App Intents.
    - `Database/` — SQLite database layer, `schemaVersion` migrations (including wake logs & recommendation history), JSON/CSV import & export.
    - `Services/EventKitReaderService.swift` — Read-only calendar & reminder fetcher + Quick Summary builder.
    - `Services/VoicePersonaEngine.swift` — 8-accent voice resolver, 4-mode script generator, `AVSpeechSynthesizer` controller.
    - `Services/VoiceCommandService.swift` — Speech capture + deterministic command & duration parser (default 5 min, clear dismiss phrase matching).
    - `Services/AlarmSessionService.swift` — Local notifications (`UNUserNotificationCenter`), snooze/dismiss state machine, active session controller, wake-event logger.
    - `Services/WakeAnalyticsService.swift` — Scheduled vs. actual wake trend calculations, success/snooze metrics, and deterministic volume/background-sound suggestion engine.
    - `Services/AmbientAudioService.swift` — Offline background/wake sound generator/player & volume controller.
    - `Views/` — Alarms