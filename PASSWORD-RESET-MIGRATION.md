# Password Reset: Link → OTP Migration (iOS)

## Why

Forgot-password used to email a one-hour `limu://reset-password?token=...&purpose=password_reset`
link (with an `https://portal.limu.co.mw/...` universal-link fallback). Tapping the emailed
"Change password" button did not reliably reopen the app — deep links and universal links depend
on OS-level routing (URL scheme registration, App Link/Universal Link verification) that doesn't
always fire from a Gmail button tap, especially on Android. The client would tap the button and
nothing would happen.

The fix: password reset is now OTP-based. The API emails a 6-digit code instead of a link; the
client types the code back into the app. No deep link, no dependency on the OS routing the tap
anywhere — it works the same way the existing email/SMS verification codes already do elsewhere
in the app.

Account claim (`AuthMode.Claim` / claiming an existing client record before any app session
exists) still uses a one-time link, unchanged — that flow is reached from a portal email before
the user has anything to type a code into, so a link is still the right mechanism there.

## Backend contract change

`Api/v4/client/ClientAuthService.php` (shared backend, not part of this repo, documented here for
reference since it drives what this app sends):

- `POST /auth/forgot-password.php` — unchanged request shape (`{ identifier }`), but now issues
  and emails a 6-digit OTP (10-minute expiry) instead of a one-hour link token.
- `POST /auth/reset-password.php` — request body changed from `{ token, password }` to
  `{ identifier, code, password }`. The code is verified against the same OTP store used for
  email/phone verification codes.

## Files changed

- **`Limu Mobile/AppState.swift`**
  - `completePasswordReset(token:password:)` → `completePasswordReset(identifier:code:password:)`,
    posting `identifier`/`code`/`password` to `auth/reset-password.php`.
  - Removed `beginPasswordResetFromLink()` (no longer reachable — nothing consumes a link token
    anymore).

- **`Limu Mobile/AuthenticationView.swift`**
  - Removed the `resetLinkToken` binding, `init(resetLinkToken:onLogin:)` parameter,
    `resetTokenFromLink`/`resetSent` state, and `consumeResetLinkToken(_:)`.
  - Added `resetIdentifier`, `resetCode`, `resetResent` state.
  - `forgotForm`: still collects an email address, but on success it stores the identifier and
    transitions straight into `.reset` mode (mirrors how registration transitions into
    `.verifyEmail` after a successful sign-up) instead of showing an inline "link sent" card.
  - `resetForm`: rebuilt around the same "6-digit code + Resend code" pattern already used by
    `verificationForm` for email verification, instead of a "paste your token" field. Submits
    `identifier` + `code` + the new password.
  - Header copy updated ("We'll send a verification code to your email" / "Enter the code we
    emailed you").

- **`Limu Mobile/ContentView.swift`**
  - Removed `passwordResetToken` state, `.onOpenURL` / `.onContinueUserActivity` (universal link)
    handlers, `handleDeepLink(_:)`, and the static `passwordResetToken(from:)` URL parser.
  - `AuthenticationView` is now constructed with no reset-link argument.

- **`LimuMobileInfo.plist`**
  - Removed the `CFBundleURLTypes` entry that registered the `limu` custom URL scheme — nothing
    in the app consumes it anymore.

## New user flow

1. Sign-in screen → "Forgot password?" → enter email → **Send Verification Code**.
2. App moves straight to the reset screen: "We sent a verification code to `<email>`."
3. Client enters the 6-digit code (with "Resend code" available), plus a new password twice.
4. **Change Password** verifies the code server-side and updates the password; success returns
   to sign-in.

## What's intentionally unchanged

- Account claim (`claimForm`) still pastes a token from an email link — separate purpose, out of
  scope for this change.
- The reset email is still sent to the client's email address only (no SMS fallback for
  phone-only accounts) — that was already the case before this change.
