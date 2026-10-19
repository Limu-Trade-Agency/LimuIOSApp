# Limu iOS API integration

## Environments

- Default app target: `https://portal.limu.co.mw/Api/v4/client/`
- Local override: launch with `--local-api` to use `http://localhost/limu/Api/v4/client/`
- Custom override: set `LIMU_API_BASE_URL` to a full V4 client base URL

The app still permits insecure HTTP only for `localhost`, so the XAMPP override remains available for development. Access and refresh tokens are stored in Keychain when **Stay logged in** is enabled; expired access tokens are refreshed and rotated automatically.

## Connected flows

- Authentication: register, login, refresh, logout, forgot/reset password, account claim
- Registration verification: WhatsApp phone OTP first (`POST /auth/verify-phone.php`), with email OTP as a fallback channel (`POST /auth/verify-email.php`, `POST /auth/resend-verification.php` with `channel`)
- Dashboard and client profile
- Profile update and password change
- KYC detail load, draft save, completion (including writing the answers to the client record), shared option lists (`kyc/options.php`), database-backed category search, and change requests for locked details (`kyc/change-requests.php`)
- KYC email verification gate: `POST /kyc/request-email-verification.php` and `POST /kyc/verify-email.php`; `kyc/submit.php` returns `EMAIL_VERIFICATION_REQUIRED` until the email is verified
- Cargo list/detail, package data, and cargo timeline
- Shipment list/detail and updates
- Live shipment pricelist from the portal shipping/customs pricing tables
- Order form list/detail, including `GET /orderforms/index.php?clientId=...`, `GET /orderforms/show.php?id=...`, item decisions, and review completion
- Notification list, mark read, and mark all read

The invoice module (invoice list/detail and payment-proof upload) was removed from this app version; invoice notifications still route to the Order Forms tab.

The V4 device-token endpoint was HTTP-tested successfully. App-side APNs registration still needs an Apple Push Notification entitlement/profile before a real iOS device token can be supplied to it.

## Backend additions still needed

### Live server status

These V4 routes are available in the backend code and are wired into the app:

1. `POST /auth/verify-email.php`
2. `POST /auth/resend-verification.php`
3. `GET /categories/get.php`
4. `GET /pricing/shipment.php` with `GET /shipment-pricelist.php` as a flat compatibility alias for production deployments

`DELETE /profile/delete.php` (account deletion, required by App Store Review Guideline 5.1.1(v)) is
implemented in the portal repository but **not yet deployed**. Contract and rollout notes in
`ACCOUNT-DELETION.md`.

### Response improvements

1. **Shipment route fields**
   - Add `origin` and `destination` to shipment list/detail responses. The current API exposes only `currentLocation`, so route labels cannot be populated accurately.

2. **Per-package stage progress**
   - Add package stage/checkpoint data (container loading, offloading, loading check, warehouse check), either inside `cargo/packages.php` or in `cargo/packages/timeline.php?id=...`.
   - The current package response exposes only one `checked` state and `checkedAt` timestamp.

## Local backend correction

V4 public URLs are now mount-aware. Under XAMPP, uploaded proof URLs resolve beneath `http://localhost/limu/uploads/...` rather than the incorrect `/portal/uploads/...` path. The OpenAPI localhost server entry was updated to `/limu/Api/v4/client`.
