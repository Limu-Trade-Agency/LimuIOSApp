# Release checklist — Limu Mobile 1.0 (release candidate)

Step 4 of the release plan: release candidate, release notes, App Store metadata, screenshots,
privacy information, production build. Owner: Andy Kaunda.

This file tracks what is done, what is blocked, and what has to be decided by someone else.

## Where things stand

| Deliverable | State | Artefact |
| --- | --- | --- |
| Release notes | **Done** | [`RELEASE-NOTES.md`](../../RELEASE-NOTES.md) |
| App Store metadata | **Drafted** — copy is final, account-level values still `«TBC»` | [`APP-STORE-METADATA.md`](APP-STORE-METADATA.md) |
| Privacy information | **Done** — manifest shipped, questionnaire answers written, policy URL wired into the app | [`APP-PRIVACY.md`](APP-PRIVACY.md), `Limu Mobile/PrivacyInfo.xcprivacy` |
| Privacy policy page | **Drafted** — needs placeholders filled, a legal review, and deploying | `policy/` in the portal repo |
| App icon | **Done** — light, dark and tinted, generated from the Limu emblem | `scripts/make-app-icon.py`, `AppIcon.appiconset` |
| Account deletion | **Built both sides** — needs deploying and testing | [`ACCOUNT-DELETION.md`](../../ACCOUNT-DELETION.md) |
| Screenshots | **Needs a size check** — the supplied set is iOS, but the capture device is unconfirmed | [`SCREENSHOTS.md`](SCREENSHOTS.md) |
| Release-candidate config | **Done** — export compliance key set, build numbering wired to CI | `LimuMobileInfo.plist`, `.github/workflows/ios-release.yml` |
| Production build | **Blocked** — no Mac, no Apple Developer Program | `.github/workflows/ios-release.yml`, `ExportOptions.plist` |

The production build genuinely cannot be produced from the current Windows workstation: archiving
an iOS app requires Xcode on macOS. Everything that does not require a Mac has been prepared, and
the CI workflow will produce the build the moment signing material exists.

## Blockers, in the order they have to be cleared

### 1. Apple Developer Program membership (L1)

Still awaiting a management decision on the Mac and the $99/yr membership. Nothing in L2, L3, L4,
L7 or L8 can move until this lands. Once it does, populate the six repository secrets listed at the
top of `.github/workflows/ios-release.yml`.

### 2. Account deletion — deploy and test

Both sides are now built. The app has `Profile → Delete Account`; the portal repository
(`gochi20/limu`, branch `Andy`) has `Api/v4/client/profile/delete.php` and
`ClientAuthService::deleteAccount()`.

What remains is deployment to `portal.limu.co.mw` and a test pass — none of the PHP has been run
against a database yet. The `api_v4_client_deletions` audit table is created automatically on the
first request after deployment, like every other V4 table. Checklist in
[`ACCOUNT-DELETION.md`](../../ACCOUNT-DELETION.md).

### 3. Privacy policy page

`https://portal.limu.co.mw/policy` is declared in the metadata and linked from two places in the app. A
full draft now exists at `policy/index.html` in the portal repository (`gochi20/limu`) —
self-contained HTML, brand-styled, covering all six data types and the deletion retention carve-out.
It sits at the repository root, which is the portal's document root, so it serves at `/policy` with
no rewrite rule and no session.

Three things stand between it and live:

1. **17 placeholders** — company registration details, contact addresses, retention periods, the
   statutory citation, and the hosting country. Listed in `policy/README.md`.
2. **A legal review** — particularly sections 5, 8, 10 and 13.
3. **Deploying it** — publicly reachable at that exact URL, with no login wall. Apple checks.

Management deliverable, but the writing is done.

### 4. Demo account for App Review

