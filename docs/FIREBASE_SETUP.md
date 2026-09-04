# Firebase Spark notification setup

QueueLess uses Firebase only for Cloud Messaging. Firebase Cloud Messaging is a
no-cost product on the Spark plan. Notification delivery runs in a Supabase
Edge Function, whose Free plan includes a monthly invocation quota.

## 1. Create the Firebase Android app

1. Create or open a Firebase project and keep it on **Spark**.
2. Open **Project settings > General > Your apps**.
3. Add an Android app with package name `com.hpc8115.queueless`.
4. Download `google-services.json` temporarily. Do not commit or share it.
5. Read these public configuration values from the JSON file:
   - `project_info.project_id` -> `FIREBASE_PROJECT_ID`
   - `project_info.project_number` -> `FIREBASE_MESSAGING_SENDER_ID`
   - `client[].client_info.mobilesdk_app_id` -> `FIREBASE_APP_ID`
   - `client[].api_key[].current_key` -> `FIREBASE_API_KEY`

Use the `client` entry whose Android package is
`com.hpc8115.queueless`. These client identifiers are not service-account
secrets, but the service-account key in the next section is secret.

## 2. Create the server credential

1. In Firebase, open **Project settings > Service accounts**.
2. Select **Generate new private key** and download the JSON file.
3. In Supabase, open **Edge Functions > Secrets**.
4. Add `FIREBASE_SERVICE_ACCOUNT_JSON` with the complete JSON file contents as
   its value.
5. Generate a long random value and save it as `QUEUELESS_WEBHOOK_SECRET`.

Never put the service-account JSON in Flutter, source control, chat messages, or
`--dart-define` arguments.

## 3. Apply and deploy the backend

1. Run `supabase/migrations/202608140003_push_notifications.sql` in the
   Supabase SQL Editor.
2. Deploy `supabase/functions/dispatch-notification` as an Edge Function named
   `dispatch-notification` with JWT verification disabled.
3. In **Database > Webhooks**, create an `INSERT` webhook for the
   `public.notification_jobs` table.
4. Point it to:

   `https://YOUR_PROJECT_REF.supabase.co/functions/v1/dispatch-notification`

5. Add headers:
   - `Content-Type: application/json`
   - `x-queueless-secret: THE_SAME_RANDOM_VALUE`

The custom secret protects the public webhook endpoint. The Edge Function also
claims each pending job only once before sending it.

## 4. Run the Android customer app

Supply the four public Firebase identifiers in addition to Supabase:

```powershell
flutter run -d YOUR_DEVICE_ID -t lib/main.dart `
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=YOUR_PUBLISHABLE_KEY `
  --dart-define=FIREBASE_API_KEY=YOUR_FIREBASE_API_KEY `
  --dart-define=FIREBASE_APP_ID=YOUR_FIREBASE_APP_ID `
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=YOUR_PROJECT_NUMBER `
  --dart-define=FIREBASE_PROJECT_ID=YOUR_FIREBASE_PROJECT_ID
```

After joining the queue, enable **Table-ready alerts** and grant Android's
notification permission. Calling that ticket from the staff dashboard inserts
a notification job; the webhook and Edge Function then deliver it through FCM.

## 5. Verify delivery

1. Put the customer app in the background without force-stopping it.
2. Call the customer's ticket from the staff dashboard.
3. Confirm the phone displays **Your table is ready**.
4. Check `notification_jobs.state` in Supabase. It should become `sent`.
5. If it becomes `failed`, inspect `error_message` and the Edge Function logs.

Android will not receive background messages after the user force-stops the app
from system settings until the app is opened again.
