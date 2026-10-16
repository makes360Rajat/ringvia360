# MKS Sales Track - Architecture

## Files

```
mks_sales_track.php                  Bootstrap: constants, schema-driven settings, permissions,
                                     the single sidebar item, the Setup > Settings link,
                                     asset injection, CRM and staff hooks
config/settings_schema.php           Every setting: section, type, default, strings, phones flag
config/routes.php                    mks_sales_track/api/v1/(:any) -> Mks_sales_track_api
config/csrf_exclude_uris.php         Exempts the API path only
install.php / uninstall.php          Idempotent schema (revision 2) / self-contained removal
migrations/180_version_180.php       Re-runs install.php (one migration, named after the version)
controllers/Mks_sales_track_wall.php The wallboard's secret link (App_Controller, no sign in)
controllers/Mks_sales_track.php      Dashboard, lists, devices, device page, settings, AJAX
controllers/Mks_sales_track_api.php  Phone API (App_Controller)
helpers/mks_sales_track_helper.php   Numbers, matching, devices, pairing, commands, sync
                                     history, ingest, recordings, JSON
helpers/mks_sales_track_view_helper.php  Columns, filters, tiles, cells, status pills, tab bar
helpers/mks_sales_track_workflow_helper.php  Outcomes and their effects, leads from calls, native
                                     reminders, notifications, the callback queue, device
                                     alerts and the cron run
helpers/mks_sales_track_lists_helper.php  Call lists, do-not-call numbers, the caller popup
                                     directory, the wallboard figures (loaded on demand)
helpers/mks_sales_track_ai_helper.php  Gemini over raw cURL: instructions, schema, analysis,
                                     cost and budget, the automatic run, coaching
helpers/mks_sales_track_drive_helper.php  Google Drive OAuth, folders, resumable verified uploads,
                                     streaming back, server-copy removal and retention
helpers/mks_sales_track_reports_helper.php  The twelve reports, CSV and Excel export, scheduled
                                     email reports (loaded on demand)
helpers/mks_sales_track_push_helper.php  Firebase Cloud Messaging: encrypted key, signed JWT,
                                     cached access token, data messages (loaded on demand)
helpers/mks_sales_track_analytics_helper.php  Dashboard periods, figures, targets and SVG charts,
                                     loaded on demand by the dashboard only
helpers/mks_sales_track_demo_helper.php  Demo data, loaded on demand only
views/dashboard.php, events.php, missed_calls.php, follow_ups.php, devices.php, device.php,
     settings.php, settings_link.php
views/partials/nav.php, pairing.php, device_form.php, outcome_modal.php, crm_calls.php
views/crm_customer_tab.php           The customer profile's Calls tab
views/reports.php                    The Reports tab
views/pitches.php, partials/pitch_modal.php  Best Pitches
views/partials/ai_insights.php       The Insights window's contents
views/lists.php                      Call Lists
views/wallboard.php                  The wallboard (a page of its own, no Perfex chrome)
tooling/fake_google.php              Local stand-in for Google (OAuth, Drive, FCM) for testing
views/tables/events.php              Server side data for the lists
assets/css/mks-sales-track.css, assets/js/mks-sales-track.js
language/english/mks_sales_track_lang.php
tooling/                             gates.php, e2e.php, phone.php, settings_doc.php (CLI only)
```

## Hooks

| Hook | Use |
| --- | --- |
| admin_init (priority 0) | Re-run the installer when the schema revision changes (also on API calls) |
| admin_init | Capabilities, the Setup > Settings link, the sidebar item |
| app_admin_head / app_admin_footer | CSS, script config and script, on the module's own screens only |
| lead_created, after_lead_updated | Link unknown events to the lead |
| contact_created, contact_updated, after_client_created, client_updated | Move events to the customer |
| after_staff_status_change, staff_member_updated, staff_member_deleted | Revoke an inactive or deleted person's phones |
| after_cron_run | Escalate overdue missed calls, flag silent phones (at most every four minutes) |
| after_lead_lead_tabs, after_lead_tabs_content | The Calls tab in the lead window |
| admin_init (customer tab) | `app_tabs->add_customer_profile_tab()` for the customer profile's Calls tab |

