# ============================================================================
# OTPBridge — ProGuard / R8 keep rules (release build)
# ----------------------------------------------------------------------------
# Philosophy: be CONSERVATIVE. Favour keeping over stripping. R8 with
# `proguard-android-optimize.txt` still shrinks/optimises everything not
# explicitly kept, so the misses that break a release build are almost always
# reflection-based plugin internals. The rules below keep those surfaces.
# ============================================================================

# ---- Global attributes -----------------------------------------------------
# Keep annotations (used by Razorpay, Gson-style serialisers, DI, etc.),
# generic signatures (needed for TypeToken / reflection over generics) and
# checked-exception metadata.
-keepattributes *Annotation*, Signature, Exceptions, InnerClasses, EnclosingMethod
-keepattributes SourceFile, LineNumberTable

# Keep all native method names + their declaring classes (JNI lookups are by
# name; renaming them silently breaks native <-> Java/Kotlin bridging).
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep enum sugar methods (values()/valueOf are reached reflectively).
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Keep Parcelable CREATOR fields (framework instantiates via reflection).
-keepclassmembers class * implements android.os.Parcelable {
    public static final ** CREATOR;
}

# Keep R.raw etc. referenced by name; and annotation default methods.
-keepclassmembers class **.R$* {
    public static <fields>;
}

# ============================================================================
# Flutter embedding + engine
# ============================================================================
-keep class io.flutter.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.embedding.**

# App's own platform-channel entry points (SmsReceiver / SmsListenerService /
# MainActivity are referenced from the manifest and via JNI/registrant).
-keep class com.otpbridge.otpbridge.** { *; }

# ============================================================================
# Kotlin runtime + metadata
# ============================================================================
-keep class kotlin.** { *; }
-keep class kotlin.Metadata { *; }
-dontwarn kotlin.**
-keepclassmembers class **$WhenMappings {
    <fields>;
}
-keepclassmembers class kotlin.Metadata {
    public <methods>;
}
# Kotlin coroutines (used transitively by several plugins).
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory {}
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler {}
-dontwarn kotlinx.coroutines.**

# ============================================================================
# Razorpay (razorpay_flutter) — heavy reflection + bundled proguard annotations
# ============================================================================
-keep class com.razorpay.** { *; }
-keep class com.razorpay.**$* { *; }
-dontwarn com.razorpay.**
# Razorpay ships its own proguard annotation package; keep it and anything it
# annotates so the checkout/analytics SDK is not stripped.
-keep class proguard.annotation.** { *; }
-keep @proguard.annotation.Keep class * { *; }
-keepclassmembers class * {
    @proguard.annotation.Keep *;
}
-keepclasseswithmembers class * {
    @proguard.annotation.KeepClassMembers *;
}
-dontwarn proguard.annotation.**
# Razorpay pulls in Google Pay / easypay webview bridges — keep JS interfaces.
-keepattributes JavascriptInterface
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}
-dontwarn com.google.android.apps.nbu.paisa.**

# ============================================================================
# Hive / hive_flutter (type adapters resolved reflectively at open time)
# ============================================================================
-keep class ** implements hive.** { *; }
-keep,allowobfuscation @interface hive.annotations.**
-keepclassmembers class * {
    @hive.annotations.* <fields>;
}
-dontwarn hive.**

# ============================================================================
# flutter_secure_storage (backed by AndroidX Security / Tink crypto)
# ============================================================================
-keep class com.it_nomads.fluttersecurestorage.** { *; }
-keep class androidx.security.crypto.** { *; }
-keep class com.google.crypto.tink.** { *; }
-dontwarn com.google.crypto.tink.**

# ============================================================================
# local_auth (BiometricPrompt / KeyStore reflection)
# ============================================================================
-keep class io.flutter.plugins.localauth.** { *; }
-keep class androidx.biometric.** { *; }
-dontwarn androidx.biometric.**

# ============================================================================
# permission_handler
# ============================================================================
-keep class com.baseflow.permissionhandler.** { *; }
-dontwarn com.baseflow.permissionhandler.**

# ============================================================================
# flutter_local_notifications (uses Gson for scheduled-notification payloads;
# core-library desugaring for java.time)
# ============================================================================
-keep class com.dexterous.** { *; }
-keep class com.dexterous.flutterlocalnotifications.** { *; }
# Gson bundled by the plugin — keep model/type-adapter reflection surfaces.
-keep class com.google.gson.** { *; }
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
-keep public class * implements java.lang.reflect.Type
-keepclassmembers,allowobfuscation class * {
    @com.google.gson.annotations.SerializedName <fields>;
    @com.google.gson.annotations.Expose <fields>;
}
-dontwarn com.google.gson.**
# The plugin references generic types via TypeToken; keep its own models.
-keep class com.dexterous.flutterlocalnotifications.models.** { *; }

# ============================================================================
# flutter_contacts
# ============================================================================
-keep class co.quis.flutter_contacts.** { *; }
-dontwarn co.quis.flutter_contacts.**

# ============================================================================
# dio / networking (OkHttp / Okio may be pulled transitively; Conscrypt is
# referenced conditionally by OkHttp on some setups)
# ============================================================================
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn org.conscrypt.**
-dontwarn org.bouncycastle.**
-dontwarn org.openjsse.**
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }
-keep class okio.** { *; }

# ============================================================================
# shared_preferences
# ============================================================================
-keep class io.flutter.plugins.sharedpreferences.** { *; }

# ============================================================================
# AndroidX / Play core (Flutter deferred components stubs) — silence warnings
# ============================================================================
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }
-dontwarn javax.annotation.**
-dontwarn javax.lang.model.element.**

# ============================================================================
# General: don't warn on missing optional annotation processors.
# ============================================================================
-dontwarn org.jetbrains.annotations.**
-dontwarn kotlin.jvm.internal.**
