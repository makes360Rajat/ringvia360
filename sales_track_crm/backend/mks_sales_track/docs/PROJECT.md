# MKS Sales Track - Project

## The brief

"Want to track mobile phone call history, its recording, WhatsApp call history,
SMS, and notifications. For tracking I will build Android and iOS apps, but
before that I need a module and DB for the interface."

Standing instructions for this module: no database tables until strictly
required, folder name as table and CSS prefix, every page in the sidebar, a
settings tab in the main Perfex settings to control the features, and a modern,
carefully spaced design.

## Decisions (round 1, superseded where ROADMAP.md says otherwise)

| Question | Decision |
| --- | --- |
| Tables | Two, both strictly required: devices (each phone's own revocable token, written on every sync) and events (a time series). Everything else is an option |
| What "notifications" means | The phone's own notification feed, limited to the apps listed in settings (WhatsApp and WhatsApp Business by default) |
| iOS | Accepts calls the app places itself and manual entries. No lead list endpoint for iOS yet |
| SMS text | Kept for every number by default; settings can keep it only for CRM numbers, or never |
| WhatsApp Business | Tracked alongside WhatsApp |
| Recording retention | Phase 2. The intended default is 90 days, notifications 30 |
| Uninstall | Keeps all data unless Delete All Sales Track Data On Uninstall is ticked |

## What the phones can actually supply

- Android: all five. Call log and SMS are restricted on Google Play, so company
  phones are simplest with a directly installed APK. Recordings come from the
  phone's own dialer; Google's Phone app keeps its recordings private.
  WhatsApp calls are read from WhatsApp's notifications and are never recorded.
- iOS: none of it beyond calls the app places itself.

## Phases

| Phase | Scope | State |
| --- | --- | --- |
| 1 | Tables, settings, permissions, API, pairing, Devices, the five lists, player, matching, demo data | Done (1.0.0) |
| 2 | Dashboard, lead and customer tabs, lead activity and Last Contact, retention, exports | Next |

## Out of scope

- Recording audio on the server side or transcoding it (no ffmpeg on shared
  hosting). Phones are asked to send AAC.
- Push messages from the CRM to the phones.

## Later decisions

ROADMAP.md holds the locked plan from the planning rounds: company phones only,
no notification tracking, one sidebar item with a Dashboard hub, a dedicated
Settings page, device-first pairing, App Lock, and the phases that follow.