Targets, working days and per-person overrides live in the settings JSON;
teams are Perfex departments (tbldepartments, tblstaff_departments). Phase 3
added no table.

## Tables

`tblmks_sales_track_devices`: one row per company phone, created in the CRM.
Phone binding: `device_uid`, `token_hash` (sha256), `platform`, `manufacturer`,
`model`, `os_version`, `app_version`, `sims`, `health` (JSON from the phone).
Record: `label` (name), `description`, `staff_id`, `phone_number`, `asset_tag`,
`track_sim`, `status` (pending, active, paused, revoked), `commands` (JSON queue,
last 20), `sync_log` (JSON, last 30 syncs), `created_at`, `created_by`,
`paired_at`, `revoked_at`, `revoked_by`, `last_seen_at`, `last_sync_at`,
`last_ip`. `device_uid`, `token_hash` and `paired_at` are empty until a phone
pairs.

`tblmks_sales_track_events`: one row per call, WhatsApp call or SMS; unchanged
in 1.1.0. Unique `(device_id, uid)`; keys on `(kind, occurred_at)`,
`(staff_id, kind, occurred_at)`, `number_key`, `(rel_type, rel_id)`,
`recording_status`.

Options: `mks_sales_track_settings` (autoloaded JSON), `mks_sales_track_salt`,
`mks_sales_track_version`, `mks_sales_track_schema_rev`,
`mks_sales_track_pairing` (not autoloaded), `mks_sales_track_saved_at`,
`mks_sales_track_demo`.

## Pairing

1. Add Device writes a `pending` row and `mks_st_pairing_create()` stores the
   code twice in the pairing option: sha256 hashes (what `pair` checks) and the
   code encrypted with the CRM's key (so the device page can show it again).
   One live code per device; a new one replaces the old.
2. `pair` redeems the code (single use, throttled), then `mks_st_device_bind()`
   writes the phone's uid and a fresh token hash and marks the device active.
   A phone already bound elsewhere is released from that record (revoked); with
   One Phone Per Staff Member on, the person's other phones are revoked.
3. Regenerate Code on a bound device repeats step 2 with the new phone: the
   token hash is replaced, so the old phone's token stops matching.
4. Revoke clears the token hash and the device's codes. Deactivating or
   deleting a staff member revokes their phones.

Events gained in 1.3.0: `lead_id` (the lead behind the number, even when a
customer outranks it), `outcome`, `outcome_note`, `outcome_at`, `outcome_by`,
`follow_up_at`, `reminder_id` (the native Perfex reminder), `callback_state`
(open, escalated, resolved), `callback_due_at`, `callback_at`, `callback_by`,
`escalated_at`, with keys on the queue, follow-ups, outcomes and lead. Devices
gained `alerts` (JSON, last 30).

## Outcomes

`mks_st_apply_outcome()` is the one path for the phone's `outcome` endpoint and
the CRM's Set Outcome window: it validates the outcome, note, follow-up and
status, creates a lead through Perfex's Leads_model when asked (our lead_created
hook then links every call with that number), writes the lead activity, sets
the lead status the way core does (activity log and `lead_status_changed`
hook), handles Converted by the setting, replaces an unfired reminder, and
inserts a native reminder in `tblreminders` for the call's rep. Everything names
the real actor, because on the API nobody is signed in.

## Callback queue

At ingest a missed or rejected call gets `callback_state = open` and a
return-by time counted in working hours (`mks_st_callback_due()`). After the
rows are written, `mks_st_callbacks_settle()` lets each connected call clear
the open calls from its number that came before it, and clears a missed call
imported after its own callback. The cron run escalates overdue ones once and
tells team leads or managers.

## After a sync

`mks_st_after_calls()` runs once per batch: it creates leads for unknown
numbers when `mks_st_auto_lead_wanted()` says the rules allow it (one per
number per batch, through Leads_model; our lead_created hook links every call
with the number), and moves each touched lead's Last Contact to its latest
connected call. Devices gained `push_token` and `push_at` in 1.4.0.

