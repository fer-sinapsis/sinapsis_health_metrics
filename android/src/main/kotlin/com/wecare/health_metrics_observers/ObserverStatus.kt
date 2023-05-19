package co.sinapsis.sinapsis_health_metrics

import android.content.Context
import java.text.SimpleDateFormat
import java.util.*

class AppConstants {
    companion object {
        const val defaultDateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ"
        const val sharedPrefId = "wecare.default.preferences"
    }
}

class ObserverStatus {
    companion object {
        //observer
        const val observerCreatedKey = "observer_created"
        const val observerSyncingKey = "observer_syncing"
        //steps
        const val lastAttemptToSendKey = "last_attempt_to_send"
        const val observerOnlyLastDateSavedKey = "last_date_saved_observer"
        const val lastStepCountSentKey = "last_step_count_sent"
        const val lastDateSavedKey = "last_date_saved"
        //sleep
        const val lastSleepValueSentKey = "last_sleep_value_sent"
        const val lastSleepDateSavedKey = "last_sleep_date_saved"


        fun getLastDateSaved(context: Context, metricType: String): Long? {
            val sharedPref =
                context.getSharedPreferences(AppConstants.sharedPrefId, Context.MODE_PRIVATE)
            val dateFormat = SimpleDateFormat(AppConstants.defaultDateFormat)
            val lastDateSavedKeyByType = getLastDateSavedKeyByMetricType(metricType)
            val dateSavedString = sharedPref.getString(lastDateSavedKeyByType, null)

            if (dateSavedString != null) {
                val lastDateSaved = dateFormat.parse(dateSavedString)
                return lastDateSaved?.time ?: null
            }else{
                return null
            }
        }

        fun updateLastDateSaved(context: Context, newDateInMilliseconds: Long, metricType: String) {
            val sharedPref = context.getSharedPreferences(AppConstants.sharedPrefId, Context.MODE_PRIVATE)
            val dateFormat = SimpleDateFormat(AppConstants.defaultDateFormat)
            val newDate = Date(newDateInMilliseconds)
            val lastDateSavedKeyByType = getLastDateSavedKeyByMetricType(metricType)
            with (sharedPref.edit()) {
                putString(lastDateSavedKeyByType, dateFormat.format(newDate))
                apply()
            }
        }

        private fun getLastDateSavedKeyByMetricType(metricType: String): String {
            return when (metricType) {
                "STEP" -> lastDateSavedKey
                "SLEEP" -> lastSleepDateSavedKey
                else -> ""
            }
        }

        private fun getLastAttemptDate(context: Context): Long? {
            val sharedPref =
                context.getSharedPreferences(AppConstants.sharedPrefId, Context.MODE_PRIVATE)
            val dateFormat = SimpleDateFormat(AppConstants.defaultDateFormat)
            val dateSavedString = sharedPref.getString(lastAttemptToSendKey, null)
            if (dateSavedString != null) {
                val lastAttempt = dateFormat.parse(dateSavedString)
                return lastAttempt?.time ?: null
            }else{
                return null
            }
        }

        //last saved - observer only
        fun getLastDateSavedObserverOnly(context: Context): Long? {
            val sharedPref =
                context.getSharedPreferences(AppConstants.sharedPrefId, Context.MODE_PRIVATE)
            val dateFormat = SimpleDateFormat(AppConstants.defaultDateFormat)
            val dateSavedString = sharedPref.getString(observerOnlyLastDateSavedKey, null)

            if (dateSavedString != null) {
                val lastDateSaved = dateFormat.parse(dateSavedString)
                return lastDateSaved?.time ?: null
            }else{
                return null
            }
        }

        fun isObserverSyncing(context: Context) : Boolean {
            val sharedPref = context.getSharedPreferences(AppConstants.sharedPrefId, Context.MODE_PRIVATE)
            return sharedPref.getBoolean(observerSyncingKey, false)
        }

        fun updateObserverSyncing(context: Context, newValue: Boolean){
            val sharedPref = context.getSharedPreferences(AppConstants.sharedPrefId, Context.MODE_PRIVATE)
            with (sharedPref.edit()) {
                putBoolean(observerSyncingKey, newValue)
                apply()
            }
        }

        fun updateObserverCreated(context: Context, created: Boolean){
            val sharedPref =
                context.getSharedPreferences(AppConstants.sharedPrefId, Context.MODE_PRIVATE)
            with (sharedPref.edit()) {
                putBoolean(observerCreatedKey, created)
                apply()
            }
        }

        fun hasObserverCreated(context: Context): Boolean {
            val sharedPref =
                context.getSharedPreferences(AppConstants.sharedPrefId, Context.MODE_PRIVATE)
            return sharedPref.getBoolean(observerCreatedKey, false)
        }

        fun getStatusMap(context: Context): Map<String, Any?> {
            val sharedPref =
                context.getSharedPreferences(AppConstants.sharedPrefId, Context.MODE_PRIVATE)
            val lastDateSavedSharedSteps = ObserverStatus.getLastDateSaved(context, "STEP")
            val lastDateSavedSharedSleep = ObserverStatus.getLastDateSaved(context, "SLEEP")
            return mapOf<String, Any?>(
                "last_saved" to lastDateSavedSharedSteps,
                "last_saved_date_across_sources" to lastDateSavedSharedSteps,
                "last_saved_date_observer_only" to ObserverStatus.getLastDateSavedObserverOnly(context),
                "last_attempt_timestamp" to ObserverStatus.getLastAttemptDate(context),
                "last_steps_count_saved" to sharedPref.getInt(lastStepCountSentKey, 0),
                "observer_syncing" to isObserverSyncing(context),
                "created" to ObserverStatus.hasObserverCreated(context),
                "last_saved_sleep_date_across_sources" to lastDateSavedSharedSleep,
            )
        }
    }
}