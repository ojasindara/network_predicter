allprojects {
    repositories {
        google()
        maven("https://maven.aliyun.com/nexus/content/groups/public")
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// ✅ Suppress obsolete Java 8 warnings globally
tasks.withType<JavaCompile>().configureEach {
    options.compilerArgs.add("-Xlint:-options")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
