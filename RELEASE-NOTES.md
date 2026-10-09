# Limu Mobile — Release Notes

## 1.0 (build 1) — Release candidate

- **Status:** Release candidate prepared. Not yet archived or submitted — see
  [`docs/release/RELEASE-CHECKLIST.md`](docs/release/RELEASE-CHECKLIST.md) for the remaining blockers.
- **Bundle identifier:** `Limu-Trade.Limu-Mobile`
- **Minimum iOS:** 26.5 · **Devices:** iPhone and iPad (portrait + landscape)
- **Backend:** `https://portal.limu.co.mw/Api/v4/client/` (V4 client API)

### App Store "What's New" text (first release)

> Limu Mobile brings your Limu Trade account to iPhone and iPad. Track cargo and shipments in real
> time, review and approve order forms, complete your KYC profile, and get push notifications the
> moment something moves.

(First releases show the description rather than "What's New"; this text is kept here so the field
can be filled if App Store Connect requests it.)

### What is in this build

**Account and access**
- Register as an individual or business client, with a 6-digit email verification code.
- Sign in with email or phone number; **Stay logged in** keeps the session in the Keychain, and
  expired access tokens are refreshed and rotated automatically.
- Password reset is OTP-based: the API emails a 6-digit code that is typed back into the app.
  This replaced the previous `limu://` deep-link reset, which did not reliably reopen the app from
  an email button tap (see `PASSWORD-RESET-MIGRATION.md`).
- Account claim for existing Limu Trade clients, via a one-time link from the portal.
- Logout clears the session and Keychain.
- **Delete account** from Profile, requiring the account password and the word DELETE typed out.
  Deletion revokes the device's push token, clears the Keychain session, and returns the app to the
  sign-in screen. Required by App Store Review Guideline 5.1.1(v); see `ACCOUNT-DELETION.md`.

**KYC**
- Full KYC capture: personal details, Malawi district picker, phone field defaulting to +265 with
  country switching, date of birth picker, import/export business type, and database-backed
  business-category search.
- Save as draft or complete immediately. Cargo, Shipments, Order Forms and dashboard summary data
  stay gated until KYC is complete — this is intentional.

**Cargo and shipments**
- Cargo list and detail, package data, and a cargo timeline with checkpoints.
- Shipment list and detail with status and current location, plus shipment updates.

**Order forms**
- Order-form list with Draft / Client Review / Pending Payment / Pending Purchase / Purchased /
  Dormant filters.
- Per-item review actions and full order-form review completion.
- Item photo previews.

**Notifications**
- In-app notification centre with unread count, mark-read and mark-all-read.
- Push notification registration and device-token upload, with taps routing to the matching tab
  (cargo, shipment, order form, profile or home).

**Profile**
- View and edit profile details, and change password.
- Privacy policy link (`https://portal.limu.co.mw/policy`), also linked from the delete-account screen.

**Platform**
- Native SwiftUI throughout, Poppins type, and the Limu palette (charcoal `#161A1C`,
  copper `#D38239`, peach `#F3CBA1`, cream `#F5F0EC`).
- App icon built from the Limu emblem, in light, dark and tinted variants. Regenerate with
  `python scripts/make-app-icon.py`.
- Privacy manifest (`Limu Mobile/PrivacyInfo.xcprivacy`) declaring no tracking and the
  UserDefaults required-reason API.
- `ITSAppUsesNonExemptEncryption = false` so export compliance is not asked on every upload.

### Known limitations in 1.0

These are deliberate MVP scope decisions or accepted gaps, not regressions. Each one is either
already agreed as out of scope or listed as an open item in `docs/release/RELEASE-CHECKLIST.md`.

1. **No invoices screen.** Invoice models, list/detail fetching and payment-proof upload exist in
   the data layer (`AppState.uploadPayment`, `APIClient.uploadPaymentProof`) but have **no UI**.
   The Invoices tab was replaced by Order Forms. App Store copy must not advertise invoice viewing
   or payment upload.
2. **Light appearance only.** The app does not follow the system dark-mode setting
   (Defect #4 in the test log). Awaiting a product-owner decision on whether dark mode is in MVP.
3. **Shipment route labels** show only `currentLocation`. The API does not expose `origin` and
   `destination` yet; confirmed out of MVP scope (L10).
4. **Per-package stage progress** is a single `checked` flag plus timestamp rather than
   container-loading / offloading / loading-check / warehouse-check stages. Out of MVP scope.
5. **Push notifications are unverified on a physical device.** The V4 device-token endpoint passed
   HTTP testing, but APNs registration has never run outside the simulator because the push
   entitlement and provisioning profile do not exist yet (F17, L11, D6).
6. **Save feedback on Edit Profile** is a button-label change ("Changes saved") rather than a
   toast (Defect #3, low severity).
7. **Pending-user login** routes through a "check your WhatsApp number" prompt with a "use email
   instead" option, rather than straight to email OTP (Defect #1, low severity, scope question
   open with the product owner).
8. **No crash reporting or analytics SDK** is integrated (L9). Post-release monitoring is limited
   to App Store Connect crash reports and Xcode Organizer.
9. **Account deletion is unverified end to end.** The screen, the client call and the server route
   are all built, but `DELETE profile/delete.php` has not been deployed to `portal.limu.co.mw` or
   run against a database. Deploy and test before submission — see `ACCOUNT-DELETION.md`.

### Testing

First-pass testing completed 25 August 2026 by Andy Kaunda — see `iOS_Test_Execution_Log.docx`.
42 checks: 18 passed, 4 failed / not started, 18 blocked or partial, 2 not applicable yet.
The blocked items cluster on three causes: no real test data on the live account, no physical
iPhone, and no Apple Developer Program membership.

---

## Release-notes conventions

- One `##` section per submitted version, newest first, titled `MARKETING_VERSION (build N)`.
- Every section carries: status, what shipped, known limitations, and the testing reference.
- The **App Store "What's New"** block is the text pasted into App Store Connect. Keep it under
  4,000 characters, customer-facing, and free of internal issue numbers.
