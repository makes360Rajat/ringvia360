# MKS Sales Track - Developer Guide

## House rules

- No Perfex core file is ever modified. Hooks, filters and module files only.
- No code shared with another MKS module.
- Complete replacement files on delivery, never diffs.
- Plain hyphens only, no em or en dashes, comments included.
- No left border accent bars. Font Awesome 6 solid and brands names only, and
  only names listed in the gate (verified against Perfex's FA 6.2.0).
- Prefixes: tables `tblmks_sales_track_*`, CSS `mks-sales-track-*`, options
  `mks_sales_track_*`, PHP functions `mks_st_*`, language keys `mks_st_*`.
- Timestamps with PHP `date()`, never SQL `NOW()`.
- Options through `mks_st_option_put()`, never `update_option(..., 1)`.
- One sidebar item only; new pages go in the tab bar.

## Test environment

Built and tested on Ubuntu 24.04 with PHP 8.3.6 and MariaDB 10.11.

```
apt-get install -y php8.3-cli php8.3-mysql php8.3-mbstring php8.3-gd php8.3-curl \
  php8.3-xml php8.3-zip php8.3-intl php8.3-bcmath mariadb-server
setsid nohup mariadbd --user=mysql --skip-grant-tables --skip-networking &
```

Install Perfex 3.4.1 by hand: import `install/database.sql`, insert an admin
into `tblstaff` with a phpass hash, copy `app-config-sample.php` to
`app-config.php` with the base URL, database and an encryption key, and move
the install folder away. Serve it with PHP's built in server and a router that
sends everything that is not a file to `index.php`, and answers 403 for upload
folders holding a Deny from all `.htaccess`, to mirror Apache or LiteSpeed.
Set `ENVIRONMENT` to `development` in `index.php` so PHP notices show.

## Tooling

| Command | What it does |
| --- | --- |
| `php tooling/gates.php` | 132 static and behavioural gates. Must pass before every release, inside the extracted ZIP |
| `php -S 127.0.0.1:8090 tooling/fake_google.php` | A stand-in for Google's OAuth, Drive, FCM and Gemini endpoints. Point a test CRM at it with `define('MKS_ST_GOOGLE_BASE', 'http://127.0.0.1:8090');` in its app-config.php; authorisation codes must be `good-code`, the Gemini key `good-gemini-key` |
| `php tooling/e2e.php --url= --email= --password=` | 54 checks against a running CRM: every screen, every report and both exports, the email preview, the dashboard's charts and filters, the callback queue, outcomes, push registration, click-to-call, Add Device, pairing, commands, sync, retries, pause, recordings, streaming, handset swap, revoke. Cleans up after itself |
| `php tooling/phone.php <command> --url=` | A simulated phone: ping, pair, config (with --ack), sync, record |
| `php tooling/settings_doc.php` | Regenerates docs/SETTINGS.md from the schema (`--check` for the gates) |

All three refuse to run over the web and `tooling/` carries Deny from all.

## Adding a list column

Add it to `mks_st_view_columns()` with `select`, optional `search`, and the
sortable and searchable flags, then a case in `mks_st_render_cell()`. The
table endpoint, the script's column flags and the tile search all follow from
that one definition.

## Adding a setting

1. Add it to `config/settings_schema.php`: section, type, default, label and
   hint language keys, `since`, and `'app' => true` if phones receive it. The
   page renders it and saving cleans it with no other change.
2. Add its strings to the language file.
3. If phones need it, add it to `mks_st_device_config()` and to API.md.
4. `php tooling/settings_doc.php` to regenerate docs/SETTINGS.md.
5. Bump `MKS_SALES_TRACK_SCHEMA_REV` so the installer seeds it on upgrade.

A new section is one entry in the schema's `sections`; a new tab in the module
is one entry in `mks_st_nav_items()`.

## Adding an API field

Validate it in `mks_st_ingest()` (or `mks_st_device_report()` for health),
store it, and document it in `docs/API.md` in the same change.

## Release

1. Bump the `Version:` header and `MKS_SALES_TRACK_VERSION` together. Keep
   minor and patch single digit (1.0.9 is the last before 1.1.0).
2. Rename the single migration to the new number and its class to match.
3. Bump `MKS_SALES_TRACK_SCHEMA_REV` if the installer learned anything.
4. `php tooling/gates.php`, then `php tooling/e2e.php` against staging.
5. ZIP with a top level `mks_sales_track/` folder, extract it fresh and run
   the gates inside the extract.
6. Update CHANGELOG.md, HANDOVER.md and any document the change touches.
