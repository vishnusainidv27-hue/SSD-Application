**SSD FARM**

**Milk Delivery Management Platform**

*Business & Software Requirements Specification (SRS)*

Customer App | Delivery Boy App | Admin App

Platforms: Android & iOS | Backend: Firebase

Version 1.0 | Prepared: September 2026

# Document Control

| **Field**            | **Details**                                                                                                                      |
|----------------------|----------------------------------------------------------------------------------------------------------------------------------|
| Document Title       | SSD Farm – Milk Delivery Application Requirements Specification                                                                  |
| Version              | 1.0 (Draft for Review)                                                                                                           |
| Prepared For         | SSD Farm                                                                                                                         |
| Applications Covered | 1. Customer App 2. Delivery Boy App 3. Admin App/Panel                                                                           |
| Target Platforms     | Android (phone), iOS (iPhone) – single codebase for all three apps                                                               |
| Backend              | Firebase Spark (free) plan: Authentication, Firestore, Hosting (optional web panel). See § 2.4 for the current backend decision. |
| Status               | Awaiting client sign-off before development start                                                                                |

# 1. Introduction & Project Overview

SSD Farm is a milk subscription and delivery management platform that digitizes the day-to-day operations of a home milk delivery business. The platform replaces manual registers and phone-call based order changes with three connected mobile applications and a shared real-time backend.

The platform manages recurring daily milk subscriptions (cow milk, buffalo milk, or both) in configurable quantities (e.g. 500 ml, 1 litre, 1.5 litre, 2 litre), tracks day-wise deliveries, supports date-wise changes and holidays, applies date-effective pricing, and generates accurate bills even when the price of milk changes mid-cycle.

## 1.1 Applications in Scope

| **#** | **App**               | **Primary User**               | **Purpose**                                                            |
|--------|-----------------------|--------------------------------|------------------------------------------------------------------------|
| 1      | Admin App / Web Panel | Business owner / office staff  | Master data, pricing, user & delivery-boy management, reports, billing |
| 2      | Customer App          | End customer (milk subscriber) | View deliveries & bills, request quantity change / skip a day          |
| 3      | Delivery Boy App      | Delivery staff                 | Daily delivery route, mark delivered/not-delivered, remarks            |

## 1.2 Goals

- Give the admin full, real-time visibility and control over customers, pricing, and deliveries.

- Let customers self-serve for quantity changes and leave/skip requests, with admin approval where required.

- Give delivery staff a simple, low-friction daily worklist that works even with patchy network.

- Ensure billing is always accurate, even when the milk price changes in the middle of a billing period.

- One shared codebase (recommended: Flutter) and one shared Firebase backend so all three apps stay in sync instantly.

# 2. Recommended Technology Stack

This section reflects the requirement that all apps run on both Android and iPhone, and that Firebase is used for all database needs.

| **Layer**                 | **Recommendation**                                                                            | **Notes**                                                                                                                                                                                                                                                               |
|---------------------------|-----------------------------------------------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Mobile framework          | Flutter (Dart) – 3 separate apps built from a shared internal package                         | One codebase per app compiles to both Android (.apk/.aab) and iOS (.ipa). Avoids maintaining two native codebases. Everything in this document — all 3 apps, Admin logic, Firebase integration — is fully buildable in Flutter alone, so no second framework is needed. |
| Authentication            | Firebase Authentication (email/password sign-in, used internally)                             | User only ever sees “mobile number + password”; see the finalized approach just below this table.                                                                                                                                                                       |
| Database                  | Cloud Firestore                                                                               | Real-time NoSQL database; all master data, subscriptions, deliveries, billing records.                                                                                                                                                                                  |
| File storage              | Firebase Storage — deferred (not enabled on the Spark plan; see § 2.4)                        | Profile photos, delivery-proof photos (optional), signed documents. Planned functionality, on hold until a future Blaze-plan decision.                                                                                                                                  |
| Server logic              | Handled inside the Flutter apps (Admin app) instead of Cloud Functions — see § 2.4            | Price-effective billing calculation, quantity-change approval, and delivery-list generation run as in-app Dart logic reading/writing Firestore directly, so no paid Cloud Functions plan is required.                                                                   |
| Push notifications        | In-app notification centre via Firestore (real-time listener), FCM added later only if needed | Delivery updates, approval status, and price-change alerts appear instantly inside the app without needing a paid backend; true “phone lock-screen” push (FCM) can be switched on later once the project is ready to move to the Blaze plan (see § 2.4).                |
| Maps & location           | Google Maps SDK / Places API                                                                  | Address pin-drop, landmark selection, delivery-boy route view.                                                                                                                                                                                                          |
| Admin web access          | Firebase Hosting + a responsive web panel (optional, in addition to an Admin mobile app)      | Recommended so office staff can work from a desktop as well as a phone.                                                                                                                                                                                                 |
| Analytics/crash reporting | Firebase Analytics + Crashlytics                                                              | Usage and stability monitoring across all three apps.                                                                                                                                                                                                                   |

