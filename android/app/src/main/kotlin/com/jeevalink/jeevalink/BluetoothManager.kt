package com.jeevalink.jeevalink

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothClass
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothServerSocket
import android.bluetooth.BluetoothSocket
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.util.Log
import kotlinx.coroutines.*
import java.io.BufferedReader
import java.io.InputStreamReader
import java.io.PrintWriter
import java.util.UUID

class BluetoothManager(
    private val context: Context,
    private val onMessageReceived: (String) -> Unit,
    private val onPeersDiscovered: (List<Map<String, String>>) -> Unit
) {
    private val tag = "BluetoothManager"
    private val appUuid: UUID = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB") // Standard SPP UUID

    private var bluetoothAdapter: BluetoothAdapter? = null
    private var serverSocket: BluetoothServerSocket? = null
    private var isListening = false
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    private val discoveredDevices = mutableListOf<BluetoothDevice>()

    init {
        bluetoothAdapter = BluetoothAdapter.getDefaultAdapter()
        if (bluetoothAdapter == null) {
            Log.w(tag, "Bluetooth is not supported on this device")
        }
    }

    private fun isJeevaLinkCandidate(device: BluetoothDevice): Boolean {
        try {
            val name = try { device.name ?: "" } catch (e: SecurityException) { "" }
            val btClass = try { device.bluetoothClass } catch (e: SecurityException) { null }

            // Always allow phones & computers
            if (btClass != null && (btClass.majorDeviceClass == BluetoothClass.Device.Major.PHONE || btClass.majorDeviceClass == BluetoothClass.Device.Major.COMPUTER)) {
                return true
            }

            // Only filter out devices with explicit audio/accessory keywords in name
            val lowerName = name.lowercase()
            val blacklistedKeywords = listOf("buds", "headphone", "earphone", "airpod", "speaker", "soundbar", "noise", "boat", "realme buds", "tv")
            for (keyword in blacklistedKeywords) {
                if (lowerName.isNotEmpty() && lowerName.contains(keyword)) {
                    Log.d(tag, "Ignoring blacklisted audio accessory BT device: $name")
                    return false
                }
            }

            // Default: ALLOW device so real phones are never blocked!
            return true
        } catch (e: Exception) {
            return true
        }
    }

    fun registerReceiver() {
        val filter = IntentFilter().apply {
            addAction(BluetoothDevice.ACTION_FOUND)
            addAction(BluetoothAdapter.ACTION_DISCOVERY_FINISHED)
        }

        val receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                when (intent?.action) {
                    BluetoothDevice.ACTION_FOUND -> {
                        val device: BluetoothDevice? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                            intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE, BluetoothDevice::class.java)
                        } else {
                            @Suppress("DEPRECATION")
                            intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE)
                        }
                        if (device != null && isJeevaLinkCandidate(device) && !discoveredDevices.contains(device)) {
                            try {
                                discoveredDevices.add(device)
                                notifyPeers()
                            } catch (e: SecurityException) {
                                Log.e(tag, "Security error adding BT device", e)
                            }
                        }
                    }
                    BluetoothAdapter.ACTION_DISCOVERY_FINISHED -> {
                        Log.d(tag, "Bluetooth discovery finished")
                    }
                }
            }
        }

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                context.registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
            } else {
                context.registerReceiver(receiver, filter)
            }
        } catch (e: Exception) {
            Log.e(tag, "Error registering BT receiver", e)
        }
    }

    fun startServer() {
        if (isListening || bluetoothAdapter == null || bluetoothAdapter?.isEnabled != true) return
        isListening = true

        scope.launch {
            try {
                serverSocket = bluetoothAdapter?.listenUsingInsecureRfcommWithServiceRecord("JeevaLinkBT", appUuid)
                Log.d(tag, "Bluetooth RFCOMM ServerSocket listening on UUID $appUuid")
                while (isListening) {
                    try {
                        val socket = serverSocket?.accept() ?: break
                        Log.d(tag, "Bluetooth RFCOMM client connected: ${socket.remoteDevice.name}")
                        handleIncomingConnection(socket)
                    } catch (e: Exception) {
                        if (isListening) {
                            Log.e(tag, "Error accepting BT connection", e)
                        }
                    }
                }
            } catch (e: SecurityException) {
                Log.e(tag, "Bluetooth permission error listening", e)
            } catch (e: Exception) {
                Log.e(tag, "Failed to start Bluetooth ServerSocket", e)
            }
        }
    }

    private fun handleIncomingConnection(socket: BluetoothSocket) {
        scope.launch {
            try {
                socket.use { s ->
                    val reader = BufferedReader(InputStreamReader(s.inputStream, Charsets.UTF_8))
                    val message = reader.readLine()
                    if (!message.isNullOrBlank()) {
                        Log.d(tag, "Received Bluetooth payload: $message")
                        withContext(Dispatchers.Main) {
                            onMessageReceived(message)
                        }
                    }
                }
            } catch (e: Exception) {
                Log.e(tag, "Error reading from Bluetooth socket", e)
            }
        }
    }

    fun discoverPeers() {
        try {
            if (bluetoothAdapter?.isEnabled == true) {
                discoveredDevices.clear()
                val paired = bluetoothAdapter?.bondedDevices
                if (paired != null) {
                    for (dev in paired) {
                        if (isJeevaLinkCandidate(dev)) {
                            discoveredDevices.add(dev)
                        }
                    }
                }
                notifyPeers()

                if (bluetoothAdapter?.isDiscovering == true) {
                    bluetoothAdapter?.cancelDiscovery()
                }
                bluetoothAdapter?.startDiscovery()
            }
        } catch (e: SecurityException) {
            Log.e(tag, "Bluetooth permission error discovering peers", e)
        }
    }

    private fun notifyPeers() {
        try {
            val list = discoveredDevices.map { device ->
                mapOf(
                    "deviceName" to (device.name ?: "JeevaLink Node"),
                    "deviceAddress" to device.address,
                    "type" to "BLUETOOTH"
                )
            }
            onPeersDiscovered(list)
        } catch (e: SecurityException) {
            Log.e(tag, "Security error building peer list", e)
        }
    }

    fun sendBluetoothMessage(jsonPayload: String, callback: (Boolean, String?) -> Unit) {
        scope.launch {
            var sentAny = false
            var lastError: String? = null

            try {
                if (bluetoothAdapter?.isEnabled == true) {
                    val devices = mutableListOf<BluetoothDevice>()
                    val paired = bluetoothAdapter?.bondedDevices
                    if (paired != null) devices.addAll(paired.filter { isJeevaLinkCandidate(it) })
                    devices.addAll(discoveredDevices)

                    for (device in devices.distinctBy { it.address }) {
                        try {
                            val socket = device.createInsecureRfcommSocketToServiceRecord(appUuid)
                            socket.connect()
                            val writer = PrintWriter(socket.outputStream, true)
                            writer.println(jsonPayload)
                            writer.flush()
                            socket.close()
                            sentAny = true
                            Log.d(tag, "Sent BT packet to ${device.name} (${device.address})")
                        } catch (e: Exception) {
                            Log.w(tag, "BT send to ${device.address} failed: ${e.message}")
                            lastError = e.message
                        }
                    }
                }
            } catch (e: SecurityException) {
                Log.e(tag, "Permission error sending BT message", e)
                lastError = e.message
            }

            withContext(Dispatchers.Main) {
                if (sentAny) {
                    callback(true, null)
                } else {
                    callback(false, lastError ?: "Bluetooth send failed")
                }
            }
        }
    }

    fun stopServer() {
        isListening = false
        try {
            serverSocket?.close()
        } catch (e: Exception) {
            Log.e(tag, "Error closing Bluetooth server socket", e)
        }
        scope.cancel()
    }
}
