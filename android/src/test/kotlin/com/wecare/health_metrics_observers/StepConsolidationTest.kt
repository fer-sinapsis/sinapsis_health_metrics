package co.sinapsis.sinapsis_health_metrics

import com.google.android.gms.fitness.data.DataPoint
import com.google.android.gms.fitness.data.DataSource
import com.google.android.gms.fitness.data.DataType
import com.google.android.gms.fitness.data.Device
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.Duration
import java.util.*

class StepConsolidationTest {
    @Test fun testSameSourcesNoConsolidated() {
        val now = Date()
        val p1 = createDataPoint(150, now, Duration.ofHours(3), "phone")
        val p2 = createDataPoint(50, now.addHours(5), Duration.ofHours(1), "phone")
        val p3 = createDataPoint(80, now.addHours(2), Duration.ofHours(2), "phone")
        val consolidated = DataPointConsolidation.consolidateIfNeeded(listOf(p1, p2, p3))
        assertTrue(consolidated.count() == 3)
    }

    @Test fun testConsolidatedContainedPoints() {
        val now = Date()
        val p1 = createDataPoint(150, now, Duration.ofHours(3), "phone")
        val p2 = createDataPoint(25, now.addHours(1), Duration.ofHours(1), "watch")
        val p3 = createDataPoint(50, now.addHours(5), Duration.ofHours(1), "phone")
        val p4 = createDataPoint(50, now.addHours(2), Duration.ofHours(1), "watch")
        val consolidated = DataPointConsolidation.consolidateIfNeeded(listOf(p1, p2, p3, p4))
        assertTrue(consolidated.count() == 2)
        assertTrue(consolidated.first().extractValue() == 150)
    }

    @Test fun testConsolidatedEscalatedPoints() {
        val now = Date()
        val p1 = createDataPoint(150, now, Duration.ofHours(3), "phone")
        val p2 = createDataPoint(25, now.addHours(1), Duration.ofHours(3), "watch")
        val p3 = createDataPoint(50, now.addHours(5), Duration.ofHours(1), "phone")
        val p4 = createDataPoint(200, now.addHours(2), Duration.ofHours(2), "watch")
        val consolidated = DataPointConsolidation.consolidateIfNeeded(listOf(p1, p2, p3, p4))
        assertTrue(consolidated.count() == 2)
        assertTrue(consolidated.first().extractValue() == 200)
    }

    @Test fun testConsolidatedSameStartPoints() {
        val now = Date()
        val p1 = createDataPoint(150, now, Duration.ofHours(3), "phone")
        val p2 = createDataPoint(100, now, Duration.ofHours(2), "watch")
        val p3 = createDataPoint(50, now.addHours(5), Duration.ofHours(1), "phone")
        val consolidated = DataPointConsolidation.consolidateIfNeeded(listOf(p1, p2, p3))
        assertTrue(consolidated.count() == 2)
        assertTrue(consolidated.first().extractValue() == 150)
    }

    @Test fun testConsolidatedAll() {
        val now = Date()
        val p1 = createDataPoint(150, now, Duration.ofHours(3), "phone")
        val p2 = createDataPoint(50, now.addHours(1), Duration.ofHours(1), "watch")
        val p3 = createDataPoint(50, now.addHours(5), Duration.ofHours(1), "phone")
        val p4 = createDataPoint(100, now.addHours(2), Duration.ofHours(2), "watch")
        val consolidated = DataPointConsolidation.consolidateIfNeeded(listOf(p1, p2, p3, p4))
        assertTrue(consolidated.count() == 2)
        assertTrue(consolidated.first().extractValue() == 150)
    }

    private fun createDataPoint(value: Int, start: Date, duration: Duration, sourceName: String) : DataPoint {
        val deviceId = if (sourceName == "phone") 1 else 3
        val device = Device("google", "pixel1", deviceId.toString(), deviceId)
        val source = DataSource.Builder()
            .setDataType(DataType.TYPE_STEP_COUNT_DELTA)
            .setType(0)
            .setStreamName(sourceName)
            .setDevice(device).build()
        return DataPoint.builder(source).setTimeInterval(start.time, (start.time + duration.toMillis()), java.util.concurrent.TimeUnit.MILLISECONDS).setIntValues(value).build()
    }
}

fun Date.addHours(hours: Int) : Date {
    val newMilliSecs = (this.time) + hours * 3600 * 1000
    return Date(newMilliSecs)
}