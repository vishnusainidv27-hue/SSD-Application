# SSD Farm — Project Status & Handoff

**Read this file first, before doing anything else.** It is the single source of
truth for where this project stands. Update it (or ask Claude Code to update it)
at the end of every phase so it never goes stale.

Companion docs in this same `docs/` folder:
- `SSD_Farm_Requirements_Document.docx` — WHAT to build (features, business rules)
- `SSD_Farm_Development_Plan.docx` — the 8-phase breakdown, folder structure, git
  workflow, and the original per-phase Claude Code prompts

---

## Key decisions already made (do not re-litigate these)

- **Stack**: Flutter (Dart). One shared package `shared/ssd_shared` + 4 app folders:
  `Admin App/Mobile app`, `Admin App/Web`, `Customer App`, `Delivery Boy App`.
- **Backend**: Firebase project `ssd-farm`, **Spark (free) plan only**.
  - Cloud Storage is **NOT enabled** — new Firebase projects require the Blaze
    plan for Storage, which we're avoiding. Any optional photo-upload feature
    (profile photos, delivery-proof photos) is on hold until this is revisited.
  - **No Cloud Functions** — all business logic (pricing calc, bill generation,
    approval workflow) runs client-side inside the Admin app, by design, to
    stay on Spark.
- **Login approach**: every screen only ever shows "mobile number + password."
  Underneath, this uses Firebase Auth email/password sign-in:
  - `AuthService.normalizeMobile()` strips non-digits and keeps the **last 10**
    (so a typed country code never breaks matching).
  - `AuthService.mobileToAuthEmail()` = `<10 digits>@ssdfarm.app`.
  - Admin creates other users' logins via `AuthService.createUserAccount()`,
    which uses a **second, temporary FirebaseApp instance** so Admin's own
    session is never disturbed.
  - `active: false` on a user's Firestore doc disables their login — enforced
    BOTH client-side (`AuthService`/`LoginScreen`) AND server-side (Firestore
    rules' `isActiveUser()`), since client-side alone isn't real security.
- **Passwords are Admin-only**: no self-service password change or reset exists
  anywhere in the apps (no "forgot password", no "change my password", no forced
  change on first login). A user who forgets their password asks Admin, who resets
  it with `AuthService.changeUserPassword` — which always works because Admin is
  the only one who ever sets or knows the current password. Self-service reset is
  a future upgrade path only if the project moves to Blaze and adds SMS.
  - **Enforcement caveat (accepted risk, not a gap to fix)**: this rule is
    enforced only by the app never exposing a change-password UI to non-admin
    users. Firebase Auth has no equivalent of Firestore security rules, so
    nothing server-side stops a signed-in user from calling `updatePassword` on
    their own account. This is accepted and documented, given the low
    sophistication and low incentive of this app's actual user base (milk
    delivery customers and delivery staff). Revisit only if the project ever
    moves to Blaze and adds a Cloud Function to enforce it properly.
