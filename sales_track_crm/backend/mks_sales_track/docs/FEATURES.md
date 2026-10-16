# MKS Sales Track - Features

## Navigation

One sidebar item, **Sales Track**, opens the Dashboard. Every module page has a
tab bar: Dashboard, Calls, Recordings, WhatsApp, SMS, Devices and Settings.
Tabs: Dashboard, Calls, Missed Calls, Follow-ups, Recordings, WhatsApp, SMS,
Devices and Settings. Tabs appear only when their feature is on and the viewer
may use them.
Setup > Settings > Sales Track links to the Settings page.

## Dashboard

What it shows depends on who is looking: a rep sees **My Dashboard**, a team
lead their department, a manager everybody.

- **Filters**: Today, Yesterday, 7 Days, 30 Days, This Month, Last Month; team
  (Perfex department) and person for those who see more than themselves. Every
  view has its own address.
- **Eight tiles**, each with its change against the equal period before (green
  when it improved, red when it got worse, so more missed calls show red):
  calls (in and out), connected (share), talk time (average), missed, unique
  clients, not answered (share of outgoing), WhatsApp calls, SMS.
- **Calls by day**, or by hour for a single day, split connected and not.
- **How calls ended**: outgoing connected, incoming connected, not answered,
  missed, rejected, other.
- **Best calling times**: calls by weekday and hour, shaded by volume, with the
  connect rate on hover and the best hour called out. Periods under a week use
  the last 30 days, so there is a pattern to see.
- **Targets**: calls, connected calls and talk time against targets for the
  working days in the period; for teams, how many people are on target.
- **Leaderboard** (more than one person): rank by calls, connected calls or
  talk time; calls against target with a progress bar, connect rate, talk time,
  average call, missed, unique clients, WhatsApp calls and SMS. A name opens
  that person's dashboard.
- **Ready To Convert** (managers and team leads): leads marked Converted on a
  call and not yet converted in Perfex, with a warning when the number is
  already a customer contact. Opening one opens the lead to convert it.
- **Latest activity** and **phone status**.
- Calls between staff are left out of every figure here unless switched on in
  Settings.

## The lists

Calls, Recordings, WhatsApp and SMS:

- Date presets, and filters for staff (managers), type, contact (leads,
  customers, staff, not in the CRM) and phone.
- KPI tiles over exactly the rows shown, search included. "Connected" follows
  the threshold set in Settings.
- Each number shows its CRM record: a lead with its Perfex status in the
  status's own colour (and Converted, Lost or Junk), a customer (and Inactive),
  a contact person, or a staff member. Unknown numbers show the name saved on
  the phone and a Create Lead button that opens Perfex's New Lead window with
  the number filled in.
- Recordings play in one floating player with seek and speed; AMR and 3GP are
  offered as downloads.
- Delete for those allowed.

## Outcomes

- After a call the app asks for an outcome, a note, an optional follow-up and
  an optional lead status, and can create a lead for an unknown number.
- On Calls and WhatsApp, an Outcome column shows the outcome in its colour,
  the note and the follow-up, with Add Outcome or Change; the same window sets
  everything the phone can. A filter shows calls by outcome, or with none yet.
- An outcome can move the lead to a status; Converted either tells managers or
  moves the lead to a converted status (Settings > Outcomes).
- Every outcome, status change and reminder is written to the lead's own
  activity log under the name of whoever set it.

## Follow-ups

Due (overdue and today), Upcoming and Done (somebody has since had a connected
call with the number). Every follow-up is also a native Perfex reminder on the
lead or customer, so Perfex notifies, and if set emails, the rep.

## Missed Calls

- Open, Overdue and Returned (last 7 days), with how many times the number was
  called back and who returned it.
- Tiles: open, overdue, returned today, average callback time.
- A call joins the queue when it is missed or rejected (and missed WhatsApp
  calls, if set). Any connected call with the number, by anyone, clears it;
  Mark Returned clears it by hand.
- Return-by times count working hours only. Past them, Perfex's cron escalates
  to team leads or managers, by notification and, if set, email.
- Calls also has Never Attended (missed and never returned) and Never Received
  (outgoing calls to numbers that have never connected) filters.

## Leads from calls (automatic)

