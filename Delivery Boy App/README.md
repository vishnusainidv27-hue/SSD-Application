# SSD Farm — Delivery Boy App

Platforms: Android, iOS

## First-time setup
```
cd "Delivery Boy App"
flutter create --org com.ssdfarm --platforms=android,ios .
flutter pub get
flutter run
```
(For the Web app, use `--platforms=web` instead, and run with `flutter run -d chrome`.)

This regenerates the native `android/`, `ios/`, or `web/` folders around the
existing `lib/` and `pubspec.yaml` — it will not overwrite your Dart code.

See `docs/SSD_Farm_Development_Plan.docx` for what to build in each phase.
