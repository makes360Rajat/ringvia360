# Sales Track - Roadmap

The locked plan: a Salestrail-class call tracking system inside Perfex CRM for
company-owned phones. Each phase is planned, confirmed, built, gated, packaged
and delivered before the next one starts.

## Status

| Phase | Version | Scope | State |
| --- | --- | --- | --- |
| 1 | 1.0.0 | Tables, phone API, pairing, the activity lists, recording player, CRM matching, demo data | Done |
| 2 | 1.1.0 | One sidebar item and a tab bar; dedicated, schema-driven Settings page; Devices v2 (add a device, 6-digit code per device, live code on the device page, handset swap, pause, revoke, commands, sync history, one phone per person, revoke on deactivation, minimum app version, App Lock PIN); lead and customer status shown on every call; notifications removed; ROADMAP, SETTINGS and APP_DEVELOPER docs | Done |
| 3 | 1.2.0 | Dashboard analytics with manager, team lead and rep views (period, team and person filters, KPIs against the previous period, calls by day or hour, how calls ended, best calling times, leaderboard), daily targets with per-person overrides and working days, teams from Perfex departments with View Team Activity, calls between staff left out of analytics, server-side SVG charts | Done |
| 4 | 1.3.0 | After-call outcomes and notes (editable list, Converted fixed), follow-ups as native Perfex reminders, outcome to lead status mapping, Create Lead from the phone, Converted handled by Settings (managers convert, or a lead status), missed-call queue counted in working hours with escalation on Perfex's cron, Never Attended and Never Received, tamper and permission alerts, customer matching and visibility controls, the lead behind a customer number | Done |
| 5 | 1.4.0 | Automatic leads by rule (direction, minimum length, WhatsApp, working hours, never for history unless asked), Last Contact kept current, a Calls tab on the lead window and the customer profile, click-to-call from lists, queue, follow-ups and tabs with Firebase push and a heartbeat fallback, test push, push token registration | Done |
| 6 | 1.5.0 | Reports page with eleven reports (team summary, daily activity, missed calls and callbacks, call duration, outcomes, speed to lead, lead engagement, conversion with paid invoices, recordings, SMS, phone health) over presets or a custom period, team and person; CSV and Excel export; print; scheduled daily, weekly and monthly email reports through the CRM's SMTP for managers, team leads and each rep, with preview and send-me-now | Done |
| 7 | 1.6.0 | Recording storage on this server or Google Drive (one Workspace account through OAuth, drive.file scope, resumable verified uploads into Sales Track/year/month/rep, server copy removed after set days, playback streamed back through the CRM with ranges), retention for server recordings, download rights, Best Pitches library with nominations, categories and moments open to the whole team, listening log in Perfex's activity log and a Recording Access report | Done |
| 8 | 1.7.0 | AI insights with Gemini (raw cURL, structured output): transcript, summary, sentiment, lead temperature, objections, next steps, score card from your own criteria, flags for competitors, discount promises, abuse and watched words with alerts, suggested outcomes a person confirms, weekly coaching notes to team leads; automatic by rule or by hand, monthly budget with per-call cost tracking, an AI Insights report; only the call itself and the module's own lists reach Google | Done |
| 9 | 1.8.0 | Call lists built from lead filters and shared out (progress read from the calls themselves, skips from CRM or phone), do-not-call numbers (no Call buttons, never on a list, refused by click-to-call, hashed to phones), caller popup directory for the phones (leads, customers, colleagues, extra entries; who sees what in settings; delta by version; lookup), wallboard for a sales-floor screen with an optional secret link, Gemini model picker from the key's own models | Done |

App track: Android development can start now (phase 3 is done), in parallel
with the CRM phases. See APP_DEVELOPER.md, stage A.

## Decisions