*Login decision (finalized): mobile number + Admin-set password, using Firebase Authentication directly — no Cloud Function needed. Firebase Authentication's email/password sign-in is used under the hood: each mobile number is mapped to a fixed-format internal address (e.g. 9999999999@ssdfarm.app) purely so Firebase Auth can store it, while every screen the user actually sees only ever asks for their mobile number and password. When Admin creates a customer or delivery boy, the Admin app creates that Firebase Auth account via a secondary, temporary Firebase app instance so the Admin's own logged-in session is never disturbed. This keeps “admin sets the password, user logs in with mobile number + password” exactly as requested, while staying fully client-side and free (Spark plan, no Blaze/Cloud Functions required).*

## 2.1 Development Approach — Claude-Managed Codebase

All three applications will be built and maintained as a single Flutter codebase (with role-based app targets/flavors for Admin, Customer, and Delivery Boy), written, tested, and version-controlled with Claude's help throughout — from initial project scaffolding through feature development, bug fixes, and ongoing enhancements.

- Claude Code (Anthropic's agentic coding tool) is used to write and edit the Flutter/Dart source, wire up Firebase, run the app, run automated tests, and manage Git commits directly on the development machine — either from the terminal or from inside VS Code.

- Source code is kept in a Git repository (e.g. GitHub) from day one, so every change is tracked, reviewable, and easy to hand off or roll back.

- The same codebase is reused across all three apps via shared packages (common UI theme, shared data models, shared Firebase service layer), with only role-specific screens differing — this keeps three apps consistent and easier for Claude to maintain together rather than as unrelated projects.

## 2.2 Development & Testing Machine — Windows-First

The project is set up so that day-to-day development, building, and testing can be done entirely on a Windows PC, with a Mac needed only for the final iOS-specific steps.

| **What**                                                | **On Windows?** | **Details**                                                                                                                                               |
|---------------------------------------------------------|-----------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------|
| Write/edit Flutter code                                 | Yes             | Full Flutter + Dart development works natively on Windows                                                                                                 |
| Run & test the Android app                              | Yes             | Run on an Android emulator (via Android Studio's emulator manager) or on any real Android phone connected by USB — no Mac needed at any point for Android |
| Quick UI preview/testing                                | Yes             | Flutter can also run the same code as a Windows desktop app or in Chrome for fast hot-reload UI checks while building screens                             |
| Build Android release file (.apk / .aab) for Play Store | Yes             | Fully buildable and signable on Windows                                                                                                                   |
| Run & preview the iOS app during development            | No (Mac only)   | Apple only allows iOS builds/emulation through Xcode, which runs on macOS — this is an Apple platform restriction, not a Flutter limitation               |
| Build iOS release file (.ipa) for the App Store         | No (Mac only)   | Requires Xcode for final compilation, code signing, and App Store submission                                                                              |

- Practical workflow: build and validate all app logic, screens, and Firebase integration on Windows against Android first (this covers roughly 95% of development, since the Flutter code is shared). Once a feature/app is stable, do a periodic iOS build-and-check pass on a Mac.

- If a physical Mac is not available for those periodic iOS passes, cloud Mac build services (e.g. Codemagic, GitHub Actions macOS runners, or a rented/virtual Mac) can run `flutter build ios` and produce a signed .ipa without owning a Mac full-time — useful as a fallback, though a MacBook remains the simplest option when one is available, as you noted.

- Recommendation: keep an Apple Developer account ready (needed for any iOS release regardless of which Mac/service is used) so the iOS pass isn't blocked later by account setup.

## 2.3 Language & IDE

- Language/Framework: Flutter (Dart) — confirmed as the best fit, since it compiles one codebase to both Android and iOS and works fully on Windows for the Android side.

- Primary IDE: Visual Studio Code (VS Code) — lightweight, free, has excellent official Flutter and Dart extensions, and integrates cleanly with Claude Code for AI-assisted development directly inside the editor or its terminal.

### IDE Comparison

| **IDE**               | **Best For**                       | **Notes**                                                                                                                                                                                                                                       |
|-----------------------|------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| VS Code (Recommended) | Day-to-day coding with Claude Code | Fast, lightweight, official Flutter/Dart extensions, best fit for an AI-assisted, terminal-driven workflow                                                                                                                                      |
| Android Studio        | Android-specific tooling           | Heavier but has the most complete built-in Android emulator manager, layout inspector, and Firebase Assistant — worth installing alongside VS Code just for its emulator manager and Android SDK manager, even if VS Code stays the main editor |
| Xcode                 | iOS-only, on Mac                   | Not an alternative to VS Code — only used on the Mac at release time for iOS-specific build/signing/App Store steps; cannot run on Windows                                                                                                      |

*Suggested setup: VS Code as the main editor for all Claude-assisted coding, with the Android SDK and an emulator installed via Android Studio's SDK/AVD Manager (Android Studio itself can remain closed day-to-day — it's only used to manage the SDK/emulator). This gives the lightweight VS Code workflow without losing Android Studio's device/emulator tooling.*

**Finalized for this project: Flutter (Dart) as the language/framework and VS Code as the primary IDE.**

## 2.4 Firebase on the Free (Spark) Plan

As requested, the project is designed to run entirely on Firebase's free “Spark” plan — no credit card and no paid plan required to build, launch, and run SSD Farm at a normal small-business scale.

| **Firebase Service**  | **Free (Spark) Plan Limit**                                                                                                                                             | **Fits This Project?**                                                                                                                 |
|-----------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------|
| Authentication        | Unlimited email/password & custom-token sign-ins, free                                                                                                                  | Yes — used for all 3 apps' login                                                                                                       |
| Cloud Firestore       | 1 GiB stored data; ~50,000 reads, 20,000 writes, 20,000 deletes per day, free, every day                                                                                | Yes — comfortably covers hundreds of customers with daily deliveries; scales further by optimizing how often each screen re-reads data |
| Firebase Storage      | Not enabled — new Firebase projects need the Blaze plan for Cloud Storage                                                                                               | Deferred — profile photos and delivery-proof photos are on hold pending a future Blaze-plan decision (see § 4.8, § 6.3)                |
| Firebase Hosting      | 10 GB storage, 360 MB/day transfer, free                                                                                                                                | Yes — if/when an Admin web panel is added                                                                                              |
| Cloud Messaging (FCM) | Free, but sending messages requires a small server-side trigger                                                                                                         | Deferred — see note below                                                                                                              |
| Cloud Functions       | Not available on Spark; requires upgrading to the Blaze (pay-as-you-go) plan and linking a billing method, even though Blaze still includes the same free monthly quota | Not used in Phase 1 (see approach below), so the project never needs to add a billing card                                             |

**How the app stays on Spark without losing the features you asked for:**

- Cloud Functions are the only Firebase piece that Google requires a billing account for (Blaze plan) — even if actual usage never costs anything. To avoid needing a card at all, the logic that would normally sit in a Cloud Function (date-effective price calculation, bill generation, approving a quantity-change request) is instead written as Dart code inside the Admin app itself, which reads/writes Firestore directly. This keeps 100% of the features described in this document — it only changes where the calculation code physically runs.

- Firestore Security Rules (which are free on Spark) still enforce who can read/write what — e.g. only Admin can write the price list, a customer can only write their own change-requests, a delivery boy can only update deliveries assigned to them — so moving logic out of Cloud Functions does not weaken security.

- Real “phone lock-screen” push notifications (FCM) technically work on Spark, but reliably triggering them automatically (e.g. “notify customer the moment Admin approves”) normally uses a small server — usually a Cloud Function. Phase 1 instead shows all alerts as an in-app notification list/badge (built on a live Firestore listener), which needs no server and is still instant while the app is open. If true push-to-lock-screen alerts become a must-have later, the project can upgrade to Blaze at that point — the Blaze free quota is generous enough that a business of this size would still typically pay ₹0/month, the card is just kept on file as a safeguard.

- Net result: the app can be fully built, tested, and run in production on Windows using only the Firebase Spark plan, with a clear, optional upgrade path later if the business grows large enough to need it.

# 3. User Roles & Access Levels

| **Role**            | **Created By**                          | **Login Credentials**                         | **Key Capabilities**                                                 |
|---------------------|-----------------------------------------|-----------------------------------------------|----------------------------------------------------------------------|
| Super Admin / Admin | Pre-provisioned (business owner)        | Email/mobile + password                       | Full access: users, delivery boys, pricing, reports, approvals       |
| Delivery Boy        | Created by Admin                        | Mobile number + password (set by Admin)       | View assigned delivery list, mark delivered/undelivered, add remarks |
| Customer            | Created by Admin only (no self sign-up) | Mobile number + password (generated by Admin) | View deliveries & bills, request quantity change / skip day          |

*Self-registration is intentionally disabled for both customers and delivery boys — every account is created by the Admin, matching the stated requirement.*

# 4. Admin App – Detailed Requirements

## 4.1 Admin Login

- Admin logs in with email/mobile number and password.

- Optional: PIN or biometric (fingerprint/Face ID) quick-unlock after first login.

- Multiple admin/staff logins with role-based permission (optional future enhancement, see § 12).

## 4.2 Customer (User) Creation

Only the Admin can create a customer account. The Admin fills in a structured onboarding form:

### 4.2.1 Login Credentials

- Customer's mobile number (used as the login ID)

- System-generated or Admin-typed password (shown to Admin to share with the customer). Passwords are set and changed only by Admin; customers have no in-app option to change their own password

### 4.2.2 Profile Details

- Customer full name

- Mobile number (primary) + optional alternate number

### 4.2.3 Structured Address (as requested: society → block → floor → flat)

- Society / Colony name

- Block name

- Floor number

- Flat / House number

- Landmark (free text)

- Auto-generated “Final Address” – the system concatenates the above fields into one readable address string, e.g. “Flat 402, Floor 4, Block C, Green Valley Society, Near City Hospital”, shown to Admin for confirmation and editable if needed.

- Map pin-drop: Admin (or customer) drags a pin on Google Maps to the exact building/landmark location; the resulting latitude/longitude is stored and used by the Delivery Boy app for navigation.

### 4.2.4 Milk Subscription Setup (at the time of registration)

- Milk type: Cow / Buffalo / Both (if “Both”, quantity is captured separately for each type)

- Quantity per type, chosen from configurable options: 500 ml, 1 Litre, 1.5 Litre, 2 Litre, or a custom value

- Delivery frequency: Daily / Alternate days / Custom weekly pattern (e.g. skip Sundays)

- Subscription start date

- Advance date-wise exceptions: Admin can mark specific upcoming dates as “no delivery” or “different quantity” directly while creating or later editing the customer (a simple calendar picker with multi-select)

- Delivery time slot (Morning / Evening) if the business runs two shifts

- Assign a default Delivery Boy / route to this customer

## 4.3 Customer Master List & Search

- Full list of all registered customers with photo/initials, name, society, mobile number, active/inactive status

- Search by name, mobile number, society name, block, or flat number

- Filter by society, delivery boy/route, milk type, active vs. paused subscription, and date of joining

- Edit / deactivate / reactivate / delete a customer

- Bulk actions: e.g. reassign all customers of Society X to a different delivery boy

## 4.4 Delivery Tracking (Admin view)

- Day-wise, society-wise, and delivery-boy-wise delivery status: Delivered / Not Delivered / Skipped-by-customer / Pending

- Filters: date range, society, delivery boy, milk type, delivery status, customer

- Drill-down into a single delivery to see quantity, price applied, remark (if any) left by the delivery boy, and timestamp

- Live/near-real-time dashboard showing today's total planned litres vs. delivered litres

## 4.5 Pricing Management — Date-Effective Pricing (core rule)

This is one of the most important business rules and is treated as a first-class feature:

1.  Admin maintains a Price List per milk type (Cow, Buffalo) with rate per litre (or per configured unit).

2.  Every price change is saved as a new price record with an “Effective From” date — the old price is never overwritten, only closed off with an “Effective To” date equal to the day before the new price starts.

3.  All historical deliveries keep the price that was valid on the delivery date. When Admin changes today's price, it never changes the amount owed for past deliveries.

4.  Bill generation always looks up, for each delivered date, “which price was effective on that date” and multiplies it by the delivered quantity for that date — so one bill can correctly contain several different rates if the price changed mid-month.

5.  Admin can view a full Price History log (rate, effective-from, effective-to, changed-by, changed-on) for audit purposes.

| **Milk Type** | **Rate / Litre** | **Effective From** | **Effective To** |
|---------------|------------------|--------------------|------------------|
| Cow Milk      | ₹62              | 01-Jul-2026        | 14-Aug-2026      |
| Cow Milk      | ₹65              | 15-Aug-2026        | Current          |
| Buffalo Milk  | ₹78              | 01-Jul-2026        | Current          |

*Example: a customer's September bill with a price change on 15-Aug does not affect September at all — within one bill period, each day is simply priced at whatever was effective that day, so a mid-month change automatically produces a mixed-rate bill for that month.*

## 4.6 Billing & Invoicing

- Auto-generate a bill per customer for a selected period (typically monthly, but any custom date range supported)

- Bill shows a day-wise breakup: date, milk type, quantity delivered, rate applied that day, amount

- Bill totals: total litres, total amount, previous dues (if any), payments received, net payable

- Mark payments as received (Cash / UPI / Bank transfer) and record partial payments

- Share the bill with the customer as a PDF / in-app view, and it also appears automatically inside the Customer App

- Outstanding-dues report across all customers, with filters (overdue, society, amount range)

## 4.7 Quantity-Change / Skip Approval Queue

- Central inbox of all pending requests raised by customers from their app (change quantity for one day / change quantity permanently from a date / skip a specific day)

- Admin can Approve or Reject each request, with an optional note

- Approved changes automatically update the delivery plan and the Delivery Boy's list for that date

- Full history of who requested what and when, and the Admin's decision

## 4.8 Delivery Boy Management

- Create/edit/deactivate delivery boy accounts (name, mobile, password, assigned societies/routes, and a profile photo — photo upload is deferred: it needs Cloud Storage, which is not enabled on the Spark plan; on hold pending a future Blaze-plan decision, see § 2.4)

- Assign or reassign customers to a delivery boy

- View each delivery boy's daily performance: assigned vs. completed deliveries, remarks raised, punctuality

## 4.9 Reports (Admin)

| **Report**                       | **Filters Available**                                                         |
|----------------------------------|-------------------------------------------------------------------------------|
| Delivery report                  | Date range, society, delivery boy, customer, milk type, status                |
| Collection / payment report      | Date range, society, payment mode, customer                                   |
| Outstanding dues report          | Society, amount range, overdue days                                           |
| Milk consumption / demand report | Date, society, milk type — used to plan procurement quantity for the next day |
| Customer activity report         | New joins, paused/cancelled subscriptions, pending change requests            |
| Delivery boy performance report  | Date range, delivery boy, completion percentage                               |

- Every report is exportable (CSV/PDF/Excel) and has a global search box in addition to filters, as requested.

## 4.10 Notifications from Admin

- In-app notification (via the notification centre described in § 2.4 and § 7) to customers when price changes, when a bill is generated, or when their change request is approved/rejected

- In-app notification to delivery boys when their route/list is updated or reassigned

- Real lock-screen push and SMS alerts are a future upgrade path, available only if/when the project moves to the Blaze plan (see § 2.4)

# 5. Customer App – Detailed Requirements

## 5.1 Login

- Login using mobile number + password (as generated/shared by Admin)

- “Forgot password”: there is no self-service reset. No real email inbox exists behind the mobile-mapped login address, and SMS-based reset requires the Blaze plan (see § 2.4). A customer or delivery boy who forgets their password must contact Admin, who resets it from the Admin app using AuthService.changeUserPassword (implemented in Phase 1; it runs on a temporary secondary Firebase instance, so Admin's own session is not disturbed). Because passwords are set and changed only by Admin (there is no self-service password change anywhere in the apps), Admin always knows the user's current password, so this reset always works.

- Real self-service password reset or change (e.g. via SMS OTP) is a future upgrade path, available only if/when the project moves to the Blaze plan

## 5.2 Home / Dashboard

- Today's/tomorrow's scheduled delivery (milk type + quantity)

- Current outstanding amount and last payment date

- Quick actions: Change quantity, Skip a day, View bill

## 5.3 Delivery History

- Calendar/list view of every delivered date with milk type, quantity, rate applied, and amount for that day

- Status shown per day: Delivered / Not Delivered / Skipped by me / Upcoming

- Filters: date range, milk type, status — as requested, “all see all type of filter on report”

## 5.4 Billing View

- Month-wise bill with full day-wise breakup and applied rate per day (reflecting date-effective pricing)

- Running total of “how much money is due till now” shown prominently

- Payment history (what was paid, when, mode)

- Download/share bill as PDF

## 5.5 Change Quantity / Skip Delivery (Upcoming Dates Only)

This directly implements the requested rule that any change must ask whether it applies to one day only or from that date onward, and always requires Admin approval before taking effect.

1.  Customer selects an upcoming date (past/today's already-in-progress delivery cannot be changed).

2.  Customer chooses: “Skip delivery on this date” or “Change quantity”.

3.  If changing quantity, the app asks: “Apply for this date only” or “Apply from this date onward (until changed again)”.

4.  Customer enters/selects the new quantity (500 ml / 1 L / 1.5 L / 2 L / custom) and submits.

5.  Request status shows as “Pending Admin Approval”; the old/default quantity remains in effect until approved.

6.  Once Admin approves, the delivery plan updates automatically and the customer is notified; if rejected, the customer is notified with the Admin's note and the original plan continues.

- Customer can view the status and history of all their past requests (Pending / Approved / Rejected).

## 5.6 Address & Profile

- View/request edit of saved address (society, block, floor, flat, landmark, map pin) — edits to core address may also route through Admin approval to prevent delivery errors

- Update alternate contact number. (Password changes are not available here — passwords are set and changed only by Admin.)

## 5.7 Notifications

- Delivery completed today, price change alert, bill generated, request approved/rejected, payment received acknowledgement — all shown in the in-app notification centre (see § 2.4 and § 7)

- Real lock-screen push and SMS delivery of these alerts is a future upgrade path, available only if/when the project moves to the Blaze plan

# 6. Delivery Boy App – Detailed Requirements

## 6.1 Login

- Login with mobile number + password set by Admin

## 6.2 Daily Delivery List

- List of all deliveries assigned for the day, grouped by Society → Block, so the route is easy to follow physically

- Each entry shows: customer name, flat/floor/block, milk type, quantity, and a map/navigate button using the saved landmark/pin location

- List automatically reflects Admin-approved skip/quantity changes for that date — the delivery boy always sees the final, correct quantity

- Search/filter the day's list by society or customer name

## 6.3 Mark Delivered / Not Delivered

- One-tap “Mark as Delivered” button per customer per day

- “Not Delivered” option with a mandatory reason (e.g. customer not home, gate locked, customer refused)

- Optional remark/note field on every entry (delivered or not) — e.g. “left with neighbour,” “customer asked to increase quantity tomorrow”

- Optional photo-proof of delivery (configurable, off by default) — deferred: it needs Cloud Storage, which is not enabled on the Spark plan; on hold pending a future Blaze-plan decision (see § 2.4)

- All marks and remarks sync to the Admin app immediately (Firestore real-time listener), exactly as requested (“admin can see it immediately”)

## 6.4 Delivery Summary

- End-of-day summary: total deliveries completed, missed, and total litres delivered by milk type

- History of previous days' completed rounds

## 6.5 Offline Support

- Local caching so the delivery boy can mark deliveries even with a weak signal in a basement/society with poor network; entries auto-sync once connectivity returns

# 7. Cross-Cutting / Common Features

- Firebase Authentication for all three apps, with role stored in each user's Firestore profile document to route them to the correct app experience/permissions

- In-app notification centre across all apps, built on a live Firestore listener (see § 2.4); FCM lock-screen push is deferred until the project moves to the Blaze plan, if ever needed

- Multi-language support ready (English + Hindi, extensible) — recommended given the target user base

- Dark/light theme (optional, low priority)

- Consistent date-effective pricing engine used by both the Admin billing screen and the Customer bill view, so numbers always match

- Centralized audit log for sensitive actions: price changes, approvals/rejections, account creation/deactivation

# 8. Proposed Firestore Data Model (High-Level)

Illustrative collection structure; final field-level schema to be confirmed during technical design.

| **Collection**     | **Key Fields**                                                                                                                           | **Notes**                                                        |
|--------------------|------------------------------------------------------------------------------------------------------------------------------------------|------------------------------------------------------------------|
| users              | uid, role (admin/customer/deliveryBoy), name, mobile, passwordHash/authRef, status                                                       | One collection for all roles, filtered by role                   |
| customers          | userRef, societyName, blockName, floor, flatNumber, landmark, finalAddress, geo(lat,lng), assignedDeliveryBoyRef, defaultSubscription    | Linked 1:1 with a users doc                                      |
| subscriptions      | customerRef, milkType, quantity, frequency, startDate, status                                                                            | One or two docs per customer if “Both” milk types                |
| deliveryExceptions | customerRef, date, type (skip/quantityChange), requestedQty, appliesFrom (single/onward), status (pending/approved/rejected), approvedBy | Drives both the approval queue and the delivery-boy's daily list |
| deliveries         | customerRef, date, milkType, quantity, rateApplied, status (delivered/notDelivered/skipped), remark, deliveryBoyRef, timestamp           | One doc per customer per day — the core transactional record     |
| priceList          | milkType, rate, effectiveFrom, effectiveTo, changedBy                                                                                    | Append-only; never edit a closed price record                    |
| bills              | customerRef, periodFrom, periodTo, lineItems[], totalAmount, previousDue, amountPaid, netPayable, status                                 | Generated from `deliveries` + `priceList`                        |
| payments           | customerRef, billRef, amount, mode, date, recordedBy                                                                                     |                                                                  |
| deliveryBoys       | userRef, assignedSocieties[], active                                                                                                     |                                                                  |
| notifications      | targetUserRef, type, message, read, createdAt                                                                                            |                                                                  |

# 9. Worked Example – Date-Effective Billing

To make the pricing rule concrete for development and testing:

| **Date**       | **Milk Type** | **Qty (L)**          | **Rate/L Applied** | **Amount**                     |
|----------------|---------------|----------------------|--------------------|--------------------------------|
| 01–14 Aug 2026 | Cow           | 1.0 / day (14 days)  | ₹62                | ₹868.00                        |
| 15–31 Aug 2026 | Cow           | 1.0 / day (17 days)  | ₹65                | ₹1,105.00                      |
| 20 Aug 2026    | Cow           | 0 (customer skipped) | —                  | ₹0.00 (already excluded above) |

*August bill total for this customer = ₹868.00 + ₹1,105.00 = ₹1,973.00, correctly split across the old and new price even though it is a single monthly bill, and correctly excluding the one day the customer skipped.*

# 10. Non-Functional Requirements

| **Category**      | **Requirement**                                                                                                                                                                                                                                       |
|-------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Platform coverage | Every app (Admin, Customer, Delivery Boy) must run natively on Android and iOS from one shared codebase                                                                                                                                               |
| Performance       | Delivery list and dashboard should load within 2–3 seconds on a typical 4G connection                                                                                                                                                                 |
| Reliability       | Delivery Boy app must tolerate intermittent connectivity with local caching and auto-sync                                                                                                                                                             |
| Security          | Passwords stored using Firebase Auth's secure hashing; Firestore Security Rules enforce that a customer can only read/write their own data, a delivery boy can only see their assigned deliveries, and only Admin can write pricing/master data       |
| Scalability       | Firestore scales automatically; on the Spark plan the design targets hundreds of customers with daily deliveries within the free daily quotas (§ 2.4), with an upgrade path to the Blaze plan for growth toward tens of thousands of daily deliveries |
| Auditability      | All price changes, approvals, and account changes are logged with user and timestamp                                                                                                                                                                  |
| Backup            | Data export from the Admin app (CSV/PDF/Excel reports, § 4.9); automated scheduled Firestore backups would need the Blaze plan and are deferred (§ 2.4)                                                                                               |
| Localization      | UI text structured for easy translation (English/Hindi at minimum)                                                                                                                                                                                    |

# 11. Assumptions & Open Questions

- Billing cycle is assumed monthly (calendar month) unless the client specifies a different default cycle.

- Only Admin can create/deactivate customer and delivery-boy accounts; there is no public sign-up screen in this version.

- Payment collection itself (online payment gateway) is assumed to be recorded manually by Admin/delivery boy in v1; online payment (UPI/Razorpay/Stripe) can be added as a later phase if required — please confirm if needed for launch.

- One delivery boy can be assigned to multiple societies/blocks; one customer has exactly one assigned delivery boy at a time.

- “Date customer does not want milk” and “Admin blocking a date in advance” are treated as the same underlying delivery-exception mechanism, viewable/manageable from both the Admin and Customer apps as per each one's permissions.

- Exact list of quantity presets (500 ml, 1 L, 1.5 L, 2 L, etc.) will be confirmed and made configurable by Admin rather than hard-coded.

- Please confirm whether the Admin app should also have a desktop/web panel in addition to the mobile app — recommended given the volume of data entry and reporting an office typically does.

# 12. Future Enhancements (Not in Phase 1 unless prioritized)

- Online payment gateway integration (UPI/cards) with auto-reconciliation against bills

- Route optimization for delivery boys (auto-sequencing stops by distance)

- Multiple admin/staff roles with granular permissions (e.g. “billing-only” staff role)

- Customer referral / loyalty program

- Inventory & procurement planning module (how much raw milk to source based on next day's demand report)

- WhatsApp-based notifications in addition to push/SMS

- Rating/feedback from customer on delivery quality

# 13. Approval & Sign-Off

This document is intended to be reviewed and confirmed by the client before design and development begin. Please mark against each major section: Approved / Needs Change, and add notes for anything that should be adjusted.

| **Section**                     | **Approved (Y/N)** | **Comments** |
|---------------------------------|--------------------|--------------|
| 4. Admin App                    |                    |              |
| 5. Customer App                 |                    |              |
| 6. Delivery Boy App             |                    |              |
| 8. Data Model                   |                    |              |
| 10. Non-Functional Requirements |                    |              |
