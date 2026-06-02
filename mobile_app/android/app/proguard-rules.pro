# ── Firebase ──────────────────────────────────────────────────
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# ── Supabase / GoTrue / PostgREST ─────────────────────────────
-keep class io.supabase.** { *; }
-dontwarn io.supabase.**

# ── Kotlin serialization ─────────────────────────────────────
-keepclassmembers class kotlinx.serialization.** { *; }
-keep,includedescriptorclasses class com.focusecho.ai.**$$serializer { *; }
-keepclassmembers class com.focusecho.ai.** {
    *** Companion;
}

# ── OkHttp / Retrofit (used transitively by Supabase) ────────
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }

# ── Flutter ───────────────────────────────────────────────────
-keep class io.flutter.** { *; }
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# ── Focus Echo Services ───────────────────────────────────────
-keep class com.focusecho.ai.FocusAccessibilityService { *; }
-keep class com.focusecho.ai.FocusDetectionService { *; }
-keep class com.focusecho.ai.DistractionEventQueue { *; }

# ── JSON / Gson ───────────────────────────────────────────────
-keep class org.json.** { *; }
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}
