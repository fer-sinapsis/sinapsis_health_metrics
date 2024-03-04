//
//  MetricObserver.swift
//  health_metrics_observers
//
//  Created by Sudarshan Chakra on 24/08/23.
//

import Foundation
import HealthKit

protocol MetricObserver {
    var metricType: MetricType { get set }
    var observerQuery: HKObserverQuery? { get set }
}

class GeneralMetricObserver: MetricObserver {
    var observerQuery: HKObserverQuery?
    var metricType: MetricType
    var newDataDetectedFn: () async throws -> Void
    
    init(metricType: MetricType, newDataDetectedFn: @escaping () async throws -> Void) throws {
        self.metricType = metricType
        self.newDataDetectedFn = newDataDetectedFn
        
        guard let sampleType = metricType.getSampleType() else {
            throw GeneralError(code: "no_sample_type_found", message: "no sample type found")
        }

        let query = HKObserverQuery(sampleType: sampleType, predicate: nil) { (query, completionHandler, errorOrNil) in
            
            if let error = errorOrNil {
                print(error)
                return
            }
            Task {
                try await newDataDetectedFn()
                completionHandler()
            }
        }
        self.observerQuery = query
        let healthKitStore: HKHealthStore = HKHealthStore()
        healthKitStore.execute(query)
    }
}

protocol BackgroundMetricObserver: MetricObserver {
    func newDataDetected(completion: @escaping () -> Void)
}

class StepObserver: BackgroundMetricObserver {
    var observerQuery: HKObserverQuery?
    var metricType = MetricType.step
    
    func newDataDetected(completion: @escaping () -> Void) {
        if ObserverStatus.isObserverSyncing() {
            completion()
            return
        }
        
        ObserverStatus.updateObserverSyncing(newValue: true)

        let metricsSender = HealthMetricsSender()
        metricsSender.attemptToSendSteps(completion: { updated in
            print("data sent: \(updated)")
            ObserverStatus.updateObserverSyncing(newValue: false)
            completion()
        })
    }
}
