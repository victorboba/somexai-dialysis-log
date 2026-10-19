# Dialysis Log

The daily log a home dialysis patient keeps: every exchange, the fluid that came off, the weight and pressure, and a monthly sheet to take to the dialysis unit.

One of a set of niche iPhone apps built from a shared SwiftUI template. It was never released on the App Store; the code is here for anyone to use. The template is [somexai-ios-template](https://github.com/victorboba/somexai-ios-template) and the rest of the collection is in [somexai-ios-apps](https://github.com/victorboba/somexai-ios-apps).

## What it does

- Opens on today. Four or five entries a day means the first question is what is left to record; the month behind it is for the visit.
- Works out drained minus filled as you type. If either figure is missing there is no answer, and the app says so rather than guessing.
- A new exchange opens pre-filled with the prescribed fill volume, dwell and usual dextrose, so a normal exchange is a time, a drained volume and Save.
- Covers CAPD, APD and home hemodialysis, each showing only the fields that belong to it.
- Recording a cloudy drain shows the standard advice to call the unit the same day and turns the unit's number into a call button. The app reports what was seen and never names a condition.
- Monthly PDF with what was prescribed, the days recorded, the average fluid off and anything flagged. Days with no entry are shown as blank, not filled in. A CSV has one row per treatment.
- Home Screen widget and a Siri/Shortcuts action to log an entry. A step-by-step How do I use guide is in Settings.

## The boundary

This is a diary, not a clinician. It does not set or change a prescription, choose a dextrose strength, fill volume or dry weight, or advise on treatment, and it is not a medical device. Every number in it is entered by the patient from what their unit wrote down. The only arithmetic it does is the subtraction the paper flow sheet already asks for.

## Privacy

Everything is stored on the device in SwiftData. There is no account, no analytics and no network access, and iCloud sync is off (`iCloudSyncEnabled = false`). CSV and PDF files leave the phone only when you share them.

## Build and run

Requirements: Xcode 26 or later, [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`), iOS 17+ (iPhone).

```bash
xcodegen generate
open DialysisLog.xcodeproj
```

Pick the `DialysisLog` scheme and an iPhone simulator, then Run.

- Tests: `xcodebuild -scheme DialysisLog -destination 'platform=iOS Simulator,name=iPhone 16 Pro Max' test`
- Paywall: the app has a hard paywall (annual subscription or lifetime purchase). Running from Xcode uses the bundled `Products.storekit` file, so purchases are simulated and free. Debug builds can also skip it with the `-unlock` launch argument or the Debug switch in Settings.
- To run on your own device or ship it: set your team in `project.yml` (`DEVELOPMENT_TEAM`), change the `com.example` bundle ID prefix in `project.yml`, both `.entitlements` files and `Products.storekit`, and update `supportEmail`, `privacyPolicyURL` and `appStoreID` in `Shared/AppConfig.swift`.

## Notes for developers

The unit tests cover the ultrafiltration arithmetic and the cases where it must refuse to answer, day totals that are absent rather than zero, the effluent advice wording, modality-specific fields, and the exports.

## Project layout

- `DialysisLog/App/`: app entry point and `RootView`, the single gate (onboarding, paywall, then the app).
- `DialysisLog/Core/`: StoreKit entitlement, CSV and PDF export, review prompt, and the App Shortcut.
- `DialysisLog/Features/`: the screens.
- `DialysisLog/Models/`: SwiftData models and the logic on them.
- `DialysisLogWidget/`: the Home Screen widget.
- `DialysisLogTests/`, `DialysisLogUITests/`: unit and UI tests.
- `Shared/AppConfig.swift`: everything that changes per app (name, copy, product IDs, links, how-to guide).

## License

MIT. See [LICENSE](LICENSE).
