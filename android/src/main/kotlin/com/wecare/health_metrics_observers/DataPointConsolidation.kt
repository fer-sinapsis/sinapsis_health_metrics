package com.wecare.health_metrics_observers

import com.google.android.gms.fitness.data.DataPoint
import java.util.concurrent.TimeUnit

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
                        overlapped.sortBy { it.extractValue().toInt() }
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