# mobilePhoeWhtsapp - Communication Activity Synchronization App

An offline-first Android/Flutter telemetry synchronization application built in accordance with the Master Engineering Prompt for **mobilePhoneData**.

## Architecture & Core Features

1. **Dual Synchronization Engine**:
   - **Automatic Synchronization (Preferred)**: Background timer drains the local offline queue every 12 seconds and immediately flushes queued records upon network reconnection.
   - **Manual Synchronization (Fallback)**: "Sync Now" button providing real-time counters (`Pending`, `Uploading`, `Successful`, `Failed`).

2. **Permitted Android Telemetry Collection**:
   - **Real-Time Pre-Answer Ringing**: Dispatches `INCOMING_RINGING` events immediately when incoming calls begin ringing before they are answered or missed.
   - **Call Records & Audio Capture**: Direction (inbound, outbound, missed, rejected), duration, SIM slot, and SHA-256 recording integrity checksum.
   - **WhatsApp & WhatsApp Business Notification Streams**: Captured via Android's permitted `NotificationListenerService` (`com.whatsapp` and `com.whatsapp.w4b`).
   - **Carrier SMS**: Inbound and outbound message logs with SIM slot details.

3. **Offline-First Resilience**:
   - Every event is persisted first to local SQLite / SharedPreferences storage with status `SYNC_PENDING`.
   - Never depends on active internet connectivity to safely record an event.

4. **Telemetry Test Simulator**:
   - Interactive testing sandbox to trigger simulated pre-answer ringing, WhatsApp alerts, completed calls, and carrier SMS.
   - Toggle simulated offline mode to inspect offline queuing and automatic queue drainage upon reconnection.

## How to Run

```bash
# Navigate to the new app directory
cd mobile_phone_whatsapp

# Install dependencies
flutter pub get

# Run on Android device / emulator
flutter run

# Or run in Web mode for testing
flutter run -d chrome
```

## Backend Endpoint
Connected directly to the production backend:
`https://ringvia360.com/api/phone_whatsapp.php`