Settings > Leads From Calls can create leads automatically for numbers not in
the CRM: incoming, outgoing or both, lasting at least a set number of seconds
(never shorter than the connected threshold), WhatsApp calls too if wanted,
optionally only inside working hours, and never for history imported at
pairing unless asked. Every earlier call with the number links to the new
lead. Last Contact on a lead follows its latest connected call.

## Calls tab on leads and customers

The lead window and the customer profile each gain a Calls tab: calls, talk
time and last call, then every call, WhatsApp call and SMS the viewer may see,
with outcomes and notes, recordings playable in place, and Call buttons for
the lead's number or the customer's contacts. The customer tab follows the
customer visibility setting.

## Click to call

With Settings > Click To Call on, Call buttons appear on Calls and WhatsApp
rows, Missed Calls, Follow-ups and the Calls tabs for anyone with a paired
phone. A click makes their own phone dial. With a Firebase service account key
saved, the request arrives in a second; without one, at the phone's next
check-in if that is within two minutes.

## Reports

A Reports tab with eleven reports, each over Today, Yesterday, 7 Days, 30 Days,
This Month, Last Month or a custom period of up to a year, for a team or one
person, scoped like everything else:

| Report | Shows |
| --- | --- |
| Team Summary | Per rep: calls in and out, connected and connect rate, talk time, average call, missed, unique clients, WhatsApp, SMS, first and last call, call target reached |
| Daily Activity | Calls per rep per day (per week beyond a month) |
| Missed Calls And Callbacks | Missed, returned, returned on time, still open, escalated, average callback time |
| Call Duration | Connected calls in length bands, average and longest |
| Outcomes | Calls per outcome per rep, and connected calls with none yet |
| Speed To Lead | For leads created in the period: called within 5 minutes, an hour, the same day, later or not yet, and the median wait, by assignee |
| Lead Engagement | Per lead status: leads, leads called, calls, connected, talk time, and open leads quiet for 14 days or more |
| Conversion | Leads each rep spoke to, Converted outcomes, leads converted in Perfex, conversion rate, and paid invoices from those customers (for people who may see customers and invoices) |
| Recordings | Answered calls, recorded, share recorded, waiting, recorded time, storage |
| SMS | Received, sent, unique numbers, numbers in the CRM |
| Phone Health | Per phone: state, app version, last seen, syncs, refused events, missing permissions, alerts |

Every report has a totals row where it makes sense, exports to CSV or Excel
exactly as shown, and prints without the menus.

## Email reports

Settings > Email Reports sends a daily report at a set time, a weekly report
on a set day and a monthly report on the 1st, through Perfex's own email
settings: managers get everybody, team leads their team, and each rep their own
(switchable). Empty reports are skipped. Preview Today's Report shows the email
in the browser; Send It To Me Now checks the mail settings.

## Recording storage

Settings > Recording Storage chooses this server or Google Drive. On Drive,
recordings upload within minutes into Sales Track / year / month / rep in the
connected Workspace account, are checked byte for byte, and leave this server
after the days set; they still play inside the CRM, with seeking, for exactly
the people allowed to play them. Server recordings can be deleted after a set
number of days. Downloads are for managers unless opened to everyone who can
play. Lists show which recordings are on Drive.

## Best Pitches

A library of calls worth learning from, open to everybody who uses Sales Track:
category filter, why each is worth hearing, and moments that play the
recording from that second. Managers with Manage Best Pitches add calls with
the star on Calls and Recordings; reps can star their own calls to nominate
them, and managers approve or decline the nominations at the top of the page.
Best Pitches are never deleted by retention.

## Listening log

Every play and download is written to Perfex's activity log, and the Recording
Access report lists who heard which call, for managers.

## AI insights (Gemini)

With Settings > AI (Gemini) switched on and a key saved, recorded calls are
analysed automatically by the rule set there (calls with CRM numbers by
default, at least a minute long, at most twenty), and managers and team leads
can analyse any call by hand. Each analysis gives the transcript, a summary,
the customer's sentiment, how hot the lead is, objections, next steps, a score
card from your own criteria and flags for competitors, discount or price
promises, abusive language and watched words. Calls and Recordings gain an AI
column; the Insights window shows everything and offers the AI's suggested
outcome for a person to accept. Flagged calls alert the people chosen under
Alerts; team leads receive weekly coaching notes for each rep; the AI Insights
report summarises it all. Spending is tracked per call and stops at the
monthly budget. Only the call itself and the module's own lists are sent to
Google, never lead or customer details.

