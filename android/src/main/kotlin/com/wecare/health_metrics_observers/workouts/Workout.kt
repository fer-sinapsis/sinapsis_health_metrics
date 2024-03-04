package com.wecare.health_metrics_observers.workouts

import java.util.Date

data class Workout(
    var sourceId: String,
    var healthAppId: String,
    var platformId: String,
    var activityType: String,
    var durationInSecs: Double,
    var startDate: Date,
    var endDate: Date,
    var distanceInMiles: Double,
    var stepsCount: Int
) {
    fun toMap(): Map<String, Any> {
        val startDateInSecs = (this.startDate.time.toDouble() / 1000.0)
        val endDateInSecs = (this.endDate.time.toDouble() / 1000.0)
        return mapOf(
            "sourceId" to this.sourceId,
            "healthAppId" to this.healthAppId,
            "platformId" to this.activityType,
            "activityType" to this.activityType,
            "durationInSecs" to this.durationInSecs,
            "startDateInSecs" to startDateInSecs,
            "endDateInSecs" to endDateInSecs,
            "distanceInMiles" to this.distanceInMiles,
            "stepsCount" to stepsCount,
        )
    }
}