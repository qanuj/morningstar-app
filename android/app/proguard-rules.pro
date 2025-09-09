# Flutter specific rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep all Flutter classes
-dontwarn io.flutter.embedding.**

# Keep HTTP/HTTPS networking
-keep class okhttp3.** { *; }
-keep class okio.** { *; }
-dontwarn okhttp3.**
-dontwarn okio.**

# Keep image loading classes
-keep class com.caverock.androidsvg.** { *; }

# Keep JSON serialization
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.google.gson.** { *; }

# Keep shared preferences
-keep class android.content.SharedPreferences** { *; }

# Keep file picker classes
-keep class com.mr.flutter.plugin.filepicker.** { *; }

# Keep image picker/cropper classes
-keep class io.flutter.plugins.imagepicker.** { *; }
-keep class com.yalantis.ucrop.** { *; }

# Keep provider classes
-keep class ** extends androidx.lifecycle.ViewModel { *; }

# General Flutter rules
-keep class androidx.lifecycle.** { *; }
-keep class * extends java.util.ListResourceBundle {
    protected java.lang.Object[][] getContents();
}