Apple cannot review a sign-in-gated app without one, and it has to be KYC-complete with real cargo,
shipment and order-form records — otherwise the reviewer sees the KYC gate and five empty tabs.
Requirements spelled out in [`APP-STORE-METADATA.md`](APP-STORE-METADATA.md#demo-account-requirements).
The same account unblocks the screenshots.

### 5. iOS screenshots

`Limu-Android-Screenshots.zip` turns out to hold iOS simulator captures, taken as the reference for
the Android copy. Whether they are usable depends on the capture device: 6.9" (Pro Max) uploads,
6.3" does not. Check that first — the command is in [`SCREENSHOTS.md`](SCREENSHOTS.md) — then
capture whatever is missing, including the iPad 13" set.

## Decisions needed from the product owner

These are open questions, not defects. Each one changes what gets submitted.

1. **iPad support.** The target builds for `TARGETED_DEVICE_FAMILY = "1,2"`, which makes a 13" iPad
   screenshot set mandatory and puts iPad layout in scope for review. If iPad is not a real 1.0
   target, set it to `"1"` now and the requirement disappears.
2. **Dark mode** (Defect #4). The app is locked to light appearance. In scope for 1.0, or descoped
   and noted?
3. **WhatsApp OTP** (Defect #1). Pending-user login prompts for WhatsApp with an email fallback,
   which is not what the approved MVP scope describes. Scope correction, or update the test plan?
4. **Minimum iOS 26.5.** This is a very narrow floor and excludes anyone who has not updated
   recently. Deliberate, or should it come down?
5. **Invoices.** Invoice fetching and payment-proof upload are implemented in the data layer with
   no UI. Ship 1.0 without them (current plan), or hold the release?

## Release-candidate steps, once the blockers clear

1. Confirm `main` is green and all merged work is in.
2. Confirm the app icon renders in Xcode with no missing-icon warning. Regenerate with
   `python scripts/make-app-icon.py` if the emblem artwork changes.
3. Confirm `MARKETING_VERSION` is `1.0` in both build configurations. The build number is injected
   by CI from the run number — do not hand-edit `CURRENT_PROJECT_VERSION`.
4. Tag the candidate: `git tag v1.0-rc1 && git push origin v1.0-rc1`.
5. Run the **iOS release build** workflow (it also fires on `v*` tags). It archives, verifies the
   privacy manifest is in the bundle, exports, and uploads to TestFlight.
6. Smoke-test the TestFlight build on a physical iPhone (L4). This is the first chance to close
   F17, D6 and L11 — APNs registration has never run outside the simulator.
7. Re-run the regression checklist (R1–R7) against the TestFlight build.
8. Complete the App Store Connect listing from
   [`APP-STORE-METADATA.md`](APP-STORE-METADATA.md), upload the screenshots, and fill the App
   Privacy questionnaire from [`APP-PRIVACY.md`](APP-PRIVACY.md).
9. Obtain and record UAT sign-off (L7).
10. Submit, with **Manually release this version** selected so the public release stays gated on
    sign-off.

## Pre-submission verification

Run through these against the actual archive, not the debug build.

- [ ] App icon present; no missing-icon warning in Xcode or at upload. The light variant must have
      no alpha channel — Apple rejects transparent App Store icons.
- [ ] `Profile → Delete Account` completes end to end against the live API, and the account really
      is gone afterwards.
- [ ] `PrivacyInfo.xcprivacy` is in `Copy Bundle Resources` and inside the built `.app` (the CI
      workflow checks this and fails the build if not).
- [ ] `ITSAppUsesNonExemptEncryption` is `false` in the built Info.plist, so export compliance is
      not asked at upload.
- [ ] `aps-environment` resolves to `production` in the Release configuration — it comes from
      `APS_ENVIRONMENT`, which is `development` in Debug and `production` in Release.
- [ ] The app points at `https://portal.limu.co.mw/Api/v4/client/`, with no `LIMU_API_BASE_URL`
      override and no `--local-api` in the scheme's launch arguments.
- [ ] `--logged-in` is **not** set in the Release scheme. It serves `MockData` instead of the API.
- [ ] Sign in, complete a cold start, and background/resume without a crash.
- [ ] Push permission prompt appears and a device token reaches `devices/push-token.php`.
- [ ] Support URL, marketing URL and privacy policy URL all load in a private browser window.
- [ ] Demo account signs in cleanly from a network outside Malawi and shows populated tabs.

## Notes on the ATS exception

`LimuMobileInfo.plist` keeps `NSAllowsLocalNetworking` and an insecure-HTTP exception scoped to
`localhost`, for the XAMPP development backend. Both are acceptable to App Review — `localhost` is
a recognised exception and does not weaken transport security for production traffic, which is
HTTPS-only. No action needed, but expect it to come up if a reviewer reads the plist.
