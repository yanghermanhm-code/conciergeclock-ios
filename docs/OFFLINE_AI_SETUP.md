# Offline AI (Gemma) — setup guide

Shared by all Greater Good Software apps (ConciergeClock, PrepPilot, FocusFound, FotoPhilter). In the apps
this guide is **Settings › Offline AI › Show me how, step by step** (`OfflineAISetupGuide`
in `Packages/GGSModelKit/Sources/GGSModelUI`), drawn screen by screen, adapted to the iPhone
and translated into all 11 languages.

## Which model for which iPhone

| iPhone memory | Examples | Recommended model | Download | Runs on |
|---|---|---|---|---|
| 8 GB or more | iPhone 15 Pro / Pro Max, iPhone 16 and 17 series | **Gemma 4 E4B** | 3.66 GB | GPU (fast) |
| 6 GB | iPhone 14 Pro / Pro Max, iPhone 15 / 15 Plus | **Gemma 4 E2B** | 2.59 GB | GPU |
| Under 6 GB | iPhone 13 and earlier, SE | — (built-in features only) | — | — |

On a 6 GB iPhone, E4B can still be chosen in Settings › Offline AI › Model, but it runs on the
processor and is much slower. The app picks the right model automatically ("Automatic").

## Steps (what you see, what you tap)

1. **Your iPhone.** The guide shows this iPhone's memory, the recommended model and its size.
   One download serves every Greater Good Software app on the iPhone.
2. **Open the app's settings.** ConciergeClock: tap the **gear** at the top right of any tab.
   (Each app shows its own instruction here.)
3. **Tap Offline AI** in Settings.
4. **Find the recommended model:** the one with the green **Recommended** label.
5. **Check Wi-Fi and free space.** Leave **Download on Wi-Fi only** on. Installing needs about
   twice the download size free for a moment (5.2 GB for E2B, 7.3 GB for E4B); the guide
   shows the iPhone's free space and says whether it is enough. Free space in iPhone
   Settings › General › iPhone Storage if needed.
6. **Tap Download** under the recommended model. A progress bar appears. You can leave the
   app; the download continues. Keep the iPhone charging and on Wi-Fi.
7. **Wait for Ready.** After downloading, the app checks the file (a minute or two); the
   model then shows a green **Ready**.
8. **Turn on Use offline AI** at the top of the Offline AI screen (it is on by default).
9. **Check it works.** ConciergeClock: on the Concierge tab, the Offline AI card says
   "Ready: Gemma 4 E2B" (or E4B). Settings › Offline AI › Test offline AI times a few replies.

## Troubleshooting

| You see | Do this |
|---|---|
| "Offline AI isn't set up in this build (App Groups capability missing)" | Developer build without App Groups: the model is then stored in the app only. For sharing, add the App Group (below). |
| "Not enough space" | Free the space shown, then Retry. |
| "The download stopped" | Check Wi-Fi, then Resume / Try again. Downloads resume where they stopped. |
| "The downloaded file didn't pass the check" | The file was damaged and deleted; tap Try again. |
| The app was closed while downloading | Open it again; the download carries on or resumes. |

## Adding the guide to another app (developers)

1. Copy `Packages/GGSModelKit` and `Packages/LiteRTLM` into the app and add the
   `GGSModelCore`, `GGSModelKit` and `GGSModelUI` products to its target.
2. Signing & Capabilities: add App Group `group.com.greatergoodsoftware.models` (and
   Increased Memory Limit) so the model is shared rather than downloaded again.
3. Show the guide:

   ```swift
   OfflineAISetupGuide(
       app: .init(appName: "FocusFound",
                  openSettings: "Tap Settings at the bottom right.",       // in the app's language
                  checkItWorks: "…how to see the AI at work in this app…"),
       downloader: ModelDownloader(),        // one per app process
       languageCode: settings.languageCode)  // the app's language setting, or nil
   ```

4. The guide's text lives in each app's `tools/translations/*.txt` (keys `guide.*`);
   `python3 tools/generate_strings.py` writes it into the package's `Resources/<lang>.lproj`.
