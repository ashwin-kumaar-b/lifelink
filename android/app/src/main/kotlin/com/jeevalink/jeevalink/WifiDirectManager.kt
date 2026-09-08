package com.jeevalink.jeevalink

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.NetworkInfo
import android.net.wifi.p2p.*
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log

class WifiDirectManager(
    private val context: Context,
    private val onConnectionInfoAvailable: (WifiP2pInfo) -> Unit,
    private val onPeersAvailable: (List<Map<String, String>>) -> Unit,
    private val onStatusChanged: (String) -> Unit
) {
    private val tag = "WifiDirectManager"
    private var manager: WifiP2pManager? = null
    private var channel: WifiP2pManager.Channel? = null
    private var receiver: BroadcastReceiver? = null
    private var intentFilter: IntentFilter = IntentFilter()

    private val handler = Handler(Looper.getMainLooper())
    private var isAutoDiscoveryActive = false
    private val discoveryRunnable = object : Runnable {
        override fun run() {
            if (isAutoDiscoveryActive) {
                discoverPeers { _, _ -> }
                handler.postDelayed(this, 10000) // Repeat peer discovery every 10 seconds
            }
        }
    }

    init {
        manager = context.getSystemService(Context.WIFI_P2P_SERVICE) as? WifiP2pManager
        channel = manager?.initialize(context, context.mainLooper, null)

        intentFilter.addAction(WifiP2pManager.WIFI_P2P_STATE_CHANGED_ACTION)
        intentFilter.addAction(WifiP2pManager.WIFI_P2P_PEERS_CHANGED_ACTION)
        intentFilter.addAction(WifiP2pManager.WIFI_P2P_CONNECTION_CHANGED_ACTION)
        intentFilter.addAction(WifiP2pManager.WIFI_P2P_THIS_DEVICE_CHANGED_ACTION)
    }

    fun registerReceiver() {
        receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                when (intent?.action) {
                    WifiP2pManager.WIFI_P2P_STATE_CHANGED_ACTION -> {
                        val state = intent.getIntExtra(WifiP2pManager.EXTRA_WIFI_STATE, -1)
                        if (state == WifiP2pManager.WIFI_P2P_STATE_ENABLED) {
                            onStatusChanged("WIFI_DIRECT_ENABLED")
                            startAutoDiscovery()
                        } else {
                            onStatusChanged("WIFI_DIRECT_DISABLED")
                        }
                    }
                    WifiP2pManager.WIFI_P2P_PEERS_CHANGED_ACTION -> {
                        requestPeers()
                    }
                    WifiP2pManager.WIFI_P2P_CONNECTION_CHANGED_ACTION -> {
                        val networkInfo = intent.getParcelableExtra<NetworkInfo>(WifiP2pManager.EXTRA_NETWORK_INFO)
                        if (networkInfo?.isConnected == true) {
                            manager?.requestConnectionInfo(channel) { info ->
                                Log.d(tag, "Connection info: isGroupOwner=${info.isGroupOwner}, ownerIp=${info.groupOwnerAddress?.hostAddress}")
                                onConnectionInfoAvailable(info)
                                onStatusChanged(if (info.isGroupOwner) "CONNECTED_GROUP_OWNER" else "CONNECTED_CLIENT")
                            }
                            requestGroupInfo()
                        } else {
                            onStatusChanged("DISCONNECTED")
                            createGroup()
                        }
                    }
                }
            }
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            context.registerReceiver(receiver, intentFilter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            context.registerReceiver(receiver, intentFilter)
        }
        startAutoDiscovery()
    }

    fun startAutoDiscovery() {
        if (!isAutoDiscoveryActive) {
            isAutoDiscoveryActive = true
            handler.post(discoveryRunnable)
        }
    }

    fun stopAutoDiscovery() {
        isAutoDiscoveryActive = false
        handler.removeCallbacks(discoveryRunnable)
    }

    fun createGroup() {
        try {
            manager?.createGroup(channel, object : WifiP2pManager.ActionListener {
                override fun onSuccess() {
                    Log.d(tag, "Local Wi-Fi Direct group created automatically")
                }

                override fun onFailure(reason: Int) {
                    Log.w(tag, "Failed to auto-create group: $reason")
                }
            })
        } catch (e: SecurityException) {
            Log.e(tag, "Security exception creating group", e)
        }
    }

    fun unregisterReceiver() {
        stopAutoDiscovery()
        receiver?.let {
            try {
                context.unregisterReceiver(it)
            } catch (e: Exception) {
                Log.e(tag, "Error unregistering receiver", e)
            }
        }
    }

    fun discoverPeers(callback: (Boolean, String?) -> Unit) {
        try {
            manager?.discoverPeers(channel, object : WifiP2pManager.ActionListener {
                override fun onSuccess() {
                    Log.d(tag, "Discovery initiated")
                    callback(true, null)
                }

                override fun onFailure(reasonCode: Int) {
                    val msg = "Discovery failed with code $reasonCode"
                    Log.e(tag, msg)
                    callback(false, msg)
                }
            })
        } catch (e: SecurityException) {
            callback(false, "Missing permission for peer discovery: ${e.message}")
        }
    }

    private fun requestGroupInfo() {
        try {
            manager?.requestGroupInfo(channel) { group ->
                if (group != null) {
                    val clientList = group.clientList.map { device ->
                        mapOf(
                            "deviceName" to (device.deviceName ?: "Connected Phone"),
                            "deviceAddress" to device.deviceAddress,
                            "status" to "CONNECTED_CLIENT"
                        )
                    }
                    if (clientList.isNotEmpty()) {
                        Log.d(tag, "Group client phones: ${clientList.size}")
                        onPeersAvailable(clientList)
                    }
                }
            }
        } catch (e: SecurityException) {
            Log.e(tag, "Permission error requesting group info", e)
        }
    }

    private fun requestPeers() {
        try {
            manager?.requestPeers(channel) { peerList ->
                val list = peerList.deviceList.map { device ->
                    mapOf(
                        "deviceName" to (device.deviceName ?: "Nearby Phone"),
                        "deviceAddress" to device.deviceAddress,
                        "status" to device.status.toString()
                    )
                }
                Log.d(tag, "Discovered ${list.size} peers")
                onPeersAvailable(list)

                for (device in peerList.deviceList) {
                    if (device.status == WifiP2pDevice.AVAILABLE) {
                        Log.d(tag, "Auto-connecting to available peer: ${device.deviceName}")
                        connect(device.deviceAddress) { _, _ -> }
                        break
                    }
                }
            }
            requestGroupInfo()
        } catch (e: SecurityException) {
            Log.e(tag, "Permission error requesting peers", e)
        }
    }

    fun connect(deviceAddress: String, callback: (Boolean, String?) -> Unit) {
        val config = WifiP2pConfig().apply {
            this.deviceAddress = deviceAddress
        }
        try {
            manager?.connect(channel, config, object : WifiP2pManager.ActionListener {
                override fun onSuccess() {
                    Log.d(tag, "Connecting to $deviceAddress")
                    onStatusChanged("CONNECTING")
                    callback(true, null)
                }

                override fun onFailure(reasonCode: Int) {
                    val msg = "Connect failed with code $reasonCode"
                    Log.e(tag, msg)
                    callback(false, msg)
                }
            })
        } catch (e: SecurityException) {
            callback(false, "Missing permission: ${e.message}")
        }
    }

    fun disconnect(callback: (Boolean) -> Unit) {
        manager?.removeGroup(channel, object : WifiP2pManager.ActionListener {
            override fun onSuccess() {
                onStatusChanged("DISCONNECTED")
                callback(true)
            }

            override fun onFailure(reason: Int) {
                callback(false)
            }
        })
    }
}
