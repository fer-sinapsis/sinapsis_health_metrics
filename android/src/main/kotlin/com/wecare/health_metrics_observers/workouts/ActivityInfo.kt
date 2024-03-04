package com.wecare.health_metrics_observers.workouts
import androidx.annotation.Keep
import com.google.gson.Gson


@Keep
data class ActivitiesJson (var content: List<ActivityInfo>)
@Keep
data class ActivityInfo(
    var id: String,
    var name: String,
    var mobileCategory: MobileCategory?,
    var tracking: Tracking
)
@Keep
data class MobileCategory (var androidIdentifier: String?)
@Keep
data class Tracking (var minimumRequiredMinutes: Int?)
