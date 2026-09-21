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
- **Dev environment**: Windows for all Android development; a Mac is only
  needed later for the final iOS build/release (App Store/Xcode signing).
- **IDE**: VS Code + Claude Code extension is now the ONLY place development
  happens — this chat is no longer part of the workflow.
- **Git**: monorepo. Branches: `main` (approved releases) ← `develop`
  (integration) ← `feature/phase-n-...` (one per phase). Remote:
  `https://github.com/vishnusainidv27-hue/SSD-Application`.

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
- PowerShell needed `Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned`
  to let `npm` run at all.
- Android build required NDK version `28.2.13676358` installed manually via
  Android Studio → SDK Manager → SDK Tools → "Show Package Details" (the
  command-line `sdkmanager.bat` crashes with `0xC0000409` on this machine —
  always install SDK components through Android Studio's GUI instead).
- `.gitignore` needed `.claude/` and `firebase-debug.log` added.
- Firebase project ID is `ssd-farm`, owned by the Google account
  `dairyfarmshreeshyam@gmail.com` — always `firebase login` with that account.
- `flutterfire` and `firebase` CLI executables live in
  `C:\Users\admin\AppData\Local\Pub\Cache\bin` — already added to PATH.

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
    tool: Admin creates Customer/DeliveryBoy/Admin logins from inside the app
  - `Admin App/Mobile app/test/widget_test.dart` — smoke test
- **Confirmed working live**: Admin logs in → creates a test Customer login →
  logs out → logging in as that Customer correctly gets rejected with
  "This app is for Admin accounts only" (proves the role guard works).

---

## What's PENDING

- **Immediate decision needed before continuing**: build order —
  **Phase 2** (Admin customer onboarding: society/block/floor/flat address,
  map pin, milk subscription setup) **vs Phase 3** (pricing engine:
  date-effective pricing, delivery exceptions calendar). Not yet decided —
  ask the user which to do first before starting new feature work.
- Phase 2 — Admin customer onboarding: not started.
- Phase 3 — Pricing engine & delivery calendar: not started.
- Phase 4 — Customer App (login, delivery history, bill view): not started.
  Note: `Customer App/` has NOT had `flutter create` run yet — no
  android/ios folders exist there yet.
- Phase 5 — Customer request/approval workflow: not started.
- Phase 6 — Delivery Boy App (daily delivery workflow): not started.
  Note: `Delivery Boy App/` also has NOT had `flutter create` run yet.
- Phase 7 — Billing engine, payments, reports: not started.
- Phase 8 — Admin Web panel, notifications, store release prep: not started.
  Note: `Admin App/Web/` also has NOT had `flutter create` run yet.
- iOS has only been REGISTERED in Firebase, never actually built or run —
  needs a Mac, deferred until one is available.
- Storage / photo-upload features are on hold pending a Blaze-plan decision.

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
