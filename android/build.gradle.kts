// 1. Define the custom path as a plain File or String first to break the circularity
val customBuildDirBase = rootProject.projectDir.parentFile.resolve("build")

allprojects {
    repositories {
        google()
        mavenCentral()
    }

    // 2. Set the build directory using a direct file path instead of mapping the existing provider
    val newProjectBuildDir = customBuildDirBase.resolve(project.name)
    layout.buildDirectory.set(newProjectBuildDir)
}

subprojects {
    // Standard Flutter requirement: wait for app evaluation
    evaluationDependsOn(":app")
}

subprojects {
    tasks.withType<JavaCompile>().configureEach {
        options.compilerArgs.add("-Xlint:deprecation")
    }
}

// 3. Update the clean task to use the resolved path
tasks.register<Delete>("clean") {
    delete(customBuildDirBase)
}
