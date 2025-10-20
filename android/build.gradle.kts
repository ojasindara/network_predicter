buildscript {
    val kotlinVersion by extra("1.7.22")

    repositories {
        google()
        mavenCentral()
        maven("https://maven.aliyun.com/nexus/content/groups/public")
    }

    dependencies {
        classpath("com.android.tools.build:gradle:7.3.1")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlinVersion")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
        maven("https://maven.aliyun.com/nexus/content/groups/public")
    }
}

// Optional: custom build directory
val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

subprojects {
    this.evaluationDependsOn(":app")
}

tasks.withType<JavaCompile>().configureEach {
    options.compilerArgs.add("-Xlint:-options")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
