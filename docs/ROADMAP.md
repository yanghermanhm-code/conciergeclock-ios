# Roadmap

Each phase is built on its own branch and reviewed on a real iPhone before the next one.
Nothing is merged into `main` until the product owner says so.

| Phase | Branch | Contents | Status |
|---|---|---|---|
| **1a** | `phase-1a-foundation` | Xcode project (iOS 26), shared packages, `ConciergeKit` (Core + Data), SQLite schema v1, every setting, 11 languages with right-to-left, 4-tab shell with the branded top bar, launch animation, butler-with-clock icon (navy, brass→teal ring, bell badge), About pages listing all 4 apps, Offline AI screen and setup guide, JSON backup/restore, automatic backup to a chosen folder, CSV export, docs, unit tests | **In review** |
| **1b** | `phase-1b-alarms` | AlarmKit alarms (ring through silent mode and Focus, Lock Screen, Dynamic Island), alarm list and editor, repeat days, labels, one-off alarms, skip next, skip days off, default snooze 5 min + presets, wake log written by every ring, next-alarm widgets and the alarm Live Activity, **Calendars & Reminders: every account on the iPhone (phone, iCloud, Google, Outlook / Exchange / Microsoft 365, Yahoo) with per-calendar on/off and an "Add Google or Outlook" guide** | **In review** |
| 2 | `phase-2-briefing` | Calendars and Reminders (read; mark done by voice), Quick / Standard / Full briefings in 4 tones × 11 languages, title + summary + start time + importance (rule-based first), renameable butler, Apple voices, **Preview voice** (every accent and tone) and **Preview my briefing** (today's real announcement), all on the **loudspeaker**, "Brief me now", importance judged by Gemma where available |  |
| 3 | `phase-3-voice-nightstand` | On-device listening (iOS 26 speech), command and duration parser (dismiss phrases, "half an hour", "mark it done"), barge-in with echo cancellation, Speaking / Listening / Done indicator with big buttons, Nightstand Mode, bedtime preview, sunrise screen, "Are you really up?", pre-recorded briefing as the AlarmKit sound, pre-event and due-task reminder sessions, snooze limit in the conversation, conversation on the loudspeaker | |
| 4 | `phase-4-sounds` | Synthesised white / pink / brown noise and chimes (from FocusFound), rain, soft pad, sleep timer, separate volumes, gradual ramp-up | |
| 5 | `phase-5-trends` | Scheduled vs. actual charts (7 / 14 / 30 days / all time), wake score, weekday vs. weekend, Wake Optimization Advisor with one-tap suggestions and 7-night experiments, Apple Health sleep (opt-in) | |
| 6 | `phase-6-offline-ai` | Gemma: importance ranking, varied lines per tone, looser commands, "Ask me about my day", weekly wake summary | |
| 7 | `phase-7-voice-engine` | Bundled offline voice engine with every voice in the app (licences checked first) | |
| 8 | `phase-8-siri-polish` | Siri and Shortcuts (App Intents: brief me, start a reminder session, wake trends, skip tomorrow), StandBy clock face, accessibility pass, UI tests, device × iOS test matrix | |
