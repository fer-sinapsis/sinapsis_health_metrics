//
//  HealthKitObserverFactory.swift
//  Runner
//
//  Created by Sudarshan Chakra on 7/01/22.
//

import Foundation
import HealthKit

class HealthKitObserverFactory {
    
    static let hkPermissionsAlreadyGiven = "HKPermissionsGiven"
    
    static func createStepsCountBackgroundObserver(startingActivity: Bool, completion: @escaping (Bool) -> Void){
        
        let healthKitStore: HKHealthStore = HKHealthStore()
        guard let stepCountType = HKObjectType.quantityType(forIdentifier: .stepCount) else {
            completion(false)
            return
        }
        
        let query = HKObserverQuery(sampleType: stepCountType, predicate: nil) { (query, completionHandler, errorOrNil) in
            
            if let error = errorOrNil {
                // TODO: confirm completion handler or inform that there was an error observing
                print(error)
                return
            }
            
            if ObserverStatus.isObserverSyncing() {
                completionHandler()
                return
            }
            
            ObserverStatus.updateObserverSyncing(newValue: true)
            
            let metricsSender = HealthMetricsSender()
            metricsSender.attemptToSendSteps(completion: { updated in
                print("data sent: \(updated)")
                ObserverStatus.updateObserverSyncing(newValue: false)
                completionHandler()
            })
        }
        
        healthKitStore.execute(query) // execute query after background delivery enabing ?
        healthKitStore.enableBackgroundDelivery(for: stepCountType, frequency: HKUpdateFrequency.hourly) { succeeded, error in
            if succeeded {
                print("Enabled background delivery of step changes")
            } else {
                if let theError = error{
                    print("Failed to enable background delivery of step changes. ")
                    print("Error = \(theError)")
                }
            }
            ObserverStatus.updateObserverCreated(succeeded)
            completion(succeeded)
        }
    }
}
