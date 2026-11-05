# Sales Track API (v1)

The contract the Android and iOS apps are built against, as of module 1.8.2.
Everything here is exercised by `tooling/e2e.php` and can be tried by hand with
`tooling/phone.php`. How the app should behave around it is in
APP_DEVELOPER.md.

Changes in 1.8.5:
- `events` endpoint (`GET/POST /mks_sales_track/api/v1/events`): allows clients and third-party systems to fetch synced events with filtering (`kind`, `since`, `limit`, `page`) and pagination, or POST batches for ingestion.
- Comprehensive Save & Update: when events arrive, `mks_st_ingest()` updates existing records with complete data including duration, direction, contact name, text body, number, media, and SIM slot.
- Full real-time synchronization for SMS (incoming/outgoing), WhatsApp messages, and calls.

Changes in 1.8.2:
- Supports `whatsapp_message` and `notification` event kinds with full body/text, sender, and package tracking.
- Full historical sync: timestamps from year 2000 (`946684800000` ms) are accepted, enabling complete historical device sync.
- Advanced natural deduplication: matching across `number_key` (last 10 digits), `number_raw`, or `number` string prevents duplicate rows for shortcode and bank SMS.
- Canonical UID migration: replaces ephemeral broadcast UIDs with canonical content-provider UIDs seamlessly.
- Device-server clock alignment with `server_time` in milliseconds on all ping, config, pair, and sync replies.

Changes in 1.4.0: config accepts `push_token` (the phone's Firebase
registration token) and carries `calling`; commands can carry `params`, and the
new `dial` command places a call; commands also arrive instantly as Firebase
data messages when the CRM has a Firebase key.

Changes in 1.3.0: config carries `outcomes` (the after-call list, rules and
Perfex lead statuses); a new `outcome` endpoint takes the popup's answers;
config accepts `tamper` reports, and a permission that goes from granted to
missing raises an alert in the CRM.

Changes in 1.1.0: pairing binds to a device created in the CRM; config carries
`paused`, `app`, `app_lock`, `commands` and `update_required`; config accepts
`acks`; sync and recording answer 426 for an app older than the minimum
version; the `notification` kind is no longer accepted.

## Basics

| | |
| --- | --- |
| Base address | `https://<crm>/mks_sales_track/api/v1/` |
| Format | JSON in, JSON out. The recording upload alone is `multipart/form-data` |
| Time | Every timestamp is **epoch milliseconds** (UTC instant). The server converts to the CRM's timezone |
| Replies | Always JSON, errors included. Every reply has `success` and `server_time` (epoch ms) |
| Errors | `{"success": false, "error": "<code>", "message": "<sentence>"}` with a matching HTTP status |

Endpoints: `ping`, `pair`, `config`, `sync`, `recording`. Anything else answers
`404 not_found`.

## Authentication

Pairing gives the phone a **device token**: 64 lowercase hex characters. Store it
in secure storage (Android Keystore backed storage, iOS Keychain). The server
keeps only its hash, so a lost token cannot be recovered, only replaced by
pairing again.

Send it on every call except `ping` and `pair`, in this order of preference:

1. Header `X-Sales-Track-Token: <token>`
2. Header `Authorization: Bearer <token>`
3. A `token` field in the JSON body or the multipart form

Shared hosting can strip the `Authorization` header before PHP sees it, which is
why the custom header comes first. Optionally also send
`X-Sales-Track-Device: <device uid>`; when present it must match the paired
device or the call is refused with `device_mismatch`.

**Keep cookies.** Perfex opens a session for every request. A client that drops
its cookies makes the CRM write a new session row on every call. Use a
persistent cookie jar (OkHttp `CookieJar`, `URLSession` default storage).

## Pairing

An administrator opens **Sales Track > Devices > Add Device**, enters the
device name, description and the staff member it belongs to, and gets a 6-digit
code and a QR code, valid once, for the time set in Settings (60 minutes by
default). The device page shows the live code again until it is used, and
**Regenerate Code** issues a new one: when another phone pairs with it, the
phone that held the device before is cut off (its token answers
`invalid_token`). That is how a handset is replaced without losing history.

