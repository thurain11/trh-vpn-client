package com.lunex.vpn

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel

object VpnEventDispatcher {
    private var eventSink: EventChannel.EventSink? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private var lastPayload: Map<String, Any> = mapOf(
        "status" to "disconnected",
        "downloadBytes" to 0,
        "uploadBytes" to 0,
    )

    fun attach(eventSink: EventChannel.EventSink?) {
        this.eventSink = eventSink
        eventSink?.success(lastPayload)
    }

    fun detach() {
        eventSink = null
    }

    fun dispatchImportUri(uri: String) {
        dispatch(
            payload = mapOf(
                "action" to "import_uri",
                "uri" to uri,
            ),
            remember = false,
        )
    }

    fun dispatchStatus(
        status: String,
        downloadBytes: Int = 0,
        uploadBytes: Int = 0,
        profileName: String? = null,
        configPath: String? = null,
        logFilePath: String? = null,
        commandPreview: String? = null,
        severity: String? = null,
        message: String? = null,
    ) {
        val payload = mutableMapOf<String, Any>(
            "status" to status,
            "downloadBytes" to downloadBytes,
            "uploadBytes" to uploadBytes,
        )
        if (profileName != null) {
            payload["profileName"] = profileName
        }
        if (configPath != null) {
            payload["configPath"] = configPath
        }
        if (logFilePath != null) {
            payload["logFilePath"] = logFilePath
        }
        if (commandPreview != null) {
            payload["commandPreview"] = commandPreview
        }
        if (severity != null) {
            payload["severity"] = severity
        }
        if (message != null) {
            payload["message"] = message
        }
        dispatch(payload)
    }

    private fun dispatch(payload: Map<String, Any>, remember: Boolean = true) {
        if (remember) {
            lastPayload = payload
        }
        mainHandler.post {
            eventSink?.success(payload)
        }
    }
}
