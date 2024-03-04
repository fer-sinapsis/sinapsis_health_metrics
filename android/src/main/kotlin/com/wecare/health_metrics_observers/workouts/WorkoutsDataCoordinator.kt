package com.wecare.health_metrics_observers.workouts

import android.content.Context
import com.wecare.health_metrics_observers.AppConstants

class WorkoutsDataCoordinator {
    companion object {
        const val externalWorkoutsNotificationDataKey = "external_workouts_notification_data"

        fun getWorkoutNotificationData(context: Context): String? {
            val sharedPref =
                context.getSharedPreferences(AppConstants.sharedPrefId, Context.MODE_PRIVATE)
            val workoutDataStr = sharedPref.getString(externalWorkoutsNotificationDataKey, null)
            return workoutDataStr
        }

        fun setWorkoutNotificationData(context: Context, notificationData: String?){
            val sharedPref =
                context.getSharedPreferences(AppConstants.sharedPrefId, Context.MODE_PRIVATE)
            with (sharedPref.edit()) {
                if (notificationData != null) {
                    putString(externalWorkoutsNotificationDataKey, notificationData)
                } else {
                    remove(externalWorkoutsNotificationDataKey)
                }
                apply()
            }
        }
    }
}