# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }
-dontwarn io.flutter.embedding.**

# Firebase / Play Services
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Google Sign-In
-keep class com.google.android.gms.auth.** { *; }

# Keep model/data classes used with Firestore reflection-free (de)serialization.
# Adjust the package below if lib/models moves.
-keepclassmembers class com.cletustech.edusphere.** {
    <init>(...);
}

# General Android
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable

# Flutter's engine references Play Store split-delivery classes
# (deferred/dynamic feature components) even when unused. This app
# doesn't include com.google.android.play:core, so these classes
# genuinely don't exist — that's expected, not a real problem.
-dontwarn com.google.android.play.core.**
