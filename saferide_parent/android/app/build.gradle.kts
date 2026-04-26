plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    // Only keep one of these:
    id("com.google.gms.google-services") 
}

android {
    // Parent app eke namespace eka
    namespace = "com.example.saferide_parent"
    
    // Aluth plugins veda karanna 36 danna oni
    compileSdk = 36
    ndkVersion = "27.0.12077973" 

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        // Parent app eke unique application ID eka
        applicationId = "com.example.saferide_parent"
        
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation(platform("com.google.firebase:firebase-bom:32.7.0"))
    implementation("com.google.firebase:firebase-analytics")
    // Add this for your bus tracking data:
    implementation("com.google.firebase:firebase-database")
}


