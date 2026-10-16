# Sales Track - Settings Reference

Generated from `config/settings_schema.php` by `php tooling/settings_doc.php`.
Do not edit by hand: change the schema and regenerate. The gates fail when
this file and the schema disagree.

Settings live on Sales Track > Settings, stored as one autoloaded JSON option
(`mks_sales_track_settings`). "Phones" marks settings sent to every paired
phone through the config call.

## General

The master switch, and how numbers are read and matched to leads, customers and staff.

| Setting | Key | Type | Default | Phones | Since | What it does |
| --- | --- | --- | --- | --- | --- | --- |
| Enable Sales Track | `enabled` | switch | On |  | 1.0.0 | The master switch. Off hides every page except this one and refuses every phone, without deleting anything. |
| Show In Sidebar | `sidebar` | switch | On |  | 1.0.0 | The single Sales Track item in the main navigation, directly under Leads. |
| Default Country Code | `country_code` | text (digits) | 91 | Yes | 1.0.0 | Completes numbers saved without one, so 98140 00002 reads as +91 98140 00002. |
| Match Numbers On The Last | `match_digits` | number 6-15 digits | 10 | Yes | 1.0.0 | Numbers are matched on their last digits, so spacing, dashes and country codes never stop a match. Ten suits Indian mobiles. A change applies to new records. |
| A Call Counts As Connected From | `connected_seconds` | number 0-120 seconds | 5 |  | 1.1.0 | Shorter calls count as not answered in every tile, filter and report. |
| Match Numbers To Customers | `match_customers` | switch | On |  | 1.3.0 | Off for a CRM run on leads alone: numbers are then matched to leads and staff only, and customers are never shown. |
| Who Sees Customer Names | `customer_visibility` | choice: managers, customer_access, everyone | managers |  | 1.3.0 | Others see the lead behind the number, or just that it is in the CRM. |
| Leave Calls Between Staff Out Of Analytics | `exclude_internal` | switch | On |  | 1.2.0 | Calls with a colleague's number stay in the lists but are not counted on the dashboard, leaderboard or targets. |
| Delete All Sales Track Data On Uninstall | `purge_on_uninstall` | switch | Off |  | 1.0.0 | Off by default. When on, uninstalling the module deletes both tables, every recording and these settings. Deactivating never deletes anything. |

## Tracking

What the phones collect. A tracker switched off here is neither collected by the phones nor accepted by the server.

| Setting | Key | Type | Default | Phones | Since | What it does |
| --- | --- | --- | --- | --- | --- | --- |
| Phone Calls | `track_calls` | switch | On | Yes | 1.0.0 | Incoming, outgoing, missed and rejected calls from the phone's call log, with their duration and SIM. |
| Call Recordings | `track_recordings` | switch | On | Yes | 1.0.0 | Uploads the recording the phone's own dialer saved. Phones whose dialer keeps recordings private cannot provide them. |
| WhatsApp Calls | `track_whatsapp_calls` | switch | On | Yes | 1.0.0 | WhatsApp and WhatsApp Business calls, read from their call notifications. Needs notification access on the phone; nothing else is read or stored, and WhatsApp calls are never recorded. |
| SMS | `track_sms` | switch | On | Yes | 1.0.0 | Text messages sent and received. What happens to the text is set under Privacy. |
| History To Import On Pairing | `history_days` | number 0-90 days | 7 | Yes | 1.0.0 | Days of call log and SMS a newly paired phone sends once. 0 starts from the moment of pairing. |

## Outcomes

What the app asks after a call, and what each answer does. Converted is fixed; every other outcome is yours to add, rename, colour or switch off.

| Setting | Key | Type | Default | Phones | Since | What it does |
| --- | --- | --- | --- | --- | --- | --- |
| Outcome List | `outcomes` | outcomes | Interested, Call Back, Not Interested, Wrong Number, No Answer, Converted | Yes | 1.3.0 | Fill an empty row to add an outcome. "Asks Follow-up" suggests a follow-up date; "Sets Lead Status" moves the lead when the outcome is chosen. |
| Ask After | `outcome_ask` | choice: connected, connected_only, all | connected | Yes | 1.3.0 | Which calls the app asks about once they end. |
| Outcome Required | `outcome_mandatory` | switch | Off | Yes | 1.3.0 | Off lets reps skip the popup; skipped calls wait in the app until answered. |
| Note Required | `note_required` | switch | Off | Yes | 1.3.0 | Every outcome must come with a note. |
| When A Call Is Marked Converted | `converted_action` | choice: review, status | review |  | 1.3.0 | Choose by how this CRM uses customers. |
| Converted Status | `converted_status` | lead_status | (Perfex default) |  | 1.3.0 | Used when converted leads only change status. Perfex default is the status Perfex gives converted leads. |

