# QueueLess

Context-aware restaurant waitlist system built with Flutter, Supabase Free, and Firebase Cloud Messaging on the Spark plan.

The repository has two Flutter entry points:

- `lib/main.dart` - customer application
- `lib/main_staff.dart` - staff web dashboard

## Demo mode

If Supabase build variables are omitted, both apps use an in-memory demo repository. Demo mode is visibly labelled in the UI and resets whenever the app restarts.

```powershell
flutter run -d chrome -t lib/main.dart
flutter run -d chrome -t lib/main_staff.dart
```

## Supabase setup

1. Create a Supabase Free project.
2. In **Authentication > Providers**, enable **Anonymous Sign-Ins**.
3. Open the SQL editor and run `supabase/migrations/202608100001_initial_schema.sql`.
4. Run `supabase/migrations/202608140002_context_and_qr.sql` to add context-event recording and secure QR arrival verification.
5. Run `supabase/migrations/202608140003_push_notifications.sql` to add safe FCM device registration.
6. Run `supabase/migrations/202608150004_seat_capacity.sql` to add live occupancy limits and departure tracking.
7. Run `supabase/seed.sql` and replace the sample venue coordinates before testing geofencing.
8. In **Authentication > Users**, create a staff email/password user.
9. Copy that user's UUID and run the `venue_staff` insert shown at the bottom of `supabase/seed.sql`.
10. Copy the project URL and publishable key from **Project Settings > API**.

Run the customer app with the real backend:

```powershell
flutter run -d chrome -t lib/main.dart `
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=YOUR_PUBLISHABLE_KEY
```

Run the staff dashboard:

```powershell
flutter run -d chrome -t lib/main_staff.dart `
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=YOUR_PUBLISHABLE_KEY
```

The seeded venue ID is the default. To use another venue, also supply:

```text
--dart-define=VENUE_ID=YOUR_VENUE_UUID
```

Never put a Supabase service-role key or Firebase service-account credential in Flutter. Only the public/publishable Supabase key belongs in the client build.

## Android setup on Windows

The Android SDK can be installed in any writable folder, including `C:\Android`. To enable Android builds:

1. Install Android Studio from <https://developer.android.com/studio>.
2. In its setup wizard, install the Android SDK.
3. Open **More Actions > SDK Manager > SDK Tools** and install:
   - Android SDK Command-line Tools (latest)
   - Android SDK Platform-Tools
   - Android SDK Build-Tools
4. In **SDK Platforms**, install one current Android SDK platform.
5. Close and reopen the terminal, then run:

```powershell
flutter config --android-sdk "C:\Android"
flutter doctor --android-licenses
flutter doctor -v
```

Accept every Android license. When `flutter doctor -v` shows a check mark for **Android toolchain**, the project can be verified with:

```powershell
flutter build apk --debug -t lib/main.dart
```

Visual Studio is not required for Android or web; Flutter Doctor only requests it for Windows desktop builds.

## Run on a physical Android phone

1. On the phone, open **Settings > About phone** and tap **Build number** seven times.
2. Open **Developer options** and enable **USB debugging**.
3. Connect the phone by USB and accept the phone's RSA/debugging prompt.
4. From the project root, confirm that Flutter can see it:

```powershell
cd C:\MobileComputing\queueless
flutter devices
```

5. Copy the Android device ID shown by that command and run the customer app with the real backend:

```powershell
flutter run -d YOUR_DEVICE_ID -t lib/main.dart `
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=YOUR_PUBLISHABLE_KEY
```

6. Join the queue, open the active ticket, and enable **Smart location**.
7. When Android asks, choose **While using the app** and enable precise location.
8. To receive entry/exit events while the app is closed, enable **Keep watching in the background**. Android may open app settings; choose **Allow all the time**.

The app calculates distance locally and does not continuously upload raw coordinates. Foreground guidance updates after meaningful movement. Background mode registers two Android geofences (approaching and arrival), and uploads only transition events such as entering or leaving a boundary. Background mode is optional and remains off until the customer explicitly grants permission.

## QR arrival check-in

1. Staff clicks **Call next** in the dashboard.
2. The called customer's ticket shows **Show arrival QR**.
3. Staff clicks **Scan arrival**, grants camera permission, and scans the customer's screen.
4. Supabase verifies the ticket ID, venue ID, one-time nonce, ticket state, and staff membership before changing the status to **Arrived**.

Staff can also use each ticket's action menu for valid manual transitions:
calling an approaching party, manual check-in, no-show, seating, and removal.
Dashboard waiting, average-wait, seated, show-rate, approaching, and checked-in
figures are calculated from live ticket data.

Staff can set the venue's guest-seat capacity in Settings. Seating a party is
blocked when its party size would exceed the remaining capacity. The Check-in
page lists currently seated parties; **Mark departed** releases their occupied
seats while retaining the seated visit in historical insights.

See `MVP_HANDOFF.md` for the project transfer and end-to-end validation checklist.

## Push notifications

The Android customer app supports opt-in table-ready notifications through
Firebase Cloud Messaging. FCM remains on Firebase Spark; notification dispatch
runs in a Supabase Edge Function. Without Firebase build variables, the feature
stays disabled and the rest of QueueLess works normally.

Follow `docs/FIREBASE_SETUP.md` when you are ready to connect the Firebase
project, deploy the sender, and create the database webhook.

For meaningful distance testing, make sure the venue coordinates in `supabase/seed.sql` match the place where you are testing. If you already ran the seed, update the existing venue coordinates through the SQL Editor.

## Verification

```powershell
flutter analyze
flutter test
flutter build web --release -t lib/main.dart
flutter build web --release -t lib/main_staff.dart --output build/web_staff
```
