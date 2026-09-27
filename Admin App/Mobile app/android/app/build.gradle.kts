import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Google Maps API key lives in android/local.properties (gitignored) as
// MAPS_API_KEY=... so it never enters git. Builds still work without it; the
// map picker just shows a blank map.
val mapsApiKey: String = Properties().let { props ->
    val file = rootProject.file("local.properties")
    if (file.exists()) file.inputStream().use { props.load(it) }
    props.getProperty("MAPS_API_KEY", "")
}

// Release signing: reads android/key.properties (gitignored) if it exists,
// so `flutter build appbundle --release` produces a properly signed .aab
// once you have a production keystore. Claude Code deliberately never
// generates this keystore itself — see the release-readiness checklist in
// docs/PROJECT_STATUS.md: losing it (or its password) means the app can
// never be updated again under the same identity on the Play Store, so
// creating it is yours to do and back up safely.
//
// To enable: run
//   keytool -genkey -v -keystore <path>.jks -keyalg RSA -keysize 2048 -validity 10000 -alias <your-alias>
// then create android/key.properties next to this file's project root with:
//   storeFile=<path to the .jks, relative to android/app/ or absolute>
//   storePassword=<the keystore password>
//   keyAlias=<your-alias>
//   keyPassword=<the key password>
// Until key.properties exists, release builds keep signing with the debug
// key (as the Flutter template does by default) so `flutter run --release`
// and `flutter build apk --debug` keep working during development.
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseSigning = keystorePropertiesFile.exists()
val keystoreProperties = Properties().apply {
    if (hasReleaseSigning) keystorePropertiesFile.inputStream().use { load(it) }
}

android {
    namespace = "com.ssdfarm.admin_mobile_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.ssdfarm.admin_mobile_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["MAPS_API_KEY"] = mapsApiKey
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                // No android/key.properties yet — see the comment above.
                signingConfigs.getByName("debug")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