## Leads From Calls

How leads created from calls are set up, and how follow-up reminders are sent.

| Setting | Key | Type | Default | Phones | Since | What it does |
| --- | --- | --- | --- | --- | --- | --- |
| Create Leads From The Phone | `lead_create_phone` | switch | On | Yes | 1.3.0 | The after-call popup offers Create Lead for numbers not in the CRM. |
| Status For New Leads | `lead_status` | lead_status | (Perfex default) |  | 1.3.0 | Perfex default uses Setup > Leads > Default status. |
| Source For New Leads | `lead_source` | lead_source | (Perfex default) |  | 1.3.0 | Perfex default uses Setup > Leads > Default source. |
| Assign New Leads To | `lead_assign` | choice: handler, fixed, none | handler |  | 1.3.0 | Who a lead created from a call is assigned to. |
| That Person | `lead_assign_staff` | staff | (none) |  | 1.3.0 | Used when new leads go to one person. |
| Create Leads Automatically | `auto_lead` | switch | Off |  | 1.4.0 | A call with a number not in the CRM becomes a lead by the rules below, set up like a lead created from the phone. |
| For Calls | `auto_lead_direction` | choice: both, incoming, outgoing | both |  | 1.4.0 | Which calls may create a lead. |
| Lasting At Least | `auto_lead_min_seconds` | number 0-600 seconds | 30 |  | 1.4.0 | Shorter calls never create a lead; neither does a call shorter than the connected threshold. |
| WhatsApp Calls Too | `auto_lead_whatsapp` | switch | On |  | 1.4.0 | Connected WhatsApp calls follow the same rules. |
| Working Hours Only | `auto_lead_working_hours` | switch | Off |  | 1.4.0 | Calls outside working hours (Settings > Missed Calls) never create a lead. |
| Include History Imported At Pairing | `auto_lead_history` | switch | Off |  | 1.4.0 | Off: calls from before a phone paired never create leads, so pairing does not flood the CRM. |
| Update Last Contact | `update_last_contact` | switch | On |  | 1.4.0 | Every connected call moves the lead's Last Contact forward, never back. |
| Calls Tab On Leads And Customers | `crm_tabs` | switch | On |  | 1.4.0 | Each lead window and customer profile lists the calls, WhatsApp calls and SMS with them, by the same visibility rules. |
| Email Follow-up Reminders | `follow_up_email` | switch | On |  | 1.3.0 | Perfex also emails the rep when a follow-up reminder is due. |

## Missed Calls

The callback queue: how soon a missed call must be returned, counted in working hours, and who hears when it is not.

| Setting | Key | Type | Default | Phones | Since | What it does |
| --- | --- | --- | --- | --- | --- | --- |
| Return Missed Calls Within | `callback_minutes` | number 5-1440 minutes | 30 |  | 1.3.0 | Counted in working hours only, so a call missed overnight is due the next morning. |
| Working Day Starts | `work_start` | time | 09:30 |  | 1.3.0 | On the working days chosen under Targets. |
| Working Day Ends | `work_end` | time | 18:30 |  | 1.3.0 | Also bounds the silent phone alert. |
| Queue Missed WhatsApp Calls | `callback_whatsapp` | switch | On |  | 1.3.0 | Missed WhatsApp and WhatsApp Business calls join the queue too. |
| Escalate Overdue Calls | `escalate` | switch | On |  | 1.3.0 | Tell someone when a missed call is past its time. Runs with Perfex's cron. |
| Escalate To | `escalate_to` | choice: team_leads, managers, both | team_leads |  | 1.3.0 | Team leads are people with View Team Activity in the rep's department; without one, managers are told. |
| Escalation Emails | `escalate_email` | switch | On |  | 1.3.0 | Also email them, through the CRM's own SMTP. |

## Targets

Daily targets for every rep, counted on working days only. Leave a person's boxes empty to use the defaults.

| Setting | Key | Type | Default | Phones | Since | What it does |
| --- | --- | --- | --- | --- | --- | --- |
| Working Days | `working_days` | days | Mon, Tue, Wed, Thu, Fri |  | 1.2.0 | Targets apply on these days only; a period with none shows no target. |
| Calls | `target_calls` | number 0-500 per day | 0 |  | 1.2.0 | Calls each rep should make or take per working day. 0 means no target. |
| Connected Calls | `target_connected` | number 0-500 per day | 0 |  | 1.2.0 | Calls that reach the connected threshold, per working day. 0 means no target. |
| Talk Time | `target_talk_minutes` | number 0-600 minutes per day | 0 |  | 1.2.0 | Minutes on the phone per working day. 0 means no target. |
| Targets Per Person | `target_overrides` | staff_targets | (none) |  | 1.2.0 | Overrides for individual reps. An empty box uses the default shown in it. |