## Reports

`mks_st_reports()` lists the reports; `mks_st_report($key, $period, $ids)` runs
`mks_st_report_<key>()`, which returns columns (each typed: text, number,
percent, duration, datetime, money), rows, an optional totals row and a note.
One view draws any report; `mks_st_report_matrix()` turns the same data into
plain values for `mks_st_report_csv()` (UTF-8 with a byte order mark,
formula-safe) and `mks_st_report_xlsx()` (a minimal SpreadsheetML workbook
written with ZipArchive). Period, team and person come from the dashboard's
filters, and every query uses `mks_st_dash_where()` or `mks_st_scope_sql()`.

Scheduled email reports run in the cron pass: `mks_st_reports_due()` decides
which of daily, weekly and monthly are due (recorded in
`mks_sales_track_reports_sent` before sending, so a slow mail server cannot
send twice), `mks_st_report_recipients()` lists managers (everybody), team
leads (their team) and reps (themselves), and `mks_st_report_email()` builds
inline-styled HTML from the Team Summary and Callbacks reports and sends it
with Perfex's `send_simple_email()`.

## Recording storage

Events gained in 1.6.0: `drive_file_id`, `drive_at`, `drive_attempts`,
`best_pitch` (0, 1 nominated, 2 in the library), `pitch_category`,
`pitch_note`, `pitch_moments` (JSON), `pitch_by`, `pitch_at`; recordings can
be `expired`. A recording is on this server while `recording_file` is set and
on Drive once `drive_file_id` is.

`mks_st_storage_run()` runs with the cron: up to twenty uploads per run
(resumable: a POST for the session, a streamed PUT, then size and MD5
compared), five attempts per recording, server copies removed once
`drive_at` is older than the days set, and retention for recordings kept only
on this server (never Best Pitches). Folder ids are cached by path. The OAuth
refresh token and access token are encrypted with the CRM's key. Every Google
URL comes from `mks_st_google_url()`, which a test install can point at
tooling/fake_google.php by defining MKS_ST_GOOGLE_BASE in its own config.

The recording route streams from disk when the file is here and proxies Drive
(passing Range through) when it is not, after the same checks; a Best Pitch is
open to anyone with Sales Track access. `mks_st_recording_audit()` writes the
listening log.

## AI insights

A third table, `tblmks_sales_track_ai` (event_id, model, language,
transcript, analysis JSON, tokens, cost, created_at), keeps transcripts out of
the events table, which only gains the figures lists use: `ai_status` (done,
failed, skipped, capped), `ai_at`, `ai_score`, `ai_sentiment`,
`ai_temperature`, `ai_flags`, `ai_cost`, `ai_note`.

`mks_st_ai_analyse()` checks the budget against an estimate (32 audio tokens a
second), reads the recording from disk or Drive, sends it inline (up to 18 MB)
to `models/<model>:generateContent` with a system instruction built only from
the call's own facts and the module's lists, a response schema and
temperature 0.2 (thinking off on 2.5 Flash), prices the reply from
`usageMetadata`, clips and checks the answer in `mks_st_ai_normalise()` (the
score is the share of score card marks), stores it, and raises flag alerts.
The cron run analyses up to three new recordings per pass by the automatic
rule; the weekly pass sends coaching notes. Every Google URL, Gemini included,
comes from `mks_st_google_url()`, so tooling/fake_google.php answers for it in
tests.

## Call lists without a table

`mks_sales_track_lists` holds every list's header (name, note, due, staff,
creator, created_at, status, count) and the next id;
`mks_sales_track_list_<id>` holds that list's lead assignments and skips. Both
are non-autoloaded. A list is frozen at creation (at most 1000 leads, newest
first, do-not-call numbers left out); where each lead stands is worked out by
one grouped query over calls with those leads since the list was made, so
there is nothing to keep in step. Deleting a list removes its option.

