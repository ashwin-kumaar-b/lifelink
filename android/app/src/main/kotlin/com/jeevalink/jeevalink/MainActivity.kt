package com.jeevalink.jeevalink

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val METHOD_CHANNEL = "com.jeevalink/bridge"
    private val EVENT_CHANNEL = "com.jeevalink/events"

    private var wifiDirectManager: WifiDirectManager? = null
    private var socketManager: SocketManager? = null
    private var speechManager: SpeechManager? = null
    private var bluetoothManager: BluetoothManager? = null
    private var notificationHelper: NotificationHelper? = null
    private var eventSink: EventChannel.EventSink? = null

    private var groupOwnerIp: String? = null
    private var pendingAssistantTrigger: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        unlockWindowFlags()
        handleVoiceAssistantIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        unlockWindowFlags()
        handleVoiceAssistantIntent(intent)
    }

    override fun onResume() {
        super.onResume()
        pauseBackgroundHotwordService()
    }

    override fun onPause() {
        super.onPause()
        resumeBackgroundHotwordService()
    }

    private fun pauseBackgroundHotwordService() {
        try {
            val intent = Intent(this, JeevaHotwordService::class.java).apply {
                action = JeevaHotwordService.ACTION_PAUSE_HOTWORD
            }
            startService(intent)
        } catch (e: Exception) {
            // ignore if service not running
        }
    }

    private fun resumeBackgroundHotwordService() {
        try {
            val intent = Intent(this, JeevaHotwordService::class.java).apply {
                action = JeevaHotwordService.ACTION_RESUME_HOTWORD
            }
            startService(intent)
        } catch (e: Exception) {
            // ignore
        }
    }

    private fun unlockWindowFlags() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
            val km = getSystemService(android.content.Context.KEYGUARD_SERVICE) as? android.app.KeyguardManager
            km?.requestDismissKeyguard(this, null)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                android.view.WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                android.view.WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                android.view.WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
                android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
            )
        }
    }

    private fun handleVoiceAssistantIntent(intent: Intent?) {
        if (intent == null) return
        val action = intent.action
        val trigger = intent.getStringExtra("EXTRA_VOICE_ASSISTANT_TRIGGER")

        if (Intent.ACTION_ASSIST == action || "android.intent.action.VOICE_COMMAND" == action || "android.intent.action.SEARCH_LONG_PRESS" == action) {
            // Power Button long press OR Assistant gesture
            val triggerType = "POWER_BUTTON_ASSIST"
            pendingAssistantTrigger = triggerType
            sendVoiceTriggerEvent(triggerType)
        } else if (trigger != null) {
            pendingAssistantTrigger = trigger
            sendVoiceTriggerEvent(trigger)
        }
    }

    private fun sendVoiceTriggerEvent(triggerType: String) {
        pendingAssistantTrigger = null
        sendEvent(
            mapOf(
                "type" to "VOICE_ASSISTANT_TRIGGERED",
                "trigger" to triggerType,
                "autoRecord" to true
            )
        )
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Initialize Native Notification Helper
        notificationHelper = NotificationHelper(this)

        // EventChannel for streaming asynchronous events to Flutter
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                    // If a pending voice trigger exists when Flutter connects, emit it immediately
                    pendingAssistantTrigger?.let {
                        sendVoiceTriggerEvent(it)
                    }
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            }
        )

        // Initialize Native Wi-Fi Direct Manager
        wifiDirectManager = WifiDirectManager(
            context = this,
            onConnectionInfoAvailable = { info ->
                groupOwnerIp = info.groupOwnerAddress?.hostAddress
                sendEvent(
                    mapOf(
                        "type" to "CONNECTION_INFO",
                        "isGroupOwner" to info.isGroupOwner,
                        "groupOwnerIp" to (groupOwnerIp ?: "")
                    )
                )
            },
            onPeersAvailable = { peers ->
                sendEvent(
                    mapOf(
                        "type" to "PEERS_DISCOVERED",
                        "peers" to peers
                    )
                )
            },
            onStatusChanged = { status ->
                sendEvent(
                    mapOf(
                        "type" to "STATUS_CHANGED",
                        "status" to status
                    )
                )
            }
        )
        wifiDirectManager?.registerReceiver()

        // Initialize Native Socket Manager
        socketManager = SocketManager(port = 8888) { jsonMessage ->
            notificationHelper?.showNotificationFromJson(jsonMessage)
            sendEvent(
                mapOf(
                    "type" to "MESSAGE_RECEIVED",
                    "payload" to jsonMessage,
                    "transport" to "WIFI_DIRECT"
                )
            )
        }
        socketManager?.startServer(context = this)

        // Initialize Native Bluetooth Fallback Manager
        bluetoothManager = BluetoothManager(
            context = this,
            onMessageReceived = { jsonMessage ->
                notificationHelper?.showNotificationFromJson(jsonMessage)
                sendEvent(
                    mapOf(
                        "type" to "MESSAGE_RECEIVED",
                        "payload" to jsonMessage,
                        "transport" to "BLUETOOTH"
                    )
                )
            },
            onPeersDiscovered = { btPeers ->
                sendEvent(
                    mapOf(
                        "type" to "PEERS_DISCOVERED",
                        "peers" to btPeers
                    )
                )
            }
        )
        bluetoothManager?.registerReceiver()
        bluetoothManager?.startServer()
        bluetoothManager?.discoverPeers()

        // Initialize Native Speech Engine
        speechManager = SpeechManager(
            context = this,
            onSTTResult = { text ->
                sendEvent(
                    mapOf(
                        "type" to "STT_RESULT",
                        "text" to text
                    )
                )
            },
            onSTTError = { error ->
                sendEvent(
                    mapOf(
                        "type" to "STT_ERROR",
                        "error" to error
                    )
                )
            }
        )

        // MethodChannel for Flutter method calls
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "discoverPeers" -> {
                    wifiDirectManager?.discoverPeers { success, error -> }
                    bluetoothManager?.discoverPeers()
                    result.success(true)
                }
                "connectPeer" -> {
                    val deviceAddress = call.argument<String>("deviceAddress")
                    if (deviceAddress != null) {
                        wifiDirectManager?.connect(deviceAddress) { success, error ->
                            if (success) {
                                result.success(true)
                            } else {
                                result.error("CONNECT_FAILED", error, null)
                            }
                        }
                    } else {
                        result.error("INVALID_ARGS", "Device address required", null)
                    }
                }
                "disconnectPeer" -> {
                    wifiDirectManager?.disconnect { success ->
                        result.success(success)
                    }
                }
                "sendMessage" -> {
                    val targetIp = call.argument<String>("targetIp")
                    val jsonPayload = call.argument<String>("jsonPayload")
                    if (jsonPayload != null) {
                        // Dual Broadcast: Send over Wi-Fi Direct Sockets AND Bluetooth RFCOMM Fallback!
                        socketManager?.broadcastMessage(jsonPayload, targetIp) { _, _ -> }
                        bluetoothManager?.sendBluetoothMessage(jsonPayload) { _, _ -> }
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGS", "jsonPayload required", null)
                    }
                }
                "startSTT" -> {
                    val language = call.argument<String>("language") ?: "en-US"
                    speechManager?.startListening(language)
                    result.success(true)
                }
                "stopSTT" -> {
                    speechManager?.stopListening()
                    result.success(true)
                }
                "speakTTS" -> {
                    val text = call.argument<String>("text") ?: ""
                    val language = call.argument<String>("language") ?: "en"
                    speechManager?.speak(text, language)
                    result.success(true)
                }
                "getGroupOwnerIp" -> {
                    result.success(groupOwnerIp ?: "")
                }
                "openAssistantSettings" -> {
                    val intentsToTry = listOf(
                        Intent(Settings.ACTION_VOICE_INPUT_SETTINGS),
                        Intent("android.settings.VOICE_INPUT_SETTINGS"),
                        Intent(Settings.ACTION_MANAGE_DEFAULT_APPS_SETTINGS),
                        Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName"))
                    )
                    var opened = false
                    for (intent in intentsToTry) {
                        try {
                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            startActivity(intent)
                            opened = true
                            break
                        } catch (e: Exception) {
                            // continue trying next setting intent
                        }
                    }
                    if (opened) {
                        result.success(true)
                    } else {
                        result.error("INTENT_FAILED", "Could not launch voice assistant settings", null)
                    }
                }
                "openOverlaySettings" -> {
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            val intent = Intent(
                                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                                Uri.parse("package:$packageName")
                            )
                            startActivity(intent)
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("INTENT_FAILED", e.message, null)
                    }
                }
                "startHotwordService" -> {
                    try {
                        val intent = Intent(this, JeevaHotwordService::class.java).apply {
                            action = JeevaHotwordService.ACTION_START
                        }
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(intent)
                        } else {
                            startService(intent)
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SERVICE_START_FAILED", e.message, null)
                    }
                }
                "stopHotwordService" -> {
                    try {
                        val intent = Intent(this, JeevaHotwordService::class.java).apply {
                            action = JeevaHotwordService.ACTION_STOP
                        }
                        startService(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("SERVICE_STOP_FAILED", e.message, null)
                    }
                }
                "isOverlayGranted" -> {
                    val granted = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        Settings.canDrawOverlays(this)
                    } else {
                        true
                    }
                    result.success(granted)
                }
                "checkPendingAssistantTrigger" -> {
                    val trigger = pendingAssistantTrigger
                    pendingAssistantTrigger = null
                    result.success(trigger)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun sendEvent(data: Map<String, Any>) {
        runOnUiThread {
            eventSink?.success(data)
        }
    }

    override fun onDestroy() {
        wifiDirectManager?.unregisterReceiver()
        socketManager?.stopServer()
        bluetoothManager?.stopServer()
        speechManager?.destroy()
        super.onDestroy()
    }
}
