package com.wecare.health_metrics_observers

import android.content.Context
import androidx.work.Worker
import androidx.work.WorkerParameters
import com.google.android.gms.fitness.Fitness
import com.google.android.gms.fitness.data.DataPoint
import com.google.android.gms.fitness.data.Field
import com.google.android.gms.fitness.request.DataReadRequest
import com.wecare.health_metrics_observers.AppConstants
import com.wecare.health_metrics_observers.ObserverStatus
import java.text.SimpleDateFormat
import java.util.*
import java.util.concurrent.TimeUnit

class StepCountUpdateWorker(appContext: Context, workerParams: WorkerParameters):
    Worker(appContext, workerParams) {
    val sharedPref = this.applicationContext.getSharedPreferences(AppConstants.sharedPrefId, Context.MODE_PRIVATE)

    override fun doWork(): Result {
        ObserverStatus.updateObserverSyncing(context = applicationContext, true);
        attemptToSendSteps {
            ObserverStatus.updateObserverSyncing(context = applicationContext, false);
        }
       return Result.success()
    }

    private fun attemptToSendSteps(completion: (Boolean) -> Unit){
        val userId = inputData.getString("user_id")
        val apiKey = inputData.getString("api_key")
        val xApiKey = inputData.getString("x_api_key")

        try {
            val context = this.applicationContext
            //TODO: next version we could remove the hardcoded url - fallback to null
            val currentApiUrl = ObserverStatus.getApiUrl(context) ?: ""
            if (!currentApiUrl.contains("wecareapi.com")) {
                ObserverStatus.updateApiUrl(context,"https://profile-api.wecareapi.com")
                if (!ObserverStatus.getMigrated(context)) {
                    val sharedPref = context.getSharedPreferences(AppConstants.sharedPrefId, Context.MODE_PRIVATE)
                    ObserverStatus.updateMigrated(context, newValue = true)
                    with (sharedPref.edit()) {
                        remove(ObserverStatus.lastDateSavedKey)
                        remove(ObserverStatus.lastSleepDateSavedKey)
                        apply()
                    }
                }
            }
            val apiUrl = ObserverStatus.getApiUrl(context)

            if(userId == null || apiKey == null || apiUrl == null || xApiKey == null){
                // TODO: communicate error to bugsnag
                completion(false)
                return
            }

            val appVersion = context.packageManager
                .getPackageInfo(context.packageName, 0).versionName

            getLastDateStepsSaved(
                userId = userId,
                apiKey = apiKey,
                xApiKey = xApiKey,
                apiUrl = apiUrl,
                appVersion = appVersion,
            ) { lastTimeSaved ->
                val endDate = Date()
                var startDate = lastTimeSaved ?: Date(endDate.time - (24 * 60 * 60 * 1000))

                HealthMetricsQueryHandler.getDataPoints(
                    startDate = startDate,
                    endDate = endDate,
                    dataType = MetricType.Step.dataType(),
                    context = this.applicationContext,
                    success = { stepDatapoints ->
                        val stepRecords = stepDatapoints.mapIndexed { _, dataPoint ->
                            return@mapIndexed dataPoint.toMap()
                        }

                        if (stepRecords.isEmpty()) {
                            completion(false)
                            return@getDataPoints
                        }

                        HealthMetricsApiService.sendSteps(
                            userId = userId,
                            apiKey = apiKey,
                            xApiKey = xApiKey,
                            apiUrl = apiUrl,
                            stepRecords = stepRecords,
                            appVersion = appVersion,
                        ){ updated ->
                            if(updated){
                                val lastDayDataPoints = stepDatapoints.filter { dt ->
                                    return@filter Date(dt.getEndTime(TimeUnit.MILLISECONDS)).isSameDay(endDate)
                                }

                                val lastDayStepCount = lastDayDataPoints.fold(0) { acc, dataPoint ->
                                    return@fold acc + dataPoint.getValue(Field.FIELD_STEPS).asInt()
                                }
                                val dateFormatted = AppConstants.defaultDateFormat.format(endDate)
                                with (sharedPref.edit()) {
                                    putString(ObserverStatus.lastDateSavedKey, dateFormatted)
                                    putInt(ObserverStatus.lastStepCountSentKey, lastDayStepCount)
                                    putString(ObserverStatus.observerOnlyLastDateSavedKey, dateFormatted)
                                    apply()
                                }
                            }
                            val lastAttemptFailed = if (updated) null else AppConstants.defaultDateFormat.format(endDate)
                            with (sharedPref.edit()) {
                                putString(ObserverStatus.lastAttemptToSendKey, lastAttemptFailed)
                                apply()
                            }
                            completion(updated)
                        }
                    },
                    failure = { e ->
                        print(e)
                        completion(false)
                        // TODO: communicate error to bugsnag
                    })
            }

        } catch (e: Exception){
            // TODO: communicate error to bugsnag
            completion(false)
        }
    }

    private fun getLastDateStepsSaved(
        userId: String,
        apiKey: String,
        xApiKey: String,
        apiUrl: String,
        appVersion: String,
        completion: (Date?)->Unit
    ){
        val lastDateSaved = sharedPref.getString(ObserverStatus.lastDateSavedKey, null)
        if(lastDateSaved != null) {
            val dateFormat = SimpleDateFormat(AppConstants.defaultDateFormat)
            val newStartDate = dateFormat.parse(lastDateSaved)
            completion(newStartDate);
        }else{
            HealthMetricsApiService.getLastTimeStepsSavedServer(
                userId= userId,
                apiKey= apiKey,
                xApiKey= xApiKey,
                apiUrl= apiUrl,
                appVersion = appVersion,
                httpClient= null,
            ) { lastTimeSaved ->

                if (lastTimeSaved != null) {
                    ObserverStatus.updateLastDateSaved(this.applicationContext, lastTimeSaved.time, "STEP")
                }
                completion(lastTimeSaved)
            }
        }
    }
}