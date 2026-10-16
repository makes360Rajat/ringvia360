# MKS Sales Track - Gotchas

Each of these cost time on this module or a sibling. The ones marked
[this build] were found while writing Sales Track.

## Perfex and CodeIgniter

- [this build] **`update_option($name, $value, 1)` creates a missing option
  with autoload off.** Core does `add_option($name, $value, $autoload === null
  ? 1 : 0)`, and `get_option()` queries the database every time for an option
  that is not autoloaded. Use `mks_st_option_put()`. Sibling modules that seed
  their schema revision this way pay one extra query per admin page.
- [this build] **`get_option()` keeps serving the value autoloaded at the start
  of the request**, so reading settings back right after saving them returns
  the old ones. `mks_st_save_settings()` replaces the cached copy directly.
- [this build] **`_l()` always runs `sprintf()`.** A string with `%s` called
  without a value loses its placeholder, so a script can never fill it in.
  Strings handed to JavaScript use named placeholders: `_l('key', '{t}')`.
  Literal per cent signs are `%%`.
- [this build] **A settings form with no `settings[]` field** makes
  `Settings_model::update()` walk a missing array key and never show Settings
  Updated. The form posts `settings[mks_sales_track_saved_at]`.
- **Fields outside `settings[]` need a form present marker**, or saving any
  other settings tab clears them.
- **An unticked checkbox posts nothing.** A hidden 0 goes before each checkbox;
  PHP keeps the last value posted under a name.
- [this build] **Perfex autoloads the session driver, database backed by
  default.** Every request without the session cookie writes a new
  `tblsessions` row, so the apps must keep their cookies.
- [this build] **The database session holds a lock for the whole request.** A
  long recording stream froze every other request from the same browser until
  `session_write_close()` was called before streaming.
- **JSON bodies never reach `$_POST`.** The API reads `php://input`.
- **Shared hosting can strip `Authorization`.** The token is also accepted from
  `X-Sales-Track-Token` and from the body.
- [this build] **Over `post_max_size` PHP discards the whole body**, token
  included. The recording endpoint compares `Content-Length` first and says
  `file_too_large` instead of an unhelpful 401.
- **`db_debug` turns any SQL error into an HTML page.** It is off in the API
  controller, which checks results itself.
- **`get_staff_user_id()` is empty on the API.** The device row says who is
  acting; `log_activity()` is given the staff id explicitly.
- **Module CSRF exemptions** go in `config/csrf_exclude_uris.php`, which core's
  InitModules hook merges. No buyer edits `config.php`.
- **`data_tables_init()` runs `SHOW COLUMNS` per draw** for a qualified column
  without an alias, and searches every `additionalSelect` column. Every column
  here is aliased and nothing is added to `additionalSelect`; cells come from a
  second query by id.
- **`initDataTable()` wants a flat `[index, 'desc']`.** A nested pair is wrapped
  again and silently ignored.
- **`[hidden]` is overridden** by Perfex's CSS. Hide with the module's class.
- **Content after `#wrapper > .content` closes is never rendered**, including a
  fixed position player.
- **Perfex's tailwind.css is precompiled.** New `tw-` classes do nothing.
- **The bundled Chart.js is 2.4.0.** Phase 2 charts will be server side SVG.
- **Perfex removes the module folder on uninstall.** Recordings live in
  `uploads/mks_sales_track/` so they survive it.

- [this build, 1.1.0] **CodeIgniter's `field_data()` does not report
  nullability.** The installer reads `SHOW COLUMNS` to decide whether a column
  still needs `MODIFY ... DEFAULT NULL`.
- [this build, 1.1.0] **Perfex shows one flash alert per type.** Several
  warnings from one save are joined into a single message.
- [this build, 1.1.0] **Core's staff Active toggle only acts on AJAX
  requests** (`admin/staff/change_staff_status`). Tests that skip the
  `X-Requested-With` header change nothing.
- [this build, 1.1.0] **A settings group can hide Perfex's Save button** with
  `'without_submit_button' => true`, which the link-only Setup > Settings entry
  uses.
- [this build, 1.1.0] **A pairing code is shown once unless it is kept.** Codes
  are stored hashed for checking and encrypted with the CRM's own key so the
  device page can show a live code again.

- [this build, 1.4.0] **CodeIgniter's query builder is one shared object.**
  A helper that runs its own query between `where()` and `update()` (a name
  lookup inside the update array, say) consumes the half-built conditions.
  Compute every value first, then build the query.
- [this build, 1.4.0] **Notifications and lead activity are language keys.**
  Core renders them with `_l($description, unserialize($additional_data))`;
  a plain sentence works but logs "Could not find the language line" every
  time it is shown.
- [this build, 1.4.0] **The settings page posts every section at once.** A
  hand-made POST with only some fields turns every missing switch off,
  including the master switch.

- [this build, 1.6.0] **PHP turns a response with a Location header into a
  302** unless the status code is set after the header. The Google stand-in
  sets headers first; Google's own resumable upload start answers 200 with a
  Location.
- [this build, 1.6.0] **The resumable upload PUT carries the bearer token
  too.** Google accepts it, and some proxies refuse a session URI without it.
- [this build, 1.6.0] **A test script that checks whether a server is running
  with `pgrep -f "<address>"` matches its own command line.** Probe the port
  instead.

- [this build, 1.7.0] **Gemini 2.5 Flash thinks by default, and thinking is
  billed as output.** The request sets `thinkingBudget: 0` for that model; a
  transcript gains nothing from it.
- [this build, 1.7.0] **Weekly schedules run on the CRM's timezone.** A test
  that works out "today" from the container's clock can pick the wrong day.

- [this build, 1.7.0] **Perfex's server-side DataTables code reads one posted
  `columns[]` entry per server column when searching.** A test request that
  posts fewer (the AI column makes Calls ten wide) logs warnings and breaks the
  JSON; browsers always post them all.

- [this build, 1.8.0] **PHP's array union keeps the left-hand value.**
  `$header + ['assign' => []] + $stored` silently drops the stored
  assignments. Merge stored values over defaults with array_merge.
- [this build, 1.8.0] **No window functions.** Perfex runs on MySQL 5.7 hosts
  too; ROW_NUMBER() would fail there. Take the latest row by MAX(id) and join.
- [this build, 1.8.0] **Demo data must never be dated in the future.** Loaded
  before 09:30, "today" has no calls yet.

## Phones

- Android 10 and later: an ordinary app cannot capture call audio. Recordings
  come from the dialer's own recorder, and Google's Phone app keeps its files
  private.
- Google Play restricts call log and SMS permissions to declared, reviewed
  uses.
- WhatsApp has no call history API; its call notifications are the only
  source, their wording varies by version and language, and WhatsApp calls are
  never recorded.
- RCS chats in Google Messages are not in the SMS provider.
- iOS exposes no call history, SMS, other apps' notifications or recordings.
