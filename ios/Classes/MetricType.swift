//
//  MetricType.swift
//  health_metrics_observers
//
//  Created by Sudarshan Chakra on 8/09/23.
//

import Foundation
import HealthKit

enum MetricType: String {
    case step = "STEP"
    case sleep = "SLEEP"
    case workout = "WORKOUT"
    case walkRunDistance = "WALK_DISTANCE"
    case swimDistance = "SWIM_DISTANCE"
    case bikeDistance = "BIKE_DISTANCE"
    case wheelChairDistance = "WHEEL_CHAIR_DISTANCE"
    case downhillSnowSportsDistance = "SNOW_SPORTS_DISTANCE"

    func getSampleType() -> HKSampleType? {
        switch (self){
        case .step:
            return HKObjectType.quantityType(forIdentifier: .stepCount)
        case .walkRunDistance:
            return HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)
        case .swimDistance:
            return HKObjectType.quantityType(forIdentifier: .distanceSwimming)
        case .bikeDistance:
            return HKObjectType.quantityType(forIdentifier: .distanceCycling)
        case .wheelChairDistance:
            return HKObjectType.quantityType(forIdentifier: .distanceWheelchair)
        case .downhillSnowSportsDistance:
            return HKObjectType.quantityType(forIdentifier: .distanceDownhillSnowSports)
        case .sleep:
            return HKObjectType.categoryType(forIdentifier: .sleepAnalysis)
        case .workout:
            return HKObjectType.workoutType()
        }
    }
    
    func getObserverCreatedKeyStr() -> String {
        var keyStr = ObserverStatus.observerCreatedKey
        if self != .step {
            keyStr = self.rawValue.lowercased() + keyStr.capitalized
        }
        return keyStr
    }
}
