# MKS Sales Track - Handover

Read this first. It assumes no memory of how the module was built.

| | |
| --- | --- |
| Folder | `mks_sales_track` |
| Module name | Sales Track |
| Version | 1.8.0 (phase 9) |
| Platform | Perfex CRM 3.4.1, PHP 8.3, CodeIgniter 3 HMVC, MariaDB or MySQL utf8mb4 |
| Hosting | Hostinger shared, no SSH, deployed as a ZIP through File Manager |
| Owner | Anish, Makes360 |
| Core files modified | None |

## What it is

The CRM side of a Salestrail-class call tracking system for company-owned
phones. Android and iOS apps (built separately) pair with a device created in
the CRM and push in calls, call recordings, WhatsApp calls and SMS. The module
stores them, matches every number to the customer, lead or staff member it
belongs to (showing the lead's or customer's own status), and presents them
behind one sidebar item: a Dashboard with a tab bar to the lists, Devices and a
dedicated Settings page whose settings also reach the phones.

## The documents

| File | Read it when |
| --- | --- |
| HANDOVER.md | First |
| ROADMAP.md | The locked plan, every decision, the phase status |
| PROJECT.md | The original brief and what is out of scope |
| API.md | The wire contract for the phone apps |
| APP_DEVELOPER.md | How the apps must behave, platform by platform, and the app roadmap |
| SETTINGS.md | Every setting (generated from the schema) |
| ARCHITECTURE.md | Before changing code |
| FEATURES.md | Explaining a page or a setting |
| DEVELOPER.md | Setting up a test CRM, running the gates, releasing |
| GOTCHAS.md | Before you are surprised by Perfex |
| CHANGELOG.md | What changed |

## State

All nine CRM phases are complete and tested end to end against a real Perfex
3.4.1 install, including upgrades from every earlier version. What remains is
the phone apps: APP_DEVELOPER.md lists stages A to D, all buildable now, and
API.md is the contract. ROADMAP.md has the full record. AI needs a Gemini API key from Google AI Studio in Settings >
AI (Gemini); it was tested end to end against tooling/fake_google.php, not
against Google itself. Google Drive needs an
OAuth client (Web application) with the redirect address shown in Settings >
Recording Storage, and the Drive API enabled; Drive and push were tested end to
end against tooling/fake_google.php, not against Google itself. Scheduled email reports need Perfex's cron and working
email settings; Settings > Email Reports > Send It To Me Now checks both.
The Android app can build stages A, B and C now: APP_DEVELOPER.md. Click-to-call
needs a Firebase project: its service account key goes in Settings > Click To
Call, and the app must be built with the same project. Delivery through Google
was not testable in the build sandbox (no route to Google); everything up to
the HTTPS call is gated. Missed-call escalation and silent phone alerts need
Perfex's cron running (Setup > Settings > Cron Job).

## Before changing anything

1. `php tooling/gates.php` from the module folder. It must pass.
2. Read ARCHITECTURE.md and GOTCHAS.md.
3. After changing code, run `php tooling/e2e.php` against a staging CRM.

## Install

1. Upload the `mks_sales_track` folder to `modules/`.
2. Setup > Modules > activate Sales Track.
3. Setup > Staff > Roles: give the sales role View Own Activity, team leads
   View Team Activity (their Perfex departments are their teams), and managers
   View All Activity, Play Recordings and Manage Devices.
4. Sales Track > Settings > Targets: working days and daily targets.
5. Sales Track > Settings: review the other sections (App Lock PIN, minimum app
   version, store links).
6. Sales Track > Devices > Add Device; give the 6-digit code to the phone.

To see the screens before any phone exists: Devices > Load Demo Data, and
Remove Demo Data afterwards.