### QR code payload

```json
{"app": "mks_sales_track", "v": 2, "url": "https://crm.example.com/",
 "api": "https://crm.example.com/mks_sales_track/api/v1/",
 "code": "9f2c4e0d1a7b4c3e8f6a5b2d1c0e9f8a",
 "device": "Sales Phone 03", "staff": "Kiranjeet Kaur"}
```

`code` here is a 32 character secret, used exactly like the six digit code.
Show `device` and `staff` before pairing ("This phone becomes Sales Phone 03,
reporting as Kiranjeet Kaur").

### Manual pairing

The user types the server address and the six digit code. Call `ping` first to
confirm the address is a Sales Track CRM, then `pair`.

### Device uid

Generate once per install and keep it: 8 to 64 characters of `A-Z a-z 0-9 _ -`.
A UUID without braces is ideal. It must not start with `demo-`, which is
reserved. A phone that pairs with a different device's code leaves its old
device record, which is revoked.

## Endpoints

### GET or POST `ping`

No authentication.

```json
{"success": true, "name": "Sales Track", "api": "v1", "module_version": "1.0.0",
 "pairing": true, "server_time": 1791897120378}
```

`pairing: false` means app connections are switched off in the CRM settings.

### POST `pair`

```json
{
  "code": "644653",
  "device": {
    "uid": "3f9b2c1e-5d7a-4e8b-9c0d-1a2b3c4d5e6f",
    "platform": "android",
    "manufacturer": "Samsung",
    "model": "SM-S921B",
    "os_version": "14",
    "app_version": "1.0.0",
    "sims": [{"slot": 1, "label": "Jio", "number": ""}, {"slot": 2, "label": "Airtel"}]
  }
}
```

`platform` is `android` or `ios`. Spaces or a hyphen inside the code are
ignored.

Reply 200:

```json
{
  "success": true,
  "token": "a8a5ad5d...64 hex...",
  "device": {"id": 12, "name": "Sales Phone 03", "description": "Inside sales", "platform": "android", "status": "active", "track_sim": 0},
  "staff": {"id": 3, "name": "Kiranjeet Kaur"},
  "config": { "...": "see config below" },
  "update_required": false,
  "commands": [],
  "server_time": 1791897127508
}
```

| Status | error | Meaning |
| --- | --- | --- |
| 400 | invalid_request | `code` or `device` missing |
| 422 | invalid_device | uid or platform invalid |
| 401 | invalid_code | wrong or already used code, or the device was revoked |
| 410 | code_expired | ask for a new code |
| 429 | too_many_attempts | ten failures from one address, or forty overall, in 15 minutes. `retry_after` seconds, also sent as `Retry-After` |
| 403 | staff_inactive | the staff member was deactivated |

### GET or POST `config`

The heartbeat. Call it when the app starts, every `sync_minutes`, and whenever a
sync reply carries a different `config_version`. Everything in the body is
optional; health is shown to managers on the device page. `acks` acknowledges
commands received earlier (see Commands).

```json
{
  "acks": [{"id": "304d6659a127", "status": "done"}],
  "app_version": "1.0.1",
  "os_version": "14",
  "sims": [{"slot": 1, "label": "Jio"}],
  "health": {
    "permissions": {
      "call_log": true, "phone_state": true, "contacts": true, "sms": true,
      "notifications": false, "recordings": true, "battery_unrestricted": false
    },
    "battery": 82, "charging": false,
    "queue": 3, "recordings_queue": 1,
    "network": "wifi",
    "last_error": "Notification access is off",
    "recorder_folder": "Recordings/Call"
  }
}
```

`network` is `wifi`, `mobile`, `none` or `unknown`. `notifications` is the
notification access WhatsApp call detection needs. Unknown permission keys are
ignored; report the real state of each, every time.

Reply:

```json
{
  "success": true,
  "device": {"id": 12, "name": "Sales Phone 03", "description": "Inside sales", "platform": "android", "status": "active", "track_sim": 1},
  "staff": {"id": 3, "name": "Kiranjeet Kaur"},
  "config": {
    "tracking": {"calls": true, "recordings": true, "whatsapp_calls": true, "sms": true},
    "paused": false,
    "excluded": {"salt": "6f8f...", "hashes": ["2c1b..."]},
    "match_digits": 10,
    "country_code": "91",
    "track_sim": 1,
    "sms_text": "all",
    "sync_minutes": 15,
    "history_days": 7,
    "batch_size": 200,
    "recordings": {"wifi_only": false, "max_mb": 25, "formats": ["m4a", "mp4", "aac", "mp3", "ogg", "oga", "opus", "webm", "wav", "flac", "amr", "awb", "3gp", "3ga"]},
    "app": {"min_version": "1.0.0", "url_android": "https://play.google.com/...", "url_ios": ""},
    "app_lock": {"enabled": true, "algorithm": "pbkdf2-sha256", "iterations": 100000, "salt": "1f0c...", "hash": "9ab3..."},
    "outcomes": {
      "ask": "connected", "mandatory": false, "note_required": false, "create_lead": true,
      "list": [
        {"key": "interested", "label": "Interested", "tone": "green", "follow_up": true, "lead_status": 0, "fixed": false},
        {"key": "converted", "label": "Converted", "tone": "violet", "follow_up": false, "lead_status": 0, "fixed": true}
      ],
      "lead_statuses": [{"id": 1, "name": "Customer", "color": "#7cb342"}, {"id": 2, "name": "New", "color": "#28B8DA"}]
    },
    "version": "a413829a8ee8"
  },
  "update_required": false,
  "commands": [{"id": "304d6659a127", "type": "sync_now"}],
  "server_time": 1791897127508
}
```

What the app must do with it:

| Field | Rule on the phone |
| --- | --- |
| `tracking.*` | Collect only what is on. The server refuses the rest anyway (`skipped: tracking_off`) |
| `paused` | Collect nothing until it turns false; keep the heartbeat going (`skipped: device_paused`) |
| `app`, `update_required` | When `update_required` is true, show a blocking update screen linking to `url_android` or `url_ios`. Sync and uploads answer 426 until the app reports a version at or above `min_version` |
| `do_not_call` | `salt` and `hashes`: sha256(salt + number key) of numbers nobody should call. Warn before dialling one |
| `popup` | `directory`, `incoming`, `outgoing`: whether to show the caller popup; `version`: fetch `directory` again when it changes |
| `call_lists` | How many active call lists the phone's owner is on; fetch `lists` when it is not 0 |
| `calling` | `click_to_call`: Call buttons are on in the CRM; `dial_confirm`: show the number and wait for a tap instead of dialling at once; `push`: the CRM can send Firebase messages, so register a token |
| `outcomes` | The after-call popup: which calls to ask about (`ask`: `connected` = connected calls and unanswered outgoing ones, `connected_only`, `all`), whether it may be skipped, whether a note is required, whether Create Lead is offered for unknown numbers, the outcome list in order (show `label` in its `tone`; `follow_up` means suggest a follow-up date) and Perfex's lead statuses for the optional status picker |
| `app_lock` | When enabled, ask for the PIN before pause, unpair or settings. PBKDF2-HMAC-SHA256 of the PIN with the hex `salt` used as text, `iterations` rounds, 32 bytes, lowercase hex, equal to `hash` |
| `excluded` | Never send a call, SMS or WhatsApp call whose number is excluded (see below) |
| `track_sim` | 0 means all SIMs. Otherwise send calls and SMS from that slot only |
| `sms_text` | `none`: never send the message text. `all` or `crm`: send it (with `crm` the server drops it for numbers not in the CRM) |
| `history_days` | On first pairing only, send this many days of call log and SMS once |
| `recordings.wifi_only` | Hold recordings until on Wi-Fi |
| `recordings.max_mb` | Already capped by the server's real PHP upload limit. Do not send larger files |

**Excluded numbers** arrive as salted hashes, so personal numbers are never
handed to every phone. To test a number: take its digits only, keep the last
`match_digits` of them, compute `sha256(salt + digits)` as lowercase hex, and
look it up in `hashes`. Numbers shorter than `match_digits` are never excluded.

### POST `sync`

Up to `batch_size` (200) events per request.

```json
{"events": [ { "...": "event" }, { "...": "event" } ]}
```

Common fields:

| Field | Required | Notes |
| --- | --- | --- |
| `uid` | yes | Your stable id for this event, 1 to 80 printable ASCII characters, no spaces. The same event must always get the same uid |
| `kind` | yes | `call`, `whatsapp_call`, `sms`, `whatsapp_message`, `notification` |
| `time` | yes | Epoch ms. Seconds and ISO 8601 strings are accepted too. Timestamps from Jan 1, 2000 (946684800000 ms) to now + 24h are accepted |
| `direction` | calls, SMS, WhatsApp | See below |
| `number` | calls, SMS, WhatsApp | As the phone has it. Any format |
| `name` | no | The contact name saved on the phone or sender title |
| `sim` | no | Slot 1 to 4 |
| `source` | no | `auto` (default), `app` (a call the app placed, iOS), `manual` |

Directions:

| kind | Values |
| --- | --- |
| call | `incoming`, `outgoing`, `missed`, `rejected`, `blocked`, `voicemail`, `unknown` |
| whatsapp_call | `incoming`, `outgoing`, `missed`, `rejected`, `unknown` |
| sms | `incoming`, `outgoing`, `unknown` |
| whatsapp_message | `incoming`, `outgoing`, `unknown` |
| notification | `incoming`, `outgoing`, `unknown` |

Aliases are mapped: `in`, `inbound`, `received`, `inbox` > incoming; `out`,
`outbound`, `sent`, `dialed`, `dialled` > outgoing; `declined` > rejected.

Kind specific fields:

| kind | Fields |
| --- | --- |
| call | `duration` seconds of talk (0 when not connected), `recording: true` when a recording file will follow |
| whatsapp_call | `duration`, `media` (`voice` or `video`), `app` (`com.whatsapp` or `com.whatsapp.w4b`). `number` when known, otherwise `name` |
| sms | `text`, `sim` slot |
| whatsapp_message | `text`, `app` (`com.whatsapp`, `com.whatsapp.w4b`), sender `name` / `number` |
| notification | `text`, `title`, `app` (package name, e.g. `com.whatsapp`, `com.google.android.apps.messaging`) |

Text is kept up to 5,000 characters, names 191.

Reply:

```json
{
  "success": true,
  "stored": ["call-8812-1791897127494"],
  "duplicate": ["call-8811-1791897067494"],
  "skipped": [{"uid": "sms-99", "reason": "tracking_off"}],
  "rejected": [{"uid": "x-1", "reason": "invalid_time"}],
  "recordings_wanted": ["call-8812-1791897127494"],
  "config_version": "a413829a8ee8",
  "server_time": 1791897127508
}
```

**Every uid in `stored`, `duplicate`, `skipped` and `rejected` is finished:
remove it from the queue.** Only retry when the request itself failed (network
error, 5xx, 429). Sending the same batch twice is always safe; the second time
everything comes back as `duplicate`. A reinstalled app that re-imports its call
log is also safe: the same call (same person, second, number and direction) is
recognised whatever its new uid.

`skipped` reasons: `tracking_off`, `device_paused`, `excluded_number`,
`sim_not_tracked`. `rejected` reasons: `invalid_event`, `invalid_uid`,
`invalid_kind`, `invalid_time`.

## Commands

Work queued in the CRM (device page > Commands) rides back on the next
`config` reply as `commands: [{id, type}]`. Do it, then acknowledge it on the
following `config` call with `acks: [{id, status: "done" | "failed", message}]`.
An unacknowledged command is sent again.

| type | Do |
| --- | --- |
| `sync_now` | Sync immediately |
| `recheck_permissions` | Re-read every permission, report health, show the setup wizard if anything is missing |
| `dial` | `params: {number, name}`. Place the call (or, with `dial_confirm`, show it and wait for a tap). Expires two minutes after it was queued: never dial a stale one |

Revoking a device needs no command: the next call answers `device_revoked`.

`recordings_wanted` lists the calls whose recording the server is waiting for.

### POST `recording`

`multipart/form-data` with:

| Field | |
| --- | --- |
| `uid` | The call's uid, already synced |
| `file` | The audio file. Its file name must carry the real extension |
| `token` | Optional here when the header is sent |

Accepted: m4a, mp4, aac, mp3, ogg, oga, opus, webm, wav, flac (play in the
browser) and amr, awb, 3gp, 3ga (kept, offered as downloads). The content is
sniffed: a file whose bytes are not audio is refused whatever its name.

Reply 200: `{"success": true, "uid": "...", "size": 48044}`, or
`{"success": true, "uid": "...", "already": true}` when it was stored before.

| Status | error | What the app does |
| --- | --- | --- |
| 404 | event_not_found | Sync the call first, then upload |
| 422 | not_a_call | Drop it: recordings belong to phone calls only |
| 403 | recordings_off | Drop it and stop collecting recordings |
| 413 | file_too_large | Drop it. `max_mb` says the real limit |
| 415 | unsupported_type | Drop it |
| 400 | upload_failed, missing_file | Retry later |

Recommended: re-encode to AAC (m4a) mono at about 24 kbps before uploading.
Speech stays clear and a minute costs around 180 KB instead of 0.5 to 1 MB.

## Errors on every authenticated call

| Status | error | What the app does |
| --- | --- | --- |
| 401 | missing_token, invalid_token | Pair again (invalid_token also means the device was given to another phone with a new code) |
| 401 | device_revoked | Stop, clear the token, tell the user the phone was revoked |
| 401 | device_mismatch | Pair again |
| 403 | staff_inactive | Stop, tell the user |
| 426 | update_required | Show the blocking update screen; `min_version` says the minimum |
| 503 | api_disabled, module_disabled | Pause and retry on the next interval |
| 503 | module_incomplete | The CRM's module files are damaged. Retry later |
| 405 | method_not_allowed | A bug in the app |
| 400 | invalid_request, invalid_json | A bug in the app |
| 413 | batch_too_large, payload_too_large | Send smaller batches |

Treat one 401 as possibly transient (a proxy hiccup); act on it after three in
a row. Keep the queue on disk meanwhile.

## Sync strategy

- Queue everything locally first (Room or SQLite), keyed by uid.
- Send straight after each call ends, and every `sync_minutes` otherwise.
- Batches of at most `batch_size`. On a network error, 5xx or 429, back off
  exponentially (30 s, 1 min, 2 min, up to 15 min).
- Upload recordings after their call is acknowledged, oldest first, honouring
  `wifi_only`.
- `server_time` in every reply lets you spot a phone whose clock is wrong.

## Android notes

Google Play treats call log and SMS access as restricted permissions: a CRM app
has to declare the use and pass review. For company phones a directly installed
APK avoids that.

| Data | Source |
| --- | --- |
| Calls | `CallLog.Calls`: `_ID`, `NUMBER`, `CACHED_NAME`, `DATE`, `DURATION`, `TYPE`, `PHONE_ACCOUNT_ID`. A good uid is `call-<_ID>-<DATE>` |
| Call type | 1 incoming, 2 outgoing, 3 missed, 4 voicemail, 5 rejected, 6 blocked, 7 answered elsewhere (send as incoming) |
| SIM slot | Map `PHONE_ACCOUNT_ID` to a slot through `SubscriptionManager` |
| SMS | `Telephony.Sms`: type 1 is incoming, 2 is outgoing. Skip drafts, outbox and failed. RCS chats are not in this provider |
| WhatsApp calls | No API exists. Read WhatsApp's own call notifications (`com.whatsapp`, `com.whatsapp.w4b`, category `call`): the incoming, ringing and ongoing call notifications give the direction and the name (the number when unsaved); time the call from the ongoing notification appearing to it being removed; missed call notifications give missed calls. The wording varies by WhatsApp version and language, so match defensively. Best effort, never recorded |
| Recordings | Since Android 10 an ordinary app cannot capture call audio. Pick up the file the phone's own dialer saved (Samsung: `Recordings/Call`; other makers vary), matching it to the call by time. Google's Phone app keeps its recordings private, so on phones using it offer a share-to-app fallback instead |

Keep the app alive with a foreground service and ask the user to exempt it from
battery optimisation; report that as `battery_unrestricted`.

## iOS notes

iOS gives apps no call history, SMS, other apps' notifications or call
recordings. What an iOS app can send:

- Calls it places itself (`tel:` links), timed with `CXCallObserver`, sent as
  `kind: call`, `direction: outgoing`, `source: app`. The duration is
  approximate.
- Calls the user logs by hand, `source: manual`.

Pair with `platform: ios`. The Devices page shows the difference.

## Trying it

```
php tooling/phone.php ping   --url=https://crm.example.com/
php tooling/phone.php pair   --url=https://crm.example.com/ --code=644653
php tooling/phone.php config --url=https://crm.example.com/
php tooling/phone.php sync   --url=https://crm.example.com/ --count=20
php tooling/phone.php record --url=https://crm.example.com/ --uid=<call uid> --file=call.m4a
```

The same requests with curl:

```
curl -X POST https://crm.example.com/mks_sales_track/api/v1/sync \
  -H "Content-Type: application/json" \
  -H "X-Sales-Track-Token: <token>" \
  -d '{"events":[{"uid":"call-1","kind":"call","direction":"outgoing","number":"+91 98765 43210","time":1791897127494,"duration":95,"recording":true}]}'

curl -X POST https://crm.example.com/mks_sales_track/api/v1/recording \
  -H "X-Sales-Track-Token: <token>" \
  -F uid=call-1 -F file=@call.m4a
```

## outcome (POST, authenticated)

The after-call popup's answers, one or many: the app queues them while offline
and sends them when it can. Each names its call by the uid it was synced with,
so sync the call first.

```json
{"items": [
  {"uid": "call-48213-1791897127508", "outcome": "interested", "note": "Wants the brochure",
   "follow_up_at": 1791990000000, "lead_status": 3, "create_lead": {"name": "Ravi Kumar"}},
  {"uid": "call-48214-1791897300000", "outcome": "no_answer"}
]}
```

| Field | Required | Meaning |
| --- | --- | --- |
| `uid` | yes | The call's uid on this phone |
| `outcome` | yes | A key from `config.outcomes.list` |
| `note` | when `note_required` | Up to 2,000 characters |
| `follow_up_at` | no | Epoch milliseconds (or seconds, or ISO 8601), within a year. Becomes a Perfex reminder on the lead or customer for the phone's owner |
| `lead_status` | no | A Perfex lead status id; otherwise the outcome's own status, if it has one |
| `create_lead` | no | For a number not in the CRM, when `config.outcomes.create_lead` is true: create a lead (name optional) and link the call and every earlier call with that number to it |

Up to 100 items per request. Sending a new outcome for the same call replaces
the old one (and its reminder, if it has not fired yet).

```json
{"success": true, "stored": ["call-48213-1791897127508"],
 "rejected": [{"uid": "call-1", "reason": "invalid_outcome"}],
 "leads": {"call-48213-1791897127508": 42}}
```

`rejected` reasons: `invalid_uid`, `event_not_found`, `not_a_call`,
`invalid_outcome`, `note_required`, `invalid_follow_up`, `invalid_status`.
Converted is a fixed outcome: depending on Settings, it either tells managers
the lead is ready to convert or moves the lead to the converted status.

## Tamper and permission reports

Add `tamper` to any `config` call when the app notices something:

```json
{"tamper": [{"type": "call_log_deleted", "detail": "3 entries between 10:02 and 10:40"}]}
```

| type | When |
| --- | --- |
| `call_log_deleted` | Call log entries disappeared before they were synced |
| `sms_deleted` | SMS disappeared before they were synced |
| `clock_changed` | The phone's time was changed by hand |
| `app_data_cleared` | The app starts with no local data on a device that was paired before |

The CRM also raises `permission_lost` itself when a permission reported as
granted comes back missing, and `silent` when an active phone sends no
heartbeat for the configured hours inside working hours. Alerts appear on the
device page and are sent to the people chosen in Settings > Alerts, at most
once every six hours per phone and type.

## Missed calls

Nothing for the app to do: a missed or rejected call (and a missed WhatsApp
call, if enabled) joins its owner's callback queue in the CRM when it syncs,
and any connected call with that number, by anyone, clears it.

## Push (Firebase Cloud Messaging)

Send the phone's FCM registration token on any `config` call, and again
whenever Firebase rotates it:

```json
{"push_token": "dGVzdC10b2tlbi...:APA91b..."}
```

An empty string forgets it. When the CRM has a Firebase service account key
(Settings > Click To Call), queued commands are also pushed straight away as
data-only, high-priority messages:

```json
{"type": "command", "id": "304d6659a127", "command": "dial", "number": "+919812200001", "name": "Sunil Traders"}
{"type": "command", "id": "6c1e09f2aa41", "command": "sync_now"}
{"type": "ping", "sent": "1791900000"}
```

All values are strings. On `command`, act on it, then call `config` with the
`acks` as usual (the heartbeat would deliver the same command anyway, so a
missed push only delays it). `ping` is the device page's Send Test Push: do
nothing visible. The app must be built with the same Firebase project as the
key saved in the CRM.

## lists (GET or POST, auth)

The phone owner's active call lists, each with its own leads (pending first,
up to 300) and progress. POST can skip leads or bring them back; a phone can
only touch its owner's own leads:

