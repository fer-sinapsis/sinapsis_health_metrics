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
        
        self.getLastTimeStepsSaved { lastTimeStepsSaved in
            
            guard let startDate = lastTimeStepsSaved ?? Calendar.current.date(byAdding: Calendar.Component.day, value: -1, to: endDate) else {
                completion(false)
                return
            }
            
            self.getStepsCountByIntervals(startDate: startDate, endDate: endDate, timeSpan: .hour, completion: { result in
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
                            
                            let lastStepCountLastDay = lastDayResults.reduce(0) { acc, sample in
                                return acc + sample.quantity.doubleValue(for: HKUnit.count())
                            }
                            defaults.set(
                                lastStepCountLastDay,
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
    
    func getStepsCountByIntervals(
        startDate: Date,
        endDate: Date,
        timeSpan: TimeSpan,
        completion: @escaping (Result<[HKQuantitySample], Error>) -> Void
    ){
        
        let statsQueryMode = getStatsQueryModeNeededForRange(
            startDate: startDate, endDate: endDate
        )
        
        switch statsQueryMode {
        case .onlyHead:
            // range under 60 min so we only need one stat query
            getStepsCountOn(startDate: startDate, endDate: endDate) { result in
                switch result {
                case .success(let sampleOrNil):
                    let samples = sampleOrNil != nil ? [sampleOrNil!] : []
                    completion(.success(samples))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        case .onlyCollection:
            //starting at a sharp hour
            stepStatsCollectionQuery(startDate: startDate, endDate: endDate, timeSpan: timeSpan) { result in
                switch result {
                case .success(let samples):
                    completion(.success(samples))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        case .headAndCollection:
            guard let closestSharpHour = Calendar.current.date(
                bySettingHour: Calendar.current.component(.hour, from: startDate) + 1,
                minute: 0,
                second: 0,
                of: startDate
            ) else {
                completion(.failure(HKRetrievingDataErrors.quantityTypeNotCreatedError))
                return
            }
            
            getStepsCountOn(startDate: startDate, endDate: closestSharpHour) { result in
                switch result {
                case .success(let sampleOrNil):
                    
                    self.stepStatsCollectionQuery(startDate: closestSharpHour, endDate: endDate, timeSpan: timeSpan) { result in
                        switch result {
                        case .success(let samples):
                            var updatedSamples: [HKQuantitySample] = []
                            updatedSamples.append(contentsOf: samples)
                            if let sample = sampleOrNil {
                                updatedSamples.append(sample)
                            }
                            completion(.success(updatedSamples))
                        case .failure(let error):
                            completion(.failure(error))
                        }
                    }
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }
    }
    
    func getStatsQueryModeNeededForRange(startDate: Date, endDate: Date) -> StatsQueryMode {
        let diffInMins = abs(startDate.timeIntervalSince(endDate).magnitude)/60
        if diffInMins > 60 {
            let startMins = Calendar.current.component(.minute, from: startDate)
            return startMins > 0 ? .headAndCollection : .onlyCollection
        } else {
            return .onlyHead
        }
    }
    
    func stepStatsCollectionQuery(
        startDate: Date,
        endDate: Date,
        timeSpan: TimeSpan,
        completion: @escaping (Result<[HKQuantitySample], Error>) -> Void
    ){
        guard let stepsQuantityType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            completion(.failure(HKRetrievingDataErrors.quantityTypeNotCreatedError))
            return
        }
        
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: [.strictStartDate, .strictEndDate]
        )
        
        let query = HKStatisticsCollectionQuery(
            quantityType: stepsQuantityType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum,
            anchorDate: startDate,
            intervalComponents: timeSpan.dateComponentValue()
        )
        
        query.initialResultsHandler = { query, statsCollectionOpt, error in
            if let error = error as? HKError {
                let isNoDataError = error.code.rawValue == 11
                completion(isNoDataError ? .success([]) : .failure(error))
                return
            }
            guard let statsCollection = statsCollectionOpt else {
                completion(Result.failure(HKRetrievingDataErrors.noDataError))
                return
            }
            
            var results: [HKQuantitySample] = []
            //iterating the stat results on the selected intervals
            let statistics = statsCollection.statistics()
            statistics.forEach { stat in
                if let sumQuantity = stat.sumQuantity() {
                    let isLast = statistics.last == stat
                    let endsInFuture = stat.endDate > endDate
                    let sampleEnddate = isLast && endsInFuture ? endDate : stat.endDate
                    let sample = HKQuantitySample(
                        type: stepsQuantityType,
                        quantity: sumQuantity,
                        start: stat.startDate,
                        end: sampleEnddate
                    )
                    results.append(sample)
                }
            }
            
            completion(Result.success(results))
        }
        
        let healthKitStore: HKHealthStore = HKHealthStore()
        healthKitStore.execute(query)
    }
    
    func getStepsCountOn(
        startDate: Date,
        endDate: Date,
        completion: @escaping (Result<HKQuantitySample?, Error>) -> Void
    ) {
        guard let stepsQuantityType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            completion(
                Result.failure(HKRetrievingDataErrors.quantityTypeNotCreatedError)
            )
            return
        }
            
        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: [.strictStartDate, .strictEndDate]
        )
        
        let query = HKStatisticsQuery(
            quantityType: stepsQuantityType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum
        ) { (query, statisticsOrNil, errorOrNil) in
            if let error = errorOrNil as? HKError {
                let isNoDataError = error.code.rawValue == 11
                completion(isNoDataError ? .success(nil) : .failure(error))
                return
            }
            guard let stats = statisticsOrNil, let sumQuantity = stats.sumQuantity() else {
                completion(.success(nil))
                return
            }
            
            let sample = HKQuantitySample(
                type: stepsQuantityType,
                quantity: sumQuantity,
                start: stats.startDate,
                end: stats.endDate
            )
            completion(Result.success(sample))
        }
        
        let healthKitStore: HKHealthStore = HKHealthStore()
        healthKitStore.execute(query)
    }
    
    func getStepsArray(startDate: Date, endDate: Date, completion: @escaping (Result<[HKQuantitySample], Error>) -> Void){
        
        guard let stepsQuantityType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
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
            sampleType: stepsQuantityType,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [sortDescriptor],
            resultsHandler: { _, samples, error in
                guard let results = samples as? [HKQuantitySample] else {
                    completion(.failure(HKRetrievingDataErrors.noDataError))
                    return
                }
                let consolidated = self.consolidateIfNeeded(samples: results)
                completion(.success(consolidated))
        })
        
        healthKitStore.execute(query)
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

extension HKQuantitySample {
    
    func toDictionary() -> [String: Any] {
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
        return Int(self.quantity.doubleValue(for: HKUnit.count()))
    }
    
    func getSourceId() -> String {
        if let additionalData = self.metadata, let unitTest = additionalData["unit_test"] as? Bool, unitTest == true {
            let sourceId = (additionalData["source_id"] as? String) ?? ""
            return sourceId
        }else{
            return self.sourceRevision.source.bundleIdentifier
        }
    }
    
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

enum TimeSpan: String, CaseIterable {
    case hour = "hour", day = "day", week = "week"
     
    func dateComponentValue() -> DateComponents {
        switch self {
        case .hour:
            return DateComponents(hour: 1)
        case .day:
            return DateComponents(day: 1)
        case .week:
            return DateComponents(day: 7)
        }
    }
}

enum StatsQueryMode {
    case onlyHead, onlyCollection, headAndCollection
}


class HKRetrievingDataError: Error {
    init(code: String, message: String){
        self.code = code
        self.message = message
    }
    var code: String
    var message: String
}

class HKRetrievingDataErrors {
    static let noDataError = HKRetrievingDataError(code: "query_error", message: "error executing query")
    
    static let quantityTypeNotCreatedError = HKRetrievingDataError(code: "type_creation_error", message: "error creating quantity type")
    
    static let missingCorrectParameters = HKRetrievingDataError(code: "missing_correct_parameters", message: "missing correct parameters")
}
