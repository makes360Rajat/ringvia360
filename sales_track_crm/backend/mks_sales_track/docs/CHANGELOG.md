# Changelog

## 1.9.7

- Real-Time Device Revocation & Unpairing: Immediate detection of device revocation or deletion on the CRM; app promptly terminates pairing, clears session caches, and returns to the pairing screen with an alert banner.
- Periodic Sync & Active Health Heartbeat: Reduced background sync interval to 30s with active heartbeat validation and health reporting to ensure device status is always up-to-date on the CRM.
- Mobile Call Card UI Refinement: Unsaved phone calls strictly render "Un Saved" title on line 1, phone number on line 2, timestamp on line 3, and direction/duration on line 4 with clean green REC badge.
- Migration `197_version_197.php` and schema revision 18 added for seamless in-place upgrade.

## 1.9.2

- Pairing is by 6-digit code only: removed QR code display from device view and pairing response.
- Replaced pairing QR icons with hashtag icon across device views.
- Updated language strings and end-to-end tests for 6-digit code pairing.
- Migration 192_version_192.php added for seamless in-place upgrade.

## 1.9.0

- Mobile Client Dialing & Sync Optimization: Resolved background thread lock and zero-data state by optimizing native call query batching, ensuring immediate local dialing history import and display.
- Call Card UI Redesign: Standardized mobile call cards into a modern 3/4-tier layout:
  - Line 1: Contact Title (saved contact name or standardized "Un Saved" label) with SIM slot badge.
  - Line 2: Phone / Contact Number.
  - Line 3: Real-time call timestamp indicator ("Call at [formatted time]").
  - Line 4: Direction and duration details ("[Direction] - Talk time: [seconds/duration]").
  - Badges: Right-aligned SYNCED / PENDING status and REC recording indicator.
- Layout Overflow Guard: Added horizontal flex constraints with ellipsis text handling to prevent RenderFlex edge overflow on narrow mobile screens.
- Numeric Pairing Input: Enforced numeric keyboard, digit-only filtering, and 6-digit limit on mobile pairing screen to ensure rapid, error-free device connection.
- Standardized Unsaved Contact Fallback: Mobile sync and CRM ingestion fallback to "Un Saved" when contact name is unavailable in device phonebook, preventing raw numbers from polluting contact name fields.
- Migration `190_version_190.php` and schema revision 17 added for automatic Perfex CRM database and options synchronization.

## 1.8.7

- Resilient Direct-DB Pairing Store Synchronization: `mks_st_pairing_load()` queries `tbloptions` directly, bypassing LiteSpeed, OPcache, and Perfex CRM in-memory option caches to prevent newly issued pairing codes from being missed or read from stale snapshots.
- Expiration Fallback Guard: Enforced minimum 5-minute to 1440-minute duration bounds (`default 60 minutes`) in `mks_st_pairing_create()`, completely eliminating zero-second instant expiration bugs.
- Safe Non-Destructive Code Redemption: `mks_st_pairing_redeem()` only deletes pairing codes from storage upon a confirmed, successful valid match. Expired or mismatched attempts no longer prematurely erase valid codes, preventing subsequent submissions from failing with false "That pairing code is not valid".
- Clock-Skew Tolerance & Reverse Traversal: Added a 5-minute grace tolerance (`$entry['expires'] >= (time() - 300)`) and newest-first code scan to seamlessly handle minor device-server clock variations.
- Explicit Cache Invalidation: `mks_st_option_put()` synchronizes `$CI->app_object_cache` and `$CI->app->options` simultaneously.
- Migration `187_version_187.php` and schema revision 15 added for automatic Perfex CRM database synchronization.

## 1.8.5

- Enhanced API Save & Update: when events arrive, all fields (`duration`, `direction`, `contact_name`, `body`, `number`, `media`, `sim_slot`, `rel_type`, `lead_id`, `contact_id`) are accurately saved or updated on existing and natural-deduplicated records.
- Added `events` API endpoint (`GET/POST /mks_sales_track/api/v1/events`): supports fetching synced telemetry events with filtering (`kind`, `since`, `limit`, `page`), total count, and pagination, as well as POST ingestion.
- Redesigned WhatsApp table view to match Calls tab column alignment: Type, Contact, Staff, Time, Duration, Phone, Activity / Message, Outcome, Options.
- Added dedicated Voice Call and Video Call badges in the Activity column for WhatsApp calls with zero or empty message text.
- Suppressed redundant WhatsApp badges in contact cells within the WhatsApp tab to ensure clean, compact 2-line rendering identical to the Calls tab.
- Added `185_version_185.php` cumulative migration for seamless Perfex CRM in-place module upgrade.

