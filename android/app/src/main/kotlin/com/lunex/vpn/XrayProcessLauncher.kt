package com.lunex.vpn

import android.content.Context
import android.util.Log
import java.io.File
import java.io.InterruptedIOException
import kotlin.concurrent.thread

data class XrayLaunchResult(
    val commandPreview: String,
    val started: Boolean,
    val details: String,
    val process: Process? = null,
)

class XrayProcessLauncher(
    private val context: Context,
) {
    private val binaryInstaller = BinaryAssetInstaller(context)

    companion object {
        private const val TAG = "XrayProcessLauncher"
    }

    fun launch(
        configFile: File,
        engineType: String,
        onLogLine: (String) -> Unit,
        onExit: (Int) -> Unit,
    ): XrayLaunchResult {
        val installResult = binaryInstaller.install(engineType)
        val command = listOf(installResult.binaryPath, "run", "-config", configFile.absolutePath)
        val commandPreview = command.joinToString(" ")
        Log.d(TAG, "Binary install result: installed=${installResult.installed}, path=${installResult.binaryPath}")
        Log.d(TAG, "Command: $commandPreview")

        if (!installResult.installed) {
            Log.e(TAG, "Binary not installed: ${installResult.details}")
            return XrayLaunchResult(
                commandPreview = commandPreview,
                started = false,
                details = installResult.details,
            )
        }

        return try {
            Log.d(TAG, "Launching process...")
            val processBuilder = ProcessBuilder(command)
                .directory(configFile.parentFile ?: context.filesDir)
                .redirectErrorStream(true)

            // Set environment for Xray
            processBuilder.environment().apply {
                put("XRAY_LOCATION_ASSET", configFile.parentFile?.absolutePath ?: context.filesDir.absolutePath)
            }

            val process = processBuilder.start()

            pipeLogs(process, onLogLine)
            watchExit(process, onExit)

            XrayLaunchResult(
                commandPreview = commandPreview,
                started = true,
                details = buildString {
                    append("Started $engineType process with ${configFile.name}")
                    if (installResult.sourcePath != null) {
                        append(" using ${installResult.sourcePath}")
                    }
                },
                process = process,
            )
        } catch (error: Exception) {
            Log.e(TAG, "Failed to launch $engineType", error)
            XrayLaunchResult(
                commandPreview = commandPreview,
                started = false,
                details = "Failed to launch $engineType: ${error.message}",
            )
        }
    }

    fun stop(process: Process?) {
        process ?: return
        if (process.isAlive) {
            process.destroy()
            if (process.isAlive) {
                process.destroyForcibly()
            }
        }
    }

    private fun pipeLogs(process: Process, onLogLine: (String) -> Unit) {
        thread(name = "lunex-xray-log-reader", isDaemon = true) {
            try {
                process.inputStream.bufferedReader().useLines { lines ->
                    lines.forEach { line ->
                        onLogLine(line)
                    }
                }
            } catch (error: InterruptedIOException) {
                // Expected during disconnect: process stream is closed from another thread.
                Log.d(TAG, "Log reader interrupted while process is stopping")
            } catch (error: Exception) {
                if (process.isAlive) {
                    Log.w(TAG, "Log reader stopped unexpectedly", error)
                } else {
                    Log.d(TAG, "Log reader closed after process exit")
                }
            }
        }
    }

    private fun watchExit(process: Process, onExit: (Int) -> Unit) {
        thread(name = "lunex-xray-exit-watcher", isDaemon = true) {
            val exitCode = process.waitFor()
            onExit(exitCode)
        }
    }
}