- **Password delivery**: after Admin creates any login, the app shows a
  copy/share step (mobile + password, pre-filled share message) so Admin can
  immediately send credentials to the new user and keep a durable record of what
  was set. This also mitigates (but doesn't eliminate) the risk of Admin losing
  track of a password needed for `AuthService.changeUserPassword` later. The
  same step is reused after an Admin password reset (Phase 2). Implemented in
  `Admin App/Mobile app/lib/widgets/credentials_share_dialog.dart` (uses
  `share_plus`).
- **Dev environment**: Windows for all Android development; a Mac is only
  needed later for the final iOS build/release (App Store/Xcode signing).
- **IDE**: VS Code + Claude Code extension is now the ONLY place development
  happens — this chat is no longer part of the workflow.
- **Git**: monorepo. Branches: `main` (approved releases) ← `develop`
  (integration) ← `feature/phase-n-...` (one per phase). Remote:
  `https://github.com/vishnusainidv27-hue/SSD-Application`.
- **Branding**: the business is "Shree Shyam Dairy Farm"; the logo (a circular
  cream-badge crest with a cow/farm scene, navy ring and text, gold wheat
  sheaves) is at `docs/branding/logo_original.jpg`, supplied by the user in
  Phase 8. `AppTheme` (`shared/ssd_shared/lib/theme/app_theme.dart`) derives
  the whole app color scheme from colors sampled off this logo — see Phase 8's
  entry below for the exact hex values and how each app's icon was built from
  it. Do not use any other color palette or logo without the user's say-so.
- **UI/design**: `docs/DESIGN_SYSTEM.md` is the reference for how every screen
  should look (colors, spacing, component theme, shared `SectionHeader`/
  `EmptyState`/`NotificationCentre` widgets, the home-screen layout pattern).
  Read it before touching any screen's layout or styling — see the "UI/design
  polish pass" entry below for what it replaced and why.

---

## Environment gotchas already solved — don't redo this troubleshooting

- **Gradle/Node connection timeouts** on this Windows machine were an IPv6
  routing issue, not a real network block. Fixes already applied:
  - `%USERPROFILE%\.gradle\gradle.properties` contains
    `systemProp.java.net.preferIPv4Stack=true`
  - For Firebase CLI / flutterfire hangs: run
    `$env:NODE_OPTIONS="--dns-result-order=ipv4first"` in the terminal first.
    (Worth making this a permanent User environment variable if it keeps
    coming up.)
- **Kotlin "Could not close incremental caches" build failure** (seen with
  `share_plus`): the project is on `E:` while the pub cache is on `C:`, and Kotlin
  incremental compilation breaks across drives. Fixed by `kotlin.incremental=false`
  in `Admin App/Mobile app/android/gradle.properties` — add the same line to the
  `android/gradle.properties` of any new app folder (Customer, Delivery Boy).
- PowerShell needed `Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned`
  to let `npm` run at all.
- Android build required NDK version `28.2.13676358` installed manually via
  Android Studio → SDK Manager → SDK Tools → "Show Package Details" (the
  command-line `sdkmanager.bat` crashes with `0xC0000409` on this machine —
  always install SDK components through Android Studio's GUI instead).
- **Google Maps API key** (Admin app map picker): put `MAPS_API_KEY=<key>` in
  `Admin App/Mobile app/android/local.properties` (gitignored). `build.gradle.kts`
  injects it into the manifest as a placeholder; builds work without it (blank
  map). In Gradle Kotlin DSL files use `import java.util.Properties` — the
  fully-qualified `java.util.…` fails because `java` resolves to the plugin
  extension.
- `.gitignore` needed `.claude/` and `firebase-debug.log` added.
- Firebase project ID is `ssd-farm`, owned by the Google account
  `dairyfarmshreeshyam@gmail.com` — always `firebase login` with that account.
- `flutterfire` and `firebase` CLI executables live in
  `C:\Users\admin\AppData\Local\Pub\Cache\bin` — already added to PATH.
- **An app folder's scaffold (android/ios) only exists on the branch it was
  committed on.** `flutter create`'s output (AndroidManifest.xml, MainActivity,
  build.gradle.kts, …) is ordinary tracked content — if it's committed on one
  feature branch and you `git checkout` a different branch that never merged
  it, git correctly removes those files from the working tree (this is normal
  branch-switch behaviour, not data loss; the commit is safe). It looked like
  the Customer App's scaffold had vanished after finishing Phase 2/3 work on
  other branches — it hadn't; `git checkout` back to the branch that has it
  restores it instantly. Merge a phase's app-scaffold commit to `develop`
  promptly (or keep working on its own branch) to avoid this surprise.
- **On this machine, the Windows USB/adb tether to the phone drops
  `flutter run` sessions unpredictably** (`Lost connection to device`),
  sometimes within a minute, sometimes after an Android "FullBackup_native"
  snapshot. The app itself keeps running fine on the phone; only the debug log
  tether drops. Just re-run `flutter run -d <device-id>`, or ask the user to
  open the already-installed app directly instead of waiting on the tether.

---

## What's DONE — Phase 1 (Foundation & Login) ✅ tested end-to-end on a real phone

- Firebase project `ssd-farm` created (Spark plan); Authentication
  (Email/Password provider) and Firestore enabled; Storage intentionally
  skipped (see decisions above).
- Firestore security rules deployed (not just written locally — actually
  `firebase deploy`ed) with `isSignedIn()`, `role()`, `isActiveUser()`.
- `flutterfire configure --project=ssd-farm` run for the Admin Mobile app —
  real `firebase_options.dart` generated; Android app
  (`com.ssdfarm.admin_mobile_app`) and iOS app (`com.ssdfarm.adminMobileApp`)
  registered in the Firebase project.
- Bootstrap Admin account created manually (Firebase Auth user +
  matching `users/{uid}` Firestore doc with `role: "admin"`, `active: true`).
- Code complete, committed, pushed to `origin/develop`, and verified working
  live on a real Android device:
  - `shared/ssd_shared/lib/services/auth_service.dart` — signIn, signOut,
    currentUserRole, isCurrentUserDeactivated, createUserAccount,
    changeUserPassword, normalizeMobile, mobileToAuthEmail
  - `shared/ssd_shared/lib/screens/login_screen.dart` — shared LoginScreen
  - `Admin App/Mobile app/lib/main.dart` — Firebase init with graceful
    "not configured yet" fallback, role-based routing, non-admin sign-out guard
  - `Admin App/Mobile app/lib/screens/admin_home_screen.dart` — placeholder
    dashboard with Create Login + Log out
  - `Admin App/Mobile app/lib/screens/create_login_screen.dart` — working
    tool: Admin creates Customer/DeliveryBoy/Admin logins from inside the app;
    on success it shows a copy/share dialog with the mobile + password
    (retrofitted after the first live test)
  - `Admin App/Mobile app/test/widget_test.dart` — smoke tests (Firebase-not-
    configured fallback screen, share-message text)
- **Confirmed working live**: Admin logs in → creates a test Customer login →
  logs out → logging in as that Customer correctly gets rejected with
  "This app is for Admin accounts only" (proves the role guard works).

---

## What's DONE — Phase 2 (Admin customer onboarding) ✅ merged to `develop`

Confirmed on a real phone (Redmi Note 9 Pro Max): Admin creates a customer, and
that customer can log in to the Customer App (and Admin still logs in to the
Admin app). **Not yet individually verified on-device**: the map pin picker
(needs a Maps API key — see gotchas), editing a customer, deactivate/reactivate,
and Reset Password. Code, analyze and unit tests are clean for all of them; treat
any failure there as a bug to fix, not a new phase.

What's built (all in `Admin App/Mobile app` + `shared/ssd_shared`):
  - `CustomerModel` / `SubscriptionModel` `fromFirestore` + `toMap`;
    `CustomerModel.buildFinalAddress`; `FirestoreService` customer CRUD
    (`watchCustomers`, `createCustomer`, `updateCustomer`, `setCustomerActive`,
    `getSubscriptions`). Customer doc id = the customer's Auth uid; subscriptions
    use doc id `<uid>_<milkType>`; `customers.milkTypes` is denormalised for the
    list's milk-type filter. `setCustomerActive` writes both `customers/{id}` and
    `users/{id}` (the latter is what actually blocks login).
  - `AddEditCustomerScreen` (create login + profile + address + map pin + milk
    type/quantity, generated password, copy/share step; edit mode keeps the
    mobile/login ID fixed), `MapPickerScreen` (tap/drag pin),
    `CustomerListScreen` (search, filters, edit / deactivate / reactivate /
    reset password), `reset_password_dialog.dart`, `utils/customer_filter.dart`.
  - Unit tests in `test/customer_logic_test.dart`.
  - **Left open / deferred**: the delivery-boy/route filter and default
    delivery-boy assignment (needs delivery-boy management, Phase 6); delivery
    frequency other than daily, time slot, and the advance date-exceptions
    calendar (Phase 3 / later); customer *delete* (not built — deactivate
    instead; a client can't delete another user's Auth account anyway); address
    search on the map picker (would need Places API).
  - **Needs the user**: a Google Maps API key (Google Cloud Console) — see the
    setup note under "Environment gotchas". Without it the map shows blank.
  - Reset Password asks Admin to type the customer's *current* password
    (`changeUserPassword` signs in as them), so Admin must have kept the
    password from the share step.

## What's DONE — Phase 3 (Pricing engine & delivery calendar) ✅ merged to `develop`

Confirmed on a real phone: setting a new price via the Prices screen and the
per-customer Delivery calendar (skip / change-quantity dates) both work.

- `PriceModel` (typed `MilkType`, dates stored as UTC midnight so they are
  timezone-safe) and `PricingService`: `setNewRate` (appends a new record and
  closes the open one the day before; rejects a start date on/before the latest
  record's start, so history is never rewritten), `rateEffectiveOn`, pure
  `PricingService.rateFor(prices, date)` for Phase 7 bills, `watchPrices`.
  Price doc id is `<milkType>_<yyyyMMdd>`.
- `PriceListScreen` (home → Prices): current rate per milk type, "New rate"
  dialog (rate + effective-from date, warns on past dates), full history
  table with changed-by / changed-on.
- `DeliveryExceptionModel` + `FirestoreService.watchExceptions/saveExceptions/
  deleteException`; `DeliveryExceptionScreen` (customer list ⋮ → Delivery
  calendar): multi-select dates, "No delivery" or "Change quantity" (per milk
  type), list of upcoming changes with remove. Admin-created exceptions are
  saved as `approved`. A skip is always all-milk-types; if a day has a skip
  and a quantity change, the skip wins (Phase 5/6 must honour this).
- Tests: `shared/ssd_shared/test/pricing_service_test.dart` (incl. the §9
  worked example) and `delivery_exceptions_test.dart`, using
  `fake_cloud_firestore`.
- **Spec fix**: Requirements §9's worked example counted the skipped 20 Aug in
  the 15–31 Aug total; corrected to 16 days / ₹1,040 / total ₹1,908.
- **Left open**: nothing applies the exceptions yet — the delivery list
  (Phase 6) and bill (Phase 7) must read `deliveryExceptions`; the "frequency
  other than daily" part of Requirements §4.2.4 is still not built.

## What's DONE — Phase 4 (Customer App: login, history & bill view) ✅ merged to `develop`

Confirmed on a real phone: the dashboard's Today/Tomorrow card shows the
signed-in customer's actual milk type + quantity from their subscription.
History and Bill View correctly show empty states (no `deliveries`/`bills`
documents exist yet — that's Phase 6/7's job to create).

- `flutter create` run, registered in Firebase (`ssd-farm`; Android
  `com.ssdfarm.customer_app`, iOS `com.ssdfarm.customerApp`).
  `android/app/google-services.json` is gitignored; regenerate with
  `flutterfire configure --project=ssd-farm` after a fresh clone.
- **Firestore rules deployed** so a signed-in customer can read their own
  `customers`, `subscriptions`, `deliveryExceptions`, `deliveries` and `bills`
  documents (`resource.data.customerId == request.auth.uid`, or doc id ==
  uid for `customers`); Admin keeps full access. Writes to all of these stay
  Admin-only for now (Phase 5 adds customer-submitted pending
  `deliveryExceptions`; Phase 6 adds delivery-boy-scoped `deliveries` writes).
- `DeliveryModel`/`BillModel` `fromFirestore`/`toMap` (previously stubs) +
  `FirestoreService.watchSubscriptions/watchDeliveries/watchBills`.
- `plannedDeliveriesForDate` (shared, pure, Firestore-free): given a
  customer's subscriptions + exceptions, computes what's actually scheduled
  for a given date — this is what makes the dashboard's Today/Tomorrow real
  today, without needing Phase 6. Reused as-is once Phase 6 generates the
  delivery boy's daily list.
- `CustomerHomeScreen` (Today/Tomorrow + outstanding-amount cards, links to
  History/Bill), `DeliveryHistoryScreen` (date range / milk type / status
  filters — `utils/delivery_filter.dart`), `BillViewScreen` (month picker,
  day-wise breakup + running total from `deliveries`, plus previous
  dues/paid/net-payable if Admin has generated an actual `bills` doc for that
  period).
- **Left open**: "Change quantity" / "Skip a day" quick actions (Phase 5 —
  needs the approval queue first); History/Bill only show real data once
  Phase 6 (deliveries) and Phase 7 (bills) exist.
- Tests: `shared/ssd_shared/test/delivery_planner_test.dart` and
  `Customer App/test/delivery_filter_test.dart`.

## What's DONE — Phase 5 (Customer requests + Admin approval workflow) ✅ merged to `develop`

Confirmed on a real phone end to end: customer submits a skip and a
quantity-change request → both show as Pending (and don't affect the
dashboard yet) → Admin approves one and rejects the other with a note → the
customer sees Approved/Rejected + the note, and the approved skip is
immediately reflected on the dashboard.

- **Fixed a latent bug**: `DeliveryExceptionModel.fromFirestore` recomputed a
  deterministic id instead of using the real Firestore doc id. Harmless while
  every writer used matching deterministic ids (Phase 3), but would have
  broken customer requests, which need auto-generated ids (see next point).
- Customer-submitted requests use `FirestoreService.submitRequest` (Firestore
  `.add()`, auto id) so a resubmission (e.g. after rejection) keeps its own
  row rather than overwriting the earlier one — Admin-direct exceptions still
  use the Phase 3 deterministic-id `saveExceptions` path unchanged.
- `plannedDeliveriesForDate` rewritten: now only `approved` exceptions affect
  the plan (pending/rejected are ignored — "the old/default quantity remains
  in effect until approved"), and `onward`-scope exceptions apply from their
  date forward until a later approved one supersedes them (same
  date-effective pattern as pricing). A skip is always single-scope
  (Requirements §5.5 has no "skip onward" option). On a same-day tie, skip
  beats quantity-change.
- `FirestoreService.watchPendingRequests`/`respondToRequest` (approve/reject
  + optional note + writes a `notifications` doc — no UI reads it yet, that's
  Phase 8's `NotificationCentreWidget`).
- **Firestore rules deployed**: a customer may `create` their own
  `deliveryExceptions` doc, but only as `status: pending` and only with their
  own `customerId` — they can never self-approve or touch another doc.
  `update`/`delete` stay Admin-only.
- Customer App: `RequestsScreen` (date picker restricted to tomorrow+, Skip
  vs Change Quantity, single/onward choice, own request history with status).
- Admin App: `ApprovalQueueScreen` (all customers' pending requests,
  Approve/Reject + note); `DeliveryExceptionScreen` now shows a grey dot +
  "not yet in effect" label for a customer's pending/rejected request instead
  of mixing it in with what's actually scheduled.
- Tests: `delivery_planner_test.dart` (9, rewritten) and
  `request_approval_test.dart` (6, new) in `shared/ssd_shared`.
- **Left open**: no UI reads the `notifications` doc yet (Phase 8); an
  onward request still only varies quantity/skip — frequency (daily only) is
  still not configurable (Requirements §4.2.4, noted since Phase 2).

## What's DONE — Phase 6 (Delivery Boy App: daily delivery workflow) ✅ merged to `develop`

Confirmed end to end on a real phone: Admin assigns a delivery boy to a
customer, opens Delivery Tracking (which generates that day's `deliveries`
rows), the delivery boy sees the entry on their own app and marks it, and it
updates live on Admin's tracking screen.

- **Key design decision**: there's no Cloud Functions/cron on Spark, so
  nothing generates a day's `deliveries` rows automatically at midnight.
  **Admin generates them** by opening the Delivery Tracking screen (or
  tapping Refresh) — it calls `DeliveryPlanningService.generateDeliveriesForDate`,
  which turns each assigned, active customer's subscription + approved
  exceptions (Phases 3/5) into pending/skipped rows at that day's price.
  Idempotent — never overwrites an already-marked row. **Operational
  consequence: Admin must open the app at least once a day (or tap Refresh)
  for delivery boys to see that day's list.**
- **Bug found and fixed during testing**: the customer form's "Assigned
  delivery boy" dropdown crashed when reopening any customer that already had
  one assigned, because `DropdownButtonFormField`'s `initialValue` had no
  matching item during the one frame before the delivery-boys list finished
  loading. Fixed by always including a placeholder item for the
  currently-assigned id when it isn't in the loaded list yet (covers both
  "still loading" and "genuinely deactivated" cases).
- `DeliveryBoyModel` (typed view over `users` where `role == 'deliveryBoy'`;
  no separate `deliveryBoys` collection yet). `DeliveryModel` gained
  `markedAt`. `FirestoreService`: `watchDeliveryBoys`, `markDelivery`,
  `watchDeliveriesForDate`/`getDeliveriesForDate` (delivery boy's own day),
  `watchAllDeliveriesForDate` (Admin, all customers).
- **Firestore rules deployed**: a delivery boy may read customers assigned to
  them (single-document `get()`s only, never a broad list query) and their
  own delivery rows, and may create/update a delivery row only under their
  own `deliveryBoyId`. **Accepted risk, deliberately not hardened further**:
  the rule doesn't verify server-side that the customer on that row is
  actually assigned to that boy — the apps never do this anyway, so it only
  stops a boy writing under a co-worker's id, not a targeted attack. Same
  risk tolerance as the existing password-security note.
- Admin App: "Assigned delivery boy" dropdown on Add/Edit Customer;
  `DeliveryTrackingScreen` (today's — or any day's — deliveries across all
  customers, live planned-vs-delivered totals, status/milk-type/boy/society
  filters).
- Delivery Boy App (new): `flutter create` run, registered in Firebase
  (`ssd-farm`; Android `com.ssdfarm.delivery_boy_app`, iOS
  `com.ssdfarm.deliveryBoyApp`). Daily list grouped Society → Block with
  search; Delivered / Not Delivered (reason required, optional remark);
  **Navigate** opens the customer's saved pin in Google Maps externally (no
  embedded map / second Maps API key needed); summary screen (today's
  completed/missed/skipped + litres by type, last 7 days). Offline: Firestore's
  default disk persistence, set explicitly in `main.dart` for clarity.
  `android/app/google-services.json` is gitignored; regenerate with
  `flutterfire configure --project=ssd-farm` after a fresh clone.
- Tests: `delivery_planning_service_test.dart` (6, shared) and
  `Delivery Boy App/test/delivery_list_entry_test.dart` (6, grouping/filter).
- **Left open**: delivery-boy performance reporting (Requirements §4.8/§4.9)
  is Phase 7 Reports scope, not built here — you can only see today's/a day's
  totals per boy via Delivery Tracking's filter, not a proper report.

## What's DONE — Phase 7 (Billing engine, payments & reports) ✅ merged to `develop`

Confirmed on a real phone: bill generation, recording a payment (with
amountPaid preserved on refresh), payment history on both Admin and Customer
App, and all six reports with CSV export.

- `PricingService.generateBill(customerId, periodFrom, periodTo)`: sums every
  `delivered`-status `deliveries` row in the period at the rate already
  stamped on it (Phase 6), carries the previous period's `netPayable` forward
  as `previousDue`. Deterministic id per customer + period, so re-generating
  (e.g. after a late delivery mark) recomputes totals in place — but always
  **preserves `amountPaid`**, so it can never silently wipe out a recorded
  payment. Verified against the Requirements §9 worked example (₹1,908).
- `PaymentModel` + `FirestoreService.recordPayment`: updates a bill's
  `amountPaid`/`netPayable` via `FieldValue.increment`, so two payments
  recorded around the same time can never race/overwrite each other.
  `watchPayments`, `getAllDeliveriesInRange`/`getAllPaymentsInRange` (single
  range-filter queries — deliberately avoid composite indexes; see the report
  screens below), `getAllBills`, `getAllCustomers`.
- **Firestore rules deployed**: a customer can read their own `payments`;
  writes stay Admin-only.
- Admin `BillGenerationScreen` (customer list ⋮ → Generate bill): month
  picker, generate/refresh, day-wise breakup, Record Payment dialog (amount
  capped at net payable, Cash/UPI/Bank), payment history.
- Customer App's `BillViewScreen` now also shows payment history for the
  displayed bill.
- Six Admin reports (Requirements §4.9), all with filters and **CSV export**
  (not PDF/Excel — see "Left open"): Delivery, Collection/payment,
  Outstanding dues, Milk consumption/demand, Customer activity, Delivery boy
  performance. Delivery/consumption/boy-performance share one
  `getAllDeliveriesInRange` fetch, filtered/grouped client-side, to keep
  reads cheap and avoid needing a composite index.
- Tests: `shared/ssd_shared/test/billing_test.dart` (9 — generateBill,
  recordPayment, range queries).
- **Left open**:
  - **PDF/Excel export** — Requirements §4.9 asks for CSV/PDF/Excel; only CSV
    is built (opens directly in Excel/Sheets; adding a PDF-generation library
    was cut for scope given this was already the largest phase). Same for
    §4.6's "share the bill as PDF" — only the in-app view exists.
  - Delivery-boy performance's "assigned" count is deliveries generated that
    day (excludes skipped), not a true daily-route/roster concept — there's
    no separate roster to compare against.
  - No UI records an *online* payment gateway — Requirements §11 already
    scoped that out of v1 (Admin/delivery boy record payments manually).

## What's DONE — Phase 8 (Admin Web, notifications, release prep) ✅ merged to `develop` and `main` (v0.8.0)

Confirmed by the user on real devices/browser: Admin Web panel, notification
centre in all three apps, and — added partway through the phase once the
user supplied it — the real logo as every app's icon/splash and the whole
app's color theme. **This was the last of the 8 planned development
phases** — see the release-readiness checklist below for what's left before
a store submission (all of it requires the user, not further coding).

- **Admin Web app** (`Admin App/Web/`, `flutter create --platforms=web` run,
  registered in Firebase as a Web app): reuses every existing Admin screen
  **unmodified** via a local path dependency on `admin_mobile_app` in its
  `pubspec.yaml` — an ordinary Dart package dependency works the same
  whether the target is nominally an "app" or a "package", so nothing had to
  move into `shared/ssd_shared`. Only `main.dart` (same login/role-gate
  pattern as the mobile app) and `AdminWebHomeScreen` (a `NavigationRail`
  side-nav instead of the mobile home's button list, opening the same
  screens) are new code. Verified it actually builds (`flutter build web`)
  and runs (`flutter run -d chrome`) before treating the approach as safe.
- **Notifications** (Requirements §2.4/§7 — no Cloud Functions, so this is
  the substitute for real push): `NotificationModel` +
  `FirestoreService.notify`/`notifyMany`/`watchNotifications`/
  `markNotificationRead`; a shared `NotificationCentre` widget (bell icon +
  unread badge + bottom sheet) wired into all three apps' app bars (Admin
  Web's is in the nav rail). Write points: Phase 5's approve/reject (already
  existed), **bill generated** (only on first generation for a period, not
  on Refresh — checked via the new `PricingService.billIdFor` +
  `FirestoreService.getBill`), **payment received**, **price changed**
  (fanned out to every active customer subscribed to that milk type).
- **Firestore rules deployed**: a user can read and mark-read their own
  notifications; only Admin can create/delete them.
- **Real branding — the SSD Farm (Shree Shyam Dairy Farm) logo**, supplied by
  the user partway through Phase 8, replacing the placeholder milk-drop glyph
  originally generated here:
  - Original logo saved at `docs/branding/logo_original.jpg`; the square,
    cream-padded crop used as the actual app icon source is
    `docs/branding/logo_icon_square.png` (same file copied into each app's
    `assets/icon/app_icon.png`, plus a circular transparent-background
    `app_icon_foreground.png` for Android's adaptive-icon safe zone).
  - **Colors sampled directly from the logo** (via a k-means cluster over its
    saturated pixels, then rounded to clean hex values) and defined as named
    constants on `AppTheme` (`shared/ssd_shared/lib/theme/app_theme.dart`):
    `brandNavy` `#1F425B` (the logo's ring/text — now the app's primary seed
    color), `brandGold` `#C79A45` (the wheat sheaf — secondary), `brandGreen`
    `#6B8E4E` (the fields — tertiary; several screens already used
    `colorScheme.tertiary` for a "delivered/approved" status color, so this
    reads as literally correct now, not just thematically close), `brandCream`
    `#FBF6E8` (the badge's background — used for splash screens and the
    Admin Web PWA manifest instead of Flutter's default blue).
  - `flutter_launcher_icons` + `flutter_native_splash` config lives in each
    app's `pubspec.yaml`; the Admin Web app additionally got its
    `web/icons/*.png`, `web/favicon.png` and `web/manifest.json` updated
    directly (those aren't covered by either generator for web).
  - Replacing the logo again later: swap `docs/branding/logo_original.jpg`
    and re-derive the square crop (or provide a new one already square/
    high-res), copy it to each app's `assets/icon/app_icon*.png`, then re-run
    `dart run flutter_launcher_icons` and
    `dart run flutter_native_splash:create` in each app folder — no code
    changes needed either way.
- **TODO review**: `grep -rn TODO` across `shared/` and all four apps' `lib/`
  returned nothing — no stray incomplete markers left in the code.
- Tests: `shared/ssd_shared/test/notifications_test.dart` (5, new); every
  app's existing suite still passes (Admin Web gained its own
  `widget_test.dart`, matching the other three apps' pattern).
- **Left open**: delivery-boy route-reassignment notifications (Requirements
  §4.10 mentions this; only price/bill/payment/request events are wired up);
  PDF/Excel export (already flagged in Phase 7); Storage-dependent features
  (still on hold, see below).

## What's DONE — post-launch: Android release signing prep + UI/design polish

Two pieces of work after all 8 phases were confirmed — neither maps to a
numbered Development Plan phase, so neither used a `feature/phase-n-...`
branch: the signing prep was committed straight to `develop` (small, inert
until a keystore exists); the UI polish used `feature/ui-design-polish`.

- **Android release signing**: `Admin App/Mobile app/android/app/build.gradle.kts`
  now reads `android/key.properties` if present and signs release builds
  with it, falling back to the debug key otherwise (unchanged from before).
  Verified both paths: `flutter build apk --debug` (no keystore) and
  `flutter build appbundle --release` (also no keystore — confirms the
  fallback itself works end-to-end, producing a real, installable `.aab`).
  Only the keystore file itself is still missing — see the release-readiness
  checklist below; Claude Code deliberately doesn't generate that.
- **UI/design polish pass** — see `docs/DESIGN_SYSTEM.md` for the reference
  going forward:
  - `AppTheme` gained a full Material 3 component theme (AppBar, Card,
    buttons, chips, inputs, dividers, dialogs, snackbars, nav rail) built
    from the brand palette, plus an `AppSpacing` scale (`xs`/`sm`/`md`/`lg`/
    `xl` = 4/8/16/24/32) — most of the visual improvement is "free" via
    inheritance, no per-screen changes needed.
  - New shared widgets: `SectionHeader` (a consistent titled-section header,
    replacing every screen's ad hoc version) and `EmptyState` (a consistent
    "nothing here"/"couldn't load this" placeholder, replacing bare
    `Center(child: Text(...))`). Both are used throughout Admin, Customer and
    Delivery Boy — forms, reports, lists.
  - The three apps' home/landing screens were redesigned around a shared
    pattern: a navy header card (greeting or live status) + grouped, titled
    sections below it. `AdminHomeScreen` in particular went from a flat list
    of buttons to a 2-column grid of icon tiles grouped into "Customers &
    delivery" / "Pricing & reports" / "Account".
  - Status colors (delivered/approved = green, not-delivered/rejected = red,
    skipped = gray, pending = navy) are now explicitly documented as a
    standing `colorScheme` convention (`tertiary`/`error`/`outline`/`primary`)
    rather than something each screen happened to do the same way.
  - Verified: all four packages analyze clean, all 74 existing tests still
    pass (no logic changed, only presentation), and both the Admin mobile app
    (`flutter build apk --debug`) and Admin Web app (`flutter build web`)
    build successfully afterward.
  - **Left open**: the six Report screens' internal layout (lists, filter
    chips) wasn't individually redesigned beyond inheriting the new theme —
    reasonable given they're dense data screens rather than a first-impression
    surface; revisit if the user wants further polish there specifically.

## What's PENDING

**All 8 phases of the original Development Plan are done.** What's left falls
into two buckets: the release-readiness checklist immediately below (all
user-only actions — nothing further to code), and optional Future
Enhancements (Requirements §12) that were never scoped as phases and would
need the user to pick one before any work starts on it — see the end of this
section.

- **Release-readiness checklist** — everything below needs the user, not
  Claude Code (Firebase Console/Play Console/App Store Connect access,
  physical publishing, and decisions with real, hard-to-reverse trade-offs):
  1. **Android signing key**: the Gradle side is now ready
     (`Admin App/Mobile app/android/app/build.gradle.kts` reads
     `android/key.properties` if present and signs release builds with it,
     falling back to the debug key otherwise — verified both paths still
     build). **Only the keystore itself is missing, and only you should
     create it**: this is a decision with a real, irreversible consequence —
     **losing this keystore (or its password) means the app can never be
     updated again under the same identity on the Play Store**, and Google
     cannot recover or reset it. Steps: run
     `keytool -genkey -v -keystore <path>.jks -keyalg RSA -keysize 2048
     -validity 10000 -alias <your-alias>` (Java's `keytool`, bundled with the
     Android SDK/JDK already installed), store the resulting `.jks` file and
     its passwords somewhere backed up and never committed to git (the
     `.gitignore` already excludes `**/*.keystore` and `key.properties`), then
     create `Admin App/Mobile app/android/key.properties` with `storeFile`,
     `storePassword`, `keyAlias`, `keyPassword` (see the comment above the
     signing config in `build.gradle.kts` for the exact format). No further
     code changes needed — `flutter build appbundle --release` will pick it
     up automatically.
  2. **Play Store listing** (Play Console, console-only): app description,
     screenshots (from a real device — Phase 1–8 testing was all on your
     Redmi Note 9 Pro Max, which works for this), category, content rating
     questionnaire, and pricing (free, per the business model so far). None
     of this can be done from the codebase.
  3. **iOS build**: still needs a Mac (or a cloud Mac service — see
     PROJECT_STATUS.md's original recommendation), for `flutter build ios`,
     Xcode signing, and App Store Connect's own listing steps. Fully deferred
     until one is available; nothing here changes that.
  4. **A staged rollout decision**: whether to launch Android-only first (the
     Mac/iOS gap allows this) or hold for both platforms together — a
     business call, not a technical one.
- iOS has only been REGISTERED in Firebase, never actually built or run —
  needs a Mac, deferred until one is available.
- Storage / photo-upload features are on hold pending a Blaze-plan decision.
- **Optional Future Enhancements** (Requirements §12 — none of these are
  scoped or started; each would become its own `feature/phase-9-...`-style
  branch only once the user picks one): online payment gateway with
  auto-reconciliation, delivery-boy route optimization, multiple admin/staff
  roles with granular permissions, a customer referral/loyalty program, an
  inventory/procurement-planning module, WhatsApp-based notifications, and a
  delivery-quality rating/feedback flow from customers.

---

## How to keep working entirely in Claude Code from here

At the start of any new session, tell Claude Code:

> "Read docs/PROJECT_STATUS.md, then continue development from where it says
> we left off."

At the end of each phase, tell Claude Code:

> "Update docs/PROJECT_STATUS.md — move [phase] from Pending to Done with a
> summary of what was built, and note anything still open."

This keeps the file (and thus any future Claude Code session) accurate without
needing to come back to any other conversation.
