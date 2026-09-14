package com.jeevalink.jeevalink

import android.os.Bundle
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
    private var eventSink: EventChannel.EventSink? = null

    private var groupOwnerIp: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // EventChannel for streaming asynchronous events to Flutter
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
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
