plugins {
    id("com.android.application")
    id("kotlin-android")
    // Flutter plugin MUST come after the Android and Kotlin plugins
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.expense_tracker"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    // ใช้ Java 17 สำหรับโค้ดโมดูล app
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // ถ้าจะใช้ API Java ใหม่บน minSdk ต่ำ และต้องการ desugaring → เปิด:
        // isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.example.expense_tracker"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
            // เปิดใช้ถ้าจะทำ production optimize:
            // isMinifyEnabled = true
            // proguardFiles(
            //     getDefaultProguardFile("proguard-android-optimize.txt"),
            //     "proguard-rules.pro"
            // )
        }
    }
}

kotlin {
    jvmToolchain(17) // ให้ Kotlin ใช้ JDK 17 ตรงกับด้านบน
}

flutter {
    source = "../.."
}

dependencies {
    implementation("org.jetbrains.kotlin:kotlin-stdlib")
    // ถ้าเปิด desugaring (ดู compileOptions):
    // coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}

// ลบ block tasks.withType<JavaCompile>() เดิมทิ้ง — ไม่ต้องมีอะไรเพิ่มตรงนี้