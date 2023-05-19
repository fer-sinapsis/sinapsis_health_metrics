package co.sinapsis.health_metrics_observers

import android.content.Context
import androidx.work.Data
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.workDataOf
import com.google.android.gms.auth.api.signin.GoogleSignIn
import com.google.android.gms.auth.api.signin.GoogleSignInAccount
import com.google.android.gms.auth.api.signin.GoogleSignInOptionsExtension
import com.google.android.gms.fitness.Fitness
import com.google.android.gms.fitness.FitnessOptions
import com.google.android.gms.fitness.data.DataType
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

import java.util.concurrent.TimeUnit

class HealthDataObserverCreator {
    companion object {
        private const val WORKER_FREQUENCY: Long = 15
        val CONFIG_DATATYPE = DataType.TYPE_STEP_COUNT_DELTA

        fun createStepCountObserver(
            flutterMethodCall: MethodCall,
            flutterResult: MethodChannel.Result,
            context: Context
        ) {
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

            createRecordingClient(context) { result ->
                result.fold({
                    createWorker(userId, xApiKey, apiKey, apiUrl, context)
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

        private fun createRecordingClient(context: Context, completion: (Result<Unit>) -> Unit) {
            try {
                val googleSignInAccount = getGoogleSignInAccount(context)
                Fitness.getRecordingClient(context, googleSignInAccount)
                    .subscribe(CONFIG_DATATYPE)
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
            userId: String,
            xApiKey: String,
            apiKey: String,
            apiUrl: String,
            context: Context
        ): Result<Unit> {
            try {
                val workerData: Data = workDataOf(
                    "user_id" to userId,
                    "api_key" to apiKey,
                    "x_api_key" to xApiKey,
                    "api_url" to apiUrl,
                )
                val workRequest =
                    PeriodicWorkRequestBuilder<StepCountUpdateWorker>(
                        WORKER_FREQUENCY,
                        TimeUnit.MINUTES
                    )
                        .setInputData(workerData)
                        .build()
                val workManager = WorkManager.getInstance(context)
                workManager.enqueue(workRequest)
                return Result.success(Unit)
            } catch (exception: Exception) {
                val customException =
                    HealthDataObserverCreationErrors.workerCreationFailed
                return Result.failure(customException)
            }
        }

        fun getGoogleSignInAccount(context: Context): GoogleSignInAccount {
            val fitnessOptions: GoogleSignInOptionsExtension = FitnessOptions.builder()
                .addDataType(
                    HealthDataObserverCreator.CONFIG_DATATYPE,
                    FitnessOptions.ACCESS_READ
                )
                .build()
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