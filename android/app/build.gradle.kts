plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.taskflow"
    // permission_handler_android requires compiling against SDK 37+.
    // Overriding flutter.compileSdkVersion (currently 36) directly,
    // since Android SDKs are backward compatible this is safe even
    // though minSdk/targetSdk stay wherever Flutter's own config sets
    // them.
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
         // flutter_local_notifications needs core library desugaring
        // enabled — it uses java.time APIs under the hood that aren't
        // natively available below Android 8 (API 26) without this.
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.example.taskflow"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    // Renames the generated APK(s) so `flutter build apk --release` produces
    // TaskFlow.apk directly under build/app/outputs/flutter-apk/, instead of
    // the default app-release.apk. Applies to every variant/flavor, so a
    // debug build would come out as TaskFlow-debug.apk, etc.
    applicationVariants.all {
        val variant = this
        variant.outputs
            .map { it as com.android.build.gradle.internal.api.BaseVariantOutputImpl }
            .forEach { output ->
                val suffix = if (variant.buildType.name == "release") "" else "-${variant.buildType.name}"
                output.outputFileName = "TaskFlow$suffix.apk"
            }
    }
}
dependencies {
    // The actual desugaring library the flag above requires.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}

// flutter_eval constructs IconData at runtime, which Flutter's icon tree-shaker rejects.
gradle.taskGraph.whenReady {
    allTasks.filter { it.name.startsWith("compileFlutterBuild") }.forEach { task ->
        val setter =
            generateSequence(task.javaClass as Class<*>?) { it.superclass }
                .flatMap { it.declaredMethods.asSequence() }
                .firstOrNull { it.name == "setTreeShakeIcons" }
        setter?.apply {
            isAccessible = true
            invoke(task, false)
        }
    }
}