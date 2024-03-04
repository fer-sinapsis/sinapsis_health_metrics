//
//  HKSampleExtension.swift
//  health_metrics_observers
//
//  Created by Sudarshan Chakra on 23/08/23.
//

import Foundation
import HealthKit

extension HKSample {
    
    @objc func toDictionary() -> [String: Any] {
        let dateFormatterIso = DateFormatter()
        dateFormatterIso.dateFormat = HealthMetricsSender.defaultDateFormat
        let startDate = dateFormatterIso.string(from: self.startDate)
        let endDate = dateFormatterIso.string(from: self.endDate)
        return [
            "measurement_start_date": startDate,
            "measurement_end_date": endDate,
            "value": self.extractValue(),
        ]
    }
    
    func extractValue() -> Int {
        if let quantitySample = self as? HKQuantitySample {
            return Int(quantitySample.quantity.doubleValue(for: HKUnit.count()))
        }
        return 0
    }
    
    func extractValueDouble() -> Double {
        if let quantitySample = self as? HKQuantitySample {
            var unit = HKUnit.count()
            let distanceType = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!
            if (quantitySample.quantityType == distanceType) {
                unit = HKUnit.mile()
            }
            return quantitySample.quantity.doubleValue(for: unit)
        }
        return 0.0
    }
    
    func getSourceId() -> String {
        if let additionalData = self.metadata, let unitTest = additionalData["unit_test"] as? Bool, unitTest == true {
            let sourceId = (additionalData["source_id"] as? String) ?? ""
            return sourceId
        }else{
            return self.sourceRevision.source.bundleIdentifier
        }
    }
}


extension HKQuantitySample {
    
    func checkIfOverlapsWith(_ pointToCompare: HKQuantitySample) -> (HKQuantitySample, HKQuantitySample)? {
        var older: HKQuantitySample
        var earlier: HKQuantitySample
        
        if self.startDate.timeIntervalSince1970 < pointToCompare.startDate.timeIntervalSince1970 {
            older = self
            earlier = pointToCompare
        } else {
            older = pointToCompare
            earlier = self
        }
        let earlierStartAfterOlderStart = earlier.startDate.timeIntervalSince1970 >= older.startDate.timeIntervalSince1970
        let earlierStartBeforeOlderEnd = earlier.startDate.timeIntervalSince1970 < older.endDate.timeIntervalSince1970
        
        let earlierStartsInsideOlder = earlierStartAfterOlderStart && earlierStartBeforeOlderEnd
        
        return earlierStartsInsideOlder ? (older, earlier) : nil
    }
}
