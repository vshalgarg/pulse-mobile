# -------------------------
# Flutter
# -------------------------
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# -------------------------
# Flutter deferred components
# -------------------------
-keep class io.flutter.embedding.engine.deferredcomponents.** { *; }

# -------------------------
# Play Core (Deferred Components)
# -------------------------
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**

# -------------------------
# Firebase
# -------------------------
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# -------------------------
# Google Play Services
# -------------------------
-keep class com.google.android.gms.** { *; }

# -------------------------
# Kotlin metadata
# -------------------------
-keep class kotlin.Metadata { *; }

# -------------------------
# Native methods
# -------------------------
-keepclasseswithmembers class * {
    native <methods>;
}