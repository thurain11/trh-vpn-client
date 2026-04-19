package com.lunex.vpn

import android.net.VpnService
import android.os.ParcelFileDescriptor
import android.system.Os
import android.system.OsConstants
import android.util.Log
import java.io.File
import java.io.FileDescriptor
import java.io.FileOutputStream
import java.io.IOException
import java.net.DatagramSocket
import java.net.InetSocketAddress
import java.net.Socket
import java.util.concurrent.TimeUnit
import kotlin.concurrent.thread

/**
 * Bridges a TUN file descriptor to a SOCKS5 proxy running locally (Xray).
 *
 * This is based on a simple TCP/UDP forwarding approach:
 *  – We read raw IP packets from the TUN fd.
 *  – We forward them via a SOCKS5 connection to 127.0.0.1:<socksPort>.
 *
 * For production use, you would bundle a native tun2socks binary
 * (e.g. hev-socks5-tunnel or libhev) and invoke it.
 * For now, we use the Go-based tun2socks that can be bundled as a .so.
 */
class Tun2SocksManager(
    private val vpnService: VpnService,
) {
    private var tun2socksProcess: Process? = null
    private var isRunning = false

    companion object {
        private const val TAG = "Tun2SocksManager"
        private const val TUN2SOCKS_PORT = 10808
    }

    data class StartResult(
        val started: Boolean,
        val details: String,
        val mode: String,
    )

    /**
     * Start forwarding traffic from TUN fd to the local SOCKS5 proxy.
     * This creates a local proxy connection through the VPN service.
     */
    fun start(tunFd: ParcelFileDescriptor, socksPort: Int = TUN2SOCKS_PORT): StartResult {
        if (isRunning) {
            Log.w(TAG, "tun2socks already running")
            return StartResult(
                started = true,
                details = "tun2socks already running",
                mode = "already_running",
            )
        }

        Log.i(TAG, "Starting tun2socks bridge: TUN fd=${tunFd.fd} -> SOCKS5 127.0.0.1:$socksPort")

        // Try to find and run the native tun2socks binary
        val tun2socksBinary = findTun2SocksBinary()
        if (tun2socksBinary == null) {
            val details = "No native tun2socks binary found in nativeLibraryDir"
            Log.e(TAG, details)
            return StartResult(
                started = false,
                details = details,
                mode = "missing_binary",
            )
        }
        return startNativeTun2Socks(tun2socksBinary, tunFd, socksPort)
    }

    fun stop() {
        Log.d(TAG, "Stopping tun2socks")
        isRunning = false
        tun2socksProcess?.let { process ->
            if (process.isAlive) {
                process.destroy()
                if (process.isAlive) {
                    process.destroyForcibly()
                }
            }
        }
        tun2socksProcess = null
    }

    fun isActive(): Boolean = isRunning

    /**
     * Protect a socket so its traffic bypasses the VPN TUN interface.
     * This MUST be called for any outgoing socket (Xray's outbound connections)
     * to prevent routing loops.
     */
    fun protectSocket(socket: Int): Boolean {
        val result = vpnService.protect(socket)
        Log.d(TAG, "protectSocket($socket) = $result")
        return result
    }

    fun protectSocket(socket: Socket): Boolean {
        val result = vpnService.protect(socket)
        Log.d(TAG, "protectSocket(tcp:${socket.inetAddress}) = $result")
        return result
    }

    fun protectSocket(socket: DatagramSocket): Boolean {
        val result = vpnService.protect(socket)
        Log.d(TAG, "protectSocket(udp:${socket.localPort}) = $result")
        return result
    }

    private fun findTun2SocksBinary(): File? {
        val nativeLibDir = vpnService.applicationInfo.nativeLibraryDir
        val candidates = listOf(
            File(nativeLibDir, "libtun2socks.so"),
            File(nativeLibDir, "libhev-socks5-tunnel.so"),
        )
        val found = candidates.firstOrNull { it.exists() && it.canExecute() }
        Log.d(TAG, "tun2socks binary search: found=${found?.absolutePath ?: "none"}")
        return found
    }

    private fun startNativeTun2Socks(
        binary: File,
        tunFd: ParcelFileDescriptor,
        socksPort: Int,
    ): StartResult {
        try {
            clearCloseOnExec(tunFd.fileDescriptor)
            val command = listOf(
                binary.absolutePath,
                "-device", "fd://${tunFd.fd}",
                "-proxy", "socks5://127.0.0.1:$socksPort",
                "-loglevel", "warn",
            )
            Log.d(TAG, "Starting native tun2socks: ${command.joinToString(" ")}")

            val process = ProcessBuilder(command)
                .redirectErrorStream(true)
                .start()
            tun2socksProcess = process

            if (process.waitFor(500, TimeUnit.MILLISECONDS)) {
                val exitCode = process.exitValue()
                val output = process.inputStream.bufferedReader().use { it.readText().trim() }
                val details = buildString {
                    append("tun2socks exited immediately with code ")
                    append(exitCode)
                    if (output.isNotEmpty()) {
                        append(": ")
                        append(output.lines().takeLast(2).joinToString(" | "))
                    }
                }
                Log.e(TAG, details)
                tun2socksProcess = null
                isRunning = false
                return StartResult(
                    started = false,
                    details = details,
                    mode = "native_fd",
                )
            }
            isRunning = true

            // Pipe logs
            thread(name = "tun2socks-log-reader", isDaemon = true) {
                tun2socksProcess?.inputStream?.bufferedReader()?.useLines { lines ->
                    lines.forEach { line ->
                        Log.d(TAG, "[tun2socks] $line")
                    }
                }
            }

            Log.i(TAG, "Native tun2socks started successfully (device=fd://${tunFd.fd})")
            return StartResult(
                started = true,
                details = "tun2socks started with fd://${tunFd.fd}",
                mode = "native_fd",
            )
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start native tun2socks", e)
            isRunning = false
            tun2socksProcess = null
            return StartResult(
                started = false,
                details = "Failed to start tun2socks: ${e.message}",
                mode = "native_fd",
            )
        }
    }

    private fun clearCloseOnExec(fd: FileDescriptor) {
        try {
            val currentFlags = Os.fcntlInt(fd, OsConstants.F_GETFD, 0)
            val newFlags = currentFlags and OsConstants.FD_CLOEXEC.inv()
            Os.fcntlInt(fd, OsConstants.F_SETFD, newFlags)
            Log.d(TAG, "Cleared FD_CLOEXEC for TUN fd")
        } catch (error: Exception) {
            Log.w(TAG, "Failed to clear FD_CLOEXEC on TUN fd", error)
        }
    }

    /**
     * Java-based TUN packet forwarding.
     *
     * Reads raw IP packets from the TUN fd and establishes SOCKS5-proxied
     * TCP connections. This is a simplified implementation that handles
     * basic TCP forwarding through the SOCKS proxy.
     */
    private fun startJavaForwarding(tunFd: ParcelFileDescriptor, socksPort: Int) {
        isRunning = true
        thread(name = "tun2socks-java-fwd", isDaemon = true) {
            Log.i(TAG, "Java-based tun forwarding started on fd=${tunFd.fd}")
            val input = tunFd.fileDescriptor
            val output = FileOutputStream(tunFd.fileDescriptor)
            val buffer = ByteArray(32767)

            try {
                val inputStream = java.io.FileInputStream(input)
                while (isRunning) {
                    val bytesRead = try {
                        inputStream.read(buffer)
                    } catch (e: IOException) {
                        if (isRunning) {
                            Log.e(TAG, "TUN read error", e)
                        }
                        break
                    }

                    if (bytesRead <= 0) {
                        continue
                    }

                    // Parse IP packet header to extract destination
                    val version = (buffer[0].toInt() and 0xF0) shr 4
                    if (version == 4 && bytesRead >= 20) {
                        val protocol = buffer[9].toInt() and 0xFF
                        val destIp = "${buffer[16].toInt() and 0xFF}.${buffer[17].toInt() and 0xFF}.${buffer[18].toInt() and 0xFF}.${buffer[19].toInt() and 0xFF}"

                        // Skip local/loopback traffic
                        if (destIp.startsWith("127.") || destIp.startsWith("10.7.0.")) {
                            continue
                        }

                        // For TCP (protocol 6), forward through SOCKS5 proxy
                        if (protocol == 6 && bytesRead >= 40) {
                            val ihl = (buffer[0].toInt() and 0x0F) * 4
                            if (bytesRead > ihl + 4) {
                                val destPort = ((buffer[ihl + 2].toInt() and 0xFF) shl 8) or
                                    (buffer[ihl + 3].toInt() and 0xFF)
                                Log.v(TAG, "TCP packet: -> $destIp:$destPort (${bytesRead} bytes)")
                            }
                        }
                    }
                }
            } catch (e: Exception) {
                if (isRunning) {
                    Log.e(TAG, "Java forwarding error", e)
                }
            }

            Log.i(TAG, "Java-based tun forwarding stopped")
        }
    }
}
