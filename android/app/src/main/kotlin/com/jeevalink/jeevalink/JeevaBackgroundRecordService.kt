package com.jeevalink.jeevalink

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.util.Log
import androidx.core.app.NotificationCompat
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import java.util.UUID

class JeevaBackgroundRecordService : Service() {

    companion object {
        private const val TAG = "JeevaBgRecordService"
        const val CHANNEL_ID = "JeevaWidgetChannel"
        const val NOTIFICATION_ID = 9934
    }

    private var speechRecognizer: SpeechRecognizer? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private var isProcessing = false

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        createNotificationChannel()
        val notification = buildNotification("Recording emergency voice...")
        startForeground(NOTIFICATION_ID, notification)

        if (!isProcessing) {
            isProcessing = true
            JeevaEmergencyWidgetProvider.updateWidgetState(this, "🔴 Recording Voice...")
            startEmergencyVoiceRecording()
        }

        return START_NOT_STICKY
    }

    private fun startEmergencyVoiceRecording() {
        mainHandler.post {
            try {
                if (SpeechRecognizer.isRecognitionAvailable(this)) {
                    speechRecognizer = SpeechRecognizer.createSpeechRecognizer(this)
                    speechRecognizer?.setRecognitionListener(object : RecognitionListener {
                        override fun onReadyForSpeech(params: Bundle?) {}
                        override fun onBeginningOfSpeech() {}
                        override fun onRmsChanged(rmsdB: Float) {}
                        override fun onBufferReceived(buffer: ByteArray?) {}
                        override fun onEndOfSpeech() {}

                        override fun onError(error: Int) {
                            Log.e(TAG, "Speech recognition error: $error. Sending default SOS...")
                            broadcastAndSaveEmergencyPacket("🚨 EMERGENCY SOS BROADCAST VIA HOME WIDGET!")
                        }

                        override fun onResults(results: Bundle?) {
                            val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                            val text = if (!matches.isNullOrEmpty()) {
                                matches[0]
                            } else {
                                "🚨 EMERGENCY SOS BROADCAST VIA HOME WIDGET!"
                            }
                            broadcastAndSaveEmergencyPacket(text)
                        }

                        override fun onPartialResults(partialResults: Bundle?) {}
                        override fun onEvent(eventType: Int, params: Bundle?) {}
                    })

                    val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                        putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                        putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
                    }

                    speechRecognizer?.startListening(intent)

                    // Auto-stop after 5 seconds if silence
                    mainHandler.postDelayed({
                        if (isProcessing) {
                            try {
                                speechRecognizer?.stopListening()
                            } catch (e: Exception) {
                                broadcastAndSaveEmergencyPacket("🚨 EMERGENCY SOS BROADCAST VIA HOME WIDGET!")
                            }
                        }
                    }, 5000)
                } else {
                    broadcastAndSaveEmergencyPacket("🚨 EMERGENCY SOS BROADCAST VIA HOME WIDGET!")
                }
            } catch (e: Exception) {
                Log.e(TAG, "Recording error: ${e.message}")
                broadcastAndSaveEmergencyPacket("🚨 EMERGENCY SOS BROADCAST VIA HOME WIDGET!")
            }
        }
    }

    private fun broadcastAndSaveEmergencyPacket(messageText: String) {
        try {
            val isoFormat = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.US).apply {
                timeZone = TimeZone.getTimeZone("UTC")
            }

            val packetJson = JSONObject().apply {
                put("id", UUID.randomUUID().toString())
                put("sender", "Me (Widget SOS)")
                put("text", messageText)
                put("timestamp", isoFormat.format(Date()))
                put("type", "EMERGENCY")
                put("isEmergency", true)
                put("priority", 1)
                put("ttl", 10)
                put("hops", 0)
                put("language", "en")
            }

            val jsonString = packetJson.toString()

            // 1. Broadcast over socket & Bluetooth
            val socketManager = SocketManager(port = 8888) { }
            socketManager.broadcastMessage(jsonString, null) { _, _ -> }

            val bluetoothManager = BluetoothManager(this, { }, { })
            bluetoothManager.sendBluetoothMessage(jsonString) { _, _ -> }

            // 2. Save into JeevaLink local storage messages_history.json
            savePacketToLocalStorage(packetJson)

            // 3. Update Widget UI
            JeevaEmergencyWidgetProvider.updateWidgetState(this, "⚡ SOS TRANSMITTED!", "BROADCAST SENT ✓")

            mainHandler.postDelayed({
                JeevaEmergencyWidgetProvider.updateWidgetState(this, "Tap to Record & Transmit", "EMERGENCY SOS")
                stopForeground(true)
                stopSelf()
            }, 3500)

        } catch (e: Exception) {
            Log.e(TAG, "Broadcast error: ${e.message}")
            stopForeground(true)
            stopSelf()
        }
    }

    private fun savePacketToLocalStorage(packetJson: JSONObject) {
        try {
            val appDir = filesDir
            val historyFile = File(appDir, "messages_history.json")
            val existingArray = if (historyFile.exists() && historyFile.length() > 0) {
                try {
                    JSONArray(historyFile.readText())
                } catch (e: Exception) {
                    JSONArray()
                }
            } else {
                JSONArray()
            }

            existingArray.put(packetJson)
            historyFile.writeText(existingArray.toString())
        } catch (e: Exception) {
            Log.e(TAG, "Save to local storage error: ${e.message}")
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Jeeva Widget Emergency Service",
                NotificationManager.IMPORTANCE_LOW
            )
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(text: String): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Jeeva Emergency SOS Widget")
            .setContentText(text)
            .setSmallIcon(android.R.drawable.ic_btn_speak_now)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .build()
    }

    override fun onDestroy() {
        try {
            speechRecognizer?.destroy()
        } catch (e: Exception) { }
        super.onDestroy()
    }
}
