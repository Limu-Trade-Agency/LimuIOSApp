# Account deletion (iOS)

## Why

App Store Review Guideline 5.1.1(v): an app that lets people create an account must let them
**start deleting that account from inside the app**. A link to "email support" does not satisfy it,
and neither does a web page that only files a request. Apps without it are rejected.

Limu Mobile creates accounts through `auth/register.php`, so the rule applies.

## What ships in the app

`Profile → Delete Account` opens `DeleteAccountView` (`Limu Mobile/ProfileView.swift`).

The screen states plainly what is removed, then requires two things before the destructive button
becomes active:

1. The account **password**.
2. The word **DELETE** typed out.

Deletion is irreversible server side, so a single tap on a phone left unlocked should not be enough
to trigger it. The password is re-checked by the API rather than trusted from the client.

`AppState.deleteAccount(password:)` (`Limu Mobile/AppState.swift`):

1. Revokes this device's push token first, while the session can still authenticate the call.
2. `DELETE profile/delete.php` with `{ "password": ..., "confirm": "DELETE" }`.
3. On success, clears the stored push token and the local session state, which drops the app back
   to the authentication screen.
4. On failure, re-registers the push token — the account still exists, so the device should not go
   silently unreachable — and surfaces the API error through the app's global error alert.

`logout()` is now guarded on `isAuthenticated`, so the view can call the shared logout closure after
deletion without firing a pointless `auth/logout.php` against a session that is already gone.

## Backend — implemented

Built in the legacy portal repository (`gochi20/limu`, branch `Andy`), not yet deployed to
`portal.limu.co.mw` and not yet exercised against a database.

| File | Change |
| --- | --- |
| `Api/v4/client/profile/delete.php` | New endpoint. Accepts `DELETE`, and `POST` as a fallback for hosts that strip bodies from `DELETE`. |
| `Api/v4/client/ClientAuthService.php` | `deleteAccount()` plus `purgeClientAuthData()`, `purgeClientAppData()`, `anonymiseClientRecord()`, `recordAccountDeletion()` and `sendAccountDeletedEmail()`. |
| `Api/v4/client/ClientAuthService.php` (`ensureSchema`) | New `api_v4_client_deletions` audit table, created on next request like every other V4 table. |

### What it does

1. Rejects the request unless `confirm` is `DELETE` and a password is supplied.
2. Rate-limits to five attempts per client every fifteen minutes, reusing `api_v4_rate_limits`.
3. Re-verifies the password against `api_v4_client_credentials`.
4. Emails a deletion confirmation **before** anonymising, because afterwards there is no address
   left to send it to. A failed send does not block the deletion.
5. In one transaction:
   - deletes the credential, every session, and every outstanding one-time token;
   - deletes device tokens, notifications, notification reads, cargo handoffs, and both KYC tables
     (each guarded by `apiV4TableExists`, since those belong to `ClientDataService`);
   - anonymises the `Clients` row;
   - writes an audit row to `api_v4_client_deletions`.

### Why the Clients row survives

Cargo, shipments and invoices are keyed to `Clients.userid`. Those are commercial records Limu
Trade is legally required to keep for customs, tax and accounting purposes, and deleting the row
would orphan them.

So the row stays and the personal data goes: `firstname`/`lastname` become `Deleted`/`Client`,
`email`, `phonenumber`, `gender`, `dob`, `uid`, `occupations`, `interests`, `alternate_phones` and
`id_number` are nulled, `business`, `businesscategory`, `Location` and `photourl` are emptied, and
`flag` is set to `deleted`. Each column is checked with `apiV4ColumnExists` first — the legacy table
has grown columns over time and not every deployment has all of them.

`shipmentcount`, `lastshipment`, `category`, `createdon` and `createdby` are kept: they are
commercial history, not personal data, and reports depend on them.

With `email` and `phonenumber` nulled, `findClientByEmailOrPhone` can no longer match the record, so
the deleted identity cannot be used to sign in or to start a password reset. The credential row is
gone as well, so there is nothing to authenticate against either way.

The audit table stores SHA-256 hashes of the email and phone rather than the values, so support can
answer "did this person delete their account?" without retaining the data the deletion removed.

### Request

```
DELETE /Api/v4/client/profile/delete.php
Authorization: Bearer <access token>
Content-Type: application/json

{
  "password": "<the account password>",
  "confirm": "DELETE"
}
```

### Response

Success — the standard envelope, with no payload needed:

```json
{ "status": 200, "message": "Account deleted", "data": {} }
```

Failure cases the app already renders through `APIError`:

| Condition | Suggested `code` | Notes |
| --- | --- | --- |
| Wrong password | `INVALID_CREDENTIALS` | Already mapped to a friendly message in `APIClient.swift` |
| Missing or wrong `confirm` | `VALIDATION_ERROR` | Defence in depth; the client enforces it too |
| Open consignment or unpaid balance blocks deletion | `DELETION_BLOCKED` | Return a `message` explaining what to settle first — the app shows it verbatim |
| Too many attempts | `RATE_LIMITED` | Already mapped |

### Still to do

1. **Deploy.** The change is in the repository only. `C:\xampp\htdocs\portal` is a separate working
   copy for local testing, and `portal.limu.co.mw` is the live target.
2. **Test against a database.** Nothing here has been run yet — see the checklist below.
3. **Update the privacy policy.** Apple does not require that every record be destroyed, only that
   the **account** is deleted and that the retention is explained. `https://limu.co.mw/policy` has to
   say which records are kept, why, and for how long, or this comes back as a rejection at the
   privacy-policy step instead of the deletion step.

## Testing

None of this has been run yet. Add to the functional checklist:

- Wrong password is rejected and the account survives.
- `api_v4_client_deletions` is created automatically on the first request after deployment.
- The `Clients` row survives with personal fields cleared, and any cargo, shipment or invoice
  attached to that `userid` still resolves.
- The deletion confirmation email arrives.
- A deleted identity cannot register-collide or start a password reset.
- `DELETE` confirmation is required; lowercase `delete` is accepted (the client uppercases it).
- After deletion the app returns to the authentication screen, and the same credentials no longer
  sign in.
- Push notifications stop arriving on the device.
- Deleting on one device invalidates the session on any other device signed into the same account.
