package com.wecare.health_metrics_observers

import android.content.Context
import android.content.Intent
import androidx.annotation.NonNull
import com.google.gson.Gson
import com.wecare.health_metrics_observers.workouts.WorkoutsDataCoordinator
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry
import java.util.Date


/** HealthMetricsObserversPlugin */
class HealthMetricsObserversPlugin: FlutterPlugin, MethodCallHandler, ActivityAware,
  PluginRegistry.NewIntentListener {
  // ActivityAware, NewIntentListener, ActivityResultListener
  /// The MethodChannel that will the communication between Flutter and native Android
  ///
  /// This local reference serves to register the plugin with the Flutter Engine and unregister it
  /// when the Flutter Engine is detached from the Activity
  private lateinit var channel : MethodChannel
  private val createObserverKey = "createObserver"
  private val getLastSavedDateKey = "getLastDateSaved"
  private val updateLastSavedDateKey = "updateLastDateSaved"
  private val getObserverStatus = "getObserverStatus"
  private val isObserverSyncing = "isObserverSyncing"
  private val updateApiUrl = "updateApiUrl"
  private val getDataForWorkoutInProgress = "getDataForWorkoutInProgress"
  private val createWorkout = "createWorkout"
  private val getValidExternalWorkouts = "getValidExternalWorkouts"
  private val getExternalWorkoutsNotificationData = "getExternalWorkoutsNotificationData"
  private lateinit var context: Context

  override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "health_metrics_observers")
    context = flutterPluginBinding.applicationContext
    
    ObserverStatus.updateObserverSyncing(context, false);
    channel.setMethodCallHandler(this)
  }

  override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
    if (call.method == createObserverKey) {
      val metricTypeStr = call.argument<String>("metricType") ?: ""
      val metricType = MetricType.fromString(metricTypeStr)

      if (metricType != null) {
        HealthDataObserverCreator.createObserver(metricType, call, result, context)
      }else{
        result.error("param_missing", "param missing", null)
      }

    } else if(call.method == getLastSavedDateKey) {
      val metricType = call.argument<String>("metricType")
      if(metricType != null) {
        val lastDatSaved = ObserverStatus.getLastDateSaved(this.context, metricType)
        result.success(lastDatSaved)
      }else{
        result.error("param_missing", "param missing", null)
      }

    } else if (call.method == updateLastSavedDateKey) {

      val newDateInMilliseconds = call.argument<Long>("newDateInMilliseconds")
      val metricType = call.argument<String>("metricType")
      if(newDateInMilliseconds != null && metricType != null) {
        ObserverStatus.updateLastDateSaved(this.context, newDateInMilliseconds, metricType)
        result.success(true)
      }else{
        result.error("param_missing", "param missing", null)
      }

    } else if (call.method == getObserverStatus) {
      result.success(ObserverStatus.getStatusMap(context))
    } else if (call.method == isObserverSyncing) {
      result.success(ObserverStatus.isObserverSyncing(context))
    } else if (call.method == updateApiUrl) {
      val newApiUrl = call.argument<String>("newApiUrl")
      if (newApiUrl != null) {
        ObserverStatus.updateApiUrl(this.context, newApiUrl)
        result.success(true)
      }else{
        result.error("param_missing", "param missing", null)
      }
    } else if(call.method == getDataForWorkoutInProgress) {
      val activitySegmentsStr = call.argument<String>("activitySegments")
      val metricsSupported = call.argument<String>("metricsSupported")
      if (activitySegmentsStr == null || metricsSupported == null) {
        result.error("param_missing", "param missing", null)
        return
      }
      val workoutDateIntervals =
        HealthMetricsQueryHandler.workoutIntervalsFromString(activitySegmentsStr)
      HealthMetricsQueryHandler.getDataForWorkoutInProgress(workoutDateIntervals, metricsSupported, context,
        success = { data ->
          val dataMap = mapOf("stepsCount" to data.stepsCount, "distanceInMiles" to (data.distanceInMeters/1609.34))
          result.success(dataMap)
        },
        failure = {
          result.error("error_getting_data", "error getting data", null)
        }
      )
    } else if (call.method == createWorkout) {
      val activitySegmentsStr = call.argument<String>("activitySegments")
      val activityPlatformId = call.argument<String>("activityPlatformId")
      val metricsSupported = call.argument<String>("metricsSupported")
      val startDateInSecs = call.argument<Double>("startDateInSecs")
      val endDateInSecs = call.argument<Double>("endDateInSecs")

      if(activitySegmentsStr != null && metricsSupported != null && activityPlatformId != null && startDateInSecs != null && endDateInSecs != null){
        val startDate = Date((startDateInSecs * 1000).toLong())
        val endDate = Date((endDateInSecs * 1000).toLong())
        HealthMetricsQueryHandler.createWorkout(
          activityPlatformId = activityPlatformId,
          activitySegmentsString = activitySegmentsStr,
          metricsSupported = metricsSupported,
          context = context,
          startDate = startDate,
          endDate = endDate,
          success = {
            result.success(true)
          },
          failure = {
            result.error("error_getting_data", "error getting data", null)
          }
        )
      } else {
        result.error("param_missing", "param missing", null)
      }
    } else if (call.method == getValidExternalWorkouts) {
      getValidExternalWorkouts(call= call, result = result)
    } else if (call.method == getExternalWorkoutsNotificationData) {
      val notificationData = WorkoutsDataCoordinator.getWorkoutNotificationData(context)
      WorkoutsDataCoordinator.setWorkoutNotificationData(context, null)
      result.success(notificationData)
    } else {
      result.notImplemented()
    }
  }

  private fun getValidExternalWorkouts(call: MethodCall, result: Result) {
    val startDateInSecs = call.argument<Double>("startDateInSecs")
    val endDateInSecs = call.argument<Double>("endDateInSecs")

    if (startDateInSecs != null && endDateInSecs != null) {
      val startDate = Date((startDateInSecs * 1000).toLong())
      val endDate = Date((endDateInSecs * 1000).toLong())

      HealthMetricsQueryHandler.getValidExternalWorkouts(
        startDate, endDate, context,
        success = { workouts ->
          val workoutsAsMaps = workouts.map { it.toMap() }
          result.success(workoutsAsMaps)
        },
        failure = { exception ->
          result.error("error_getting_external_workouts", exception.message, null)
        }
      )
    } else {
      result.error("param_missing", "param missing", null)
    }
  }

  override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }

  override fun onDetachedFromActivityForConfigChanges() {
    TODO("Not yet implemented")
  }

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    TODO("Not yet implemented")
  }

  override fun onDetachedFromActivity() {
    TODO("Not yet implemented")
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    binding.addOnNewIntentListener(this)
    this.handlePayload(intent = binding.activity.intent, false)
  }

  override fun onNewIntent(intent: Intent): Boolean {
    this.handlePayload(intent, true)
    return true
  }

  private fun handlePayload(intent: Intent, newIntent: Boolean) {
    val payload = intent.getStringExtra("payload")

    if (payload != null) {
      WorkoutsDataCoordinator.setWorkoutNotificationData(context, payload)
      if (newIntent) {
        val map: Map<*, *> = Gson().fromJson(payload, MutableMap::class.java)
        channel.invokeMethod("workout_local_notification_tapped", map)
      }
    }
  }

}