## Alerts

Who is told when a phone is tampered with, loses a permission or goes quiet.

| Setting | Key | Type | Default | Phones | Since | What it does |
| --- | --- | --- | --- | --- | --- | --- |
| Tampering | `alert_tamper` | switch | On |  | 1.3.0 | Call logs or SMS deleted before they synced, the clock changed, or the app reset. |
| Lost Permissions | `alert_permissions` | switch | On |  | 1.3.0 | A permission the app needs is switched off on the phone. |
| Silent Phone After | `alert_silent_hours` | number 0-24 hours | 2 |  | 1.3.0 | Hours without a heartbeat inside working hours before someone is told. 0 switches it off. |
| Tell | `alert_to` | choice: team_leads, managers, both | managers |  | 1.3.0 | At most once every six hours per phone and alert. |
| Alert Emails | `alert_email` | switch | Off |  | 1.3.0 | Also email them, through the CRM's own SMTP. |

## Click To Call

Call buttons in the CRM make the rep's own company phone dial. Firebase Cloud Messaging delivers the request at once; without it the phone only learns of it at its next check-in.

| Setting | Key | Type | Default | Phones | Since | What it does |
| --- | --- | --- | --- | --- | --- | --- |
| Click To Call | `click_to_call` | switch | Off | Yes | 1.4.0 | Shows Call buttons on the lists, Missed Calls, Follow-ups and the Calls tabs, for staff with a paired phone. |
| Ask Before Dialling | `dial_confirm` | switch | Off | Yes | 1.4.0 | Off: the phone dials at once. On: the phone shows the number and waits for a tap. |
| Firebase Service Account Key | `fcm_key` | secret_json | (none) |  | 1.4.0 | From Firebase console > Project settings > Service accounts > Generate new private key. Kept encrypted, never shown again. The app must be built with the same Firebase project. |

## Email Reports

Reports emailed through the CRM's own SMTP: managers see everybody, team leads their team, and each rep their own day.

| Setting | Key | Type | Default | Phones | Since | What it does |
| --- | --- | --- | --- | --- | --- | --- |
| Daily Report | `report_daily` | switch | On |  | 1.5.0 | The day's calls, talk time and callbacks, every day. |
| Daily Report At | `report_daily_time` | time | 19:00 |  | 1.5.0 | Sent by Perfex's cron, at the first run after this time. |
| Weekly Report | `report_weekly` | switch | On |  | 1.5.0 | The seven days before the day it is sent. |
| Weekly Report On | `report_weekly_day` | choice: mon, tue, wed, thu, fri, sat, sun | mon |  | 1.5.0 | The day of the week it goes out. |
| Weekly Report At | `report_weekly_time` | time | 09:00 |  | 1.5.0 | Sent by Perfex's cron, at the first run after this time. |
| Monthly Report | `report_monthly` | switch | On |  | 1.5.0 | The month before, sent on the 1st. |
| Monthly Report At | `report_monthly_time` | time | 09:00 |  | 1.5.0 | Sent by Perfex's cron, at the first run after this time. |
| Send To | `report_to` | choice: both, managers, team_leads | both |  | 1.5.0 | Who receives the team reports. |
| Each Rep Gets Their Own | `report_reps` | switch | On |  | 1.5.0 | Every rep with a phone receives a report of their own activity. |
| Skip Empty Reports | `report_skip_empty` | switch | On |  | 1.5.0 | No email when there was no activity to report. |

## Recording Storage

Where recordings are kept, for how long, who may download them, and the Best Pitches library.

