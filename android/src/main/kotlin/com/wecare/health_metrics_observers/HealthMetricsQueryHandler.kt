package com.wecare.health_metrics_observers

import android.content.Context
import android.icu.util.DateInterval
import com.google.android.gms.auth.api.signin.GoogleSignIn
import com.google.android.gms.fitness.Fitness
import com.google.android.gms.fitness.FitnessOptions
import com.google.android.gms.fitness.data.DataPoint
import com.google.android.gms.fitness.data.DataSet
import com.google.android.gms.fitness.data.DataSource
import com.google.android.gms.fitness.data.DataType
import com.google.android.gms.fitness.data.Field
import com.google.android.gms.fitness.data.Session
import com.google.android.gms.fitness.request.DataReadRequest
import com.google.android.gms.fitness.request.SessionInsertRequest
import com.google.android.gms.fitness.request.SessionReadRequest
import com.google.android.gms.fitness.result.DataReadResponse
import com.google.android.gms.tasks.Task
import com.google.android.gms.tasks.Tasks
import com.google.gson.FieldNamingPolicy
import com.google.gson.Gson
import com.google.gson.GsonBuilder
import com.wecare.health_metrics_observers.workouts.ActivitiesJson
import com.wecare.health_metrics_observers.workouts.ActivityInfo
import com.wecare.health_metrics_observers.workouts.Workout
import java.lang.Long
import java.util.Date
import java.util.UUID
import java.util.concurrent.TimeUnit
import kotlin.Double
import kotlin.Exception
import kotlin.Int
import kotlin.String
import kotlin.Unit
import kotlin.math.abs


