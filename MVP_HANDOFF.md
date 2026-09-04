# QueueLess project handoff

## Product status

QueueLess is a functional Flutter mobile and ubiquitous computing project with
two entry points:

- `lib/main.dart` — Android customer application
- `lib/main_staff.dart` — responsive staff web dashboard

The end-to-end flow is connected to Supabase and Firebase: a customer joins,
staff calls the party, Firebase sends a table-ready notification, location
context helps with arrival, staff verifies the secure QR pass, seats the party,
and releases its occupied seats when the party departs.

## Implemented customer experience

- Persistent Home, My Queue, History, and Settings navigation
- Live venue details and queue availability
- Queue join and cancellation
- Realtime position and status updates
- Foreground distance and leave-now guidance
- Optional Android background geofences
- Opt-in Firebase Cloud Messaging alerts
- Secure one-time arrival QR pass
- Completed/cancelled/no-show history
- Permission, privacy, and arrival help content

## Implemented staff experience

- Overview with live queue and seat occupancy
- Dedicated searchable/filterable Live Queue page
- Dedicated Check-in page and QR scanner
- Currently seated list and seat-release/departure control
- Insights calculated from today's live ticket data
- Venue, queue timing, geofence, availability, and capacity settings
- Staff-only ticket transitions enforced by Supabase RPCs and RLS

## Backend setup order

In the Supabase SQL Editor, run the full contents of these files in order:

1. `supabase/migrations/202608100001_initial_schema.sql`
2. `supabase/migrations/202608140002_context_and_qr.sql`
3. `supabase/migrations/202608140003_push_notifications.sql`
4. `supabase/migrations/202608150004_seat_capacity.sql`
5. `supabase/seed.sql` for a new project only

Enable anonymous sign-ins in Supabase Authentication. Create a staff email and
password user, then add its UUID to `public.venue_staff` using the example at
the bottom of `supabase/seed.sql`.

Do not rerun the seed against a configured production/demo venue unless its
name, address, coordinates, and capacity should be overwritten.

## Push notification infrastructure

The Android client uses Firebase Cloud Messaging on the Firebase Spark plan.
The sender is `supabase/functions/dispatch-notification/index.ts`.

Supabase Edge Function secrets:

- `FIREBASE_SERVICE_ACCOUNT_JSON` — complete Firebase service-account JSON
- `QUEUELESS_WEBHOOK_SECRET` — a separate long random value

Deploy the function as `dispatch-notification` with JWT verification disabled.
Create an INSERT database webhook for `public.notification_jobs` pointing to:

```text
https://YOUR_PROJECT_REF.supabase.co/functions/v1/dispatch-notification
```

Headers:

```text
Content-Type: application/json
x-queueless-secret: THE_SAME_QUEUELESS_WEBHOOK_SECRET
```

Never store or share the Firebase service-account JSON, Supabase secret key, or
service-role key in this repository.

## Running locally

Customer Android app:

```powershell
flutter run -d YOUR_ANDROID_DEVICE -t lib/main.dart `
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=YOUR_PUBLISHABLE_KEY `
  --dart-define=FIREBASE_API_KEY=YOUR_FIREBASE_API_KEY `
  --dart-define=FIREBASE_APP_ID=YOUR_FIREBASE_ANDROID_APP_ID `
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=YOUR_PROJECT_NUMBER `
  --dart-define=FIREBASE_PROJECT_ID=YOUR_FIREBASE_PROJECT_ID
```

Staff dashboard:

```powershell
flutter run -d chrome -t lib/main_staff.dart `
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=YOUR_PUBLISHABLE_KEY
```

Omitting Supabase variables intentionally launches in-memory demo mode.

## End-to-end validation

1. Open the queue from staff Settings.
2. Join from the Android customer app.
3. Enable table-ready alerts and confirm `device_installations` has an Android row.
4. Enable foreground location and optionally background arrival.
5. Call the party from the staff dashboard.
6. Confirm the Android notification and `notification_jobs.state = 'sent'`.
7. Show the customer QR and scan it from Check-in.
8. Mark the arrived party seated.
9. Confirm Overview occupancy increases by the party size.
10. Mark the seated party departed and confirm occupancy decreases.
11. Confirm the completed visit appears in customer History and staff Insights.

## Verification commands

```powershell
flutter analyze
flutter test
flutter build web --release -t lib/main.dart
flutter build web --release -t lib/main_staff.dart --output build/web_staff
flutter build apk --debug -t lib/main.dart
```

Android builds that need real notifications must include the Firebase and
Supabase `--dart-define` values shown above.

## Files to omit from a handoff archive

- `.dart_tool/`
- `build/`
- `.idea/`
- `android/.gradle/`
- `android/local.properties`
- IDE metadata and local SDK caches

Keep `pubspec.lock`. The Android `google-services.json` contains client
configuration rather than the service-account private key; if it is omitted,
the recipient can download it again from the same Firebase Android app.

## Sensible next work

- Replace the sample staff name/avatar with the signed-in staff profile
- Add date-range and historical aggregate RPCs for richer analytics
- Add multi-venue discovery if the project scope expands beyond one venue
- Add integration tests against a disposable Supabase project
- Create signed Android release configuration and final university demo data
