# Limu iOS API integration

## Environments

- Default app target: `https://portal.limu.co.mw/Api/v4/client/`
- Local override: launch with `--local-api` to use `http://localhost/limu/Api/v4/client/`
- Custom override: set `LIMU_API_BASE_URL` to a full V4 client base URL

The app still permits insecure HTTP only for `localhost`, so the XAMPP override remains available for development. Access and refresh tokens are stored in Keychain when **Stay logged in** is enabled; expired access tokens are refreshed and rotated automatically.

## Connected flows

- Authentication: register, login, refresh, logout, forgot/reset password, account claim
- Dashboard and client profile
- Profile update and password change
- KYC detail load, draft save, completion (which now also writes the answers to the client record), shared option lists (`kyc/options.php`), and change requests for locked details (`kyc/change-requests.php`)
- Cargo list/detail, package data, and cargo timeline
- Shipment list/detail and updates
- Invoice list/detail, document link, payment history, and payment-proof upload
- Notification list, mark read, and mark all read

The V4 device-token endpoint was HTTP-tested successfully. App-side APNs registration still needs an Apple Push Notification entitlement/profile before a real iOS device token can be supplied to it.

## Backend additions still needed

### Live server status

These V4 routes are now available on the live server and are wired into the app:

1. `POST /auth/verify-email.php`
2. `POST /auth/resend-verification.php`
3. `GET /categories/get.php`

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
