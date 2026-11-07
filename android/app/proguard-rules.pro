# Flutter wraps most of this already; these keep the plugins we use from being
# stripped by R8 in release builds.
-keep class io.flutter.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn io.flutter.embedding.**