| Topic | Decision |
| --- | --- |
| Phones | Company-owned only; apps installed from the Play Store and App Store |
| Navigation | One sidebar item, Sales Track, opening the Dashboard; every other page, Settings included, from the tab bar |
| Settings | A dedicated page drawn from `config/settings_schema.php`; Setup > Settings keeps a link to it |
| Notifications | Not tracked. WhatsApp call tracking still needs notification access on the phone, and reads nothing else |
| Background | The app runs in the background; Android's small running-status notification is accepted (hideable on Android 13+) |
| App protection | An App Lock PIN set in Settings guards everything inside the app; the phone's owner can still uninstall a store app, so silence and lost permissions are flagged instead |
| Connected | The administrator sets the seconds from which a call counts as connected |
| Outcomes | After every connected call (and unanswered outgoing call) the app asks outcome, note, follow-up and optional lead status |
| Missed calls | Per-rep queue, managers see all, cleared when anyone reaches the customer |
| Leads | Created manually or by rules set in Settings; assignment rule set in Settings |
| Reports | Targets and scheduled emails, sent through the CRM's own SMTP |
| Recordings | Storage and retention in Settings; optional Google Drive offload through one fixed Workspace account; off means files stay on the server |
| Learning | Calls can be marked Best Sales Pitch |
| AI | Gemini, everything set in Settings |
| Click-to-call | Yes; the phone dials immediately; delivered through Firebase Cloud Messaging |
| Customers | Matching numbers to customers can be switched off for CRMs run on leads alone; who sees customer names is set in Settings (managers by default); others see the lead behind the number |
| Converted | Fixed outcome. Settings choose: managers are told and convert with Perfex's own Convert To Customer (seeing when the number is already a customer contact), or the lead just moves to a converted status |
| Follow-ups | Native Perfex reminders on the lead or customer, for the rep |
| Missed-call time | Set in Settings, counted in working hours; escalation target and email set in Settings |
| Caller popup | A Truecaller-style popup fed by lists built in the module; parked until briefed |

## Statuses: how calls, leads and customers fit together

Three different things carry a "status", and keeping them apart is what keeps
the CRM consistent.

| | Belongs to | Defined in | Shown where |
| --- | --- | --- | --- |
| Call outcome | One call | Sales Track Settings (phase 4): a list you edit, with name, colour, needs follow-up, and an optional lead status it sets. One fixed outcome, **Converted**, cannot be deleted | After-call popup, every call list, reports |
| Lead status | The lead | Perfex (Setup > Leads > Statuses) | Next to every call with that lead (built in 1.1.0), in the popup, and changeable from the popup |
| Customer state | The customer | Perfex (active, inactive) | Next to every call with that customer (built in 1.1.0) |

- A number is matched to a customer contact first, then a customer, then a
  lead, then staff. A lead that became a customer shows as that customer.
- Converted leads show **Converted**, and Lost or Junk leads say so, beside the
  lead's own status in its own colour.
- Choosing the **Converted** outcome on a lead's call marks the lead ready to
  convert and offers Perfex's own Convert To Customer, which creates the
  customer properly. The exact behaviour is confirmed when phase 4 is planned.
- An unknown number can become a lead from the CRM or from the popup; rules in
  Settings can create leads automatically.

## Workflows

| | Flow |
| --- | --- |
| W1 | Phone onboarding: Add Device in the CRM, install the app, enter the code, grant permissions, device goes Online |
| W2 | A rep's day: calls tracked, outcome popup, follow-ups, missed-call queue, click-to-call, own summary email |
| W3 | A manager's day: dashboard, alerts, recordings and Best Pitches, reports, coaching |
| W4 | Unknown number to lead: manual or by rule; past calls link themselves; speed-to-lead counts |
| W5 | Recording lifecycle: phone, CRM, AI, Drive, local cleanup, retention |
| W6 | Click-to-call: CRM button, push, phone dials, call tracked |
| W7 | Phone replaced (Regenerate Code) or rep leaves (deactivation revokes) |
