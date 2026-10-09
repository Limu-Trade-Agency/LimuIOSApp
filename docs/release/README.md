# Release documentation — Limu Mobile

Everything needed to take Limu Mobile from source to the App Store. This page is the entry point:
what each document is for, what the app-side work actually changed, and who owns what is left.

Written for Step 4 of the release plan — *prepare the release candidate, release notes, App Store
metadata, screenshots, privacy information, and production build*. Owner: Andy Kaunda.

## Start here

| If you need to… | Read |
| --- | --- |
| Know whether we can submit yet | [`RELEASE-CHECKLIST.md`](RELEASE-CHECKLIST.md) |
| Fill in the App Store Connect listing | [`APP-STORE-METADATA.md`](APP-STORE-METADATA.md) |
| Answer the App Privacy questionnaire | [`APP-PRIVACY.md`](APP-PRIVACY.md) |
| Capture or check the store screenshots | [`SCREENSHOTS.md`](SCREENSHOTS.md) |
| See what shipped in a version | [`RELEASE-NOTES.md`](../../RELEASE-NOTES.md) |
| Deploy or test the account-deletion endpoint | [`ACCOUNT-DELETION.md`](../../ACCOUNT-DELETION.md) |
| Run the production build | [`ios-release.yml`](../../.github/workflows/ios-release.yml) |

Two older documents still carry weight and are referenced throughout: `iOS_Test_Execution_Log.docx`
(first-pass test results, 25 August 2026) and `API-INTEGRATION.md` (which backend flows are wired
up, and what the backend still owes us).

## How the pieces fit

```
RELEASE-CHECKLIST.md ......... the spine. Status of every deliverable, blockers in
                               clearing order, and the step-by-step RC procedure.
   |
   +-- RELEASE-NOTES.md ...... what shipped, per version. Also holds the customer-facing
   |                           "What's New" text for App Store Connect.
   +-- APP-STORE-METADATA.md . every field in the listing, as paste-ready copy.
   +-- APP-PRIVACY.md ........ the questionnaire answers, traced to the code that
   |                           causes each one. Must agree with PrivacyInfo.xcprivacy.
   +-- SCREENSHOTS.md ........ sizes, shot list, capture commands.
   +-- ACCOUNT-DELETION.md ... the backend contract this release depends on, and what
                               the portal now implements for it.
```

The rule that matters: **`APP-PRIVACY.md`, `PrivacyInfo.xcprivacy` and the App Store Connect
questionnaire are three statements of the same fact.** If a feature starts collecting something new,
all three change together or the submission gets held.

## What changed in the app

Step 4 was mostly documentation, but five things landed in the source.

### App icon

`Limu Mobile/Assets.xcassets/AppIcon.appiconset/` previously held only `Contents.json` with three
empty entries — no image was bundled, which fails upload validation before a human sees it.

Three 1024 × 1024 icons now ship, generated from the existing emblem artwork by
[`scripts/make-app-icon.py`](../../scripts/make-app-icon.py):

| Variant | Format | Why it is built that way |
| --- | --- | --- |
| `AppIcon.png` | opaque RGB, cream gradient | Apple rejects App Store icons with an alpha channel |
| `AppIcon-Dark.png` | RGBA, transparent | The system paints the dark backdrop; the charcoal ink is recoloured to cream so the hull and plane stay visible against it |
| `AppIcon-Tinted.png` | RGBA grayscale | The system applies the user's tint |

The source is `LimuEmblem.imageset/limu-emblem.pdf` — the ship-and-plane mark, not the full lock-up,
because the "LIMU TRADE AGENCY" wordmark is unreadable at 60 px. That PDF sits on an opaque white
page, so the script flood-fills the background out from the four corners rather than keying white
globally; the white stripes *inside* the ship are part of the mark and have to survive.

Rerun the script after any change to the emblem artwork:

```bash
python scripts/make-app-icon.py
```

### Account deletion

App Store Review Guideline 5.1.1(v) requires that an app which creates accounts lets people delete
them from inside the app. `Profile → Delete Account` now does.

- `DeleteAccountView` (`Limu Mobile/ProfileView.swift`) — states what is removed, then requires the
  account password **and** the word DELETE typed out before the destructive button activates.
