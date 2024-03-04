package com.wecare.health_metrics_observers

import android.content.Context
import androidx.work.Data
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkRequest
import androidx.work.workDataOf
import com.google.android.gms.auth.api.signin.GoogleSignIn
import com.google.android.gms.auth.api.signin.GoogleSignInAccount
import com.google.android.gms.auth.api.signin.GoogleSignInOptionsExtension
import com.google.android.gms.fitness.Fitness
import com.google.android.gms.fitness.FitnessOptions
import com.google.android.gms.fitness.data.DataType
import com.wecare.health_metrics_observers.workouts.WorkoutTrackerWorker
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

import java.util.concurrent.TimeUnit

class HealthDataObserverCreator {
    companion object {
        private const val WORKER_FREQUENCY: Long = 15

        fun createObserver(
            metricType: MetricType,
            flutterMethodCall: MethodCall,
            flutterResult: MethodChannel.Result,
            context: Context
        ) {
            val shouldSyncWithServer = flutterMethodCall.argument<Boolean>("shouldSyncToServer")
            var workerData: Data?
            if (shouldSyncWithServer == true) {
                val userId = flutterMethodCall.argument<String>("userId")
                val apiKey = flutterMethodCall.argument<String>("userApiKey")
                val xApiKey = flutterMethodCall.argument<String>("xApiKey")
                val apiUrl = flutterMethodCall.argument<String>("apiUrl")

                if (userId == null || apiKey == null || apiUrl == null || xApiKey == null) {
                    val exception = HealthDataObserverCreationErrors.expectedDataFailed
                    flutterResult.error(
                        exception.code,
                        exception.message,
                        null
                    )
                    return
                }
                ObserverStatus.updateApiUrl(context, newApiUrl = apiUrl)
                workerData = workDataOf(
                    "user_id" to userId,
                    "api_key" to apiKey,
                    "x_api_key" to xApiKey,
                    "api_url" to apiUrl,
                    "metric_type" to metricType.getValue(),
                )
            } else {
                val metadata = flutterMethodCall.argument<String>("metadata")
                val observerMetadataKey = "${metricType.getValue().lowercase()}_observer_metadata"
                if (metadata != null) {
                    ObserverStatus.updateObserverMetadata(
                        context,
                        observerMetadataKey,
                        metadata
                    )
                }
                workerData = workDataOf(
                    "metric_type" to metricType.getValue(),
                )
            }

            createRecordingClient(metricType, context) { result ->
                result.fold({
                    createWorker(metricType, workerData, context)
                        .fold({
                            ObserverStatus.updateObserverCreated(context, created = true)
                            flutterResult.success(true)
                        }, { exception ->
                            ObserverStatus.updateObserverCreated(context, created = false)
                            flutterResult.error(
                                (exception as HealthDataObserverCreationException).code,
                                exception.message,
                                null
                            )
                        })
                }, { exception ->
                    ObserverStatus.updateObserverCreated(context, created = false)
                    flutterResult.error(
                        (exception as HealthDataObserverCreationException).code,
                        exception.message,
                        null
                    )
                })
            }
        }

        private fun createRecordingClient(metricType: MetricType, context: Context, completion: (Result<Unit>) -> Unit) {
            try {
                val dataType: DataType = metricType.dataType()
                val googleSignInAccount = getGoogleSignInAccount(dataType, context)
                Fitness.getRecordingClient(context, googleSignInAccount)
                    .subscribe(dataType)
                    .addOnSuccessListener {
                        completion(Result.success(Unit))
                    }.addOnFailureListener {
                        val customException =
                            HealthDataObserverCreationErrors.recordingClientCreationFailed
                        completion(Result.failure(customException))
                    }
            } catch (exception: Exception) {
                val customException = HealthDataObserverCreationErrors.recordingClientCreationFailed
                completion(Result.failure(customException))
            }
        }

        private fun createWorker(
            metricType: MetricType,
            workerData: Data,
            context: Context
        ): Result<Unit> {
            try {
                val workRequest: WorkRequest
                if (metricType == MetricType.Workout) {
                    workRequest = PeriodicWorkRequestBuilder<WorkoutTrackerWorker>(
                        WORKER_FREQUENCY,
                        TimeUnit.MINUTES
                    ).setInputData(workerData).build()

                } else {
                    workRequest = PeriodicWorkRequestBuilder<StepCountUpdateWorker>(
                        WORKER_FREQUENCY,
                        TimeUnit.MINUTES
                    ).setInputData(workerData).build()
                }

                val workManager = WorkManager.getInstance(context)
                workManager.enqueue(workRequest)
                return Result.success(Unit)
            } catch (exception: Exception) {
                val customException =
                    HealthDataObserverCreationErrors.workerCreationFailed
                return Result.failure(customException)
            }
        }

        fun getGoogleSignInAccount(dataType: DataType, context: Context): GoogleSignInAccount {
            val fitnessOptionsBuilder = FitnessOptions.builder()
            fitnessOptionsBuilder.addDataType(dataType, FitnessOptions.ACCESS_READ)

            if (dataType == DataType.TYPE_ACTIVITY_SEGMENT) {
                fitnessOptionsBuilder
                    .accessActivitySessions(FitnessOptions.ACCESS_READ)
                    .addDataType(DataType.TYPE_DISTANCE_DELTA)
                    .addDataType(DataType.TYPE_STEP_COUNT_DELTA)
            }
            val fitnessOptions: GoogleSignInOptionsExtension = fitnessOptionsBuilder.build()
            return GoogleSignIn.getAccountForExtension(context, fitnessOptions)
        }
    }
}

class HealthDataObserverCreationException(val code: String, message: String? = null) :
    Exception(message)

class HealthDataObserverCreationErrors {
    companion object {
        val expectedDataFailed = HealthDataObserverCreationException(
            "missing_input_data",
            "userId, apiKey or apiUrl are missing"
        )

        val recordingClientCreationFailed = HealthDataObserverCreationException(
            "recording_creation_failed",
            "recording client creation has failed"
        )

        val workerCreationFailed = HealthDataObserverCreationException(
            "worker_creation_failed",
            "worker creation has failed"
        )
    }
}