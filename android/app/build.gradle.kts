plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Requires android/app/google-services.json (run `flutterfire configure`).
    // Comment this out if you need a build before Firebase is wired up.
    id("com.google.gms.google-services")
}

android {
    // TODO: adjust to match Cletus Tech's real reverse-domain if different.
    namespace = "com.cletustech.edusphere"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // Must stay identical to `namespace` unless you have a reason to split them.
        applicationId = "com.cletustech.edusphere"
        // firebase_auth / google_sign_in on current versions require >= 23.
        minSdk = 23
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    signingConfigs {
        // Debug signing is used for the release build below only so that
        // `flutter run --release` / `flutter build apk` work out of the box.
        // Replace with a real upload keystore before shipping to Play.
        getByName("debug") {}
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
        debug {
            isMinifyEnabled = false
            // No applicationIdSuffix: google-services.json only registers
            // com.cletustech.edusphere (no ".debug" variant added in the
            // Firebase console), so debug must keep the same package name
            // or the Google Services Gradle plugin fails the build with
            // "No matching client found for package name ...debug".
        }
    }

    packaging {
        resources {
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Version-aligns all `com.google.firebase:firebase-*` artifacts pulled in
    // transitively by the FlutterFire plugins declared in pubspec.yaml.
    implementation(platform("com.google.firebase:firebase-bom:33.1.2"))
    implementation("androidx.multidex:multidex:2.0.1")
}
