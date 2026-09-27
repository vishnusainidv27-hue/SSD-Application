# SSD Farm — Design System

**Reference doc for how every screen should look.** If you're building a new
screen or editing an old one, match what's here rather than inventing a new
pattern. Everything described lives in `shared/ssd_shared` and is inherited
automatically by all four apps (Admin Mobile, Admin Web, Customer, Delivery
Boy) — most of it needs no per-screen code at all.

---

## 1. Brand & Colors

The palette is sampled directly from the SSD Farm (Shree Shyam Dairy Farm)
logo (`docs/branding/logo_original.jpg`), not invented. Defined as named
constants on `AppTheme` (`shared/ssd_shared/lib/theme/app_theme.dart`):

| Name | Hex | From the logo | Used for |
|---|---|---|---|
| `AppTheme.brandNavy` | `#1F425B` | Outer ring & lettering | Primary color — AppBar, primary buttons, headings |
| `AppTheme.brandGold` | `#C79A45` | Wheat sheaves | Secondary accent — highlights, selected states |
| `AppTheme.brandGreen` | `#6B8E4E` | Fields | Tertiary — also **the standing "success" color** (delivered / approved / paid-up) |
| `AppTheme.brandCream` | `#FBF6E8` | Badge background | Scaffold background, splash screens |
| `AppTheme.surfaceCream` | `#FFFDF8` | (derived, slightly lighter) | Cards, dialogs, input fill — anything that sits *on* the cream background |

**Status color convention** (used everywhere a chip/icon shows a state —
deliveries, requests, bills): this isn't arbitrary per screen, it's the same
mapping throughout, via `Theme.of(context).colorScheme`:

