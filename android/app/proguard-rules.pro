# mapvina_gl: the plugin's offline module references classes that are not in the SDK jar (R8 "Missing classes"),
# and the SDK is reached through JNI/reflection, so keep it untouched.
-dontwarn com.mapvina.**
-keep class com.mapvina.** { *; }
-keep class io.github.mapvina.** { *; }
