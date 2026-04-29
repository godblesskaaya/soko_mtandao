import java.util.Properties
import java.io.FileInputStream
import java.util.Base64

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

configurations.configureEach {
    resolutionStrategy.dependencySubstitution {
        substitute(module("com.mapbox.maps:android"))
            .using(module("com.mapbox.maps:android-ndk27:11.14.0"))
            .because("Mapbox default Android artifacts do not support 16 KB page sizes")
    }
}

// 1. Load keystore properties using Kotlin syntax
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

fun loadDartDefines(): Map<String, String> {
    val dartDefines = project.findProperty("dart-defines") as String? ?: return emptyMap()
    return dartDefines
        .split(",")
        .mapNotNull { encodedDefine ->
            val decoded = String(Base64.getDecoder().decode(encodedDefine))
            val index = decoded.indexOf('=')
            if (index <= 0) return@mapNotNull null
            val key = decoded.substring(0, index)
            val value = decoded.substring(index + 1)
            key to value
        }
        .toMap()
}

val dartDefines = loadDartDefines()
val mapboxAccessToken = (project.findProperty("MAPBOX_ACCESS_TOKEN") as String?)
    ?: dartDefines["MAPBOX_ACCESS_TOKEN"]
    ?: System.getenv("MAPBOX_ACCESS_TOKEN")
    ?: ""

android {
    namespace = "com.soko_mtandao.soko_mtandao"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    // 2. Define signingConfigs using Kotlin 'create' syntax
    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = keystoreProperties["storeFile"]?.let { file(it as String) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    defaultConfig {
        applicationId = "com.soko_mtandao.soko_mtandao"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["MAPBOX_ACCESS_TOKEN"] = mapboxAccessToken
    }

    buildTypes {
        release {
            // 3. Link the release signing configuration
            signingConfig = signingConfigs.getByName("release")
            
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }

    packaging {
        jniLibs {
            useLegacyPackaging = false
        }
    }
}

flutter {
    source = "../.."
}
