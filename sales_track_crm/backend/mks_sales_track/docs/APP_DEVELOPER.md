# Sales Track - App Developer Guide

Everything needed to build the Android and iOS apps against the Sales Track
module. The wire contract is in API.md; this guide is about how the app should
work. Both stay current with every module release.

## What the app is

A background companion for company phones. It pairs once with a 6-digit code,
then quietly sends the phone's calls, call recordings, WhatsApp calls and SMS to
the CRM. It has no notifications feature of its own. Its screens are:

| Screen | Content |
| --- | --- |
| Pairing | Server address and 6-digit code, or scan the QR code shown in the CRM. Shows the device name and owner before confirming |
| Setup wizard | Each permission with what it is for, a tick when granted, and a link to the right system screen |
| Home | Connection status, last sync, next sync, waiting to sync, recordings waiting, today's calls, connected calls and talk time, the device name and owner, app version, and a Sync Now button |
| App Lock | A PIN prompt before pausing, unpairing or opening settings, when App Lock is on |
| After-call popup | Outcome chips from `config.outcomes.list`, a note, a follow-up date and time, a lead status picker, and Create Lead for unknown numbers; sent to `outcome` |
| Caller popup | Phase 9: who is calling, from lists built in the CRM |

## Pairing (device-first)

1. An administrator adds the device in the CRM (name, description, staff member,
   SIM number). The CRM shows a 6-digit code and a QR code.
2. The app takes the server address and code (or scans the QR payload, which
   carries both), calls `ping` to confirm the address, then `pair`.
3. The reply carries the token (store it in Android Keystore backed storage or
   the iOS Keychain), the device record and the first configuration.
4. If the same device record later gets a new code and another phone pairs,
   this phone's token stops working (`invalid_token`): show "This phone has
   been replaced" and return to the pairing screen.

Generate one device uid per install (a UUID is ideal) and keep it.

## Staying alive (Android)

- A foreground service with the smallest possible status notification. On
  Android 13 and later the user can hide it.
- Start on boot (`RECEIVE_BOOT_COMPLETED`) and after app updates.
- Ask to be exempted from battery optimisation and report the result as
  `battery_unrestricted`. On Xiaomi, Oppo, Vivo, Realme and some Samsung builds
  also guide the user to the maker's autostart or "no restrictions" setting:
  these makers kill background apps aggressively.
- React to `PHONE_STATE` changes so a call is read and synced the moment it
  ends; WorkManager handles the periodic sync every `sync_minutes`.

## Collecting

| Data | Android source | Notes |
| --- | --- | --- |
| Calls | `CallLog.Calls` after each call ends, plus a sweep on every sync | uid `call-<_ID>-<DATE>`. Types 1 incoming, 2 outgoing, 3 missed, 4 voicemail, 5 rejected, 6 blocked, 7 answered elsewhere (send as incoming) |
| SIM | `PHONE_ACCOUNT_ID` mapped through `SubscriptionManager` | Send `sim` as slot 1 or 2; honour `config.track_sim` |
| Recordings | The file the phone's own dialer saved, found by time | Samsung saves under `Recordings/Call`; other makers vary. Google's Phone app keeps recordings private: offer share-to-app there. Re-encode to AAC mono around 24 kbps before upload |
| WhatsApp calls | `NotificationListenerService` on `com.whatsapp` and `com.whatsapp.w4b` call notifications | Incoming, ringing and ongoing call notifications give direction and name (number when unsaved); time the call from the ongoing notification appearing to its removal; missed-call notifications give missed calls. Wording varies by version and language: match defensively. Read nothing else |
| SMS | `Telephony.Sms` | Type 1 incoming, 2 outgoing; skip drafts, outbox and failed. RCS chats are not in this provider. Honour `config.sms_text` |

iOS can send only calls placed from the app (`tel:` links, timed with
`CXCallObserver`, `source: app`) and manual entries (`source: manual`).

