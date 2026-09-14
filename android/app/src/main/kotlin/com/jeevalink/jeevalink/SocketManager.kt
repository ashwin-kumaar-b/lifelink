package com.jeevalink.jeevalink

import android.content.Context
import android.net.wifi.WifiManager
import android.util.Log
import kotlinx.coroutines.*
import java.io.BufferedReader
import java.io.InputStreamReader
import java.io.PrintWriter
import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.InetAddress
import java.net.ServerSocket
import java.net.Socket

class SocketManager(
    private val port: Int = 8888,
    private val onMessageReceived: (String) -> Unit
) {
    private val tag = "SocketManager"
    private var serverSocket: ServerSocket? = null
    private var udpSocket: DatagramSocket? = null
    private var multicastLock: WifiManager.MulticastLock? = null
    private var isListening = false
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())

    private val connectedPeerIps = mutableSetOf<String>()

    fun registerPeerIp(ip: String) {
        if (ip.isNotEmpty() && ip != "127.0.0.1") {
            connectedPeerIps.add(ip)
        }
    }

    fun startServer(context: Context? = null) {
        if (context != null) {
            try {
                val wifi = context.applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager
                multicastLock = wifi?.createMulticastLock("JeevaLinkMulticastLock")?.apply {
                    setReferenceCounted(true)
                    acquire()
                }
                Log.d(tag, "Acquired WifiManager MulticastLock")
            } catch (e: Exception) {
                Log.w(tag, "Could not acquire MulticastLock: ${e.message}")
            }
        }

        if (isListening) return
        isListening = true

        // 1. TCP ServerSocket Listener
        scope.launch {
            try {
                serverSocket = ServerSocket(port)
                Log.d(tag, "TCP ServerSocket started on port $port")
                while (isListening) {
                    try {
                        val socket = serverSocket?.accept() ?: break
                        val clientIp = socket.inetAddress.hostAddress
                        if (clientIp != null) {
                            registerPeerIp(clientIp)
                        }
                        handleIncomingTcpConnection(socket)
                    } catch (e: Exception) {
                        if (isListening) {
                            Log.e(tag, "Error accepting TCP connection", e)
                        }
                    }
                }
            } catch (e: Exception) {
                Log.e(tag, "Failed to start TCP ServerSocket", e)
            }
        }

        // 2. UDP Broadcast Listener
        scope.launch {
            try {
                udpSocket = DatagramSocket(port).apply {
                    broadcast = true
                }
                Log.d(tag, "UDP BroadcastSocket started on port $port")
                val buffer = ByteArray(4096)
                while (isListening) {
                    try {
                        val packet = DatagramPacket(buffer, buffer.size)
                        udpSocket?.receive(packet)
                        val message = String(packet.data, 0, packet.length, Charsets.UTF_8).trim()
                        if (message.isNotEmpty()) {
                            val senderIp = packet.address.hostAddress
                            if (senderIp != null) {
                                registerPeerIp(senderIp)
                            }
                            Log.d(tag, "Received UDP broadcast packet from $senderIp: $message")
                            withContext(Dispatchers.Main) {
                                onMessageReceived(message)
                            }
                        }
                    } catch (e: Exception) {
                        if (isListening) {
                            Log.e(tag, "Error receiving UDP broadcast", e)
                        }
                    }
                }
            } catch (e: Exception) {
                Log.e(tag, "Failed to start UDP BroadcastSocket", e)
            }
        }
    }

    private fun handleIncomingTcpConnection(socket: Socket) {
        scope.launch {
            try {
                val clientIp = socket.inetAddress.hostAddress
                if (clientIp != null) {
                    registerPeerIp(clientIp)
                }
                socket.use { s ->
                    val reader = BufferedReader(InputStreamReader(s.getInputStream(), Charsets.UTF_8))
                    var message: String?
                    while (s.isConnected && !s.isClosed) {
                        message = reader.readLine() ?: break
                        if (message.isNotBlank()) {
                            Log.d(tag, "Received TCP payload from $clientIp: $message")
                            withContext(Dispatchers.Main) {
                                onMessageReceived(message)
                            }
                        }
                    }
                }
            } catch (e: Exception) {
                Log.e(tag, "Error reading from TCP socket", e)
            }
        }
    }

    fun broadcastMessage(jsonPayload: String, targetIp: String? = null, callback: (Boolean, String?) -> Unit) {
        scope.launch {
            var sentAny = false
            var lastError: String? = null

            // 1. Send UDP Subnet Broadcast
            try {
                val broadcastAddresses = listOf(
                    InetAddress.getByName("255.255.255.255"),
                    InetAddress.getByName("192.168.49.255"),
                    InetAddress.getByName("192.168.43.255")
                )
                val bytes = (jsonPayload + "\n").toByteArray(Charsets.UTF_8)
                val sendSocket = DatagramSocket().apply { broadcast = true }

                for (addr in broadcastAddresses) {
                    try {
                        val packet = DatagramPacket(bytes, bytes.size, addr, port)
                        sendSocket.send(packet)
                        sentAny = true
                    } catch (e: Exception) {
                        Log.w(tag, "UDP send to $addr failed: ${e.message}")
                    }
                }
                sendSocket.close()
            } catch (e: Exception) {
                Log.e(tag, "UDP broadcast error", e)
                lastError = e.message
            }

            // 2. Send TCP to known target IP / connected peers list / standard group owner IP + Subnet Scan (192.168.49.x and 192.168.43.x)
            val targetIps = mutableSetOf<String>()
            if (!targetIp.isNullOrBlank()) targetIps.add(targetIp)
            targetIps.add("192.168.49.1") // Standard Android Wi-Fi Direct Group Owner IP
            targetIps.add("192.168.43.1") // Standard Android Local Hotspot Gateway IP
            targetIps.addAll(connectedPeerIps)

            // Add standard Wi-Fi Direct & Hotspot DHCP Client Subnet Range (.2 -> .20)
            for (i in 2..20) {
                targetIps.add("192.168.49.$i")
                targetIps.add("192.168.43.$i")
            }

            val jobs = targetIps.map { ip ->
                scope.async {
                    try {
                        Socket().use { socket ->
                            socket.connect(java.net.InetSocketAddress(ip, port), 600)
                            val writer = PrintWriter(socket.getOutputStream(), true)
                            writer.println(jsonPayload)
                            writer.flush()
                            sentAny = true
                            registerPeerIp(ip)
                            Log.d(tag, "Sent TCP packet to $ip")
                        }
                    } catch (e: Exception) {
                        // Silent catch for unreachable IP in range scan
                    }
                }
            }
            jobs.awaitAll()

            withContext(Dispatchers.Main) {
                if (sentAny) {
                    callback(true, null)
                } else {
                    callback(false, lastError ?: "Broadcast packet failed")
                }
            }
        }
    }

    fun stopServer() {
        isListening = false
        try {
            multicastLock?.let {
                if (it.isHeld) it.release()
            }
            serverSocket?.close()
            udpSocket?.close()
        } catch (e: Exception) {
            Log.e(tag, "Error closing sockets", e)
        }
        scope.cancel()
    }
}