## Caller popup directory

`mks_st_directory($staffId)` builds entries keyed by number key from staff,
leads (all or the owner's), customers and contacts (by
`mks_st_customer_visible_for()`), and extra lines, with the latest call per
lead (by highest id: no window functions, for MySQL 5.7) and the next
follow-up. `mks_st_directory_version()` is a hash of cheap aggregates and the
relevant settings, sent in the heartbeat so phones fetch only on change.

## Click to call

`mks_st_dial()` finds the signed in member of staff's active phone, queues a
`dial` command with its number and a two minute expiry, and, when a Firebase
key is saved and the phone has a token, pushes it at once. The push helper
signs an RS256 JWT with the service account key, exchanges it for an access
token (cached, encrypted), and posts a data-only, high-priority message to
FCM's HTTP v1 API. A token FCM reports unregistered is forgotten. The page
script binds Call buttons on every page it loads on, which now includes
Perfex's leads and customer pages.

## How an event travels

1. The phone posts a batch to `sync` with its token.
2. `_remap()` checks the endpoint whitelist, the master and API switches and the
   method, authenticates the device, and refuses outdated apps with 426 on
   sync, outcome and recording.
3. `mks_st_ingest()` validates each event, applies the policies (tracking
   switches, paused device, excluded numbers, SIM choice), drops held uids and
   reinstall duplicates, matches numbers, applies the SMS text rule, and writes
   with `INSERT IGNORE` per hundred rows.
4. The reply sorts every uid into stored, duplicate, skipped or rejected; the
   sync is prepended to the device's history.
5. Recordings arrive on `recording`, are sniffed, stored under
   `uploads/mks_sales_track/recordings/YYYY/MM/` and streamed back with range
   support after a permission check.

## Commands

`mks_st_device_command_add()` queues `sync_now` or `recheck_permissions` on the
device row. `config` hands pending commands to the phone (marking them
delivered) and applies the phone's `acks` (done or failed). Phase 5 adds push
delivery through Firebase.

## Settings

`config/settings_schema.php` is the single definition. `mks_st_setting_defaults()`
and `mks_st_save_settings()` read it, `views/settings.php` renders it, and
`tooling/settings_doc.php` writes docs/SETTINGS.md from it. Saving cleans every
field by type, stores 0 for absent switches, hashes the App Lock PIN with
PBKDF2-SHA256 and a random salt, keeps the PIN when the field is left empty, and
refuses App Lock without a PIN. The phones receive their part through
`mks_st_device_config()`, whose version hash rides on every sync reply.

## Permissions and scope

`mks_st_scope()` answers null (everybody), a list of staff ids (yourself, plus
everybody sharing a Perfex department with you when you hold View Team
Activity) or false (nothing). `mks_st_scope_sql()` turns it into the one SQL
condition every list, tile, chart, device read and dashboard query uses, and
`mks_st_scope_allows()` checks single record routes and filters. Device pages
open for Manage Devices or anyone whose scope covers the device's owner.
Settings follow Perfex's settings permission.

## Dashboard analytics

`mks_st_dash_filters()` validates the period, team and person against the
viewer's scope; `mks_st_dash_staff_ids()` narrows the scope by them; and
`mks_st_dash_where()` builds the WHERE every figure shares (period, kinds,
scope, and calls between staff left out when the setting says so). Each tile
runs its period and the equal period before it. Trend, call mix, heatmap and
leaderboard are one grouped query each. Targets come from the settings: a
person's override for a metric, else the default, multiplied by the working
days in the period. Charts are SVG strings built in PHP with every label
escaped and hover text in native title elements; no chart library is loaded.

## Screens

The sidebar item opens the Dashboard. `views/partials/nav.php` draws the tab bar
from `mks_st_nav_items()`, which hides switched-off trackers and what the viewer
may not use. The four lists share `views/events.php` and one DataTables
endpoint; their columns, search and tiles come from one definition, and the
cells come from a second query by id that also brings the lead status, its
colour, Lost, Junk, Converted and the customer's active flag.
