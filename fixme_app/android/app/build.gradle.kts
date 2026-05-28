plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}


android {
    namespace = "com.smartfixoman.app"
    compileSdk = 36
    ndkVersion = "27.0.12077973"

defaultConfig {
    applicationId = "com.smartfixoman.app"
    minSdk = 24         // ← was 21
    targetSdk = 36
    versionCode = 1
    versionName = "1.0"
    multiDexEnabled = true
}


    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    // NOTE: using debug signing for release is fine for local tests only.
    signingConfigs {
        // create("release") { /* add real release keystore here later */ }
    }

    buildTypes {
        getByName("release") {
            // Temporary: sign with debug for testing only
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
        getByName("debug") {
            isMinifyEnabled = false
        }
    }

    packaging {
        resources {
            excludes += setOf(
                "/META-INF/{AL2.0,LGPL2.1}",
                "META-INF/*.kotlin_module"
            )
        }
    }
}

dependencies {
    implementation(platform("com.google.firebase:firebase-bom:33.5.1"))
    implementation("com.google.firebase:firebase-analytics")
    implementation("com.google.firebase:firebase-firestore")
    implementation("androidx.multidex:multidex:2.0.1")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
    implementation("com.google.android.gms:play-services-auth:21.2.0")
}

flutter {
    source = "../.."
}

java {
    toolchain {
        languageVersion.set(JavaLanguageVersion.of(17))
    }
}
