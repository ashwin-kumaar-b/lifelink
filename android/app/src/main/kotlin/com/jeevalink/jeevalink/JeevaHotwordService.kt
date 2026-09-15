package com.jeevalink.jeevalink

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
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

class JeevaHotwordService : Service() {

    companion object {
        private const val TAG = "JeevaHotwordService"
        const val CHANNEL_ID = "JeevaHotwordChannel"
        const val NOTIFICATION_ID = 9921
        const val ACTION_START = "com.jeevalink.ACTION_START_HOTWORD"
        const val ACTION_STOP = "com.jeevalink.ACTION_STOP_HOTWORD"
        const val ACTION_TRIGGER_RECORD = "com.jeevalink.ACTION_TRIGGER_RECORD"
        const val ACTION_PAUSE_HOTWORD = "com.jeevalink.ACTION_PAUSE_HOTWORD"
        const val ACTION_RESUME_HOTWORD = "com.jeevalink.ACTION_RESUME_HOTWORD"
    }

    private var speechRecognizer: SpeechRecognizer? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private var isListeningActive = false

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action ?: ACTION_START

        when (action) {
            ACTION_STOP -> {
                stopHotwordListening()
                stopForeground(true)
                stopSelf()
                return START_NOT_STICKY
            }
            ACTION_PAUSE_HOTWORD -> {
                stopHotwordListening()
            }
            ACTION_RESUME_HOTWORD -> {
                startHotwordListening()
            }
            ACTION_TRIGGER_RECORD -> {
                triggerAppLaunchAndRecord("HEY_JEEVA")
            }
            else -> {
                createNotificationChannel()
                val notification = buildNotification()
                startForeground(NOTIFICATION_ID, notification)
                startHotwordListening()
            }
        }

        return START_STICKY
    }

    private fun startHotwordListening() {
        if (isListeningActive) return
        isListeningActive = true

        mainHandler.post {
            initSpeechRecognizer()
        }
    }

    private fun stopHotwordListening() {
        isListeningActive = false
        mainHandler.post {
            try {
                speechRecognizer?.stopListening()
                speechRecognizer?.destroy()
                speechRecognizer = null
            } catch (e: Exception) {
                Log.e(TAG, "Error stopping SpeechRecognizer: ${e.message}")
            }
        }
    }

    private fun initSpeechRecognizer() {
        if (!isListeningActive) return

        try {
            if (!SpeechRecognizer.isRecognitionAvailable(this)) {
                Log.e(TAG, "Speech Recognition unavailable on this device")
                return
            }

            if (speechRecognizer != null) {
                try {
                    speechRecognizer?.destroy()
                } catch (e: Exception) {}
            }

            speechRecognizer = SpeechRecognizer.createSpeechRecognizer(this)
            speechRecognizer?.setRecognitionListener(object : RecognitionListener {
                override fun onReadyForSpeech(params: Bundle?) {}
                override fun onBeginningOfSpeech() {}
                override fun onRmsChanged(rmsdB: Float) {}
                override fun onBufferReceived(buffer: ByteArray?) {}
                override fun onEndOfSpeech() {}

                override fun onError(error: Int) {
                    Log.d(TAG, "Speech recognizer error in background service: $error")
                    scheduleNextListeningCycle(1000)
                }

                override fun onResults(results: Bundle?) {
                    val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                    if (!matches.isNullOrEmpty()) {
                        for (text in matches) {
                            Log.d(TAG, "Background audio recognized text: $text")
                            if (isHotwordDetected(text)) {
                                Log.d(TAG, "HOTWORD DETECTED! Directly launching app and starting record...")
                                triggerAppLaunchAndRecord("HEY_JEEVA")
                                scheduleNextListeningCycle(3000)
                                return
                            }
                        }
                    }
                    scheduleNextListeningCycle(500)
                }

                override fun onPartialResults(partialResults: Bundle?) {
                    val matches = partialResults?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                    if (!matches.isNullOrEmpty()) {
                        for (text in matches) {
                            if (isHotwordDetected(text)) {
                                Log.d(TAG, "HOTWORD DETECTED IN PARTIAL RESULTS! Directly launching app...")
                                triggerAppLaunchAndRecord("HEY_JEEVA")
                                scheduleNextListeningCycle(3000)
                                return
                            }
                        }
                    }
                }

                override fun onEvent(eventType: Int, params: Bundle?) {}
            })

            val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 3)
                putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            }

            speechRecognizer?.startListening(intent)

        } catch (e: Exception) {
            Log.e(TAG, "Error initializing background speech recognizer: ${e.message}")
            scheduleNextListeningCycle(2000)
        }
    }

    private fun scheduleNextListeningCycle(delayMs: Long) {
        if (!isListeningActive) return
        mainHandler.postDelayed({
            if (isListeningActive) {
                initSpeechRecognizer()
            }
        }, delayMs)
    }

    private fun isHotwordDetected(rawText: String): Boolean {
        val text = rawText.lowercase().replace(Regex("[^a-z0-9\\s]"), "")
        return text.contains("hey jeeva") ||
               text.contains("hey jiva") ||
               text.contains("jeeva") ||
               text.contains("jiva") ||
               text.contains("hey ziva") ||
               text.contains("ziva") ||
               text.contains("emergency") ||
               text.contains("sos") ||
               text.contains("help")
    }

    private fun triggerAppLaunchAndRecord(triggerType: String) {
        val launchIntent = Intent(this, MainActivity::class.java).apply {
            addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_SINGLE_TOP or
                Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or
                Intent.FLAG_ACTIVITY_CLEAR_TOP
            )
            putExtra("EXTRA_VOICE_ASSISTANT_TRIGGER", triggerType)
            putExtra("EXTRA_START_RECORDING", true)
        }

        val pendingIntent = PendingIntent.getActivity(
            this,
            1,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        try {
            pendingIntent.send()
        } catch (e: Exception) {
            try {
                startActivity(launchIntent)
            } catch (ex: Exception) {
                Log.e(TAG, "Failed to launch activity: ${ex.message}")
            }
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Jeeva Voice Assistant",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Jeeva Voice Assistant Listening Service"
            }
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(): Notification {
        val launchIntent = Intent(this, MainActivity::class.java).apply {
            addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_SINGLE_TOP or
                Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
            )
            putExtra("EXTRA_VOICE_ASSISTANT_TRIGGER", "NOTIFICATION_TAP")
            putExtra("EXTRA_START_RECORDING", true)
        }

        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Jeeva Voice Assistant Active")
            .setContentText("Listening for 'Hey Jeeva' — Saying it opens app directly!")
            .setSmallIcon(android.R.drawable.ic_btn_speak_now)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .build()
    }

    override fun onDestroy() {
        stopHotwordListening()
        super.onDestroy()
    }
}
