# Keep Supabase / GoTrue
-keep class io.supabase.** { *; }
-dontwarn io.supabase.**
# Keep drift (ORM) generated code is Dart-side; protect native sqlite libs consumers.
-keep class org.sqlite.** { *; }
-dontwarn org.sqlite.**
# flutter_local_notifications
-keep class com.dexterous.** { *; }
-dontwarn com.dexterous.**
# Supabase Kotlin client
-keep class io.github.jan.** { *; }
-dontwarn io.github.jan.**
