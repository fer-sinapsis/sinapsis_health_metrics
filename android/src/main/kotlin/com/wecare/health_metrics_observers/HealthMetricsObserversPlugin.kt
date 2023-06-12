package com.sinapsis.health_metrics_observers

import android.content.Context
import androidx.annotation.NonNull

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.util.*

/** HealthMetricsObserversPlugin */
class HealthMetricsObserversPlugin: FlutterPlugin, MethodCallHandler {
  /// The MethodChannel that will the communication between Flutter and native Android
  ///
  /// This local reference serves to register the plugin with the Flutter Engine and unregister it
  /// when the Flutter Engine is detached from the Activity
  private lateinit var channel : MethodChannel
  private val createStepCountObserverKey = "createStepCountObserver"
  private val getLastSavedDateKey = "getLastDateSaved"
  private val updateLastSavedDateKey = "updateLastDateSaved"
  private val getObserverStatus = "getObserverStatus"
  private val isObserverSyncing = "isObserverSyncing"
  private val getStepsCountByIntervals = "getStepsCountByIntervals"
  private lateinit var context: Context

  override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "health_metrics_observers")
    context = flutterPluginBinding.applicationContext
    ObserverStatus.updateObserverSyncing(context, false);
    channel.setMethodCallHandler(this)
  }

  override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
    if (call.method == createStepCountObserverKey) {
      HealthDataObserverCreator.createStepCountObserver(call, result, context)
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
    } else if (call.method == getStepsCountByIntervals) {
      val startDateMillisecs = call.argument<Long>("startDateMillisecs")
      val endDateMillisecs = call.argument<Long>("endDateMillisecs")
      val intervalString = call.argument<String>("interval") ?: ""
      val span = TimeSpan.fromString(intervalString)

      if(startDateMillisecs != null && endDateMillisecs != null && span != null) {
        val startDate = Date(startDateMillisecs)
        val endDate = Date(endDateMillisecs)
        HealthMetricsRetriever.getStepsCountByIntervals(startDate, endDate, span, context, success = { results ->
          result.success(results.map { it.toMap() } )
        }, failure = { _ ->
          result.error(
            "error_retrieving_data",
            "error retrieving step counts by intervals",
            null
          )
        })
      }else{
        result.error("param_missing", "param missing", null)
      }
    } else {
      result.notImplemented()
    }
  }

  override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }
}
