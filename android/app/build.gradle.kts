// build.gradle.kts 
plugins {
    id("com.android.application")
    // Apply Flutter after the Android and Kotlin plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.taskflow"

    // permission_handler_android requires Android SDK 37+.
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    // Kotlin JVM target: Java 17
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
            isMinifyEnabled = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            // keep your existing signingConfig line
        }
    }
}

dependencies {
    // Required for flutter_local_notifications desugaring.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}

// flutter_eval creates IconData at runtime, so disable icon tree shaking.
gradle.taskGraph.whenReady {
    allTasks
        .filter { it.name.startsWith("compileFlutterBuild") }
        .forEach { task ->
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