## 1.8.4

- Added native support for full WhatsApp message sync and display (`whatsapp_message` telemetry kind).
- Unified WhatsApp view to display both WhatsApp Calls and WhatsApp Messages with contact name, phone/source, and expandable message content.
- Enabled auto-permission check for WhatsApp message tracking under both `track_whatsapp_calls` and `track_sms` CRM configurations.
- Offline-first delta synchronization optimizations with single-click manual sync controls on mobile app.
- Fixed MySQL duplicate key 'device_uid' exception during database upgrade by deleting duplicates before merging and preserving primary row UID.
- Migration `184_version_184.php` added for in-place Perfex CRM module update.

## 1.8.3

- Enhanced telemetry sync compatibility with local dev server and cloud endpoints.
- Added comprehensive call audio recording ingestion and streaming endpoint.
- Updated schema migrations to v1.8.3.

## 1.8.2

- Resolved duplicate call entries on CRM by introducing intelligent 120s fuzzy-window deduplication for calls and WhatsApp calls.
- Resolved zero-duration ("Not Answered" / duration `-`) display by updating call duration and direction when richer CallLog data arrives.
- Enhanced recording upload matching in API (`mks_recording`) to search across paired devices, staff ID, and timestamp ranges.
- Auto-healing for call recording events so no uploaded audio recording returns 404 or causes client upload loops.
- Added self-healing duplicate event cleaner `mks_st_cleanup_duplicate_events()` on schema upgrade.

## 1.8.1

- Enhanced API sync for mobile client offline-first SQLite database ingestion.
- Multi-channel sync support for historical and live call audio recordings (.m4a, .aac, .mp3, .3gp, .amr).
- Added token fallback in multipart POST form-fields to ensure recording upload success on shared hosting.
- Seamless re-sync support for pending batches, call lists, and status updates.

## 1.8.0

Phase 9, the last CRM phase.

- Call Lists tab: managers and team leads build a list from lead filters
  (status, source, owner, not contacted for N days, created between, open
  only), share it among reps evenly or by owner, and follow progress. Reps see
  their own leads with Call buttons and Skip. Whether a lead was called,
  reached or given an outcome is read from the calls themselves. Lists need no
  new table: headers and lead assignments are kept in options.
- Do Not Call (Settings > Privacy): no Call buttons for those numbers, never
  on a call list, click-to-call refuses them, managers add numbers from a
  list, and phones receive them as salted hashes to warn before dialling.
- Caller popup (Settings > Caller Popup): phones fetch a directory of leads
  (all or their own), customers and contacts (by the customer names rule, all
  or none), colleagues and extra entries, with status, owner, last call and
  outcome, last note and next follow-up; a version in the heartbeat says when
  to fetch again, and a lookup answers for one number.
- Wallboard: today's totals, leaderboard and latest calls for a sales-floor
  screen, from the Dashboard for managers and team leads, or through a secret
  link (off by default, renewable). Rep names and figures only.
- AI: the default model is now gemini-3.1-flash-lite, prices to match, and
  Choose From My Key's Models lists the models the key may use. Existing
  installs keep their chosen model.
- API: lists, directory and lookup endpoints; config carries do_not_call,
  popup and call_lists.
- Fixed: demo data loaded before the working day began dated today's calls in
  the future.
- Gates 132, end-to-end checks 54.

## 1.7.0

Phase 8.

- AI insights with Google Gemini, over raw cURL with a JSON schema: the call's
  transcript (Hindi, Punjabi, English or a mix), summary, sentiment, how hot
  the lead is, objections, next steps, a score card from your own criteria
  (the score is worked out from the marks, not taken from the model), flags
  for competitors, discount or price promises, abusive language and watched
  words, and a suggested outcome.
- Settings > AI (Gemini): key (encrypted), model, automatic rule (CRM numbers,
  every call, or on request only), length limits, monthly budget with prices
  per million tokens, score card, competitors, watched words, alerts,
  suggestions, whether reps see their own insights, weekly coaching. Test The
  Key checks the key and model.
