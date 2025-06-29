import org.gradle.api.tasks.Delete
import org.gradle.api.file.Directory
import com.android.build.gradle.LibraryExtension
import com.android.build.gradle.AppExtension
import com.android.build.gradle.LibraryPlugin
import com.android.build.gradle.AppPlugin

// Repositórios globais usados por todos os subprojetos
allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Diretório customizado para os arquivos de build
val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

// Garante que todos os subprojetos dependam do módulo app
subprojects {
    project.evaluationDependsOn(":app")
}

// Tarefa padrão de limpeza do projeto
tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

// ✅ 🔧 Adicionando buildscript corretamente
buildscript {
    // 🔹 Repositórios que o Gradle usará para buscar os plugins
    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        // 🔹 Plugin do Firebase (google-services)
        classpath("com.google.gms:google-services:4.4.1")
    }
}

// Hack para definir namespace em modules Android sem namespace pré-definido
subprojects {
    plugins.withType<LibraryPlugin> {
        extensions.configure<LibraryExtension> {
            if (namespace.isNullOrBlank()) {
                namespace = project.group.toString()
            }
        }
    }
    plugins.withType<AppPlugin> {
        extensions.configure<AppExtension> {
            if (namespace.isNullOrBlank()) {
                namespace = project.group.toString()
            }
        }
    }
}
