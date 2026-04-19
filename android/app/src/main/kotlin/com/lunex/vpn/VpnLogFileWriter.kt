package com.lunex.vpn

import android.content.Context
import java.io.File
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter

class VpnLogFileWriter(
    private val context: Context,
) {
    private val maxLogBytes = 256 * 1024L
    private val maxBackupFiles = 2
    private val formatter =
        DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss")
            .withZone(ZoneId.systemDefault())

    fun create(profileId: String): File {
        val logDir = File(context.filesDir, "runtime/logs").apply {
            if (!exists()) {
                mkdirs()
            }
        }
        val file = File(logDir, "$profileId.log")
        if (!file.exists()) {
            file.createNewFile()
        }
        return file
    }

    fun append(file: File?, severity: String, message: String) {
        file ?: return
        rotateIfNeeded(file)
        val line = "[${formatter.format(Instant.now())}] ${severity.uppercase()} $message\n"
        file.appendText(line)
    }

    private fun rotateIfNeeded(file: File) {
        if (!file.exists() || file.length() < maxLogBytes) {
            return
        }

        for (index in maxBackupFiles downTo 1) {
            val backup = File(file.parentFile, "${file.name}.$index")
            if (!backup.exists()) {
                continue
            }
            if (index == maxBackupFiles) {
                backup.delete()
            } else {
                backup.renameTo(File(file.parentFile, "${file.name}.${index + 1}"))
            }
        }

        val firstBackup = File(file.parentFile, "${file.name}.1")
        file.renameTo(firstBackup)
        file.writeText(
            "[${formatter.format(Instant.now())}] WARN Log rotated after exceeding ${maxLogBytes / 1024}KB\n",
        )
    }
}