- An AI column on Calls and Recordings: score, temperature and flags, opening
  the Insights window, or Analyse for managers and team leads.
- Flags alert the people chosen under Alerts. A suggested outcome is applied
  only when a person clicks Use This Outcome.
- Weekly coaching notes per rep to their team lead, written from the week's
  figures, on the weekly report's day and time.
- An AI Insights report: analysed calls, average score, hot, warm and cold,
  sentiment, flagged calls and, for managers, cost.
- Only the call's recording, direction, length, the rep's name and the
  module's own lists are sent; never lead or customer details.
- A third table, tblmks_sales_track_ai, holds transcripts and full analyses so
  the events table stays light for every list read; uninstall with purge drops
  it too.
- Gates 126, end-to-end checks 47.

## 1.6.0

Phase 7.

- Settings > Recording Storage: keep recordings on this server or on Google
  Drive, delete server recordings after set days (0 keeps them), who may
  download, the listening log, Best Pitch nominations and categories.
- Google Drive: one Workspace account connected through OAuth (drive.file
  scope: Sales Track sees only what it created), client secret and refresh
  token stored encrypted. The cron run uploads new recordings with resumable
  uploads into Sales Track / year / month / rep, verifies size and MD5, and
  deletes the server copy after the days set. Playback streams from Drive
  through the CRM with seeking, under the same permission checks.
- Best Pitches tab: a library open to everyone who uses Sales Track, filtered
  by category, with notes and clickable moments. Managers (new capability
  Manage Best Pitches) add calls or approve the nominations reps send with the
  star on Calls and Recordings. Best Pitches are never deleted.
- Every play and download goes to Perfex's activity log (once per person and
  recording every ten minutes); a Recording Access report lists them for
  managers. The Recordings report counts recordings on Drive.
- tooling/fake_google.php: a local stand-in for Google's OAuth, Drive and FCM
  endpoints, so Drive storage and push are tested end to end; only a test
  install's own config can point the module at it.
- Gates 120, end-to-end checks 45.

## 1.5.0

Phase 6.

- Reports tab with eleven reports: Team Summary, Daily Activity, Missed Calls
  And Callbacks, Call Duration, Outcomes, Speed To Lead, Lead Engagement,
  Conversion, Recordings, SMS and Phone Health. Presets or a custom period up
  to a year, team and person filters, totals rows, notes on how each is
  counted, all scoped like the rest of the module.
- Export any report to CSV (UTF-8 for Excel, formula-safe) or to an Excel
  workbook (numbers stay numbers, durations in minutes); print view.
- Conversion analytics: leads each rep spoke to, how many were converted in
  Perfex, Converted outcomes, and paid invoices from those customers for
  people allowed to see customers and invoices.
- Scheduled email reports through Perfex's own email settings: daily at a set
  time, weekly on a set day, monthly on the 1st; to managers, team leads (their
  team) and each rep (their own day); empty ones skipped. Preview and Send It
  To Me Now in Settings > Email Reports.
- Gates 115, end-to-end checks 43.

## 1.4.0

Phase 5.

- Automatic leads: off until switched on; rules for incoming, outgoing or both,
  minimum length, WhatsApp calls, working hours only, and calls imported at
  pairing. Created through Perfex's Leads_model with the status, source and
  assignment already set for leads from calls.
- Last Contact on the lead follows its latest connected call, also when calls
  link to a lead later.
- A Calls tab on the lead window and the customer profile: totals, every call,
  WhatsApp call and SMS the viewer may see, outcomes, recordings playable in
  place, and Call buttons.
- Click-to-call: Call buttons on Calls and WhatsApp rows, Missed Calls,
  Follow-ups and the Calls tabs make the user's own company phone dial.
  Delivered at once through Firebase Cloud Messaging (service account key in
  Settings, stored encrypted, never shown again) and on the next heartbeat
  otherwise; a dial expires after two minutes.
- Phones register their Firebase token; the device page shows it and can send
  a test push.
- Lead activity and notifications are stored as language keys with their
  values, as core does.
- Fixed: looking up a name between a query's where() and update() leaked into
  the half-built query when a lead was created from the API.
- Gates 110, end-to-end checks 39.

## 1.3.0

Phase 4.

