# R8 / ProGuard keep rules for Godot + AdMob (Play Console R8 suggestion).
-keep class com.godot.** { *; }
-keep class org.godotengine.** { *; }
-keep class ** extends org.godotengine.godot.plugin.GodotPlugin { *; }

-keep class com.google.android.gms.** { *; }
-keep class com.google.android.ump.** { *; }
-keep class com.google.ads.** { *; }

-dontwarn org.godotengine.**
-dontwarn com.google.android.gms.**
-dontwarn com.google.android.ump.**