- `tertiary` (green) → delivered / approved / paid / on track
- `error` (Material's red, derived from the seed) → not delivered / rejected / overdue
- `outline` (neutral gray) → skipped / inactive / not applicable
- `primary` (navy) → pending / in progress

Don't hardcode a status color — use the scheme role above so a future palette
change (a new logo, a rebrand) updates every screen at once.

To replace the logo/palette later: see the note at the bottom of
`shared/ssd_shared/lib/theme/app_theme.dart` and PROJECT_STATUS.md's Phase 8
entry — swap the source image, re-sample the four colors, update the four
constants, done. No screen needs to change.

## 2. Spacing

`AppSpacing` (same file as `AppTheme`) is the only spacing scale to use in
new code — don't write bare numbers like `SizedBox(height: 18)`:

```dart
AppSpacing.xs  // 4  — tight gaps (icon-to-label)
AppSpacing.sm  // 8  — gap between related elements
AppSpacing.md  // 16 — a screen's default padding, gap between unrelated elements
AppSpacing.lg  // 24 — gap above a new section
AppSpacing.xl  // 32 — bottom padding on a scrollable list
```

## 3. Typography

Material 3's default type scale, unmodified — `headlineSmall`,
`titleLarge/Medium/Small`, `bodyLarge/Medium/Small`, `labelLarge` etc. via
`Theme.of(context).textTheme`. The only customization is that `AppBar` titles
and `SectionHeader`/header-card titles are bolded (`FontWeight.w600/w700`) for
more visual weight — see the component notes below.

## 4. Global component theme

Set once in `AppTheme.light` and inherited everywhere — **don't override these
per-screen** unless there's a specific reason:

- **AppBar** — solid `brandNavy` background, white text/icons, left-aligned
  title (not centered), no elevation/shadow.
- **Card** — `surfaceCream` fill, 16px rounded corners, a subtle 1px outline,
  1dp elevation. Default margin is a small vertical gap; screens that lay
  cards out in a list/grid themselves pass `margin: EdgeInsets.zero` and
  handle spacing with `AppSpacing` instead.
- **Buttons** — `FilledButton` (primary action), `OutlinedButton` (secondary
  action), `TextButton` (tertiary/dialog actions) all get 12px rounded
  corners and semi-bold labels. `FilledButton.tonal` (secondaryContainer,
  i.e. gold-tinted) is for a lower-emphasis "still primary-ish" action.
- **Chips** (`Chip`/`FilterChip`/`ChoiceChip`) — stadium (fully rounded)
  shape, navy-tinted background, filled/selected state in solid navy.
- **Text fields** — filled (`surfaceCream`), 12px rounded border, 2px navy
  border when focused.
- **Divider** — subtle, 24px of vertical space around it by default.
- **SnackBar** — floating, solid navy background, white text, rounded.
- **Dialog** — `surfaceCream` background, 20px rounded corners.
- **NavigationRail** (Admin Web only) — cream background, navy-on-gold
  selection indicator.

## 5. Shared widgets — use these instead of ad hoc versions

### `SectionHeader`
`shared/ssd_shared/lib/widgets/section_header.dart`

The title above a group of related fields/rows (a form section, a report's
group, "Upcoming changes", "Payment history", …). Every screen that used to
build its own bespoke section-title `Text` now uses this instead.

```dart
const SectionHeader('Address', icon: Icons.home_outlined)
// or, for the first section on a screen (skip the usual top gap):
const SectionHeader('Customer', icon: Icons.person_outline, topGap: false)
```

### `EmptyState`
`shared/ssd_shared/lib/widgets/empty_state.dart`

The full-body placeholder for "nothing here yet" or "couldn't load this" —
replaces every screen's old bare `Center(child: Text('...'))`. Pick an icon
that matches the situation (`Icons.error_outline` for a load failure,
something meaningful for "no data yet" — see the examples already in the
codebase for the tone to match).

```dart
const EmptyState(
  icon: Icons.local_shipping_outlined,
  message: 'No deliveries assigned for today.',
)
```

A short inline message that lives *inside* an already-populated screen (e.g.
"No price history yet." under a card that has other content) doesn't need
the full `EmptyState` treatment — a plain `Text` is fine there. `EmptyState`
is for when it's the *entire* body of the screen/list.

### `NotificationCentre`
`shared/ssd_shared/lib/widgets/notification_centre.dart`

The bell-icon-with-badge in every app's `AppBar.actions` (or the Admin Web
nav rail). Takes the signed-in user's id and a `FirestoreService`. Don't
build a second notification UI — extend this one if it needs to do more.

## 6. Page layout pattern (home/landing screens)

All three mobile apps' home screens (`AdminHomeScreen`,
`CustomerHomeScreen`, `DailyDeliveryListScreen`'s header) follow the same
shape — match it for any new top-level screen:

1. A **header card**: solid `brandNavy` background, 20px rounded corners, a
   `CircleAvatar` (icon or initial) + a bold white title + a short white
   (85% opacity) subtitle. Used for a greeting ("Welcome back, Asha") or a
   live status summary ("6 of 9 delivered today").
2. **Grouped, titled sections** below it via `SectionHeader`, each holding
   either: a `Card`-based grid of tappable action tiles (Admin home — see
   `_ActionGrid`/`_ActionTile` in `admin_home_screen.dart`), or content cards
   (Customer home's delivery/outstanding cards).
3. Everything scrolls in one `ListView`/`Column` with `AppSpacing.md` outer
   padding — no nested scroll views, no fixed-height sections.

## 7. Where things live

- Theme, spacing, shared widgets: `shared/ssd_shared/lib/theme/app_theme.dart`,
  `shared/ssd_shared/lib/widgets/`.
- Logo source files: `docs/branding/` (`logo_original.jpg` is the source of
  truth; `logo_icon_square.png` is the cropped square used to derive every
  app's icon).
- Per-app icon/splash assets: `<app>/assets/icon/app_icon*.png`, generated via
  `flutter_launcher_icons` + `flutter_native_splash` — see the comment block
  above those tools' config in each app's `pubspec.yaml` for the exact
  regeneration commands.