```json
{"skip": [{"list_id": 3, "lead_id": 41}], "unskip": []}
```

```json
{"success": true, "lists": [{"id": 3, "name": "October follow-ups", "note": "", "due": "2026-10-31",
  "progress": {"total": 40, "done": 12, "reached": 9, "skipped": 1, "pending": 27, "percent": 33},
  "items": [{"lead_id": 41, "name": "Sunil Traders", "company": "", "number": "+919812200001", "status": "Interested",
    "state": "pending", "last_call": null, "outcome": "", "do_not_call": false}]}]}
```

States: `pending`, `tried` (called, not reached), `reached`, `skipped`. They
come from the calls themselves: sync the call and the lead moves on.

## directory (GET, auth, `page`)

Everyone the phone can recognise for the caller popup, 1000 entries a page,
up to 5000, as Settings > Caller Popup allows for the phone's owner:

```json
{"success": true, "version": "faccba508f9ed395", "page": 1, "pages": 1, "total": 2, "entries": [
  {"k": "9812200001", "t": "lead", "id": 6, "n": "Sunil Traders", "c": "", "s": "Interested", "o": "Anish Admin",
   "l": "2026-10-13T11:20:00+05:30", "lo": "Interested", "ln": "Wants a quotation", "f": "2026-10-15T10:00:00+05:30"},
  {"k": "9811100002", "t": "staff", "n": "Amit Sharma", "c": "Makes360"}]}
```

`k` is the matching key (the last digits, as `match_digits`); `t` is lead,
customer, staff or custom; `dnc` is true for do-not-call numbers. Keep the
copy encrypted on the phone and fetch again when `config.popup.version`
changes. 403 `directory_disabled` when the popup is off.

## lookup (GET, auth, `number`)

One number the phone's copy does not know: `{"found": true, "entry": {...}}`
in the directory's shape, or `{"found": false, "entry": null}`.