## Rules from the configuration

Read them from `config` on every heartbeat; refetch when a sync reply's
`config_version` changes.

| Field | What the app does |
| --- | --- |
| `tracking.*` | Collect only what is on |
| `paused` | Collect nothing; keep the heartbeat going |
| `excluded` | Never send a number whose last `match_digits` digits hash (`sha256(salt + digits)`) into `hashes` |
| `track_sim` | 0 means every SIM; otherwise only that slot |
| `sms_text` | `none`: never send message text |
| `history_days` | First pairing only: send this many days of call log and SMS once |
| `recordings.wifi_only`, `max_mb`, `formats` | Upload rules |
| `app.min_version` and `update_required` | Show a blocking update screen with `app.url_android` or `app.url_ios`. Sync and uploads answer 426 until updated |
| `app_lock` | When `enabled`, ask for the PIN before pause, unpair and settings. Check it locally: PBKDF2-HMAC-SHA256, the given `iterations`, the hex `salt` used as text, 32-byte output compared as lowercase hex with `hash` |

## Sync

- Queue everything in a local database keyed by uid; never lose an event
  because the network was down.
- Send batches of up to `batch_size`; remove every uid listed in `stored`,
  `duplicate`, `skipped` or `rejected`. Retry only failed requests, with
  exponential backoff.
- Upload recordings after their call is acknowledged.
- Keep cookies between requests (the CRM opens a session per request).

## Heartbeat and commands

Call `config` on start, every `sync_minutes`, and after a sync reply with a new
`config_version`. Send health every time (permissions, battery, charging,
queue, recordings_queue, network, last_error). The reply's `commands` list
holds work queued in the CRM:

| Command | Do |
| --- | --- |
| `sync_now` | Sync immediately |
| `recheck_permissions` | Re-read every permission, report health, and bring up the setup wizard if anything is missing |

Acknowledge each one on the next `config` call: `{"acks": [{"id": "...", "status": "done"}]}`
(`failed` with a `message` if it could not be done). Phase 5 adds instant
delivery through Firebase Cloud Messaging and the `dial` command.

## Errors

| Answer | App behaviour |
| --- | --- |
| 401 `invalid_token` | The device was re-paired elsewhere or deleted: clear the token, show the pairing screen |
| 401 `device_revoked` | Revoked in the CRM: clear the token, tell the user |
| 403 `staff_inactive` | Stop and tell the user |
| 426 `update_required` | Blocking update screen |
| 503 | Pause and retry on the next interval |

Treat a single 401 as possibly transient; act after three in a row.

## Store submission

- **Google Play**: call log and SMS access are restricted permissions. Submit
  the Permissions Declaration as an enterprise CRM / call logging tool for the
  company's own phones, with a privacy policy and a demo video. Notification
  access (for WhatsApp calls) and the overlay permission (for the caller popup
  later) need clear in-app explanations. If the SMS declaration is refused,
  ship without SMS first or publish as a private app through Managed Google
  Play for the company's Workspace.
- **App Store**: the iOS app only places and logs calls; no special
  entitlements beyond `CXCallObserver` and, later, a Call Directory extension
  for caller labels.

## Testing without a phone

```
php tooling/phone.php ping   --url=https://crm.example.com/
php tooling/phone.php pair   --url=https://crm.example.com/ --code=123456
php tooling/phone.php config --url=https://crm.example.com/ [--ack=<command id>]
php tooling/phone.php sync   --url=https://crm.example.com/ --count=20
php tooling/phone.php record --url=https://crm.example.com/ --uid=<call uid> --file=call.m4a
```

Devices > Load Demo Data fills every screen with realistic activity.

## App roadmap

