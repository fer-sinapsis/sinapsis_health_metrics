package com.wecare.health_metrics_observers

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import com.google.gson.Gson


class CustomNotificationManager {
    companion object {
        fun triggerLocalNotification(
            context: Context,
            channelId: String,
            identifier: Int,
            title: String,
            subtitle: String,
            payload: Map<String, Any>,
        ){
            try {
                val notificationManager: NotificationManager = context.getSystemService(
                    Context.NOTIFICATION_SERVICE
                ) as NotificationManager

                val channel = NotificationChannel(
                    channelId,
                    channelId,
                    NotificationManager.IMPORTANCE_DEFAULT
                )
                notificationManager.createNotificationChannel(channel)

                val packageName = context.packageName
                val launchIntent: Intent? = context.packageManager.getLaunchIntentForPackage(packageName)
                val className = launchIntent?.component?.className

                val intent = Intent(context, className?.let { Class.forName(it) })
                val payloadString = Gson().toJson(payload).toString()
                intent.putExtra("payload", payloadString)

                val pendingIntent: PendingIntent? = PendingIntent.getActivity(
                    context,
                    0,
                    intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )

                val notificationBuilder = NotificationCompat.Builder(context, channelId)
                    .setSmallIcon(R.drawable.ic_stat_onesignal_default)
                    .setContentTitle(title)
                    .setContentText(subtitle)
                    .setPriority(NotificationCompat.PRIORITY_DEFAULT)
                    .setContentIntent(pendingIntent)
                    .setAutoCancel(true)

                NotificationManagerCompat.from(context).notify(identifier, notificationBuilder.build())
            } catch (e: Exception) {
                print(e)
            }
        }
    }
}