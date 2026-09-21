**SSD FARM**

**Development & Delivery Plan**

*Folder Structure, Git Workflow, Phased Delivery Roadmap,*

*and Command / Claude Code Prompt Reference*

Companion document to: SSD_Farm_Requirements_Document.docx

Version 1.0 | September 2026

# 1. How to Use This Document

This document is the execution companion to the SSD Farm Requirements Document. Where the requirements document describes WHAT to build, this document describes HOW and IN WHAT ORDER — the repo layout, the Git workflow, the build phases, and for each phase the exact terminal commands and the Claude Code prompts to use inside VS Code.

- Yellow boxes are prompts — type these into the Claude Code chat/terminal inside VS Code, adjusting details as needed.

- Grey boxes are shell commands — run these directly in the VS Code integrated terminal.

- Each phase ends with a clearly stated client-facing deliverable, so progress can be demoed and signed off before moving on.

# 2. Repository & Folder Structure

A single Git repository (“monorepo”) holds all three apps plus a shared package, matching the structure you asked for:

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<tbody>
<tr class="odd">
<td><p>SSD-Application/</p>
<p>├── docs/ Requirements doc + this Development Plan</p>
<p>├── firebase/ Shared Firestore/Storage security rules</p>
<p>├── shared/</p>
<p>│ └── ssd_shared/ Shared Dart package: models, Firebase services, theme</p>
<p>├── Admin App/</p>
<p>│ ├── Mobile app/ Flutter app — Android + iOS (Admin)</p>
<p>│ └── Web/ Flutter web build of the Admin panel</p>
<p>├── Delivery Boy App/ Flutter app — Android + iOS</p>
<p>└── Customer App/ Flutter app — Android + iOS</p></td>
</tr>
</tbody>
</table>

Why a shared package: the Admin, Customer, and Delivery Boy apps all read/write the same Firestore collections (customers, subscriptions, deliveries, priceList, bills). Keeping the data models, Firebase access code, and the pricing/billing calculation logic in one shared package (ssd_shared) means that logic is written once and reused by all three apps and both Admin targets (Mobile + Web) — instead of being copy-pasted four times and drifting out of sync.

This exact folder structure has already been created and pushed as the initial commit — see § 3 below — so it's ready to clone and open in VS Code.

# 3. Git Version Control Workflow

## 3.1 Branch Strategy

| **Branch**                         | **Purpose**                                                                                                       |
|------------------------------------|-------------------------------------------------------------------------------------------------------------------|
| main                               | Always reflects the last client-approved, working delivery. Only merged into at the end of a phase, after review. |
| develop                            | Day-to-day integration branch. All phase branches merge here first.                                               |
| feature/phase-\<n\>-\<short-name\> | One branch per phase (e.g. feature/phase-2-customer-onboarding). All work for that phase happens here.            |

## 3.2 Standard Flow for Every Phase

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<tbody>
<tr class="odd">
<td><p>git checkout develop</p>
<p>git pull</p>
<p>git checkout -b feature/phase-&lt;n&gt;-&lt;short-name&gt;</p>
<p># ... work happens here, with Claude Code committing as it goes ...</p>
<p>git add -A</p>
<p>git commit -m "feat(phase-&lt;n&gt;): &lt;what changed&gt;"</p>
<p>git checkout develop</p>
<p>git merge feature/phase-&lt;n&gt;-&lt;short-name&gt;</p>
<p>git push</p>
<p># once the phase is demoed and approved by the client:</p>
<p>git checkout main</p>
<p>git merge develop</p>
<p>git tag v0.&lt;n&gt;.0</p>
<p>git push --tags</p></td>
</tr>
</tbody>
</table>

The repository already has main and develop branches created, with the initial folder-structure commit on both. Each phase below simply branches off develop.

# 4. Phase Overview

| **Phase** | **Title**                                                | **Primary App(s)**   |
|-----------|----------------------------------------------------------|----------------------|
| 1         | Foundation, Firebase Setup & Login                       | All (shared) + Admin |
| 2         | Admin – Customer Onboarding (Address, Map, Subscription) | Admin                |
| 3         | Admin – Pricing Engine & Delivery Calendar               | Admin                |
| 4         | Customer App – Login, History & Bill View                | Customer             |
| 5         | Customer Requests + Admin Approval Workflow              | Customer + Admin     |
| 6         | Delivery Boy App – Daily Delivery Workflow               | Delivery Boy + Admin |
| 7         | Billing Engine, Payments & Admin Reports                 | Admin                |
| 8         | Admin Web Panel, Notifications & Store Release Prep      | Admin Web + All      |

