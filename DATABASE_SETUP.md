# Database setup

The Hostinger database is empty, as shown in the supplied screenshot. Deploy the `api/` directory (or the contents of `web/public/api/` with the web build) and then open:

`https://ringvia360.com/api/setup_db.php`

The one-time initializer connects to `u488332847_dn_name`, creates all application tables, and seeds the current site sections and application data. It is safe to run again because it uses `CREATE TABLE IF NOT EXISTS` and only seeds empty tables.

After it reports **MySQL** and non-zero table counts, open the site. The frontend reads editable text and structured page content from `site_pages` through `/api/pages.php?action=all`. The Super Admin content editor writes back to that same table.

Do not upload the database password to the frontend. It is used only by the PHP API connection files.