- `AppState.deleteAccount(password:)` — revokes the device's push token while the session can still
  authenticate the call, sends `DELETE profile/delete.php`, then clears the Keychain session. On
  failure it re-registers the push token rather than leaving the device silently unreachable.
- `AppState.logout()` is now guarded on `isAuthenticated`, so the shared logout closure is a no-op
  when deletion has already torn the session down.

The endpoint, `DELETE profile/delete.php`, is now built in the portal repository (`gochi20/limu`)
but not yet deployed or tested. It destroys the credential, sessions, device tokens, verification
codes and KYC submission, anonymises the `Clients` row so the legally retained cargo, shipment and
invoice records are not orphaned, and writes a hashed audit row. Detail in
[`ACCOUNT-DELETION.md`](../../ACCOUNT-DELETION.md).

### Privacy manifest

`Limu Mobile/PrivacyInfo.xcprivacy` declares no tracking, the `UserDefaults` required-reason API
(`CA92.1`), and the six data types the app transmits. The project uses Xcode 16's
filesystem-synchronised groups (`objectVersion = 77`), so a file dropped into `Limu Mobile/` is
bundled automatically — no project-file edit was needed. The CI workflow fails the build if it is
missing from the archive anyway.

### Privacy policy links

`LimuLinks.privacyPolicy` (`Limu Mobile/DesignSystem.swift`) holds `https://portal.limu.co.mw/policy`, used
by a Privacy Policy row in Profile and a link on the delete screen. One constant, so the app and the
App Store listing cannot drift apart.

The page itself is drafted in the portal repository at `policy/index.html`, with deployment notes
and the outstanding placeholders alongside it in `policy/README.md`. It is not deployed yet.

### Export compliance

`ITSAppUsesNonExemptEncryption = false` in `LimuMobileInfo.plist`. The app uses only HTTPS, which is
exempt; setting it in the plist stops App Store Connect asking on every single upload.

## The production build

It cannot be produced on the current Windows workstation — archiving an iOS app requires Xcode on
macOS. [`ios-release.yml`](../../.github/workflows/ios-release.yml) is the substitute: a
`macos-latest` job that imports the signing material, archives, verifies the privacy manifest made
it into the bundle, exports with [`ExportOptions.plist`](ExportOptions.plist), and uploads to
TestFlight.

It runs on a `v*` tag or on demand, and fails until six repository secrets exist — they are listed
in the header comment of the workflow, and none of them can be created without an Apple Developer
Program membership.

Build numbering is deliberate: `MARKETING_VERSION` stays in source control and is edited by hand per
release, while `CURRENT_PROJECT_VERSION` is injected by CI from the run number. Do not hand-edit the
build number — every upload needs a unique, increasing one, and the run number gives that for free.

## What is still outstanding

Four blockers, none of which are code. The checklist carries the detail and the current status.

| # | Blocker | Owner |
| --- | --- | --- |
| 1 | Apple Developer Program membership and a Mac | Management |
| 2 | Deploy and test `DELETE profile/delete.php` | Backend |
| 3 | Fill in, legally review and host the drafted privacy policy page | Management |
| 4 | Demo account for App Review — KYC-complete, with real records | Backend / Ops |

The demo account also unblocks the screenshots, so it is worth doing early even though it looks like
the smallest item on the list.

Five product-owner decisions are open as well — iPad support, dark mode, WhatsApp OTP, the iOS 26.5
floor, and whether to ship without an invoices screen. They are written up at the end of
[`RELEASE-CHECKLIST.md`](RELEASE-CHECKLIST.md).

## Keeping this current

- A new version means a new `##` section at the top of `RELEASE-NOTES.md`, following the conventions
  at the foot of that file.
- A feature that collects new data means updating `APP-PRIVACY.md`, `PrivacyInfo.xcprivacy` and the
  App Store Connect questionnaire in the same change.
- A change to the emblem means rerunning `scripts/make-app-icon.py`.
- A new backend dependency means a contract document in the repository root, alongside
  `ACCOUNT-DELETION.md` and `PASSWORD-RESET-MIGRATION.md`, and a line in `API-INTEGRATION.md`.