*Each phase is scoped so it can be demoed to you as a working, meaningful increment — not just internal code with nothing to see.*

Phase 1: Foundation, Firebase Setup & Login

*Get the repo, Firebase project, and all four app shells running on Windows/Android, with a working login screen.*

**Git branch: feature/phase-1-foundation**

## Tasks

- Create the Firebase project (Spark/free plan) and register all app IDs (Admin, Customer, Delivery Boy × Android/iOS).

- Wire firebase_core into all four apps; add google-services.json per app.

- Build the shared AuthService using Firebase Authentication's email/password sign-in, with mobile numbers mapped to a fixed internal address format (e.g. 9999999999@ssdfarm.app) purely so Firebase can store them — see the finalized approach below.

- Build the Admin-side “Create Login” logic using a secondary, temporary FirebaseApp instance so creating a customer/delivery-boy account never signs the Admin out of their own session.

- Build a shared login screen UI in ssd_shared (mobile number + password fields only), used by all three apps with role-based redirect.

- Set up app theming (AppTheme) and basic navigation shell for each app.

### Finalized Login Approach

Every screen the user sees only ever asks for a mobile number and a password set by Admin — there is no OTP and no visible email field anywhere. Underneath, Firebase Authentication's standard email/password sign-in does the actual work, which keeps everything client-side and free (no Cloud Functions / Blaze plan needed):

1.  A helper function converts a mobile number to an internal address, e.g. mobileToAuthEmail('9999999999') → '9999999999@ssdfarm.app'.

2.  Admin creates a customer/delivery boy: the Admin app spins up a second, temporary FirebaseApp instance (separate from the one the Admin is signed into), calls createUserWithEmailAndPassword on that instance with the converted address and the password Admin typed, then immediately signs that temporary instance out and disposes it. The Admin's own session is untouched throughout.

3.  The new user's profile (name, mobile, role, etc.) is saved to the \`users\` Firestore collection, keyed by the new Firebase Auth UID.

4.  To log in, a customer/delivery boy/admin types their mobile number and password; the app converts the mobile number the same way and calls the normal signInWithEmailAndPassword on the main FirebaseApp instance.

5.  Admin changing a user's password later works the same way — via the temporary secondary instance, sign in with the old password and call updatePassword(newPassword) — since Admin is the one who set it originally and always knows the current value.

## Commands

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<tbody>
<tr class="odd">
<td><p>cd "SSD-Application/Admin App/Mobile app"</p>
<p>flutter create --org com.ssdfarm --platforms=android,ios .</p>
<p>flutter pub add firebase_auth</p>
<p>flutter pub get</p>
<p>flutter run</p></td>
</tr>
</tbody>
</table>

(Repeat the same commands inside “Delivery Boy App” and “Customer App”, and with --platforms=web inside “Admin App/Web”.)

## Claude Code Prompts

|                                                                                                                                                                                                                                                                                               |
|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| ***Claude Code prompt:** In shared/ssd_shared/lib/services/auth_service.dart, add a mobileToAuthEmail(String mobile) helper that returns '\<mobile\>@ssdfarm.app', and implement signIn(mobile, password) using FirebaseAuth.instance.signInWithEmailAndPassword with the converted address.* |

