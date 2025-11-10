plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin") // Flutter plugin
    // Remove Google Services if you fully migrate to Supabase
    // id("com.google.gms.google-services")
}

android {
    namespace = "com.example.network_predicter"
    compileSdk = 36
    ndkVersion = "27.0.12077973"

    defaultConfig {
        applicationId = "com.example.network_predicter"
        minSdk = flutter.minSdkVersion // Supports runtime permissions
        targetSdk = 36
        versionCode = 1
        versionName = "1.0.0"
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = "11"
    }

    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

dependencies {
    // Core Kotlin & Android
    implementation("androidx.core:core-ktx:1.10.1")
    implementation("androidx.appcompat:appcompat:1.6.1")

    // Location services
    implementation("com.google.android.gms:play-services-location:21.0.1")

    // Optional: lifecycle aware components (helpful if you need to observe foreground service)
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.6.2")

    // Optional: Kotlin coroutines if you want async work
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.7.3")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-play-services:1.7.3")

    implementation("org.json:json:20230227")
    implementation("com.squareup.okhttp3:okhttp:4.12.0")


}

flutter {
    source = "../.."
}
