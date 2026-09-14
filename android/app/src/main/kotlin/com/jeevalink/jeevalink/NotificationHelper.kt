package com.jeevalink.jeevalink

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.os.Build
import androidx.core.app.NotificationCompat
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class NotificationHelper(private val context: Context) {

    companion object {
        private const val EMERGENCY_CHANNEL_ID = "jeevalink_emergency_channel"
        private const val EMERGENCY_CHANNEL_NAME = "JeevaLink Emergency SOS Alerts"

        private const val NORMAL_CHANNEL_ID = "jeevalink_normal_channel"
        private const val NORMAL_CHANNEL_NAME = "JeevaLink Normal Messages"

        private var notificationIdCounter = 1000
    }

    private val notificationManager =
        context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

    init {
        createNotificationChannels()
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            // 1. High Priority Emergency SOS Alert Channel
            val emergencyChannel = NotificationChannel(
                EMERGENCY_CHANNEL_ID,
                EMERGENCY_CHANNEL_NAME,
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "High priority notifications for emergency SOS broadcasts"
                enableLights(true)
                lightColor = Color.RED
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 500, 200, 500, 200, 800)
            }

            // 2. Normal Message Channel (WhatsApp Style)
            val normalChannel = NotificationChannel(
                NORMAL_CHANNEL_ID,
                NORMAL_CHANNEL_NAME,
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply {
                description = "Standard notifications for normal off-grid messages"
                enableLights(true)
                lightColor = Color.BLUE
                enableVibration(true)
            }

            notificationManager.createNotificationChannel(emergencyChannel)
            notificationManager.createNotificationChannel(normalChannel)
        }
    }

    fun showNotificationFromJson(jsonPayload: String) {
        try {
            val json = JSONObject(jsonPayload)
            val type = json.optString("type", "NORMAL")
            val text = json.optString("text", "No message content")
            val latitude = json.optDouble("latitude", 0.0)
            val longitude = json.optDouble("longitude", 0.0)
            val isEmergency = type.equals("EMERGENCY", ignoreCase = true)

            val timeFormat = SimpleDateFormat("hh:mm a", Locale.getDefault())
            val formattedTime = timeFormat.format(Date())

            val intent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }

            val pendingIntent = PendingIntent.getActivity(
                context,
                0,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            val notificationId = notificationIdCounter++

            if (isEmergency) {
                // EMERGENCY NOTIFICATION
                val gpsString = if (latitude != 0.0 || longitude != 0.0) {
                    "📍 Location: Lat %.4f, Lon %.4f".format(latitude, longitude)
                } else {
                    "📍 Location: Coordinates unavailable"
                }

                val expandedText = "🚨 EMERGENCY SOS\nMessage: \"$text\"\nTiming: $formattedTime\n$gpsString"

                val builder = NotificationCompat.Builder(context, EMERGENCY_CHANNEL_ID)
                    .setSmallIcon(android.R.drawable.stat_sys_warning)
                    .setContentTitle("🚨 EMERGENCY SOS - JeevaLink")
                    .setContentText("\"$text\" • $formattedTime")
                    .setSubText("Emergency Alert")
                    .setStyle(NotificationCompat.BigTextStyle().bigText(expandedText))
                    .setColor(Color.RED)
                    .setPriority(NotificationCompat.PRIORITY_MAX)
                    .setCategory(NotificationCompat.CATEGORY_ALARM)
                    .setContentIntent(pendingIntent)
                    .setAutoCancel(true)
                    .setDefaults(NotificationCompat.DEFAULT_ALL)

                notificationManager.notify(notificationId, builder.build())
            } else {
                // NORMAL NOTIFICATION
                val expandedText = "💬 JeevaLink Message\nMessage: \"$text\"\nTiming: $formattedTime"

                val builder = NotificationCompat.Builder(context, NORMAL_CHANNEL_ID)
                    .setSmallIcon(android.R.drawable.stat_notify_chat)
                    .setContentTitle("💬 JeevaLink Message")
                    .setContentText("\"$text\" • $formattedTime")
                    .setSubText("JeevaLink Off-Grid")
                    .setStyle(NotificationCompat.BigTextStyle().bigText(expandedText))
                    .setColor(Color.parseColor("#1976D2"))
                    .setPriority(NotificationCompat.PRIORITY_DEFAULT)
                    .setCategory(NotificationCompat.CATEGORY_MESSAGE)
                    .setContentIntent(pendingIntent)
                    .setAutoCancel(true)

                notificationManager.notify(notificationId, builder.build())
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
}
