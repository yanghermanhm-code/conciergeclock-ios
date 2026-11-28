# Data schema (database schemaVersion 4, backup schemaVersion 1)

This document is the **contract** for the on-device database, the JSON backup format and a future
Android app. Field names are identical in Swift, SQLite and JSON.

General rules (the same as FocusFound and PrepPilot):

- IDs are uppercase UUID strings.
- Timestamps are ISO-8601 strings in UTC with milliseconds in JSON (`2026-11-27T07:12:00.000Z`).
- `dateKey` is `YYYY-MM-DD` in the user's **local** time zone: the day the alarm was **scheduled**.
- Raw values of enums are stored as text and never renamed.
- Every record carries its own `schemaVersion`.
- The wake log stores **times and counts only** — never calendar text and never what was said.

## Tables

### keyValue
`key` (text PK), `value` (JSON blob). Keys: `settings` (the `AppSettings` document),
`schemaVersion` (database version), `autoBackupFolderBookmark` (this iPhone only; never exported).

### alarm
| field | type | notes |
|---|---|---|
| id | text PK | |
| schemaVersion | int | 1 |
| kind | text | `wakeUp` \| `checkIn` |
| label | text | may be empty |
| hour / minute | int | local time, 0–23 / 0–59 |
| repeatDays | JSON int array | 1 = Sunday … 7 = Saturday; empty = rings once |
| isEnabled | bool | |
| snoozeMinutes | int? | 1–120; null = default from settings |
| toneOverride | text? | `moderate` \| `professional` \| `child` \| `unhinged` |
| accentOverride | text? | `canadianMale` … `indianFemale` (8 values) |
| lengthOverride | text? | `quick` \| `standard` \| `full` |
| soundID | text | wake sound id (default `chime.soft`) |
| rampUpSeconds | int | 0–300 |
| ambientSoundID | text? | Nightstand Mode sound |
| skipDay | text? | `YYYY-MM-DD` of a single skipped occurrence |
| date | text? | since database version 3 (alarm record version 2): `YYYY-MM-DD` of a one-off alarm on an exact date; only when `repeatDays` is empty. Scheduled however far ahead, and not skipped on days off |
| skipOnDaysOff | bool | holidays and day-off keywords in the calendar |
| snoozeLimit | int? | 0–20; null = no limit |
| createdAt / updatedAt | datetime | |

### wakeEvent (wake log)
| field | type | notes |
|---|---|---|
| id | text PK | |
| schemaVersion | int | 1 |
| alarmID | text? | → alarm, set null on delete |
| alarmLabel | text | snapshot |
| scheduledAt | datetime | first ring |
| dismissedAt | datetime? | null when missed |
| dismissMethod | text | `voice` \| `button` \| `system` \| `missed` |
| snoozeCount / snoozedMinutes | int | |
| volume | double? | app alarm volume 0–1 |
| ambientSoundID / wakeSoundID | text? | |
| nightstandMode | bool | full conversation vs. AlarmKit fallback |
| awakeCheck | text | `notAsked` \| `passed` \| `missed` |
| score | int | 0–100, see below |
| isSuccess | bool | score ≥ threshold |
| dateKey | text | indexed |
| createdAt | datetime | |

Variance (minutes) = `dismissedAt − scheduledAt` (negative = early), derived, not stored.

