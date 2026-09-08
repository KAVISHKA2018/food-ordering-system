allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

// Force every plugin subproject (e.g. geocoding_android, geolocator_android)
// to compile against the same SDK version as the app itself. Individual
// plugin packages ship their own Gradle config pulled from Flutter's
// package cache, which doesn't automatically follow the app module's
// compileSdk setting — this override closes that gap. Registered BEFORE
// evaluationDependsOn below, so the callback is queued before any
// subproject's evaluation is forced to complete early.
subprojects {
    afterEvaluate {
        extensions.findByType(com.android.build.gradle.BaseExtension::class.java)?.let {
            it.compileSdkVersion(36)
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}