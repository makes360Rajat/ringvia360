import java.util.Properties

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")

if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.makes360.salestrack.sales_track_crm"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.makes360.salestrack.sales_track_crm"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // A signed release is enabled after android/key.properties is
            // filled with the private keystore credentials. Until then,
            // Gradle produces an unsigned release rather than silently using
            // the debug certificate.
            val signingValues = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
            val hasReleaseCredentials = keystorePropertiesFile.exists()
                && signingValues.all {
                    val value = keystoreProperties.getProperty(it)?.trim()
                    !value.isNullOrEmpty() && !value.startsWith("CHANGE_ME")
                }
                && rootProject.file(keystoreProperties.getProperty("storeFile")).exists()
            if (hasReleaseCredentials) {
                signingConfig = signingConfigs.create("release") {
                    keyAlias = keystoreProperties["keyAlias"] as String
                    keyPassword = keystoreProperties["keyPassword"] as String
                    storeFile = rootProject.file(keystoreProperties["storeFile"] as String)
                    storePassword = keystoreProperties["storePassword"] as String
                }
            }
        }
    }
}

flutter {
    source = "../.."
}
