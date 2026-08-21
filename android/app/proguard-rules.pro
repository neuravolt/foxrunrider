# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# Keep native methods
-keepclassmembers class * {
    native <methods>;
}

# Play Core (for deferred components)
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**

# Keep domain models and data entities from R8/ProGuard obfuscation
-keep class com.foxrunmobility.rider.** { *; }
-keep class ride_on.domain.entities.** { *; }
-keep class ride_on.data.** { *; }
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# Suppress optional annotation warning used by transitive telemetry deps.
-dontwarn com.google.auto.value.AutoValue$CopyAnnotations
