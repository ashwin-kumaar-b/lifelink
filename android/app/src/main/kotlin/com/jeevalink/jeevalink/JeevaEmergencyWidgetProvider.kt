package com.jeevalink.jeevalink

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

class JeevaEmergencyWidgetProvider : AppWidgetProvider() {

    companion object {
        const val ACTION_WIDGET_SOS_TAP = "com.jeevalink.ACTION_WIDGET_SOS_TAP"

        fun updateWidgetState(context: Context, statusText: String, titleText: String = "EMERGENCY SOS") {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val componentName = ComponentName(context, JeevaEmergencyWidgetProvider::class.java)
            val widgetIds = appWidgetManager.getAppWidgetIds(componentName)

            for (widgetId in widgetIds) {
                val views = RemoteViews(context.packageName, R.layout.jeeva_emergency_widget)
                views.setTextViewText(R.id.widget_title, titleText)
                views.setTextViewText(R.id.widget_status, statusText)

                val intent = Intent(context, JeevaEmergencyWidgetProvider::class.java).apply {
                    action = ACTION_WIDGET_SOS_TAP
                }
                val pendingIntent = PendingIntent.getBroadcast(
                    context,
                    0,
                    intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.widget_button, pendingIntent)

                appWidgetManager.updateAppWidget(widgetId, views)
            }
        }
    }

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.jeeva_emergency_widget)

            val intent = Intent(context, JeevaEmergencyWidgetProvider::class.java).apply {
                action = ACTION_WIDGET_SOS_TAP
            }
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                0,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_button, pendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (ACTION_WIDGET_SOS_TAP == intent.action) {
            val serviceIntent = Intent(context, JeevaBackgroundRecordService::class.java)
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                context.startForegroundService(serviceIntent)
            } else {
                context.startService(serviceIntent)
            }
        }
    }
}
