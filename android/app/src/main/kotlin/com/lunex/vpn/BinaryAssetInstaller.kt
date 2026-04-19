package com.lunex.vpn

import android.content.Context
import android.util.Log
import java.io.File

data class BinaryInstallResult(
    val binaryPath: String,
    val installed: Boolean,
    val sourcePath: String? = null,
    val details: String,
)

class BinaryAssetInstaller(
    private val context: Context,
) {
    companion object {
        private const val TAG = "BinaryAssetInstaller"
    }

    fun install(engineType: String): BinaryInstallResult {
        val binaryFile = resolveNativeLibrary(engineType)
        if (binaryFile == null) {
            Log.e(
                TAG,
                "Binary not found for $engineType in nativeLibraryDir: ${context.applicationInfo.nativeLibraryDir}",
            )
            return BinaryInstallResult(
                binaryPath = File(context.applicationInfo.nativeLibraryDir, libraryFileName(engineType)).absolutePath,
                installed = false,
                details = missingAssetMessage(engineType),
            )
        }

        Log.i(TAG, "Binary found: ${binaryFile.absolutePath} (${binaryFile.length()} bytes)")
        return BinaryInstallResult(
            binaryPath = binaryFile.absolutePath,
            installed = true,
            sourcePath = binaryFile.absolutePath,
            details = "Bundled $engineType binary resolved from ${binaryFile.absolutePath}",
        )
    }

    private fun resolveNativeLibrary(engineType: String): File? {
        val nativeLibraryDir = context.applicationInfo.nativeLibraryDir ?: return null
        val targetName = libraryFileName(engineType)
        val candidate = File(nativeLibraryDir, targetName)
        Log.d(
            TAG,
            "Checking: ${candidate.absolutePath}, exists=${candidate.exists()}, canRead=${candidate.canRead()}, canExecute=${candidate.canExecute()}",
        )
        candidate.takeIf { it.exists() }?.let { return it }

        // Some devices expose nativeLibraryDir as .../lib/arm64 while actual files can end up
        // under sibling ABI folders. Probe nearby ABI directories as a fallback.
        val abiParentDir = File(nativeLibraryDir).parentFile
        if (abiParentDir != null && abiParentDir.exists()) {
            val discovered = abiParentDir.walkTopDown()
                .maxDepth(2)
                .firstOrNull { file ->
                    file.isFile && file.name == targetName
                }
            if (discovered != null) {
                Log.i(TAG, "Resolved $targetName via fallback lookup: ${discovered.absolutePath}")
                return discovered
            }
        }

        return null
    }

    private fun libraryFileName(engineType: String): String {
        return when (engineType) {
            "xray" -> "libxray.so"
            "sing-box" -> "libsingbox.so"
            else -> "lib${engineType.replace("-", "")}.so"
        }
    }

    private fun missingAssetMessage(engineType: String): String {
        val libName = libraryFileName(engineType)
        val nativeLibraryDir = context.applicationInfo.nativeLibraryDir ?: "<null>"
        val nearbyLibs = File(nativeLibraryDir).parentFile
            ?.takeIf { it.exists() }
            ?.walkTopDown()
            ?.maxDepth(2)
            ?.filter { it.isFile && it.name.startsWith("lib") && it.name.endsWith(".so") }
            ?.take(8)
            ?.joinToString { it.name }
            ?: "none"
        return buildString {
            append("Bundled native binary missing from nativeLibraryDir. ")
            append("Expected: $libName. ")
            append("nativeLibraryDir: $nativeLibraryDir. ")
            append("Nearby libs: $nearbyLibs. ")
            append("Make sure $libName is packaged for the current ABI in android/app/src/main/jniLibs.")
        }
    }
}
