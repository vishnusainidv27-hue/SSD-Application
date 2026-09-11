# SSD Farm – Milk Delivery Application

Monorepo containing all SSD Farm applications, built with **Flutter** and **Firebase**.

## Folder Structure

```
SSD-Application/
├── docs/                     Project documents (requirements + development plan)
├── firebase/                 Shared Firebase config: security rules, indexes
├── shared/
│   └── ssd_shared/           Shared Dart package: models, Firebase services, theme, constants
│                             (imported by all three apps via a local path dependency)
├── Admin App/
│   ├── Mobile app/           Flutter app (Android + iOS) for the Admin/office
│   └── Web/                  Flutter web build of the Admin panel (desktop use)
├── Delivery Boy App/         Flutter app (Android + iOS) for delivery staff
└── Customer App/             Flutter app (Android + iOS) for end customers
```

## One-time setup (Windows, VS Code)

1. Install the Flutter SDK and add it to PATH: https://docs.flutter.dev/get-started/install/windows
2. Run `flutter doctor` and resolve any red flags (Android toolchain, VS Code plugin).
3. Install the **Flutter** and **Dart** extensions in VS Code.
4. Clone this repo, then open the `SSD-Application` folder in VS Code (`code .`).
5. Each app folder is a normal Flutter project. The very first time, run inside each app folder:
   ```
   flutter create --org com.ssdfarm --platforms=android,ios .
   ```
   This safely generates the native `android/` and `ios/` folders around the existing `lib/` and `pubspec.yaml` without overwriting your Dart code.
6. Then, in each app folder: `flutter pub get`.

See `docs/SSD_Farm_Development_Plan.docx` for the full phase-by-phase build plan and the exact commands/prompts to use at each stage.
