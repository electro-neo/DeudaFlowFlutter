plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.deuda_flow_flutter"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "29.0.13599879"

    signingConfigs {
        create("release") {
            storeFile = file("C:/Users/MARIA/OneDrive/Desktop/Aplicacion Deudas/release-key.jks")
            storePassword = "23893937d" // Cambia aquí por tu contraseña real si es diferente
            keyAlias = "deuda_flow_release"
            keyPassword = "23893937d" // Cambia aquí por tu contraseña real si es diferente
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.example.deuda_flow_flutter"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}


