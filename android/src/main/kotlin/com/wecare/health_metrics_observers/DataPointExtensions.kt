package com.wecare.health_metrics_observers

import com.google.android.gms.fitness.data.DataPoint
import com.google.android.gms.fitness.data.DataType
import com.google.android.gms.fitness.data.Field
import java.text.SimpleDateFormat
import java.util.Date
import java.util.concurrent.TimeUnit

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

fun DataPoint.extractValue(): Number {
    return when(this.dataType) {
        DataType.TYPE_STEP_COUNT_DELTA -> this.getValue(Field.FIELD_STEPS).asInt()
        DataType.TYPE_DISTANCE_DELTA -> this.getValue(Field.FIELD_DISTANCE).asFloat()
        else -> 0
    }
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