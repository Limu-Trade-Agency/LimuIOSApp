# App Store Connect metadata — Limu Mobile 1.0

Paste-ready copy for the App Store Connect listing. Anything marked **«TBC»** needs a decision or a
value from Limu Trade management before submission — do not invent these.

## App record

| Field | Value |
| --- | --- |
| App name (30 char max) | `Limu Mobile` |
| Bundle ID | `Limu-Trade.Limu-Mobile` |
| SKU | `LIMU-MOBILE-IOS-001` |
| Primary language | English (U.K.) |
| Apple Team ID | **«TBC»** — no Apple Developer Program membership yet (L1) |
| Primary category | Business |
| Secondary category | Productivity |
| Age rating | 4+ (no objectionable content; answer "None" to every questionnaire item) |
| Price | Free |
| Availability | Malawi at minimum; confirm whether the wider region should be included — **«TBC»** |

## Subtitle (30 char max)

```
Cargo and shipment tracking
```
(27 characters.)

## Promotional text (170 char max — editable without a new build)

```
Track your Limu Trade cargo and shipments, review order forms, and complete your KYC profile from your phone. Push alerts keep you posted as consignments move.
```
(158 characters.)

## Description (4,000 char max)

```
Limu Mobile puts your Limu Trade account in your pocket. Follow every consignment from booking to
delivery, review the order forms waiting on you, and keep your client profile current — without
opening the portal.

TRACK CARGO AND SHIPMENTS
See your cargo list at a glance, open any consignment for package-level detail, and follow its
timeline through each recorded checkpoint. Shipments show current status and location, with the
updates logged against them.

REVIEW ORDER FORMS
Work through the order forms assigned to you, filtered by stage — draft, client review, pending
payment, pending purchase, purchased or dormant. Review items individually, check the supplier
photos, and complete your review when you are satisfied.

STAY NOTIFIED
Push notifications tell you when something changes, and tapping one takes you straight to the
cargo, shipment or order form it refers to. The in-app notification centre keeps the full history,
with unread counts and mark-all-read.

COMPLETE YOUR KYC
Fill in your KYC profile directly in the app — personal details, district, business type and
business category, with a searchable category list. Save a draft and come back to it, or submit in
one sitting.

MANAGE YOUR ACCOUNT
Register as an individual or a business client, verify your email with a 6-digit code, and stay
signed in securely. Update your profile details or change your password whenever you need to.
Forgotten passwords are reset with an emailed code — no links to chase.

BUILT FOR MALAWI
Phone numbers default to +265 and format as you type, with the full Malawi district list built in,
and country codes available when you need them.

Limu Mobile requires an active Limu Trade client account. Cargo, shipment and order-form data
becomes available once your KYC profile is complete.
```

## Keywords (100 char max, comma-separated, no spaces after commas)

```
cargo,shipment,freight,logistics,tracking,consignment,order form,kyc,malawi,import,export,trade
```
(95 characters. Do not repeat the app name or subtitle words — Apple already indexes those.)

## URLs

| Field | Value |
| --- | --- |
| Support URL (required) | **«TBC»** — needs a live page, e.g. `https://limu.co.mw/support` |
| Marketing URL (optional) | **«TBC»** — e.g. `https://limu.co.mw` |
| Privacy Policy URL (required) | `https://limu.co.mw/policy` — confirm it is live and covers the data types in `APP-PRIVACY.md` |

Apple rejects submissions where the support or privacy URL 404s, redirects to a login wall, or
points at a placeholder page. Confirm all three load in a private browser window.

## Copyright

```
2026 Limu Trade
```

## App Review Information

| Field | Value |
| --- | --- |
| First name / Last name | Andy Kaunda |
| Phone number | **«TBC»** |
| Email address | **«TBC»** — a monitored address; Apple replies here |
| Sign-in required | **Yes** |
| Demo account username | **«TBC»** — a real live-backend account |
| Demo account password | **«TBC»** |

### Demo account requirements

This is the single most common rejection cause for an app like this. The demo account Apple
receives must:

1. Be on the **live** backend (`portal.limu.co.mw`) and work from outside Malawi.
2. Have **KYC already completed**, otherwise the reviewer hits the gate and sees five empty tabs.
3. Have **real cargo, shipment and order-form records** attached, so every tab has content.
4. Not expire, lock out, or require an OTP the reviewer cannot receive. If email verification is
   already done on the account, sign-in is a plain password login — verify this end to end before
   submitting.

### Notes for the reviewer (paste into "Notes")

```
Limu Mobile is a client-facing companion app for Limu Trade, a Malawian freight and customs
clearing company. It requires an existing Limu Trade client account; the demo account above is a
real account on our production backend with sample cargo, shipment and order-form records.

Sign in with the demo email address and password on the first screen. The account's KYC profile is
already complete, so all five tabs (Home, Cargo, Shipments, Order Forms, Profile) are unlocked
immediately. New accounts are gated until KYC is submitted, which is why the demo account is
pre-completed.

Push notifications are used to alert clients when a consignment changes status. The app registers
for remote notifications after sign-in; declining the prompt does not block any functionality.

The app does not use tracking, contains no advertising, and does not process payments in-app. All
freight services are contracted offline with Limu Trade; nothing is sold through the app.
```

## Version information

| Field | Value |
| --- | --- |
| Version | `1.0` |
| Build | set by CI (see `.github/workflows/ios-release.yml`) |
| What's New | See the "What's New" block in `RELEASE-NOTES.md`. First releases usually leave this blank. |
| Release option | **Manually release this version** — do not auto-release on approval, so UAT sign-off (L7) can gate the public release. |

## Content rights and compliance answers

| Question | Answer |
| --- | --- |
| Does your app contain, show or access third-party content? | No |
| Does your app use encryption? | Yes — HTTPS only, which is exempt. `ITSAppUsesNonExemptEncryption = false` is already set in `LimuMobileInfo.plist`, so App Store Connect will not ask again. |
| Does your app use IDFA? | No |
| Does your app use tracking (ATT)? | No — no `NSUserTrackingUsageDescription`, no `AppTrackingTransparency` import |
| Third-party SDKs | None. No package dependencies, no analytics, no crash reporter. |
