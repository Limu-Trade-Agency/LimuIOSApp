# Push notifications and notification preferences

## How it works now

- The apps register a device token with `devices/push-token.php` (`platform` = `ios` or `android`).
- Every notification the portal creates for a client (`mobile_app_notify_client`) is stored for the in-app
  list, then delivered outside the app according to the client's **preferences**
  (`notifications/preferences.php`, table `api_v4_client_notification_prefs`):
  - Types: shipments, orders, invoices, general (category -> type map in `lib/mobile_app_notification_prefs.php`).
  - Channels: push (default on), WhatsApp and email (default off, opt-in).
- Push goes to each device token: a raw iOS APNs token goes to Apple directly (`apns_*` config); any other
  token (Android, or iOS registered through the Firebase SDK) goes through **Firebase Cloud Messaging**
  (HTTP v1, `lib/mobile_app_fcm.php`, `fcm_*` config). No SDK or Composer package is required.
- Apps: Profile -> Notification Settings reads and saves the preferences.

## What is still needed from the LIMU Firebase project (Chigomezgo)

1. **Sending from the portal.** Preferred (the organization blocks service account keys): deploy the relay Cloud Function in the portal repo, `firebase/functions` (see `firebase/README.md`), and set `fcm_relay_url` / `fcm_relay_secret`. Alternative if keys are allowed: a **service account key** (JSON) for the server: Firebase console -> Project settings -> Service accounts ->
   Generate new private key. Put it on the server and set `fcm_enabled` and `fcm_service_account_path` in
   `config/mobile_app_push.php` (see `config/mobile_app_push.example.php`).
2. **Android:** register the app `com.limu.android` in the project and download `google-services.json` into
   `limuAndroid/app/`, then apply the `com.google.gms.google-services` Gradle plugin.
3. **iOS:** register `Limu-Trade.Limu-Mobile`, download `GoogleService-Info.plist`, add the Firebase iOS SDK
   (Messaging) in Xcode, upload the APNs auth key (.p8) to Firebase (Project settings -> Cloud Messaging), and
   register the FCM token with the API instead of the raw APNs token. Until then iOS keeps using direct APNs,
   which needs the `apns_*` settings and the push entitlement on the live server.
4. WhatsApp updates use the same WaAPI instance as the OTP messages, which is currently disconnected (see the
   WhatsApp/OTP notes) — re-pair it before turning WhatsApp updates on for clients.
