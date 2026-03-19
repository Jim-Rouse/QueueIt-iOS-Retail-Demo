# Queue-it Android SDK — keep all SDK classes
-keep class com.queue_it.androidsdk.** { *; }
-dontwarn com.queue_it.androidsdk.**

# Gson — keep model classes used for JSON parsing
-keep class com.queueit.retaildemo.model.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