| Setting | Key | Type | Default | Phones | Since | What it does |
| --- | --- | --- | --- | --- | --- | --- |
| Keep Recordings On | `storage_mode` | choice: server, drive | server |  | 1.6.0 | Google Drive moves them off this server once uploaded; they still play inside the CRM. |
| Delete Server Recordings After | `recording_keep_days` | number 0-3650 days | 90 |  | 1.6.0 | Recordings kept on this server are deleted this many days after the call; 0 keeps them forever. Best Pitches and recordings on Drive are never deleted. |
| Google OAuth Client ID | `drive_client_id` | text | (none) |  | 1.6.0 | From Google Cloud Console > APIs & Services > Credentials: an OAuth client of type Web application, with the redirect address below. Enable the Google Drive API in the same project. |
| Google OAuth Client Secret | `drive_client_secret` | secret | (none) |  | 1.6.0 | Kept encrypted, never shown again. |
| Drive Folder | `drive_folder` | text | Sales Track |  | 1.6.0 | Recordings go into this folder, then year, month and rep. |
| Keep A Server Copy For | `drive_keep_days` | number 0-90 days | 7 |  | 1.6.0 | Days after a verified upload before the server copy is deleted; 0 deletes it at once. |
| Who May Download | `recording_download` | choice: managers, play | managers |  | 1.6.0 | Playing follows Play Recordings; downloading can be narrower. |
| Log Who Listens | `audit_recordings` | switch | On |  | 1.6.0 | Every play and download goes to Perfex's activity log, and to the Recording Access report. |
| Reps Can Nominate Best Pitches | `pitch_nominate` | switch | On |  | 1.6.0 | Reps star their own calls for a manager to approve. |
| Best Pitch Categories | `pitch_categories` | textarea (lines) | Opening
Discovery
Objection Handling
Closing
Follow-up
Product Demo |  | 1.6.0 | One per line. |

## AI (Gemini)

Transcripts, summaries, scores, flags and coaching from Google Gemini, within a monthly budget.

| Setting | Key | Type | Default | Phones | Since | What it does |
| --- | --- | --- | --- | --- | --- | --- |
| AI Insights | `ai_enabled` | switch | Off |  | 1.7.0 | Adds an AI column to Calls and Recordings and the AI Insights report. |
| Gemini API Key | `gemini_key` | secret | (none) |  | 1.7.0 | From Google AI Studio. Kept encrypted, never shown again. |
| Model | `gemini_model` | text (model) | gemini-3.1-flash-lite |  | 1.7.0 | A Gemini model that accepts audio. Keep the prices below in line with the model you choose. |
| Analyse Automatically | `ai_auto` | choice: crm, all, manual | crm |  | 1.7.0 | Which recorded calls are sent without anyone asking. Managers can always analyse a call by hand. |
| Calls Lasting At Least | `ai_min_seconds` | number 0-3600 seconds | 60 |  | 1.7.0 | Shorter calls are not analysed automatically. |
| Calls No Longer Than | `ai_max_minutes` | number 1-60 minutes | 20 |  | 1.7.0 | Longer calls are never sent. |
| Monthly Budget | `ai_budget` | number 0-10000 USD per month | 10 |  | 1.7.0 | Analysis stops for the month once this much has been spent; 0 stops it altogether. |
| Price: Audio Input | `ai_price_audio` | text (decimal) | 0.50 |  | 1.7.0 | US dollars per million tokens, from Google's pricing page for the model, used to track spending. |
| Price: Text Input | `ai_price_text` | text (decimal) | 0.25 |  | 1.7.0 | US dollars per million tokens, from Google's pricing page for the model, used to track spending. |
| Price: Output | `ai_price_output` | text (decimal) | 1.50 |  | 1.7.0 | US dollars per million tokens, from Google's pricing page for the model, used to track spending. |
| Score Card | `ai_rubric` | textarea (lines) | Greeted the customer and introduced themselves
Asked about the customer's needs
Explained the offer clearly
Handled objections calmly
Agreed a clear next step |  | 1.7.0 | One criterion per line. Each is marked 0, 1 or 2; the call's score is the share of marks earned. |
| Competitors | `ai_competitors` | textarea (lines) | (none) |  | 1.7.0 | One per line. Mentions are flagged. |
| Words To Watch | `ai_keywords` | textarea (lines) | (none) |  | 1.7.0 | One per line. Discount promises and abusive language are always watched. |
| Alert On Flags | `ai_alerts` | switch | On |  | 1.7.0 | Flagged calls notify the people chosen under Alerts. |
| Suggest Outcomes | `ai_suggest` | switch | On |  | 1.7.0 | For calls without an outcome, the AI suggests one for a person to confirm. |
| Reps See Their Own Insights | `ai_rep_view` | switch | On |  | 1.7.0 | Off: insights are for managers and team leads only. |
| Weekly Coaching Notes | `ai_coaching` | switch | On |  | 1.7.0 | Each rep's team lead receives coaching points from the week's analysed calls, on the weekly report's day and time. |

## Caller Popup

Who the phones recognise when a call comes in or goes out, and what the popup shows: name, company, lead status, owner, last call and outcome, last note and the next follow-up.

