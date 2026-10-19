import Foundation

/// The one file to edit when starting a new app from this template.
/// Everything user-facing that changes per app (name, copy, product IDs, links) lives here.
/// Compiled into both the app and the widget, so keep it free of UIKit/SwiftUI imports.
enum AppConfig {
    // MARK: Identity
    static let appName = "Dialysis Log"
    static let bundleID = "com.example.dialysis-log"
    static let appGroupID = "group.com.example.dialysis-log"
    /// Your App Store ID once the app is live. The Rate button stays hidden while it is empty.(the number in the App Store URL).
    static let appStoreID = ""

    // MARK: Sync
    /// Set to true only after enabling iCloud + CloudKit on the App ID (see docs/capabilities.md).
    /// With false, SwiftData stores locally and the app works with no Apple capabilities at all.
    static let iCloudSyncEnabled = false

    // MARK: StoreKit (must match App Store Connect and StoreKit/Products.storekit)
    /// Apple allows only letters, digits, underscores and periods in product IDs, so hyphens in the bundle ID are dropped.
    static let productPrefix = bundleID.replacingOccurrences(of: "-", with: "")
    static let annualProductID = "\(productPrefix).pro.annual"
    static let lifetimeProductID = "\(productPrefix).pro.lifetime"

    // MARK: Links
    static let supportEmail = "support@somexai.com"
    /// Hosted copy of PrivacyPolicyView, one page per app under somexai.com/privacy (somexai_corp repo, scripts/privacy.py).
    static let privacyPolicyURL = URL(string: "https://somexai.com/privacy/dialysis-log/")!
    static let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

    // MARK: Copy
    /// What the app calls one record. "Entry" for a generic log; "Dose", "Visit", "Inspection" in real apps.
    static let entryNoun = "Entry"
    static let entryNounPlural = "Entries"
    /// File name stem for exports: "dialysis-log-2026-09-11.csv".
    static let exportFileStem = "dialysis-log"

    static let onboarding: [OnboardingPage] = [
        OnboardingPage(symbol: "drop.circle", title: "Today, first",
                       body: "Four or five exchanges a day is a lot of writing down. This opens on today, with the prescribed values already filled in."),
        OnboardingPage(symbol: "equal.circle", title: "The subtraction, done for you",
                       body: "Drained minus filled, worked out as you type, so nobody is doing arithmetic at the drain bag at two in the morning."),
        OnboardingPage(symbol: "doc.richtext", title: "A sheet for the visit",
                       body: "One PDF a month with your numbers and anything you reported. Your data stays on your phone."),
    ]

    static let paywallSymbol = "checkmark.seal.fill"
    static let paywallHeadline = "Unlock \(appName)"
    static let paywallBenefits = [
        "Unlimited exchanges, sessions and days",
        "The monthly sheet as a PDF for your unit",
        "CAPD, APD and home haemodialysis",
        "No ads, no account, no tracking",
    ]

    // MARK: How-to guide (Settings → How do I use this app; also the ? button on the home screen)
    static let howToIntro = "Four steps. The first takes five minutes and only happens once."
    static let howTo: [HowToStep] = [
        HowToStep(symbol: "list.clipboard", title: "Copy in your prescription",
                  body: "Tap ⋯ then My prescription. Put in what your unit wrote: modality, fill volume, dwell, usual dextrose, dry weight and the daily fluid target. Leave anything blank that your unit has not given you a number for.",
                  tip: "Put your unit's phone number in. It becomes a call button the moment you record a cloudy drain, which is exactly when nobody can find it."),
        HowToStep(symbol: "plus.circle", title: "Record each exchange",
                  body: "Tap Record an exchange. It opens already filled in with your prescribed values, so a normal exchange is the time, the drained volume, and save. The fluid removed appears as you type.",
                  tip: "Say \"Record an exchange in \(appName)\" to Siri to jump straight here."),
        HowToStep(symbol: "heart.text.square", title: "Add the day's numbers",
                  body: "Weight and blood pressure once a day, at the same point each day — most units say first thing, after the overnight drain. Note anything you felt: swelling, breathlessness, the exit site."),
        HowToStep(symbol: "doc.richtext", title: "Take the sheet to your visit",
                  body: "Tap ⋯ then This month's sheet. It prints what was prescribed, the days you recorded, the average fluid off, and anything you flagged — and it says plainly which days are blank rather than closing the gap."),
        HowToStep(symbol: "phone.fill", title: "What this app will not do",
                  body: "It is a diary, not a clinician. It will never tell you which bag to hang, change a prescription, or say what a number means. If something worries you — a cloudy drain especially — that is a call to your unit, and the app puts the number in front of you rather than an opinion."),
    ]

    /// Display prices used only by DEBUG screenshot runs (`-mockPrices`). Keep in sync with StoreKit/Products.storekit.
    static let mockPrices = (annual: "$4.99", lifetime: "$12.99")

    // MARK: Behaviour
    /// Ask for an App Store review after this many successful saves (once per app version).
    static let reviewAfterSuccesses = 3
}

struct HowToStep: Identifiable, Hashable {
    var id: String { title }
    let symbol: String
    let title: String
    let body: String
    var tip: String? = nil
}

struct OnboardingPage: Identifiable, Hashable {
    var id: String { title }
    let symbol: String
    let title: String
    let body: String
}