class HealthMetricsQueryHandler {
    companion object {
        private fun getDataPointsTask(
            startDate: Date,
            endDate: Date,
            dataType: DataType,
            context: Context,
        ): Task<DataReadResponse> {
            val readRequest =
                DataReadRequest.Builder()
                    .read(dataType)
                    .setTimeRange(startDate.time, endDate.time, TimeUnit.MILLISECONDS)
                    .build()

            val googleSignInAccount = HealthDataObserverCreator
                .getGoogleSignInAccount(dataType, context)

            return Fitness.getHistoryClient(context, googleSignInAccount).readData(readRequest)
        }
        fun getDataPoints(
            startDate: Date,
            endDate: Date,
            dataType: DataType,
            context: Context,
            success: (List<DataPoint>) -> Unit,
            failure: (Exception) -> Unit,
        ) {
            val readDataTask = getDataPointsTask(startDate, endDate, dataType, context)
            readDataTask.addOnSuccessListener { response ->
                val dataSet = response.getDataSet(dataType)
                if (dataSet.dataPoints.size == 0) {
                    success(listOf())
                    return@addOnSuccessListener
                }
                val consolidated =
                    DataPointConsolidation.consolidateIfNeeded(dataSet.dataPoints)
                success(consolidated)
            }.addOnFailureListener { e ->
                failure(e)
            }
        }

        fun workoutIntervalsFromString(activitySegmentsString: String) : List<DateInterval> {
            val segmentsArray = activitySegmentsString.split("|")
            val workoutDateIntervals: MutableList<DateInterval> = mutableListOf()
            for (segmentStr in segmentsArray) {
                val segmentInfo = segmentStr.split(":")
                val startDateMillisecs = Long.parseLong(segmentInfo.first())
                var endDateMillisecs = Long.parseLong(segmentInfo.last())
                // validate if not null ^^
                /*if (startDateMillisecs == endDateMillisecs) {
                    endDateMillisecs = Date().time
                }*/
                workoutDateIntervals.add(DateInterval(startDateMillisecs, endDateMillisecs))
            }
            return workoutDateIntervals
        }

        fun getDataForWorkoutInProgress(
            workoutIntervals: List<DateInterval>,
            metricsSupported: String,
            context: Context,
            success: (WorkoutDataAggregated) -> Unit,
            failure: (Exception) -> Unit
        ){
            var queryTasks = mutableListOf<Task<DataReadResponse>>()
            var metricsSupportedArray =  metricsSupported.split(",")
            for (interval in workoutIntervals) {
                val startDate = Date(interval.fromDate)
                val endDate = Date(interval.toDate)

                if (metricsSupportedArray.contains("steps")) {
                    val stepsQueryTask = getDataPointsTask(startDate, endDate, DataType.TYPE_STEP_COUNT_DELTA, context)
                    queryTasks.add(stepsQueryTask)
                }

                if (metricsSupportedArray.contains("distance")) {
                    val distanceQueryTask =
                        getDataPointsTask(startDate, endDate, DataType.TYPE_DISTANCE_DELTA, context)
                    queryTasks.add(distanceQueryTask)
                }
            }
            if (queryTasks.isNotEmpty()) {
                Tasks.whenAllComplete(queryTasks).addOnSuccessListener {
                    var stepDataPoints = mutableListOf<DataPoint>()
                    var distanceDataPoints = mutableListOf<DataPoint>()
                    for (queryTask in queryTasks) {
                        stepDataPoints.addAll(queryTask.result.getDataSet(DataType.TYPE_STEP_COUNT_DELTA).dataPoints)
                        distanceDataPoints.addAll(queryTask.result.getDataSet(DataType.TYPE_DISTANCE_DELTA).dataPoints)
                    }
                    val stepsCount: Int = stepDataPoints.fold(0) { acc, next ->
                        acc + next.extractValue().toInt()
                    }
                    val distanceInMeters: Double = distanceDataPoints.fold(0.0) { acc, next ->
                        acc + next.extractValue().toDouble()
                    }
                    success(WorkoutDataAggregated(stepsCount, distanceInMeters))
                }.addOnFailureListener { e ->
                    failure(e)
                }
            } else {
                return success(WorkoutDataAggregated(0, 0.0))
            }
        }

        fun createWorkout(
            activityPlatformId: String,
            metricsSupported: String,
            activitySegmentsString: String,
            context: Context,
            startDate: Date,
            endDate: Date,
            success: () -> Unit,
            failure: (Exception) -> Unit,
        ){
            val workoutDateIntervals = workoutIntervalsFromString(activitySegmentsString)
            getDataForWorkoutInProgress(workoutDateIntervals, metricsSupported, context,
                success = { workoutData ->
                    val workoutDuration = workoutDateIntervals.fold(0.0) { acc, dateInterval -> acc + (dateInterval.toDate - dateInterval.fromDate)  }
                    createWorkoutInGoogleFit(
                        startDate = startDate,
                        endDate = endDate,
                        duration = workoutDuration.toLong(),
                        activityType = activityPlatformId,
                        distanceInMeters = workoutData.distanceInMeters,
                        stepsCount = workoutData.stepsCount,
                        context = context,
                        success= {
                            success()
                        },
                        failure= { e ->
                            failure(e)
                        },
                    )
                },
                failure = { e ->
                    failure(e)
                }
            )
        }

        private fun createWorkoutInGoogleFit(
            startDate: Date,
            endDate: Date,
            duration: kotlin.Long,
            activityType: String,
            distanceInMeters: Double,
            stepsCount: Int,
            context: Context,
            success: () -> Unit,
            failure: (Exception) -> Unit,
        ){
            try {
                // session setup
                val session = Session.Builder()
                    .setActiveTime(duration, TimeUnit.MILLISECONDS)
                    .setName(activityType)
                    .setDescription("")
                    .setIdentifier(UUID.randomUUID().toString())
                    .setActivity(activityType)
                    .setStartTime(startDate.time, TimeUnit.MILLISECONDS)
                    .setEndTime(endDate.time, TimeUnit.MILLISECONDS)
                    .build()
                // Build a session
                val sessionInsertRequestBuilder = SessionInsertRequest.Builder()
                    .setSession(session)

                // Create the Activity Segment DataSource
                val activitySegmentDataSource = DataSource.Builder()
                    .setAppPackageName(context.packageName)
                    .setDataType(DataType.TYPE_ACTIVITY_SEGMENT)
                    .setStreamName("FLUTTER_HEALTH - Activity")
                    .setType(DataSource.TYPE_RAW)
                    .build()
                // Create the Activity Segment
                val activityDataPoint = DataPoint.builder(activitySegmentDataSource)
                    .setTimeInterval(startDate.time, endDate.time, TimeUnit.MILLISECONDS)
                    .setActivityField(Field.FIELD_ACTIVITY, activityType)
                    .build()
                // Add DataPoint to DataSet
                val activitySegments = DataSet.builder(activitySegmentDataSource)
                    .add(activityDataPoint)
                    .build()
                sessionInsertRequestBuilder.addDataSet(activitySegments)

            if (distanceInMeters > 0) {
                val distanceDataSource = DataSource.Builder()
                    .setAppPackageName(context.packageName)
                    .setDataType(DataType.TYPE_DISTANCE_DELTA)
                    .setStreamName("FLUTTER_HEALTH - Distance")
                    .setType(DataSource.TYPE_DERIVED)
                    .build()
                val distanceDataSetBuilder = DataSet.builder(distanceDataSource)
                val distanceDataPoint = DataPoint.builder(distanceDataSource)
                    .setTimeInterval(startDate.time, endDate.time, TimeUnit.MILLISECONDS)
                    .setField(Field.FIELD_DISTANCE, distanceInMeters.toFloat())
                    .build()
                distanceDataSetBuilder.add(distanceDataPoint)
                sessionInsertRequestBuilder.addDataSet(distanceDataSetBuilder.build())
            }

            if (stepsCount > 0) {
                val stepsDataSource = DataSource.Builder()
                    .setAppPackageName(context.packageName)
                    .setDataType(DataType.TYPE_STEP_COUNT_DELTA)
                    .setStreamName("FLUTTER_HEALTH - steps")
                    .setType(DataSource.TYPE_DERIVED)
                    .build()

                val stepsDataSetBuilder = DataSet.builder(stepsDataSource)
                val stepsDataPoint = DataPoint.builder(stepsDataSource)
                    .setTimeInterval(startDate.time, endDate.time, TimeUnit.MILLISECONDS)
                    .setField(Field.FIELD_STEPS, stepsCount)
                    .build()
                stepsDataSetBuilder.add(stepsDataPoint)
                sessionInsertRequestBuilder.addDataSet(stepsDataSetBuilder.build())
            }

            val insertRequest = sessionInsertRequestBuilder.build()

            val fitnessOptionsBuilder = FitnessOptions.builder()
                .addDataType(DataType.TYPE_ACTIVITY_SEGMENT, FitnessOptions.ACCESS_WRITE)

            if (distanceInMeters > 0) {
                fitnessOptionsBuilder.addDataType(DataType.TYPE_DISTANCE_DELTA, FitnessOptions.ACCESS_WRITE)
            }
            if (stepsCount > 0) {
                fitnessOptionsBuilder.addDataType(DataType.TYPE_STEP_COUNT_DELTA, FitnessOptions.ACCESS_WRITE)
            }
            val fitnessOptions = fitnessOptionsBuilder.build()

            GoogleSignIn.getAccountForExtension(context.applicationContext, fitnessOptions)
                Fitness.getSessionsClient(
                    context,
                    GoogleSignIn.getAccountForExtension(context, fitnessOptions)
                )
                    .insertSession(insertRequest)
                    .addOnSuccessListener {
                        success()
                    }
                    .addOnFailureListener { e ->
                        failure(e)
                    }
            } catch (e: Exception) {
                failure(e)
            }
        }

        private fun getSessions(
            startDate: Date,
            endDate: Date,
            context: Context,
            success:(List<SessionWithDataPoints>) -> Unit,
            failure: (Exception) -> Unit,
        ){
            val dataType = MetricType.Workout.dataType()
            val googleSignInAccount = HealthDataObserverCreator
                .getGoogleSignInAccount(dataType, context)

            val sessionReadRequest =
                SessionReadRequest.Builder()
                    .readSessionsFromAllApps()
                    .includeActivitySessions()
                    .read(dataType)
                    .read(DataType.TYPE_DISTANCE_DELTA)
                    .read(DataType.TYPE_STEP_COUNT_DELTA)
                    .setTimeInterval(startDate.time, endDate.time, TimeUnit.MILLISECONDS)
                    .build()

            Fitness.getSessionsClient(context, googleSignInAccount)
                .readSession(sessionReadRequest)
                .addOnSuccessListener { response ->
                    val sessions = response.sessions

                    val sessionsWithDataPoints = mutableListOf<SessionWithDataPoints>()
                    for (session in sessions) {
                        val dataPoints: MutableList<DataPoint> = mutableListOf()
                        val dataSets = response.getDataSet(session)
                        for (dataSet in dataSets) {
                            dataPoints.addAll(dataSet.dataPoints)
                        }
                        sessionsWithDataPoints.add(SessionWithDataPoints(session, dataPoints))
                    }

                    if (sessions.size == 0) {
                        return@addOnSuccessListener
                    }

                    val sessionsSortedDesc = sessionsWithDataPoints.sortedByDescending { it.session.getStartTime(TimeUnit.MILLISECONDS) }
                    success(sessionsSortedDesc)
                }
                .addOnFailureListener { e ->
                    failure(e)
                }
        }

        fun getValidExternalWorkouts(
            startDate: Date,
            endDate: Date,
            context: Context,
            success: (List<Workout>) -> Unit,
            failure: (Exception) -> Unit
        ){
            this.getSessions(startDate, endDate, context, success = { results ->
                val activitiesInfo = getActivitiesInfo(context)

                val filteredResults = results.filter { result ->
                    val packageRootName = "com.sharecare.wecare"
                    val isExternal = !(result.session.appPackageName ?: "").contains(packageRootName)
                    var hasMinimumRequiredMins = false
                    val workoutDurationInMins = abs(result.session.getEndTime(TimeUnit.MINUTES) - result.session.getStartTime(TimeUnit.MINUTES)).toDouble()
                    val activityInfo = activitiesInfo[result.session.activity]
                    if (activityInfo != null) {
                        val minimumRequired = activityInfo.tracking.minimumRequiredMinutes ?: 0
                        hasMinimumRequiredMins = workoutDurationInMins >= minimumRequired
                    }
                    return@filter isExternal && hasMinimumRequiredMins
                }

                val workouts = filteredResults.map { result ->
                    val session = result.session
                    val dataPoints = result.dataPoints
                    val duration = abs(session.getEndTime(TimeUnit.SECONDS) - session.getStartTime(TimeUnit.SECONDS)).toDouble()

                    val stepsCount: Int = dataPoints.filter{ it.dataType == DataType.TYPE_STEP_COUNT_DELTA }.fold(0) { acc, next ->
                        acc + next.extractValue().toInt()
                    }
                    val distanceInMeters: Double = dataPoints.filter{ it.dataType == DataType.TYPE_DISTANCE_DELTA }.fold(0.0) { acc, next ->
                        acc + next.extractValue().toDouble()
                    }

                    return@map Workout(
                        session.appPackageName ?: "",
                        session.identifier,
                        session.activity,
                        session.activity,
                        duration,
                        Date(session.getStartTime(TimeUnit.MILLISECONDS)),
                        Date(session.getEndTime(TimeUnit.MILLISECONDS)),
                        distanceInMeters * 0.000621,
                        stepsCount
                    )
                }

                success(workouts)
            }, failure = { exception ->
                failure(exception)
            })
        }

        private fun getActivitiesInfo(context: Context): Map<String, ActivityInfo> {
            try {
                val observerMetadataKey = "workout_observer_metadata"
                val metadata = ObserverStatus.getObserverMetadata(context, observerMetadataKey)
                val gson =
                    GsonBuilder().setFieldNamingPolicy(FieldNamingPolicy.LOWER_CASE_WITH_UNDERSCORES).create()
                val activities: ActivitiesJson = gson.fromJson(metadata, ActivitiesJson::class.java)
                val activitiesInfoMap = mutableMapOf<String, ActivityInfo>()

                for (activityInfo in activities.content) {
                    val platformIdentifier = activityInfo.mobileCategory?.androidIdentifier
                    if (platformIdentifier != null) {
                        activitiesInfoMap[platformIdentifier] = activityInfo
                    }
                }
                return activitiesInfoMap
            } catch (e: Exception) {
                print(e)
                return mapOf()
            }
        }
    }
}
data class WorkoutDataAggregated(val stepsCount: Int, val distanceInMeters: Double)
data class SessionWithDataPoints(val session: Session, val dataPoints: List<DataPoint>)