| Setting | Key | Type | Default | Phones | Since | What it does |
| --- | --- | --- | --- | --- | --- | --- |
| Caller Popup | `directory_enabled` | switch | On | Yes | 1.8.0 | Phones keep an encrypted copy of the directory below so the popup works without signal. |
| On Incoming Calls | `popup_incoming` | switch | On | Yes | 1.8.0 | Shows who is calling while the phone rings. |
| On Outgoing Calls | `popup_outgoing` | switch | On | Yes | 1.8.0 | Shows who the rep is calling as the call starts. |
| Leads | `directory_leads` | choice: all, own, none | all |  | 1.8.0 | Which leads each phone recognises. |
| Customers | `directory_customers` | choice: visible, all, none | visible |  | 1.8.0 | Customers and their contacts. |
| Colleagues | `directory_staff` | switch | On |  | 1.8.0 | Staff phone numbers from their Perfex profiles. |
| Extra Entries | `directory_extra` | textarea (lines) | (none) |  | 1.8.0 | One per line: number, name, label. For suppliers, partners and other numbers that are not in the CRM. |

## Wallboard

Today's figures and leaderboard for a screen on the sales floor. Rep names and figures only, never customers.

| Setting | Key | Type | Default | Phones | Since | What it does |
| --- | --- | --- | --- | --- | --- | --- |
| Secret Link | `wallboard_public` | switch | Off |  | 1.8.0 | Lets a screen that is not signed in show the board through a private link. |
| Refresh Every | `wallboard_refresh` | number 15-600 seconds | 60 |  | 1.8.0 | How often the board reloads itself. |

## Privacy

What is kept, and which numbers are never tracked.

| Setting | Key | Type | Default | Phones | Since | What it does |
| --- | --- | --- | --- | --- | --- | --- |
| SMS Text | `sms_text` | choice: all, crm, none | all | Yes | 1.0.0 | Who the message itself is kept for. The number, time and direction are always kept. |
| Excluded Numbers | `excluded_numbers` | textarea (numbers) | (none) | Yes | 1.0.0 | One per line. Calls, SMS and WhatsApp calls with these numbers are skipped on the phone and refused by the server. Phones receive them as salted hashes, never as numbers. |
| Do Not Call | `dnc_numbers` | textarea (numbers) | (none) | Yes | 1.8.0 | Numbers nobody should call: no Call buttons, never on a call list, and the app warns before dialling. Calls from them are still tracked. |

## Recordings

How call recordings travel from the phones.

| Setting | Key | Type | Default | Phones | Since | What it does |
| --- | --- | --- | --- | --- | --- | --- |
| Largest Recording Accepted | `recording_max_mb` | number 1-200 MB | 25 | Yes | 1.0.0 | This server currently accepts up to N MB, after PHP's own upload limits. |
| Upload Recordings On Wi-Fi Only | `recording_wifi_only` | switch | Off | Yes | 1.0.0 | Phones hold recordings until they are on Wi-Fi. Call details still sync at once. |

## Devices And App

Pairing, syncing, the app version in use and protection against the app being switched off.

| Setting | Key | Type | Default | Phones | Since | What it does |
| --- | --- | --- | --- | --- | --- | --- |
| Allow App Connections | `api_enabled` | switch | On |  | 1.0.0 | Off stops every phone from pairing and syncing until it is switched back on. Paired phones keep their pairing. |
| Sync Every | `sync_minutes` | number 5-240 minutes | 15 | Yes | 1.0.0 | How often phones send what they have collected. They also sync straight after each call. |
| Pairing Codes Expire After | `pair_minutes` | number 5-1440 minutes | 60 |  | 1.0.0 | Each code works once, within this time. A new code can be issued from the device page at any time. |
| One Phone Per Staff Member | `one_phone_per_staff` | switch | On |  | 1.1.0 | When a new phone pairs for someone, their other phones are revoked. |
| Revoke Phones Of Deactivated Staff | `revoke_on_deactivate` | switch | On |  | 1.1.0 | Deactivating or deleting a staff member cuts off their phones at once. Their records stay. |
| Minimum App Version | `min_app_version` | text (version) | (none) | Yes | 1.1.0 | Older app builds are told to update and cannot sync until they do. Leave empty to allow every version. |
| Android App Link | `app_url_android` | text (url) | (none) | Yes | 1.1.0 | Store links the app opens when it has to be updated. |
| iPhone App Link | `app_url_ios` | text (url) | (none) | Yes | 1.1.0 | Store links the app opens when it has to be updated. |
| App Lock | `app_lock_enabled` | switch | Off | Yes | 1.1.0 | The app asks for this PIN before it can be paused, unpaired or have its settings changed on the phone. |
| App Lock PIN | `app_lock_pin` | pin | (none) | Yes | 1.1.0 | 4 to 8 digits. Stored as a salted hash; phones receive only the hash. |
