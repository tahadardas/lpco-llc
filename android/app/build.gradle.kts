import java.io.File
import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

fun signingProperty(name: String): String =
    keystoreProperties.getProperty(name)?.trim().orEmpty()

fun containsPlaceholder(value: String): Boolean =
    value.contains("CHANGE_ME", ignoreCase = true) || value.equals("TODO", ignoreCase = true)

fun resolveStoreFile(path: String): File {
    val storeFile = File(path)
    if (storeFile.isAbsolute) {
        return storeFile
    }

    val rootRelativeStoreFile = rootProject.file(path)
    if (rootRelativeStoreFile.exists()) {
        return rootRelativeStoreFile
    }

    return project.file(path)
}

val releaseStoreFilePath = signingProperty("storeFile")
val releaseStoreFile = releaseStoreFilePath.takeIf { it.isNotBlank() }?.let(::resolveStoreFile)
val requiredReleaseSigningProperties = mapOf(
    "storeFile" to releaseStoreFilePath,
    "storePassword" to signingProperty("storePassword"),
    "keyAlias" to signingProperty("keyAlias"),
    "keyPassword" to signingProperty("keyPassword"),
)
val missingReleaseSigningProperties = requiredReleaseSigningProperties
    .filterValues { it.isBlank() }
    .keys
val placeholderReleaseSigningProperties = requiredReleaseSigningProperties
    .filterValues(::containsPlaceholder)
    .keys
val releaseSigningError = when {
    !keystorePropertiesFile.exists() ->
        "Missing android/key.properties."
    missingReleaseSigningProperties.isNotEmpty() ->
        "Missing release signing properties: ${missingReleaseSigningProperties.joinToString()}."
    placeholderReleaseSigningProperties.isNotEmpty() ->
        "Replace placeholder release signing properties: ${placeholderReleaseSigningProperties.joinToString()}."
    releaseStoreFile == null || !releaseStoreFile.exists() ->
        "Release keystore file was not found: $releaseStoreFilePath."
    else -> null
}
val hasReleaseSigning = releaseSigningError == null

gradle.taskGraph.whenReady {
    val releaseTaskInGraph = allTasks.any { task ->
        task.name.contains("Release", ignoreCase = true)
    }

    if (releaseTaskInGraph && releaseSigningError != null) {
        throw org.gradle.api.GradleException(
            "Release builds must use a real upload keystore. $releaseSigningError " +
                "Create/update android/key.properties, then run flutter build appbundle --release."
        )
    }
}

android {
    namespace = "com.lpco.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.lpco.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (hasReleaseSigning) {
                keyAlias = signingProperty("keyAlias")
                keyPassword = signingProperty("keyPassword")
                storeFile = requireNotNull(releaseStoreFile)
                storePassword = signingProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")

            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    lint {
        checkReleaseBuilds = false
        abortOnError = false
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
