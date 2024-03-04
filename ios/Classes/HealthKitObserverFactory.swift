//
//  HealthKitObserverFactory.swift
//  Runner
//
//  Created by Sudarshan Chakra on 7/01/22.
//

import Foundation
import HealthKit

class ObserverFactory {
    
    static func createBackgroundObserver(
        metricType: MetricType,
        completion: ((Bool) -> Void)? = nil
    ){
        guard let sampleType = metricType.getSampleType() else {
            completion?(false)
            return
        }
        
        var observer: BackgroundMetricObserver = (metricType == .workout) ? WorkoutObserver() : StepObserver()
        
        let query = HKObserverQuery(sampleType: sampleType, predicate: nil) { (query, completionHandler, errorOrNil) in
            
            if let error = errorOrNil {
                // TODO: confirm completion handler or inform that there was an error observing
                print(error)
                return
            }

            observer.newDataDetected(completion: {
                completionHandler()
            })
        }
        
        observer.observerQuery = query
        
        let healthKitStore: HKHealthStore = HKHealthStore()
        healthKitStore.execute(query)
        let frequency: HKUpdateFrequency = (metricType == .workout) ? .immediate : .hourly
        healthKitStore.enableBackgroundDelivery(for: sampleType, frequency: frequency) { succeeded, error in
            if succeeded {
                print("Enabled background delivery of \(metricType.rawValue) changes")
            } else {
                if let theError = error {
                    print("Failed to enable background delivery of step changes. ")
                    print("Error = \(theError)")
                }
            }
            ObserverStatus.updateObserverCreated(succeeded, metricType: metricType)
            completion?(succeeded)
        }
    }
    
}
