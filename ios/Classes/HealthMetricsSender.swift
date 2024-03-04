//
//  HealthMetricsSender.swift
//  Runner
//
//  Created by Sudarshan Chakra on 5/01/22.
//

import Foundation
import HealthKit

class HealthMetricsSender {
    
    static let defaultDateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ"
    
    func attemptToSendSteps(completion: @escaping (Bool) -> Void){
        let endDate = Date()
        let defaults = UserDefaults.standard
        
        //TODO: remove in next releases
        let currentApiUrl = ObserverStatus.getApiUrl() ?? ""
        if currentApiUrl.contains("wecareapi.com") == false {
            ObserverStatus.updateApiUrl("https://profile-api.wecareapi.com")
            
            if(ObserverStatus.getMigrated() == false){
                defaults.set(nil, forKey: ObserverStatus.nextStartDateKey)
                defaults.set(nil, forKey: ObserverStatus.lastSleepDateSavedKey)
                ObserverStatus.updateMigrated(true)
            }
        }
        
        self.getLastTimeStepsSaved { lastTimeStepsSaved in
            guard let startDate = lastTimeStepsSaved ?? Calendar.current.date(byAdding: Calendar.Component.day, value: -1, to: endDate) else {
                completion(false)
                return
            }
            
            self.getDataPoints(
                startDate: startDate,
                endDate: endDate,
                hkSampleType: MetricType.step.getSampleType(),
                completion: { result in
                switch result {
                case .success(let results):
                    // results to dictionaries
                    let stepsRecords = results.map({ sample in
                        return sample.toDictionary()
                    })
                    
                    if stepsRecords.count == 0 {
                        completion(true)
                        return
                    }
                    
                    HealthMetricsApiService.sendStepsToServer(stepRecords: stepsRecords) { updated in
                        if(updated){
                            defaults.set(endDate, forKey: ObserverStatus.nextStartDateKey)
                            defaults.set(endDate, forKey: ObserverStatus.observerOnlyLastSavedKey)
                            
                            let lastDayResults = results.filter { sample in
                                return Calendar.current.isDate(
                                    endDate,
                                    inSameDayAs: sample.endDate
                                )
                            }
                            
                            defaults.set(
                                results.first?.extractValue() ?? 0,
                                forKey: ObserverStatus.lastStepCountSentKey
                            )
                        }
                        defaults.set(
                            updated ? nil : endDate,
                            forKey: ObserverStatus.lastAttemptToSendKey
                        )
                        completion(updated)
                    }
                case .failure( _):
                    completion(false)
                }
            })
        }
    }
    
    func getDataPoints(startDate: Date, endDate: Date, hkSampleType: HKSampleType?, completion: @escaping (Result<[HKSample], Error>) -> Void){
        
        guard let sampleType = hkSampleType else {
            completion(.failure(HKRetrievingDataErrors.quantityTypeNotCreatedError))
            return
        }
        
        let healthKitStore: HKHealthStore = HKHealthStore()
        
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: [.strictStartDate, .strictEndDate]
        )
        
        let sortDescriptor = NSSortDescriptor(
            key: HKSampleSortIdentifierEndDate,
            ascending: false
        )
        
        let query = HKSampleQuery(
            sampleType: sampleType,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [sortDescriptor],
            resultsHandler: { _, samples, error in
                guard let results = samples else {
                    completion(.failure(HKRetrievingDataErrors.noDataError))
                    return
                }
                var consolidated = results
                if let quantitySamples = results as? [HKQuantitySample], sampleType == HKObjectType.quantityType(forIdentifier: .stepCount) {
                    consolidated = self.consolidateIfNeeded(samples: quantitySamples)
                }
                completion(.success(consolidated))
        })
        
        healthKitStore.execute(query)
    }
    
    func getDataPointsAsync(startDate: Date, endDate: Date, hkSampleType: HKSampleType?) async throws -> [HKSample] {
        
        guard let sampleType = hkSampleType else {
            throw HKRetrievingDataErrors.quantityTypeNotCreatedError
        }
        
        let healthKitStore: HKHealthStore = HKHealthStore()
        
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: []
        )
        
        let sortDescriptor = NSSortDescriptor(
            key: HKSampleSortIdentifierEndDate,
            ascending: false
        )
        
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKSample], Error>) -> Void in
            
            let query = HKSampleQuery(
                sampleType: sampleType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sortDescriptor],
                resultsHandler: { _, samples, error in
                    guard let results = samples else {
                        continuation.resume(with: .failure(HKRetrievingDataErrors.noDataError))
                        return
                    }
                    continuation.resume(with: .success(results))
                })
            
            healthKitStore.execute(query)
        }
    }
    
    func consolidateIfNeeded(samples: [HKQuantitySample]) -> [HKQuantitySample] {
        var sources = Set<String>()
        for sample in samples {
            let sourceId = sample.getSourceId()
            sources.insert(sourceId)
        }
        if sources.count > 1 {
            //sort samples ascending
            let sortedSamples = samples.sorted { a, b in
                a.startDate.timeIntervalSince1970 < b.startDate.timeIntervalSince1970
            }
            var cursor = 0
            var consolidatedResults: [HKQuantitySample] = []
            
            while (cursor < sortedSamples.count) {
                let current = sortedSamples[cursor]
                var lastOverlapped: Int?
                var overlapped: [HKQuantitySample] = []
                
                //compare current against the rest to see if overlaps
                for i in (cursor + 1)..<sortedSamples.count {
                    let next = sortedSamples[i]
                    if current.getSourceId() != next.getSourceId() {
                        let overlapResult = current.checkIfOverlapsWith(next)
                        if (overlapResult != nil) {
                            if (overlapped.isEmpty) { overlapped.append(current) }
                            overlapped.append(next)
                            lastOverlapped = i
                        }
                    }
                }
                if let lastOverlappedIndex = lastOverlapped {
                    cursor = lastOverlappedIndex + 1
                    //sort by value
                    overlapped.sort { a, b in
                        return a.extractValue() < b.extractValue()
                    }
                    // pick the biggest
                    if let lastOverlappedSample = overlapped.last {
                        consolidatedResults.append(lastOverlappedSample)
                    }
                } else {
                    consolidatedResults.append(current)
                    cursor = cursor + 1 // if no merges move to next to evaluate
                }
            }
            return consolidatedResults
        } else {
            return samples
        }
    }
    
    func getLastTimeStepsSaved(completion: @escaping (Date?) -> Void){
        let defaults = UserDefaults.standard
        let localLastDateSaved = defaults.object(forKey: ObserverStatus.nextStartDateKey) as? Date
        
        if(localLastDateSaved == nil){
            HealthMetricsApiService.getLastTimeStepsSavedServer { lastDateInServer in
                if let lastDateSaved = lastDateInServer {
                    defaults.set(lastDateSaved, forKey: ObserverStatus.nextStartDateKey)
                }
                completion(lastDateInServer)
            }
        }else{
            completion(localLastDateSaved)
        }
    }
}

class GeneralError: Error {
    init(code: String, message: String){
        self.code = code
        self.message = message
    }
    var code: String
    var message: String
}

class HKRetrievingDataErrors {
    static let noDataError = GeneralError(code: "query_error", message: "error executing query")
    
    static let quantityTypeNotCreatedError = GeneralError(code: "type_creation_error", message: "error creating quantity type")
    
    static let missingCorrectParameters = GeneralError(code: "missing_correct_parameters", message: "missing correct parameters")
}