## Call lists

Managers and team leads build a call list from lead filters (status, source,
owner, not contacted for a number of days, created between, open leads only),
see how many leads match, and share them among reps evenly or by owner. Reps
see their own leads on the Call Lists tab and in the app, with Call buttons
and Skip; each lead moves on by itself when a call with it syncs (to call,
not reached, reached). Progress bars and figures follow the real calls.

## Do not call

Numbers on the do-not-call list (Settings > Privacy, or the button on a call
list) get no Call buttons, never land on a call list, are refused by
click-to-call, and reach the phones as hashes so the app can warn before
dialling. Calls from them are still tracked.

## Caller popup

Phones recognise callers from a directory the CRM sends: leads (all or each
rep's own), customers and contacts (by the customer names rule, everyone or
nobody), colleagues and extra entries such as suppliers. The popup shows the
name, company, lead status, owner, last call and outcome, last note and the
next follow-up, on incoming and outgoing calls, and works without signal from
the phone's encrypted copy.

## Wallboard

A dark, large, self-refreshing screen of today's calls, connected calls, talk
time, missed calls, calls to return, the leaderboard with targets and the
latest calls: rep names and figures only. Managers and team leads open it from
the Dashboard; a secret link (off by default, renewable) lets a screen that is
not signed in show it.

## Customers

Settings > General decides whether numbers are matched to customers at all (off
for CRMs run on leads alone) and who sees customer names: managers, anyone with
Perfex customer access, or everybody. Others see the lead behind the number, or
only that it is in the CRM. A customer number also shows the lead behind it,
with its status.

## Devices

- **Add Device**: name, description, the staff member it belongs to, SIM number
  and asset tag. The window then shows the 6-digit code, a QR code and the
  server address, counts down, and notices the moment the phone pairs.
- A card per device: state (Waiting For Phone, Online, Idle, Offline, Paused,
  Revoked), owner, phone, app version, last sync, records, battery, missing
  permissions. Each card opens the device page.
- Load or remove demo data (administrators).

## Device page

- The live pairing code and QR, shown again until used; **Regenerate Code**
  swaps the handset while keeping the device's history.
- Overview: owner, phone, system, app version, SIM number, SIM tracked, asset
  tag, paired, last seen, last sync, added, last address.
- Health: each permission granted or missing, battery, network, waiting to
  sync, recordings waiting, last error.
- Activity: calls, WhatsApp calls and SMS today and over seven days.
- Commands: Sync Now and Re-check Permissions, with their delivery state.
- Sync history: the last thirty syncs with stored, duplicates, skipped and
  rejected counts.
- Edit (name, description, owner, SIM number, asset tag, SIM tracked), Pause or
  Resume, Revoke, Delete.
- Banners when the device is paused or its app is older than the minimum.
- Alerts: call logs or SMS deleted before sync, the clock changed, the app
  reset, a lost permission, or the phone silent in working hours.
- Push: whether the phone has registered for Firebase messages, and Send Test
  Push to check the whole chain.

## Settings

A section menu: General, Tracking, Privacy, Recordings, Devices And App. Every
setting, its default and what it does is in SETTINGS.md, generated from the
schema. Highlights: the connected threshold, targets (working days, daily
calls, connected calls and talk time, per-person overrides), leaving calls
between staff out of analytics, one phone per staff member,
revoke on deactivation, minimum app version with store links, and App Lock with
a write-only PIN.

## Permissions (Setup > Staff > Roles > Sales Track)

| Capability | Allows |
| --- | --- |
| View Own Activity | Your own records, My Dashboard, your own device page |
| View Team Activity | The records, dashboard and devices of everybody sharing a Perfex department with you |
| View All Activity | Everybody's records and devices |
| Play Recordings | Listening to and downloading recordings you can see |
| Manage Devices | Add, edit, pair, regenerate, pause, revoke and delete devices; send commands |
| Delete Activity | Deleting records and their recordings |

Settings follow Perfex's own settings permission. Administrators have
everything.
