package com.lunex.vpn

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.pm.ServiceInfo
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.os.IBinder
import android.os.ParcelFileDescriptor
import android.util.Log
import androidx.core.app.NotificationCompat
import org.json.JSONObject
import java.io.File
import kotlin.concurrent.fixedRateTimer

class LunexVpnService : VpnService() {
    private var tunInterface: ParcelFileDescriptor? = null
    private var trafficTimer: java.util.Timer? = null
    private var runtimeConfigFile: File? = null
    private var logFile: File? = null
    private var engineProcess: Process? = null
    private var downloadBytes: Int = 0
    private var uploadBytes: Int = 0
    private var isStopping = false
    private val processLauncher by lazy { XrayProcessLauncher(this) }
    private val logFileWriter by lazy { VpnLogFileWriter(this) }
    private val tun2socksManager by lazy { Tun2SocksManager(this) }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "onStartCommand: action=${intent?.action}")
        return when (intent?.action) {
            ACTION_START -> {
                Log.i(TAG, "Received ACTION_START")
                startStubTunnel(intent)
                START_STICKY
            }

            ACTION_STOP -> {
                Log.i(TAG, "Received ACTION_STOP")
                stopStubTunnel()
                START_NOT_STICKY
            }

            else -> {
                Log.w(TAG, "Unknown action: ${intent?.action}")
                START_NOT_STICKY
            }
        }
    }

    override fun onDestroy() {
        if (!isStopping) {
            stopStubTunnel()
        }
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? {
        return super.onBind(intent)
    }

    private fun startStubTunnel(intent: Intent) {
        val config = VpnConnectionConfig.fromIntent(intent)
        Log.d(TAG, "startStubTunnel: profile=${config.profileName}, server=${config.serverAddress}:${config.serverPort}, engine=${config.engineType}")
        isStopping = false
        logFile = logFileWriter.create(config.profileId)
        emitStatus(
            status = "connecting",
            profileName = config.profileName,
            severity = "info",
            message = "Preparing ${config.engineType.uppercase()} runtime",
        )
        startForegroundCompat(buildNotification(config, "Connecting"))

        // --- Step 1: Write the Xray config file first ---
        val configFile = persistRuntimeConfig(config)
        runtimeConfigFile = configFile
        Log.d(TAG, "Runtime config written to: ${configFile.absolutePath}")
        Log.d(TAG, "Config file size: ${configFile.length()} bytes")

        // --- Step 2: Launch Xray process (SOCKS5 proxy on 127.0.0.1:10808) ---
        val launchResult = processLauncher.launch(
            configFile = configFile,
            engineType = config.engineType,
            onLogLine = { line ->
                Log.d(TAG, "[${config.engineType}] $line")
                emitStatus(
                    status = if (tun2socksManager.isActive()) "connected" else "connecting",
                    downloadBytes = downloadBytes,
                    uploadBytes = uploadBytes,
                    profileName = config.profileName,
                    configPath = runtimeConfigFile?.absolutePath,
                    severity = "info",
                    message = line,
                )
            },
            onExit = { exitCode ->
                Log.w(TAG, "${config.engineType} process exited with code $exitCode, isStopping=$isStopping")
                if (!isStopping) {
                    emitStatus(
                        status = "error",
                        profileName = config.profileName,
                        configPath = runtimeConfigFile?.absolutePath,
                        commandPreview = launchResultCommand(configFile, config.engineType),
                        severity = "error",
                        message = "${config.engineType.uppercase()} exited with code $exitCode",
                    )
                }
            },
        )
        engineProcess = launchResult.process
        Log.i(TAG, "Launch result: started=${launchResult.started}, details=${launchResult.details}")

        if (!launchResult.started) {
            val connectedNotification = buildNotification(config, "Launch Failed")
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.notify(NOTIFICATION_ID, connectedNotification)
            emitStatus(
                status = "error",
                profileName = config.profileName,
                configPath = configFile.absolutePath,
                commandPreview = launchResult.commandPreview,
                severity = "error",
                message = launchResult.details,
            )
            return
        }

        // --- Step 3: Wait for Xray to initialize (give it a moment to bind SOCKS port) ---
        Thread.sleep(500)

        // --- Step 4: Establish TUN interface ---
        if (tunInterface == null) {
            Log.d(TAG, "Establishing TUN interface...")
            tunInterface = Builder()
                .setSession(config.profileName)
                .addAddress("10.7.0.2", 32)
                .addRoute("0.0.0.0", 0)
                .addRoute("::", 0)
                .addDnsServer("1.1.1.1")
                .addDnsServer("2606:4700:4700::1111")
                .addDisallowedApplication(packageName)
                .setMtu(1500)
                .setBlocking(true)
                .establish()
            Log.d(TAG, "TUN interface established: ${tunInterface != null}")
        }

        if (tunInterface == null) {
            Log.e(TAG, "Failed to establish TUN interface")
            emitStatus(
                status = "error",
                profileName = config.profileName,
                severity = "error",
                message = "Failed to establish TUN interface. VPN permission may not be granted.",
            )
            return
        }

        // --- Step 5: Start tun2socks bridge (TUN ↔ SOCKS5 proxy) ---
        Log.d(TAG, "Starting tun2socks bridge...")
        val tun2socksResult = tun2socksManager.start(tunInterface!!, SOCKS_PORT)
        if (!tun2socksResult.started) {
            Log.e(TAG, "tun2socks failed: ${tun2socksResult.details}")
            emitStatus(
                status = "error",
                profileName = config.profileName,
                configPath = configFile.absolutePath,
                commandPreview = launchResult.commandPreview,
                severity = "error",
                message = "tun2socks failed (${tun2socksResult.mode}): ${tun2socksResult.details}",
            )
            stopStubTunnel()
            return
        }
        emitStatus(
            status = "connected",
            profileName = config.profileName,
            severity = "info",
            message = "tun2socks bridge started (${tun2socksResult.mode}), routing traffic through SOCKS5 proxy on port $SOCKS_PORT",
        )

        startTrafficTicker(config)

        val connectedNotification = buildNotification(config, "Connected")
        val notificationManager = getSystemService(NotificationManager::class.java)
        notificationManager.notify(NOTIFICATION_ID, connectedNotification)
        emitStatus(
            status = "connected",
            downloadBytes = downloadBytes,
            uploadBytes = uploadBytes,
            profileName = config.profileName,
            configPath = configFile.absolutePath,
            commandPreview = launchResult.commandPreview,
            severity = "info",
            message = launchResult.details,
        )
    }

    private fun stopStubTunnel() {
        Log.d(TAG, "stopStubTunnel called")
        isStopping = true
        trafficTimer?.cancel()
        trafficTimer = null
        emitStatus(status = "disconnecting", severity = "warn", message = "Stopping VPN service")

        // Stop tun2socks bridge first
        tun2socksManager.stop()

        // Stop Xray process
        processLauncher.stop(engineProcess)
        engineProcess = null

        // Close TUN interface
        tunInterface?.close()
        tunInterface = null

        runtimeConfigFile?.delete()
        runtimeConfigFile = null
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        Log.i(TAG, "VPN service stopped")
        emitStatus(status = "disconnected", severity = "info", message = "VPN service stopped")
        stopSelf()
    }

    private fun startTrafficTicker(config: VpnConnectionConfig) {
        trafficTimer?.cancel()
        downloadBytes = 0
        uploadBytes = 0
        trafficTimer = fixedRateTimer(
            name = "lunex-traffic-ticker",
            initialDelay = 2_000L,
            period = 2_000L,
        ) {
            // Read real traffic stats from the TUN interface
            val tun = tunInterface
            if (tun != null) {
                try {
                    val stats = android.net.TrafficStats.getUidRxBytes(android.os.Process.myUid())
                    val txStats = android.net.TrafficStats.getUidTxBytes(android.os.Process.myUid())
                    if (stats != android.net.TrafficStats.UNSUPPORTED.toLong()) {
                        downloadBytes = stats.toInt()
                        uploadBytes = txStats.toInt()
                    }
                } catch (_: Exception) {
                    // Fallback: just increment to show activity
                    downloadBytes += 0
                    uploadBytes += 0
                }
            }

            emitStatus(
                status = "connected",
                downloadBytes = downloadBytes,
                uploadBytes = uploadBytes,
                profileName = config.profileName,
                configPath = runtimeConfigFile?.absolutePath,
                severity = "info",
                message = "Traffic stats updated",
            )
        }
    }

    private fun emitStatus(
        status: String,
        downloadBytes: Int = 0,
        uploadBytes: Int = 0,
        profileName: String? = null,
        configPath: String? = null,
        commandPreview: String? = null,
        severity: String = "info",
        message: String? = null,
    ) {
        if (message != null && message != "Traffic stats updated") {
            logFileWriter.append(logFile, severity, message)
        }
        VpnEventDispatcher.dispatchStatus(
            status = status,
            downloadBytes = downloadBytes,
            uploadBytes = uploadBytes,
            profileName = profileName,
            configPath = configPath,
            logFilePath = logFile?.absolutePath,
            commandPreview = commandPreview,
            severity = severity,
            message = message,
        )
    }

    private fun persistRuntimeConfig(config: VpnConnectionConfig): File {
        val runtimeDir = File(filesDir, "runtime").apply {
            if (!exists()) {
                mkdirs()
            }
        }
        // Extract only the engineConfig portion — Xray cannot parse the
        // full TunnelRuntimeConfig wrapper that includes profileId, platform, etc.
        val xrayConfig = try {
            val root = JSONObject(config.runtimeConfigJson)
            val engine = root.optJSONObject("engineConfig")
            if (engine != null) {
                Log.d(TAG, "Extracted engineConfig from runtimeConfigJson")
                engine.toString(2)
            } else {
                Log.w(TAG, "No engineConfig key found, writing raw runtimeConfigJson")
                config.runtimeConfigJson
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to parse runtimeConfigJson, writing raw value", e)
            config.runtimeConfigJson
        }
        return File(runtimeDir, "${config.profileId}.json").apply {
            writeText(xrayConfig)
            Log.d(TAG, "Persisted xray config (${length()} bytes): ${absolutePath}")
        }
    }

    private fun launchResultCommand(configFile: File, engineType: String): String {
        return "${File(filesDir, "runtime/bin/$engineType").absolutePath} run -config ${configFile.absolutePath}"
    }

    private fun buildNotification(
        config: VpnConnectionConfig,
        contentText: String,
    ): Notification {
        createNotificationChannelIfNeeded()
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
            ?: Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        return NotificationCompat.Builder(this, NOTIFICATION_CHANNEL_ID)
            .setContentTitle(config.profileName)
            .setContentText(contentText)
            .setSubText(
                "${config.engineType.uppercase()}  ${config.protocol.uppercase()}  ${config.serverAddress}:${config.serverPort}",
            )
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setStyle(
                NotificationCompat.BigTextStyle().bigText(
                    "Engine: ${config.engineType.uppercase()}\n"
                        + "Server: ${config.serverAddress}:${config.serverPort}\n"
                        + "Protocol: ${config.protocol.uppercase()}\n"
                        + "Config file: ${runtimeConfigFile?.absolutePath ?: "pending"}\n"
                        + "Config: ${config.runtimeSummary}",
                ),
            )
            .addAction(
                0,
                "Disconnect",
                createStopPendingIntent(),
            )
            .build()
    }

    private fun createStopPendingIntent(): PendingIntent {
        val stopIntent = Intent(this, LunexVpnService::class.java).apply {
            action = ACTION_STOP
        }
        return PendingIntent.getService(
            this,
            1,
            stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun createNotificationChannelIfNeeded() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }

        val notificationManager = getSystemService(NotificationManager::class.java)
        val existingChannel = notificationManager.getNotificationChannel(NOTIFICATION_CHANNEL_ID)
        if (existingChannel != null) {
            return
        }

        val channel = NotificationChannel(
            NOTIFICATION_CHANNEL_ID,
            "Lunex VPN",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "Keeps the Lunex VPN service running in the foreground."
        }
        notificationManager.createNotificationChannel(channel)
    }

    private fun startForegroundCompat(notification: Notification) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    companion object {
        private const val TAG = "LunexVpnService"
        const val ACTION_START = "com.lunex.vpn.action.START"
        const val ACTION_STOP = "com.lunex.vpn.action.STOP"
        private const val NOTIFICATION_CHANNEL_ID = "lunex_vpn_status"
        private const val NOTIFICATION_ID = 1001
        private const val SOCKS_PORT = 10808

        const val EXTRA_PROFILE_ID = "extra_profile_id"
        const val EXTRA_PROFILE_NAME = "extra_profile_name"
        const val EXTRA_SERVER_ADDRESS = "extra_server_address"
        const val EXTRA_SERVER_PORT = "extra_server_port"
        const val EXTRA_PROTOCOL = "extra_protocol"
        const val EXTRA_RAW_CONFIG = "extra_raw_config"
        const val EXTRA_ENGINE_TYPE = "extra_engine_type"
        const val EXTRA_RUNTIME_CONFIG_JSON = "extra_runtime_config_json"
    }
}

private data class VpnConnectionConfig(
    val profileId: String,
    val profileName: String,
    val serverAddress: String,
    val serverPort: Int,
    val protocol: String,
    val rawConfig: String,
    val engineType: String,
    val runtimeConfigJson: String,
    val runtimeSummary: String,
) {
    companion object {
        fun fromIntent(intent: Intent): VpnConnectionConfig {
            val runtimeConfigJson =
                intent.getStringExtra(LunexVpnService.EXTRA_RUNTIME_CONFIG_JSON) ?: "{}"
            val runtimeSummary = summarizeRuntimeConfig(runtimeConfigJson)
            return VpnConnectionConfig(
                profileId = intent.getStringExtra(LunexVpnService.EXTRA_PROFILE_ID) ?: "unknown",
                profileName = intent.getStringExtra(LunexVpnService.EXTRA_PROFILE_NAME) ?: "Lunex",
                serverAddress = intent.getStringExtra(LunexVpnService.EXTRA_SERVER_ADDRESS) ?: "",
                serverPort = intent.getIntExtra(LunexVpnService.EXTRA_SERVER_PORT, 0),
                protocol = intent.getStringExtra(LunexVpnService.EXTRA_PROTOCOL) ?: "custom",
                rawConfig = intent.getStringExtra(LunexVpnService.EXTRA_RAW_CONFIG) ?: "",
                engineType = intent.getStringExtra(LunexVpnService.EXTRA_ENGINE_TYPE) ?: "xray",
                runtimeConfigJson = runtimeConfigJson,
                runtimeSummary = runtimeSummary,
            )
        }

        private fun summarizeRuntimeConfig(runtimeConfigJson: String): String {
            return try {
                val root = JSONObject(runtimeConfigJson)
                val engineConfig = root.optJSONObject("engineConfig")
                val outbounds = engineConfig?.optJSONArray("outbounds")
                val proxy = outbounds?.optJSONObject(0)
                val streamSettings = proxy?.optJSONObject("streamSettings")
                val network = streamSettings?.optString("network", "tcp") ?: "tcp"
                val security = streamSettings?.optString("security", "none") ?: "none"
                "network=$network, security=$security"
            } catch (_: Exception) {
                "unparsed runtime config"
            }
        }
    }
}