| Stage | Starts after | Scope |
| --- | --- | --- |
| A. Android core | Module phase 3 | Pairing, setup wizard, home screen, background service, calls, recordings, WhatsApp calls, SMS, sync, heartbeat, commands, App Lock, update screen |
| B. After-call popup | Ready now (module 1.3.0) | Outcome, note, follow-up, lead status, Create Lead, tamper reports |
| C. Click-to-call | Ready now (module 1.4.0) | Firebase messaging, token registration, `dial` command, immediate dialling |
| D. Caller popup | Module phase 9 | Lists synced from the CRM, offline cache, overlay |
| E. iOS companion | After C | Pairing, tap-to-call, call timing, manual logging, caller labels |
| F. Release | Each stage | OEM survival testing (Xiaomi, Samsung, Vivo, Oppo, Realme), store submissions |

Technology: native Kotlin for Android (background services, permissions and
OEM quirks are easiest there), Swift for iOS.

## The after-call popup (stage B)

1. When a call ends, decide whether to ask: `config.outcomes.ask` is
   `connected` (connected calls, and outgoing calls nobody answered),
   `connected_only` or `all`. "Connected" means at least the CRM's connected
   seconds; use the call's duration from the call log.
2. Sync the call first (straight after the call is the norm), then show the
   popup as an overlay ("Display over other apps").
3. Show the outcomes as chips in their tones, in list order. Converted is
   always there (`fixed`).
4. When the chosen outcome has `follow_up`, suggest tomorrow at 10:00 in the
   date and time picker.
5. Offer the lead status picker (`config.outcomes.lead_statuses`) and, for a
   number the CRM does not know (the sync reply's match is empty), Create Lead
   with an optional name, when `create_lead` is true.
6. Skippable unless `mandatory`; skipped calls stay in an "Outcomes to add"
   list on the home screen.
7. Queue answers locally and send them to `outcome` in batches; retry
   `rejected` only when the reason is not permanent.

## Tamper detection

- Keep the highest call log `_ID` and SMS `_id` synced. On every sweep, ids
  below that which disappeared before being synced mean deletion: report
  `call_log_deleted` or `sms_deleted` with how many and the time span.
- Listen for `ACTION_TIME_CHANGED` and `ACTION_TIMEZONE_CHANGED`; report
  `clock_changed` when the change was manual.
- On first start with no local data but a pairing already on record (for
  example, a stored device uid in backup-excluded storage is gone), report
  `app_data_cleared` once paired again.
- Report the real state of every permission on every heartbeat; the CRM spots
  the one that went missing.

## Click-to-call (stage C)

1. Add Firebase Cloud Messaging with the company's Firebase project (the same
   project whose service account key is saved in the CRM).
2. Send the registration token in `push_token` on the next `config` call and
   whenever `onNewToken` fires.
3. In `onMessageReceived`, read the data payload. For `command` = `dial`:
   with "Display over other apps" granted, start `ACTION_CALL` for the number
   at once (needs `CALL_PHONE`); with `calling.dial_confirm`, show the number in
   an overlay with a Call button instead. Then acknowledge it on `config`.
4. Never dial a command older than two minutes (the heartbeat path already
   drops expired ones; a delayed push can still arrive late).
5. The call is tracked like any other call; the after-call popup follows.

iOS cannot place a call from the background; there a `dial` arrives as a
local notification the user taps.

## Caller popup and call lists (stage D)

- On every heartbeat, compare `config.popup.version` with the stored one and
  fetch `directory` (all pages) when it differs. Keep it encrypted on the
  device; match calls by the last `match_digits` digits.
- Incoming: on RINGING with `popup.incoming`, show an overlay with name,
  company, status, owner, last call and outcome, last note and the next
  follow-up. Outgoing: the same on NEW_OUTGOING_CALL with `popup.outgoing`.
  Unknown numbers may call `lookup` when online.
- iOS cannot draw over calls: use a Call Directory extension for names only.
- With `config.call_lists` above 0, show the lists on the home screen from
  `lists`; tapping a lead dials it; Skip posts `skip`. Never offer to dial a
  number whose hash is in `do_not_call`.
