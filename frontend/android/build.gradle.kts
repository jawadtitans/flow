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
subprojects {
    project.evaluationDependsOn(":app")
    pluginManager.withPlugin("com.android.library") {
        extensions.configure<com.android.build.api.variant.LibraryAndroidComponentsExtension> {
            finalizeDsl {
                // Build native plugins with the same NDK as the application.
                it.ndkVersion = project(":app")
                    .extensions.getByType<com.android.build.gradle.AppExtension>().ndkVersion
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
