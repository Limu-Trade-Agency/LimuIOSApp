# iOS Deployment Review — 9 October 2026

Source: minutes of the LIMU / Worketech iOS deployment readiness review (Chigomezgo Ndovie, Timothy
Kamanga). This file records how each agreed item was handled in the app and what is still open.

## Implemented in the app

| Agreed change | Implementation |
|---|---|
| Password-visibility option | `LimuTextField` (`DesignSystem.swift`) shows an eye / eye-slash toggle on every secure field: sign-in, registration, reset, claim. VoiceOver labels: "Show password" / "Hide password". |
| Lengthy form becomes multi-step | Registration (`AuthenticationView.swift`) is now three steps — **Account** (type, name), **Contact** (phone, email, district, business name), **Password** — with a step indicator, Back/Continue, and per-step validation. The KYC form in Profile was already stepped. |
| Keyboard must not hide fields | Auth screens swap the tall hero header for a slim logo bar while the keyboard is up and add bottom padding; the KYC form gained `scrollDismissesKeyboard(.interactively)` (it already had bottom padding). Scroll views dismiss the keyboard on drag. |
| Separate verification code from new-password screen | Password reset is two screens: **Step 1** enter the 6-digit code (with Resend), **Step 2** choose the new password. If the server rejects the code on submit, the user is returned to Step 1. The API contract is unchanged — code and password are still sent together in one call at the end. |
| Terms & Conditions URL | `LimuLinks.terms` (`https://limu.co.mw/terms`) added and linked from the last registration step and the KYC consent step. |

## Open items (not code in this repo)

| Item | Owner | Status |
|---|---|---|
| Publish the `/terms` page and confirm the final URL — prerequisite for TestFlight | Chigomezgo (with LIMU IT support) | Target Mon 12 Oct 2026. If the final host/path differs, change `LimuLinks.terms` and the App Store Connect field. |
| Remove the client-portal reference from the privacy policy | Chigomezgo / LIMU IT | The policy page lives in the portal repo (`policy/index.html`, `gochi20/limu`), not here. Must be done before public submission. |
| Re-verify account deletion: confirm a deleted/inactive account **cannot** log in | Andy / LIMU IT | The recording did not show the outcome. The backend endpoint is still undeployed per `ACCOUNT-DELETION.md`, so this needs an end-to-end test once deployed. |
| App Store Connect access | Chigomezgo, Timothy | Invitation sent and accepted; not confirmed fully working. |
| Confirm the latest merge (~4 days old) is in the build | Andy / Timothy | Not confirmed in the recording. |
| Store artwork (header / search-result imagery) | Timothy sends dimensions, then Chigomezgo designs | No dates set. |

## Not committed to

- **Google sign-in** — proposed by Timothy to reduce reliance on OTPs; no commitment or deadline.
- **In-app messaging/chat** — future idea only. Adding it would need permission and privacy-label
  changes (`APP-PRIVACY.md`). Current version has no messaging or advertising.
- **TestFlight / public launch dates** — none agreed. TestFlight is gated on the terms URL; public
  submission is gated on the interface changes above and the privacy-policy fix. Publication will go
  through Worketech's Apple account.

## Verification status

The changes were written on Windows and have **not been compiled or run**. Before TestFlight: build in
Xcode, then check the password toggle on each form, the three registration steps, the two reset
screens (including a wrong code), and the keyboard on a small iPhone (SE-size) in sign-in and
registration.
