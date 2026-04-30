# LPC LLC Proguard Rules

# Flutter-specific rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep Firebase and Google Play Services
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# Keep PDF and Printing libraries
-keep class com.baseflow.geolocator.** { *; }
-keep class net.nfet.flutter.printing.** { *; }

# Keep Models and Serialized Classes
-keepclassmembers class * {
  @com.google.gson.annotations.SerializedName <fields>;
}

# General shrinking prevention for dynamically loaded classes
-dontwarn io.flutter.embedding.**
-dontwarn com.google.firebase.**
