package com.wecare.health_metrics_observers.workouts

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.Context.NOTIFICATION_SERVICE
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat.getSystemService
import androidx.work.Worker
import androidx.work.WorkerParameters
import com.wecare.health_metrics_observers.CustomNotificationManager
import com.wecare.health_metrics_observers.HealthMetricsQueryHandler
import com.wecare.health_metrics_observers.MetricType
import com.wecare.health_metrics_observers.ObserverStatus
import com.wecare.health_metrics_observers.R
import java.lang.Exception
import java.util.Date

class WorkoutTrackerWorker(appContext: Context, workerParams: WorkerParameters):
    Worker(appContext, workerParams) {
    override fun doWork(): Result {
        val metricType = MetricType.Workout
        val context = applicationContext
        val lastCheckWorkouts = ObserverStatus.getLastDateSaved(context, metricType.getValue())
        val endDate = Date()
        val daysBackInMillis = 7 * 24 * 60 * 60 * 1000
        val startDate = if (lastCheckWorkouts != null) Date(lastCheckWorkouts) else Date(endDate.time - daysBackInMillis)

        HealthMetricsQueryHandler.getValidExternalWorkouts(
            startDate, endDate, context,
            success = { workouts ->
                if (workouts.isNotEmpty()) {
                    ObserverStatus.updateLastDateSaved(context, Date().time, metricType.getValue())
                    val notificationTitle = "${if (workouts.size > 1) "Activity" else "Activities" } synced! \uD83D\uDD25"
                    val notificationSubtitle = "open Wecare to claim your points"
                    val payload = mutableMapOf<String, Any>("count" to workouts.size)
                    if (workouts.size == 1) {
                        payload["workoutData"] = workouts.first().toMap()
                    }
                    CustomNotificationManager.triggerLocalNotification(
                        applicationContext,
                        "updates",
                        1,
                        notificationTitle,
                        notificationSubtitle,
                        payload
                    )
                }
            },
            failure = { exception ->
                print(exception)
            }
        )
        return Result.success()
        //TODO: Validate if makes sense creating a async worker
    }
}