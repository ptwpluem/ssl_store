# Device-dependent work — ready to execute

These three features need native config (Gradle/Pods, Firebase console) **and a
real device/emulator to verify** — they can't be validated in `flutter test` or
`flutter analyze`, so they were deliberately not committed blind. The app-side
seams already exist; each item below is a short, guided session on a machine
that can `flutter run` to a device.

Do them in this order (smallest/lowest-risk first). After each: `flutter run`
on a device and confirm the listed check.

---

## 1. Crashlytics (≈15 min) — wire the existing seam

The logging seam is already in place (`lib/utils/app_logger.dart`,
`AppLogger.onError`). This just connects it.

1. Firebase console → **Crashlytics** → enable for the `store-backend-93d66` project.
2. Add deps:
   ```bash
   flutter pub add firebase_crashlytics
   ```
3. Native: ensure the Crashlytics Gradle plugin is applied (Android
   `android/app/build.gradle` + `android/build.gradle`) per the FlutterFire
   Crashlytics docs; iOS needs the dSYM upload build phase.
4. In `lib/main.dart`, inside `main()` after `Firebase.initializeApp(...)`:
   ```dart
   AppLogger.onError = (error, stack, {reason}) =>
       FirebaseCrashlytics.instance.recordError(error, stack, reason: reason);
   FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
   ```
   (Keep the existing `_isSuppressedError` filter — call Crashlytics only for
   non-suppressed errors.)
5. **Verify:** trigger a test crash (`FirebaseCrashlytics.instance.crash()` behind
   a debug button), confirm it appears in the console within a few minutes.

---

## 2. Receipt sharing (≈20 min) — deliver `ReceiptFormatter` output

The receipt **content** is already built and tested
(`lib/utils/receipt_formatter.dart`). This adds the share/print delivery.

1. Add deps:
   ```bash
   flutter pub add share_plus
   ```
2. On the transaction detail / history row, add a share action:
   ```dart
   import 'package:share_plus/share_plus.dart';
   import '../../utils/receipt_formatter.dart';

   IconButton(
     icon: const Icon(Icons.ios_share),
     onPressed: () => Share.share(ReceiptFormatter.format(tx)),
   );
   ```
3. (Optional, later) For a styled PDF instead of text: add `pdf` + `printing`,
   render `ReceiptFormatter`'s fields into a `pw.Document`, and call
   `Printing.sharePdf(...)`.
4. **Verify:** tap share on a transaction, confirm the OS share sheet opens with
   the Thai receipt text.

---

## 3. FCM pawn-due reminders (≈1–2 hr) — the biggest native lift

Goal: notify a customer when a pawn loan is due soon / overdue. The owner
dashboard already computes due dates; loans live in `pawn_loans` with `dueDate`.

**Client (Flutter):**
1. `flutter pub add firebase_messaging flutter_local_notifications`
2. iOS: enable Push Notifications + Background Modes capabilities, add the APNs
   key in the Firebase console. Android: no extra key (uses FCM directly).
3. On login, request permission and save the FCM token to the user doc:
   ```dart
   final token = await FirebaseMessaging.instance.getToken();
   // write to users/{uid}.fcmToken
   ```
4. Handle foreground messages with `flutter_local_notifications`.

**Server (Cloud Function — `functions/`):**
5. Add a scheduled function (daily) that queries `pawn_loans` where
   `status == 'active'` and `dueDate` within the next N days (and overdue),
   looks up each owner's `users/{uid}.fcmToken`, and sends via the Admin SDK
   (`admin.messaging().send(...)`). This mirrors the existing hourly
   `scrapeGoldPrice` function's shape.

**Verify:** set a test loan's `dueDate` to tomorrow, run the function locally
against the emulator (or deploy), confirm the device receives the push.

---

## Not started

- **English localization** — large, cross-cutting (`flutter_localizations` +
  ARB files + replacing hardcoded Thai strings). A separate milestone.
- **Scheduled Firestore backups** — ops task: enable scheduled exports to a GCS
  bucket via `gcloud firestore export` on a Cloud Scheduler job (no app code).