|                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| ***Claude Code prompt:** In AuthService, add createUserAccount(mobile, password, name, role) that creates a second, temporary FirebaseApp instance (a unique name like 'temp-create-user'), uses it to call createUserWithEmailAndPassword with the converted mobile address and the given password, writes the resulting UID + name/mobile/role to the \`users\` Firestore collection using the main app instance, then signs out and deletes the temporary app instance. The currently signed-in Admin must remain signed in throughout.* |

|                                                                                                                                                                                                                                                                                                                |
|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| ***Claude Code prompt:** Build a shared LoginScreen widget inside shared/ssd_shared/lib with only a mobile number field and a password field, calling AuthService.signIn, showing loading/error states, and after login reading the user's \`role\` field from Firestore to decide which home screen to show.* |

|                                                                                                                                                                                                                                                                                    |
|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| ***Claude Code prompt:** Wire the LoginScreen into Admin App/Mobile app/lib/main.dart as the starting screen, replacing the placeholder home widget. Also add a simple AdminCreateUserScreen that calls AuthService.createUserAccount so we can test creating a login end-to-end.* |

**Client-facing deliverable at end of phase:** You can install the Admin app on an Android phone/emulator, use it to create a test customer login (mobile number + password), then log in as that customer on a second device using only that mobile number and password — proving the whole login approach end to end.

Phase 2: Admin – Customer Onboarding (Address, Map, Subscription)

*Admin can fully create and manage customers, exactly as described in Requirements §4.2–§4.3.*

**Git branch: feature/phase-2-customer-onboarding**

## Tasks

- Build the “Add Customer” form: name, mobile, password generation, society/block/floor/flat fields, auto-built Final Address.

- Integrate Google Maps SDK for pin-drop / landmark selection; store latitude/longitude.

- Save the milk type (Cow/Buffalo/Both) and default quantity at registration.

- Build the Customer List screen with search (name/mobile/society/block/flat) and filters (society, route, milk type, active status).

- Edit / deactivate / reactivate a customer.

## Commands

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<tbody>
<tr class="odd">
<td><p>cd "SSD-Application"</p>
<p>git checkout develop &amp;&amp; git pull</p>
<p>git checkout -b feature/phase-2-customer-onboarding</p>
<p>cd "Admin App/Mobile app"</p>
<p>flutter pub add google_maps_flutter</p>
<p>flutter pub get</p></td>
</tr>
</tbody>
</table>

## Claude Code Prompts

|                                                                                                                                                                                                         |
|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| ***Claude Code prompt:** Finish CustomerModel in shared/ssd_shared/lib/models/customer_model.dart by adding fromFirestore and toMap methods, then implement customer CRUD methods in FirestoreService.* |

|                                                                                                                                                                                                                                                                                                 |
|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| ***Claude Code prompt:** Build an AddEditCustomerScreen in Admin App/Mobile app/lib/screens with fields for name, mobile, society name, block name, floor, flat number, landmark, and a button that auto-generates the Final Address string by combining those fields, editable before saving.* |

|                                                                                                                                                                                                   |
|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| ***Claude Code prompt:** Add a Google Map picker screen that lets the Admin drag a pin to select the customer's exact location, and return the latitude/longitude back to AddEditCustomerScreen.* |

|                                                                                                                                                                                                                |
|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| ***Claude Code prompt:** Build a CustomerListScreen with a search bar and filter chips (society, delivery boy, milk type, active/inactive), reading from FirestoreService, matching Requirements section 4.3.* |

**Client-facing deliverable at end of phase:** Admin can add a real customer end-to-end (details + address + map pin + milk type/quantity), see them in a searchable/filterable list, and edit or deactivate them.

Phase 3: Admin – Pricing Engine & Delivery Calendar

*Implement the date-effective pricing rule and advance date exceptions (Requirements §4.5).*

**Git branch: feature/phase-3-pricing-engine**

## Tasks

- Build the Price List screen: add a new rate with an Effective-From date; automatically close the previous rate's Effective-To date.

- Build PricingService.rateEffectiveOn(milkType, date) that looks up the correct historical rate.

- Build the delivery-exception calendar: Admin can mark specific upcoming dates as “no delivery” or “different quantity” for a customer.

- Show full Price History log for audit.

## Claude Code Prompts

|                                                                                                                                                                                                                                                           |
|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| ***Claude Code prompt:** Implement PriceModel.fromFirestore/toMap and a PricingService.setNewRate(milkType, rate, effectiveFrom) method that closes the previous active price record's effectiveTo date to the day before, per Requirements section 4.5.* |

|                                                                                                                                                                                                   |
|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| ***Claude Code prompt:** Implement PricingService.rateEffectiveOn(milkType, DateTime date) that queries priceList and returns the rate whose effectiveFrom/effectiveTo range contains that date.* |

|                                                                                                                                                        |
|--------------------------------------------------------------------------------------------------------------------------------------------------------|
| ***Claude Code prompt:** Build a PriceListScreen showing current rates per milk type, a button to add a new rate, and a Price History table below it.* |

|                                                                                                                                                                                                                               |
|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| ***Claude Code prompt:** Build a calendar-based DeliveryExceptionScreen for a given customer where Admin can multi-select upcoming dates and mark them Skip or Change Quantity, saving to the deliveryExceptions collection.* |

**Client-facing deliverable at end of phase:** Admin can change today's milk price without touching any past record, see a full price history, and block/adjust specific upcoming delivery dates for any customer.

Phase 4: Customer App – Login, Delivery History & Bill View

*Customers can log in and see their real delivery and billing data (Requirements §5.1–§5.4).*

**Git branch: feature/phase-4-customer-history-billing**

## Tasks

- Reuse the shared LoginScreen for the Customer app.

- Build the Customer dashboard: next delivery, current outstanding amount.

- Build Delivery History list/calendar with date range, milk type, and status filters.

- Build the Bill view with a day-wise breakup showing the rate applied each day (proving the pricing engine from Phase 3 is correct end-to-end).

## Claude Code Prompts

|                                                                                                                                                    |
|----------------------------------------------------------------------------------------------------------------------------------------------------|
| ***Claude Code prompt:** Wire the shared LoginScreen into Customer App/lib/main.dart, redirecting to a CustomerHomeScreen after successful login.* |

|                                                                                                                                                                                                   |
|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| ***Claude Code prompt:** Build CustomerHomeScreen showing the next scheduled delivery and current outstanding balance, reading from FirestoreService for the logged-in customer's own data only.* |

|                                                                                                                                                                                                                                                               |
|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| ***Claude Code prompt:** Build a DeliveryHistoryScreen with date range and status filters, and a BillViewScreen that lists each delivered day with the milk type, quantity, rate applied, and amount, matching the worked example in Requirements section 9.* |

**Client-facing deliverable at end of phase:** A real customer can log in on their own phone and see their actual delivery history and an accurate bill that correctly reflects any mid-month price change.

Phase 5: Customer Requests + Admin Approval Workflow

*Close the loop on quantity-change/skip requests with Admin approval (Requirements §5.5 & §4.7).*

**Git branch: feature/phase-5-request-approval-workflow**

## Tasks

- Customer app: “Skip a day” and “Change quantity” flow on an upcoming date, with the “this date only vs. from this date onward” choice.

- Request is written as a pending deliveryExceptions document.

- Admin app: build the Approval Queue inbox listing all pending requests with Approve/Reject + note.

- On approval, automatically update the affected delivery plan; notify the customer either way.

## Claude Code Prompts

|                                                                                                                                                                                                                                                                                |
|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| ***Claude Code prompt:** Build a RequestChangeScreen in Customer App that lets the user pick an upcoming date, choose Skip or Change Quantity, and if changing quantity, choose 'this date only' or 'from this date onward', then save a pending deliveryExceptions document.* |

|                                                                                                                                                                                                                    |
|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| ***Claude Code prompt:** Build an ApprovalQueueScreen in Admin App listing all pending deliveryExceptions documents with customer name, requested change, and Approve/Reject buttons plus an optional note field.* |

|                                                                                                                                                                                                                                  |
|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| ***Claude Code prompt:** When Admin approves a request, update the customer's subscription or the specific delivery record accordingly, mark the request Approved, and write an in-app notification document for that customer.* |

**Client-facing deliverable at end of phase:** A customer can request a change or skip, see it as Pending, and once Admin approves or rejects it from the Admin app, the customer sees the outcome and the delivery plan updates automatically.

Phase 6: Delivery Boy App – Daily Delivery Workflow

*Delivery staff get their daily list and can mark deliveries in real time (Requirements §6).*

**Git branch: feature/phase-6-delivery-boy-workflow**

## Tasks

- Build the Daily Delivery List grouped by Society → Block, reflecting Admin-approved exceptions from Phase 5.

- Mark Delivered / Not Delivered (with mandatory reason) + optional remark, syncing instantly to the Admin app.

- End-of-day summary screen.

- Basic offline caching so marks made with poor network sync once connectivity returns.

## Claude Code Prompts

|                                                                                                                                                                                                                                        |
|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| ***Claude Code prompt:** Build a DailyDeliveryListScreen in Delivery Boy App that queries today's deliveries for the logged-in delivery boy, grouped by society and block, showing customer name, flat/floor, milk type and quantity.* |

|                                                                                                                                                                                                                                          |
|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| ***Claude Code prompt:** Add Mark Delivered and Mark Not Delivered buttons per entry; Not Delivered must require selecting a reason, and both should allow an optional free-text remark, writing straight to the deliveries collection.* |

|                                                                                                                                                                                                |
|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| ***Claude Code prompt:** Add a live listener in the Admin app's delivery tracking screen (Requirements section 4.4) so marks from the Delivery Boy app appear immediately without refreshing.* |

|                                                                                                                                                                               |
|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| ***Claude Code prompt:** Add basic offline persistence using Firestore's built-in offline cache so marks made with no signal sync automatically once the connection returns.* |

**Client-facing deliverable at end of phase:** A delivery boy can walk their real route, mark each stop delivered or not with a reason/remark, and Admin sees it update live on their own screen — the full 3-app loop is now working end to end.

Phase 7: Billing Engine, Payments & Admin Reports

*Full monthly billing, payment recording, and all Admin reports (Requirements §4.6, §4.9).*

**Git branch: feature/phase-7-billing-reports**

## Tasks

- Build PricingService.generateBill(customerId, periodFrom, periodTo), summing each delivered day at that day's effective rate.

- Bill screen: day-wise breakup, totals, previous dues, mark payments received (Cash/UPI/Bank).

- Outstanding dues report with filters.

- All remaining Admin reports (delivery, collection, consumption/demand, customer activity, delivery-boy performance), each with filters and CSV/PDF export.

## Claude Code Prompts

|                                                                                                                                                                                                                                                                                                                           |
|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| ***Claude Code prompt:** Implement PricingService.generateBill(customerId, periodFrom, periodTo) that reads all delivered-status deliveries in that range, looks up the rate that was effective on each date, and returns a BillModel with a full line-item breakdown, per the worked example in Requirements section 9.* |

|                                                                                                                                                                                        |
|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| ***Claude Code prompt:** Build a BillGenerationScreen for Admin to generate and view a customer's bill, record a payment (cash/UPI/bank) against it, and see the updated net payable.* |

|                                                                                                                                           |
|-------------------------------------------------------------------------------------------------------------------------------------------|
| ***Claude Code prompt:** Build an OutstandingDuesReportScreen with filters for society, amount range, and overdue days, plus CSV export.* |

|                                                                                                                                                                                                                                                                                  |
|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| ***Claude Code prompt:** Build the remaining Admin reports listed in Requirements section 4.9 (delivery report, collection report, consumption/demand report, customer activity report, delivery-boy performance report), each with the filters specified and an export button.* |

**Client-facing deliverable at end of phase:** Admin can generate an accurate monthly bill for any customer (correctly split across price changes), record payments, and run every report from the requirements document with working filters and export.

Phase 8: Admin Web Panel, Notifications & Store Release Prep

*Desktop access for office staff, in-app notifications, and getting both stores ready (Requirements §4.10, §2.4, §11).*

**Git branch: feature/phase-8-web-notifications-release**

## Tasks

- Build/port the Admin Web app (desktop-optimized layout, same shared package and Firebase project).

- Build the in-app notification centre (Firestore-listener based, per §2.4) across all three apps.

- App icons, splash screens, and basic QA pass on both apps across a few real Android devices.

- Prepare Play Store listing and signed Android release (.aab).

- iOS pass on a Mac: run flutter build ios, fix any platform-specific issues, prepare App Store Connect listing and TestFlight build.

## Commands

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<tbody>
<tr class="odd">
<td><p># Android release build (Windows)</p>
<p>cd "Admin App/Mobile app"</p>
<p>flutter build appbundle --release</p>
<p># iOS release build (on a Mac, once available)</p>
<p>flutter build ios --release</p>
<p>open ios/Runner.xcworkspace # then Archive &amp; upload via Xcode</p></td>
</tr>
</tbody>
</table>

## Claude Code Prompts

|                                                                                                                                                                                                                         |
|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| ***Claude Code prompt:** Adapt the Admin app's screens for a wider desktop layout (side navigation instead of bottom tabs) for Admin App/Web, reusing the same screens and ssd_shared package as the mobile Admin app.* |

|                                                                                                                                                                                                                                  |
|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| ***Claude Code prompt:** Build a shared NotificationCentreWidget in ssd_shared that listens to the notifications collection for the current user and shows an unread-count badge, then add it to the app bar of all three apps.* |

|                                                                                                                                                         |
|---------------------------------------------------------------------------------------------------------------------------------------------------------|
| ***Claude Code prompt:** Add app icons and splash screens to all four app targets using the flutter_launcher_icons and flutter_native_splash packages.* |

|                                                                                                                                                                             |
|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| ***Claude Code prompt:** Review the app for any TODOs left in shared/ssd_shared and each app's screens, and list anything still incomplete before we do the release build.* |

**Client-facing deliverable at end of phase:** Office staff can use the Admin panel from a desktop browser, everyone gets in-app notifications, and you have a signed Android build ready for the Play Store plus an iOS build ready for TestFlight/App Store submission.

# 5. After Phase 8

Once all 8 phases are approved, main will contain a fully working, store-ready version of all three apps. From here, further work (the Future Enhancements listed in the Requirements Document §4.11/§12 — online payments, route optimization, multi-staff roles, etc.) can be planned as additional phases using the exact same branch-per-phase workflow described in §3.