### alarmOccurrence (since database version 2; this iPhone only, not in backups)
One ring handed to AlarmKit. `id` (the AlarmKit alarm UUID, uppercase string — derived from the alarm id
and ring time, see `AlarmPlanner.occurrenceID`), `schemaVersion`, `alarmID`, `scheduledAt`, `snoozeCount`
(reported Snooze taps), `snoozeMinutes` (the length it was scheduled with), `status` (`scheduled` \|
`finished` \| `missed` \| `cancelled`), `originID` (since database version 4, occurrence record version 2: for a
"remind again" ring, the id of the morning's first ring; null for a first ring), `createdAt`, `updatedAt`.
Each "remind again" adds one to the first ring's `snoozeCount`. When the morning ends (dismissed, or missed),
one `wakeEvent` is written with the first ring's `id` and `scheduledAt`; snoozes = its `snoozeCount`. Outcomes
older than 60 days are deleted (the wake log keeps the history).

### recommendation (Wake Optimization Advisor)
`id`, `schemaVersion`, `kind` (`raiseVolume` \| `addRampUp` \| `clearerWakeSound` \| `softenVolume` \|
`keepSettings` \| `tryAmbientSound` \| `stopAmbientSound` \| `earlierBedtime`), `status` (`offered` \|
`testing` \| `applied` \| `dismissed`), `alarmID?` (→ alarm, set null), `parameters` (JSON string
map), `experimentStart?` / `experimentEnd?` (`YYYY-MM-DD`), `createdAt`, `resolvedAt?`.

## Wake score

```
lateMinutes = max(0, floor(variance) − graceMinutes)
latePenalty = min(maxLatePenalty, lateMinutes × pointsPerLateMinute)
score       = clamp(100 − latePenalty − snoozeCount × pointsPerSnooze − (awakeCheck == missed ? missedCheckPenalty : 0), 0, 100)
success     = score ≥ successThreshold
```

Defaults: grace 2, per late minute 4, max late 60, per snooze 10, missed check 15, threshold 80.
A missed alarm scores 0. Ports must reproduce `WakeScore.compute` exactly.

## Settings document (`AppSettings`)

JSON object; unknown keys are ignored and missing or invalid values fall back to defaults, so
files from older and newer versions always open. Fields and defaults:
`theme` system · `languageCode` null (follow iPhone) · `appIcon` dark · `hapticsEnabled` true ·
`butlerName` {formal "Charles", familiar "Charlie"} · `voiceAccent` britishMale · `tone`
professional · `briefingLength` quick · `briefingLanguageCode` "en" · `unhingedAcknowledged` false ·
`allowMildSwearing` true · `speakEventTitles` true · `defaultSnoozeMinutes` 5 · `snoozeEscalation`
true · `snoozeLimit` null · `awakeCheckEnabled` true · `awakeCheckDelayMinutes` 3 ·
`bedtimePreviewEnabled` true · `sunriseEnabled` true · `sunriseMinutes` 15 ·
`suggestAlarmFromCalendar` true · `getReadyMinutes` 90 · `dayOffKeywords` [Vacation, Holiday, Day
off, PTO, Out of office, OOO] · `healthSleepEnabled` false · `wakeScoreRules` (above) ·
`excludedCalendarIDs` [] · `excludedReminderListIDs` [] (EventKit identifiers, device-specific) ·
`useOfflineAI` true · `localModel` automatic · `modelDownloadWiFiOnly` true · `lastBackupAt` ·
`autoBackupEnabled` false · `lastAutoBackupAt`.

## Backup file (`.conciergeclock`)

```json
{
  "format": "conciergeclock-backup",
  "schemaVersion": 1,
  "databaseSchemaVersion": 4,
  "createdAt": "2026-11-27T07:12:00.000Z",
  "appVersion": "1.0 (1)",
  "settings": { … },
  "alarms": [ … ],
  "wakeEvents": [ … ],
  "recommendations": [ … ]
}
```

Restoring replaces everything in one transaction. Links to alarms missing from the file are
cleared. This iPhone's onboarding state and automatic-backup choice are kept. A file with a
higher `schemaVersion` is refused ("made by a newer version"); older ones are upgraded by
`BackupMigrator`.

## CSV exports

- **Wake log:** `date, alarm, scheduled, woke, variance_minutes, snoozes, snoozed_minutes,
  dismissed_by, awake_check, score, success, nightstand_mode, ambient_sound, wake_sound, volume`
- **Alarms:** `label, time, repeats_on, enabled, snooze_minutes, tone, accent, briefing, sound,
  ramp_up_seconds`

UTF-8, CRLF line ends, RFC 4180 quoting; text starting with `= + - @` is prefixed with `'`.
