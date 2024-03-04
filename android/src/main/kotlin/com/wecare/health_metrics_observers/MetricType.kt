package com.wecare.health_metrics_observers

import com.google.android.gms.fitness.data.DataType

enum class MetricType {
    Step, Sleep, Workout;

    fun getValue(): String {
        return when (this) {
            Sleep -> "SLEEP"
            Step -> "STEP"
            Workout -> "WORKOUT"
        }
    }

    fun dataType(): DataType {
        return when (this) {
            Sleep -> DataType.TYPE_SLEEP_SEGMENT
            Step -> DataType.TYPE_STEP_COUNT_DELTA
            Workout -> DataType.TYPE_ACTIVITY_SEGMENT
        }
    }
    companion object {
        fun fromString(typeString: String): MetricType? {
            return when (typeString) {
                "SLEEP" -> MetricType.Sleep
                "STEP" -> MetricType.Step
                "WORKOUT" -> MetricType.Workout
                else -> null
            }
        }
    }
}