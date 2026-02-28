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
}

// Compatibility fallback for older Android library plugins that do not define
// `android.namespace` (required by AGP 8+). This reads package name from each
// plugin AndroidManifest and assigns it as namespace when missing.
subprojects {
    pluginManager.withPlugin("com.android.library") {
        val androidExt = extensions.findByName("android") ?: return@withPlugin
        val getNamespace = androidExt.javaClass.methods.firstOrNull { it.name == "getNamespace" }
        val currentNamespace = getNamespace?.invoke(androidExt) as? String
        if (!currentNamespace.isNullOrBlank()) {
            return@withPlugin
        }

        val manifestFile = file("src/main/AndroidManifest.xml")
        if (!manifestFile.exists()) {
            return@withPlugin
        }

        val manifest = manifestFile.readText()
        val packageName = Regex("package\\s*=\\s*\"([^\"]+)\"")
            .find(manifest)
            ?.groupValues
            ?.getOrNull(1)
        if (packageName.isNullOrBlank()) {
            return@withPlugin
        }

        androidExt.javaClass.methods
            .firstOrNull { it.name == "setNamespace" }
            ?.invoke(androidExt, packageName)
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