- After-call outcomes: an editable outcome list in Settings (colour, asks for a
  follow-up, sets a lead status, active), with Converted fixed. The phone sends
  answers to the new `outcome` endpoint; the CRM sets and changes them from an
  Outcome column on Calls and WhatsApp, with an outcome filter.
- Follow-ups are native Perfex reminders on the lead or customer, emailed if
  set; a Follow-ups page lists them as Due, Upcoming and Done.
- Create Lead from the phone, by the status, source and assignment set in
  Settings, through Perfex's own Leads_model.
- Converted: managers are told and convert with Perfex's own Convert To
  Customer (Ready To Convert on the dashboard), or the lead moves to a status.
- Missed Calls page: the callback queue, counted in working hours, cleared by
  any connected call with the number, escalated on Perfex's cron to team leads
  or managers, by notification and email.
- Never Attended and Never Received filters on Calls.
- Device alerts: tampering reported by the phone, lost permissions, silent
  phones; shown on the device page and sent as set in Settings > Alerts.
- Customer matching can be switched off; who sees customer names is a setting;
  a customer number also shows the lead behind it.
- Lead activity: outcomes, status changes and reminders logged under the real
  actor's name.
- Demo data includes outcomes, follow-ups and the queue.
- Gates 103, end-to-end checks 37.

## 1.2.0

Phase 3.

- The Dashboard becomes analytics: Today, Yesterday, 7 Days, 30 Days, This
  Month and Last Month; team and person filters; eight KPI tiles, each against
  the equal period before; calls by day (or by hour for one day) split
  connected and not; how calls ended; best calling times by weekday and hour
  with the best hour called out; targets; a leaderboard ranked by calls,
  connected calls or talk time; latest activity and phone status.
- Reps see My Dashboard (themselves), team leads their department, managers
  everybody. New capability: View Team Activity (Perfex departments are teams).
- Targets section in Settings: working days, daily calls, connected calls and
  talk time, and per-person overrides.
- Calls between staff are left out of analytics (switchable).
- Charts are drawn as SVG on the server.
- Gates 95, end-to-end checks 31.

## 1.1.0

Phase 2.

- One sidebar item, Sales Track, opening a new Dashboard (the day's numbers,
  phone health, latest activity); a tab bar on every module page.
- A dedicated Settings page drawn from `config/settings_schema.php`, with a
  section menu; Setup > Settings keeps a link to it. New settings: connected
  call threshold, one phone per staff member, revoke on deactivation, minimum
  app version, store links, App Lock and its PIN.
- Devices v2: add a device (name, description, staff member, SIM number, asset
  tag) and get its 6-digit code and QR; the device page shows a live code
  again, regenerates it to swap handsets, pauses, resumes, revokes and
  deletes, queues commands, and shows health, activity and sync history.
- API: pairing binds to the device record; config carries `paused`, `app`,
  `app_lock`, `commands`, `update_required` and accepts `acks`; sync and
  recording answer 426 to outdated apps.
- Lead status (in Perfex's own colour), Converted, Lost and Junk, and inactive
  customers shown next to every call.
- Notifications removed.
- Deactivating or deleting a staff member revokes their phones.
- docs/ROADMAP.md, docs/SETTINGS.md (generated) and docs/APP_DEVELOPER.md.
- Gates grow to 84, the end-to-end suite to 29 checks.

## 1.0.0

First release (phase 1).

- Two tables, `tblmks_sales_track_devices` and `tblmks_sales_track_events`.
- Phone API: ping, pair, config, sync, recording. Token per device, CSRF exempt
  through the module's own config file, idempotent sync.
- Pairing with a QR code or a six digit code, single use, throttled.
- Calls, Recordings, WhatsApp Calls, SMS and Notifications lists with filters,
  search and KPI tiles that always describe the rows shown.
- A floating recording player with seek and speed, streaming with range
  support through a permission checked endpoint.
- Devices page with phone health, SIM choice, revoke and delete.
- Numbers matched to customers, leads and staff on their last digits, and
  re-matched when a lead, contact or customer is saved.
- Settings tab with General, Tracking, Privacy, Recordings and Devices And API
  sections, sent to the phones.
- Five capabilities: View Own Activity, View All Activity, Play Recordings,
  Manage All Devices, Delete Activity.
- Demo data loaded through the real ingest path and removable in one click.
- Release gates (`tooling/gates.php`), an end to end suite (`tooling/e2e.php`)
  and a phone simulator (`tooling/phone.php`).
