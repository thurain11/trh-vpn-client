package com.lunex.vpn

import android.app.Activity
import android.content.Intent
import android.net.VpnService
import android.os.Bundle
import android.util.Base64
import android.util.Log
import androidx.core.content.FileProvider
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity(), MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
    private var pendingStartArguments: Map<String, Any?>? = null
    private var pendingImportUri: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleIncomingIntent(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            METHOD_CHANNEL_NAME,
        ).setMethodCallHandler(this)

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            EVENT_CHANNEL_NAME,
        ).setStreamHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        Log.d(TAG, "onMethodCall: ${call.method}")
        when (call.method) {
            "startVpn" -> {
                val arguments = call.arguments<Map<String, Any?>>().orEmpty()
                Log.d(TAG, "startVpn: id=${arguments["id"]}, engine=${arguments["engineType"]}")
                val prepareIntent = VpnService.prepare(this)
                if (prepareIntent != null) {
                    Log.d(TAG, "VPN permission not granted yet, requesting...")
                    pendingStartArguments = arguments
                    startActivityForResult(prepareIntent, VPN_PERMISSION_REQUEST_CODE)
                } else {
                    Log.d(TAG, "VPN permission already granted, starting service")
                    startVpnService(arguments)
                }
                result.success(null)
            }

            "stopVpn" -> {
                Log.d(TAG, "stopVpn called")
                val stopIntent = Intent(this, LunexVpnService::class.java).apply {
                    action = LunexVpnService.ACTION_STOP
                }
                startService(stopIntent)
                result.success(null)
            }

            "openLogFile" -> {
                val path = call.argument<String>("path")
                if (path.isNullOrBlank()) {
                    result.error("invalid_path", "Log file path is required.", null)
                    return
                }
                openLogFile(path)
                result.success(null)
            }

            "shareLogFile" -> {
                val path = call.argument<String>("path")
                if (path.isNullOrBlank()) {
                    result.error("invalid_path", "Log file path is required.", null)
                    return
                }
                shareLogFile(path)
                result.success(null)
            }

            "consumePendingImportUri" -> {
                result.success(pendingImportUri)
                pendingImportUri = null
            }

            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        VpnEventDispatcher.attach(events)
    }

    override fun onCancel(arguments: Any?) {
        VpnEventDispatcher.detach()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIncomingIntent(intent)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)

        if (requestCode != VPN_PERMISSION_REQUEST_CODE) {
            return
        }

        if (resultCode == Activity.RESULT_OK) {
            Log.i(TAG, "VPN permission granted")
            startVpnService(pendingStartArguments.orEmpty())
        } else {
            Log.w(TAG, "VPN permission denied")
            VpnEventDispatcher.dispatchStatus(
                status = "error",
                message = "VPN permission was denied.",
            )
        }
        pendingStartArguments = null
    }

    private fun startVpnService(arguments: Map<String, Any?>) {
        Log.d(TAG, "startVpnService: building intent for LunexVpnService")
        val intent = Intent(this, LunexVpnService::class.java).apply {
            action = LunexVpnService.ACTION_START
            putExtra(LunexVpnService.EXTRA_PROFILE_ID, arguments["id"] as? String)
            putExtra(LunexVpnService.EXTRA_PROFILE_NAME, arguments["name"] as? String)
            putExtra(LunexVpnService.EXTRA_SERVER_ADDRESS, arguments["serverAddress"] as? String)
            putExtra(LunexVpnService.EXTRA_SERVER_PORT, (arguments["serverPort"] as? Int) ?: 0)
            putExtra(LunexVpnService.EXTRA_PROTOCOL, arguments["protocol"] as? String)
            putExtra(LunexVpnService.EXTRA_RAW_CONFIG, arguments["rawConfig"] as? String)
            putExtra(LunexVpnService.EXTRA_ENGINE_TYPE, arguments["engineType"] as? String)
            putExtra(
                LunexVpnService.EXTRA_RUNTIME_CONFIG_JSON,
                arguments["runtimeConfigJson"] as? String,
            )
        }
        ContextCompat.startForegroundService(this, intent)
    }

    private fun handleIncomingIntent(intent: Intent?) {
        if (intent?.action != ACTION_IMPORT_URI) {
            return
        }
        val uri = resolveImportUri(intent)
        if (uri.isNotEmpty()) {
            pendingImportUri = uri
            VpnEventDispatcher.dispatchImportUri(uri)
        }
    }

    private fun resolveImportUri(intent: Intent): String {
        val directUri = intent.getStringExtra(EXTRA_IMPORT_URI)?.trim().orEmpty()
        if (directUri.isNotEmpty()) {
            return directUri
        }

        val encodedUri = intent.getStringExtra(EXTRA_IMPORT_URI_BASE64)?.trim().orEmpty()
        if (encodedUri.isEmpty()) {
            return ""
        }

        return try {
            String(Base64.decode(encodedUri, Base64.DEFAULT)).trim()
        } catch (_: IllegalArgumentException) {
            ""
        }
    }

    private fun openLogFile(path: String) {
        val file = File(path)
        if (!file.exists()) {
            throw IllegalArgumentException("Log file does not exist: $path")
        }
        val uri = FileProvider.getUriForFile(this, FILE_PROVIDER_AUTHORITY, file)
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "text/plain")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(Intent.createChooser(intent, "Open Lunex log"))
    }

    private fun shareLogFile(path: String) {
        val file = File(path)
        if (!file.exists()) {
            throw IllegalArgumentException("Log file does not exist: $path")
        }
        val uri = FileProvider.getUriForFile(this, FILE_PROVIDER_AUTHORITY, file)
        val intent = Intent(Intent.ACTION_SEND).apply {
            type = "text/plain"
            putExtra(Intent.EXTRA_STREAM, uri)
            putExtra(Intent.EXTRA_SUBJECT, "Lunex VPN Log")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        startActivity(Intent.createChooser(intent, "Share Lunex log"))
    }

    companion object {
        private const val TAG = "LunexMainActivity"
        private const val METHOD_CHANNEL_NAME = "com.lunex.vpn/methods"
        private const val EVENT_CHANNEL_NAME = "com.lunex.vpn/events"
        private const val VPN_PERMISSION_REQUEST_CODE = 101
        private const val FILE_PROVIDER_AUTHORITY = "com.lunex.vpn.fileprovider"
        const val ACTION_IMPORT_URI = "com.lunex.vpn.action.IMPORT_URI"
        const val EXTRA_IMPORT_URI = "extra_import_uri"
        const val EXTRA_IMPORT_URI_BASE64 = "extra_import_uri_base64"
    }
}
