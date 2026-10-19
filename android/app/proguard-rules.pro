# ML Kit Text Recognition Proguard / R8 rules
-keep class com.google.mlkit.** { *; }
-keep interface com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

-keep class com.google.android.gms.** { *; }
-keep interface com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

-keep class com.google_mlkit_text_recognition.** { *; }
-dontwarn com.google_mlkit_text_recognition.**

# Llama CPP Dart
-keep class com.llama.** { *; }
-dontwarn com.llama.**

# Flutter / Plugins
-keep class io.flutter.** { *; }
-dontwarn io.flutter.**
