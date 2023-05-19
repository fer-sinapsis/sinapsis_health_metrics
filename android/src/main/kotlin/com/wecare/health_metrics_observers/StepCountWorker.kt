package co.sinapsis.sinapsis_health_metrics

import android.content.Context
import androidx.work.Worker
import androidx.work.WorkerParameters
import com.google.android.gms.fitness.Fitness
import com.google.android.gms.fitness.data.DataPoint
import com.google.android.gms.fitness.data.Field
import com.google.android.gms.fitness.request.DataReadRequest
import co.sinapsis.sinapsis_health_metrics.AppConstants
import co.sinapsis.sinapsis_health_metrics.ObserverStatus
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
        val apiUrl = inputData.getString("api_url")

        if(userId == null || apiKey == null || apiUrl == null || xApiKey == null){
            // TODO: communicate error to bugsnag
            completion(false)
            return
        }

        try {
            val context = this.applicationContext
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

                getStepsArray(
                    startDate = startDate,
                    endDate = endDate,
                    context = this.applicationContext,
                    success = { stepDatapoints ->
                        val stepRecords = stepDatapoints.mapIndexed { _, dataPoint ->
                            return@mapIndexed dataPoint.toMap()
                        }

                        if (stepRecords.isEmpty()) {
                            completion(false)
                            return@getStepsArray
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

    private fun getStepsArray(
        startDate: Date,
        endDate: Date,
        context: Context,
        success:(List<DataPoint>) -> Unit,
        failure: (Exception) -> Unit,
    ){
        val readRequest =
            DataReadRequest.Builder()
                .read(HealthDataObserverCreator.CONFIG_DATATYPE)
                .setTimeRange(startDate.time, endDate.time, TimeUnit.MILLISECONDS)
                .build()

        val googleSignInAccount = HealthDataObserverCreator
            .getGoogleSignInAccount(context)

        Fitness.getHistoryClient(context, googleSignInAccount)
            .readData(readRequest)
            .addOnSuccessListener { response ->
                val dataSet = response.getDataSet(HealthDataObserverCreator.CONFIG_DATATYPE)
                if (dataSet.dataPoints.size == 0) {  return@addOnSuccessListener }
                val consolidated = DataPointConsolidation.consolidateIfNeeded(dataSet.dataPoints)
               success(consolidated)
            }
            .addOnFailureListener { e ->
                failure(e)
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

class DataPointConsolidation {
    companion object {
        fun consolidateIfNeeded(samples: List<DataPoint>): List<DataPoint> {
            val sources: MutableMap<String, String> = mutableMapOf()
            for (sample in samples) {
                val streamIdentifier = sample.dataSource.streamIdentifier
                sources[streamIdentifier] = streamIdentifier
            }
            if(sources.keys.count() > 1){
                val timeUnit = TimeUnit.MILLISECONDS
                val sortedSamples = samples.sortedBy { it.getStartTime(timeUnit) }
                var cursor = 0
                val consolidatedResults: MutableList<DataPoint> = mutableListOf()

                while (cursor < sortedSamples.count()) {
                    var current = sortedSamples[cursor]
                    var lastOverlapped: Int? = null
                    var overlapped: MutableList<DataPoint> = mutableListOf()

                    for(i in (cursor + 1) until sortedSamples.count()){
                        var next = sortedSamples[i];
                        if(current.dataSource.streamIdentifier != next.dataSource.streamIdentifier){
                            val overlapResult = current.checkIfOverlapsWith(next)
                            if(overlapResult != null){
                                if(overlapped.isEmpty()) {
                                    overlapped.add(current)
                                }
                                overlapped.add(next)
                                lastOverlapped = i
                            }
                        }
                    }

                    if(lastOverlapped != null){
                        cursor = lastOverlapped + 1; // updated with last overlapped
                        overlapped.sortBy { it.extractValue() }
                        //pick biggest or the longest from overlapped ones
                        consolidatedResults.add(overlapped.last());
                    }else{
                        consolidatedResults.add(current)
                        cursor += 1; // if no merges move to next to evaluate
                    }
                }
                return consolidatedResults
            } else {
                return samples
            }
        }
    }
}

fun Date.isSameDay(date2: Date): Boolean {
    val fmt = SimpleDateFormat("yyyyMMdd")
    return fmt.format(this) == fmt.format(date2)
}

fun DataPoint.toMap(): Map<String, Any> {
    val startDateMillisecs = this.getStartTime(TimeUnit.MILLISECONDS)
    val endDateMillisecs = this.getEndTime(TimeUnit.MILLISECONDS)
    val dateFormat = SimpleDateFormat(AppConstants.defaultDateFormat)
    return hashMapOf(
        "value" to this.extractValue(),
        "measurement_start_date" to dateFormat.format(Date(startDateMillisecs)),
        "measurement_end_date" to dateFormat.format(Date(endDateMillisecs)),
    )
}

fun DataPoint.extractValue(): Int{
    return this.getValue(Field.FIELD_STEPS).asInt()
}

fun DataPoint.checkIfOverlapsWith(pointToCompare: DataPoint) : Pair<DataPoint, DataPoint>? {
    var older: DataPoint
    var earlier: DataPoint
    val timeUnit = TimeUnit.MILLISECONDS
    if (this.getStartTime(timeUnit) < pointToCompare.getStartTime(timeUnit)) {
        older = this
        earlier = pointToCompare
    } else {
        older = pointToCompare
        earlier = this
    }

    val earlierStartAfterOlderStart = earlier.getStartTime(timeUnit) >= older.getStartTime(timeUnit)
    val earlierStartBeforeOlderEnd = earlier.getStartTime(timeUnit) < older.getEndTime(timeUnit)
    val earlierStartsInsideOlder = earlierStartAfterOlderStart && earlierStartBeforeOlderEnd
    return if (earlierStartsInsideOlder) (older to earlier) else null
}