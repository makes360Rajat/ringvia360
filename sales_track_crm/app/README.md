# Sales Track CRM

A Flutter/Dart mobile companion for sales-call tracking. It pairs with a Sales
Track backend, guides first-time setup, records call outcomes, and keeps local
telemetry ready to sync when connectivity is available.

## Run

```bash
flutter pub get
flutter run
```

## Verify

```bash
flutter test
```

## Included capabilities

- Secure device pairing and first-run setup
- Call outcome capture and contact lookup
- Local SQLite storage for offline resilience
- Background telemetry synchronization
- Optional application lock protection

The application source is in `lib/`; Android, iOS, web, macOS, Linux, and
Windows runners are included.
