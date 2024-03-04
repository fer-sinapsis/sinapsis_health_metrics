//
//  WorkoutQueries.swift
//  health_metrics_observers
//
//  Created by Sudarshan Chakra on 5/09/23.
//

import Foundation
import HealthKit
import Combine

class WorkoutDataHandler {
    
    static var stepObserver: GeneralMetricObserver?
    static var distanceObserver: GeneralMetricObserver?
    static let defaults = UserDefaults.standard
    static let currentWorkoutIntervalsKey = "currenWorkoutIntervals"
    static let currentWorkoutStartDate = "currentWorkoutStartDate"
    static let observerMetadataKey = "observerMetadata"
    static let externalWorkoutsNotificationDataKey = "externalWorkoutsNotificationData"
    static var observableMetricValues: ObservableMetricValues?
    static var metricValuesCancellable: AnyCancellable?
    
    static var workoutRequiredTypes = [
        HKObjectType.workoutType(),
        HKObjectType.quantityType(forIdentifier: .stepCount)!,
        HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
        HKObjectType.quantityType(forIdentifier: .distanceCycling)!,
        HKObjectType.quantityType(forIdentifier: .distanceSwimming)!,
        HKObjectType.quantityType(forIdentifier: .distanceWheelchair)!,
        HKObjectType.quantityType(forIdentifier: .distanceDownhillSnowSports)!,
    ]
    
    static func getValidExternalWorkouts(
        startDate: Date,
        endDate: Date,
        completion: @escaping ([HKWorkout]
    ) -> ()){
        
        HealthMetricsSender().getDataPoints(
            startDate: startDate,
            endDate: endDate,
            hkSampleType: MetricType.workout.getSampleType()
        ) { result in
            
            switch result {
            case .success(let workouts):
                let workouts = (workouts as? [HKWorkout]) ?? []
                let externalWorkouts = workouts.filter({ workout in
                    var hasMinimumRequiredMins = false
                    let activitiesDictionary = getActivitiesInfo();
                    if let activityInfo = activitiesDictionary[String(workout.workoutActivityType.rawValue)] {
                        let workoutDurationInMins = Int(workout.duration / 60)
                        let minmiumRequired = activityInfo.tracking.minimumRequiredMinutes ?? 0
                        hasMinimumRequiredMins = workoutDurationInMins >= minmiumRequired
                    }
                    
                    let sourceId = workout.getSourceId()
                    let bundleId = Bundle.main.bundleIdentifier ?? ""
                    let isExternal = !sourceId.contains(bundleId)
                    return isExternal && hasMinimumRequiredMins
                })
                completion(externalWorkouts)
            case .failure(_):
                completion([])
            }
        }
    }
    
    static func getActivitiesInfo() -> [String: ActivityInfo] {
        let metadata = UserDefaults.standard.string(forKey: observerMetadataKey)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        guard let jsonData = metadata?.data(using: .utf8),
              let activitiesInfo = try? decoder.decode(ActivitiesJson.self, from: jsonData) else {
            return [:]
        }
        
        // dictionary of activities with mobile category identifier
        var activitiesDictionary: [String: ActivityInfo] = [:]
        for activity in activitiesInfo.activities {
            if let platformIdentifier = activity.mobileCategory?.iosIdentifier {
                activitiesDictionary[platformIdentifier] = activity
            }
        }
        return activitiesDictionary
    }
    
    static func allInRange(
        startDate: Date,
        endDate: Date,
        completion: @escaping ([HKWorkout]
    ) -> ()){
        
        HealthMetricsSender().getDataPoints(
            startDate: startDate,
            endDate: endDate,
            hkSampleType: MetricType.workout.getSampleType()
        ) { result in
            
            switch result {
            case .success(let workouts):
                completion((workouts as? [HKWorkout]) ?? [])
            case .failure(_):
                completion([])
            }
        }
    }
    
    static func dataForWorkoutInProgress(activitySegmentsString: String, metricsSupported: String) async throws -> [String: Any] {
        var stepsCount = 0.0;
        var distanceInMiles = 0.0;
        let intervals = try activitySegmentsToDateIntervals(segmentsStr: activitySegmentsString)
        let metricsSupportedArray = metricsSupported.split(separator: ",")
        
        if metricsSupportedArray.contains("steps") {
            var stepSamples = await samplesOnIntervalsFromIphone(
                intervals, hkSampleType: MetricType.step.getSampleType()
            )
            stepsCount += stepSamples.reduce(0.0) { $0 + $1.extractValueDouble() }
        }
        
        if metricsSupportedArray.contains("distance") {
            var distanceSamples = await samplesOnIntervalsFromIphone(
                intervals, hkSampleType: MetricType.walkRunDistance.getSampleType()
            )
            distanceInMiles += distanceSamples.reduce(0.0) { $0 + $1.extractValueDouble() }
        }
        
        return [
            "stepsCount": Int(stepsCount),
            "distanceInMiles": distanceInMiles
        ]
    }
    
    static func samplesOnIntervalsFromIphone(_ intervals: [DateInterval], hkSampleType: HKSampleType?) async -> [HKSample] {
        //TODO: check if its better to do a query from start to end and filter them instead of multiple queries
        var samples: [HKSample] = []
        for interval in intervals {
            var tempSamples = (try? await HealthMetricsSender().getDataPointsAsync(
                startDate: interval.start,
                endDate: interval.end,
                hkSampleType: hkSampleType
            )) ?? []
            
            if (!tempSamples.isEmpty) {
                tempSamples = tempSamples.filter({ sample in
                    return sample.device?.model?.lowercased().contains("iphone") ?? false
                })
                samples.append(contentsOf: tempSamples)
            }
        }
        return samples
    }
    
    static func activitySegmentsToDateIntervals(segmentsStr: String) throws -> [DateInterval] {
        let segmentsArray = segmentsStr.split(separator: "|")
        var intervals: [DateInterval] = []
        for segmentString in segmentsArray {
            let segmentInfo = segmentString.split(separator: ":")
            guard let startStr = segmentInfo.first,
                  let startDateMillisecs = Int(startStr),
                  let endStr = segmentInfo.last,
                  var endDateMillisecs = Int(endStr) else {
                throw WorkoutHealthKitErrors.convertingIntervalsFailed
            }
            let endDateInterval = TimeInterval(endDateMillisecs / 1000)
            let startDate = Date(timeIntervalSince1970: TimeInterval(startDateMillisecs / 1000))
            let endDate = Date(timeIntervalSince1970: endDateInterval)
            intervals.append(DateInterval(start: startDate, end: endDate))
        }
        return intervals
    }
    
    static func validatePermissionsForWorkouts(result: @escaping FlutterResult) {
        Task {
            do {
                let healthStore = HKHealthStore()
                var totalCountWritingsApproved = 0
                let endDate = Date()
                guard let starDate = Calendar.current.date(byAdding: Calendar.Component.day, value: -7, to: endDate) else {
                    let domainError = WorkoutHealthKitErrors.validatingPermissionsForWorkoutsFailed(message: "error setting start date 7 days ago")
                    result(FlutterError(code: domainError.code, message: domainError.message, details: nil))
                    return
                }
                
                let stepSamplesLastSevenDays = try await HealthMetricsSender().getDataPointsAsync(
                    startDate: starDate,
                    endDate: endDate,
                    hkSampleType: MetricType.step.getSampleType()
                )
                let hasReadPermissionForSteps = stepSamplesLastSevenDays.filter({ item in
                    let sourceId = item.getSourceId()
                    let bundleId = Bundle.main.bundleIdentifier ?? ""
                    return !sourceId.contains(bundleId)
                }).isEmpty == false
                
                for sampleType in Self.workoutRequiredTypes {
                    let isWritingApproved = healthStore.authorizationStatus(for: sampleType) == .sharingAuthorized
                    if isWritingApproved {
                        totalCountWritingsApproved += 1
                    }
                }
                let approved = totalCountWritingsApproved == Self.workoutRequiredTypes.count && hasReadPermissionForSteps
                result(approved)
            } catch {
                let errorMessage = (error as? GeneralError)?.message ?? error.localizedDescription 
                let domainError = WorkoutHealthKitErrors.validatingPermissionsForWorkoutsFailed(message: errorMessage)
                result(FlutterError(code: domainError.code, message: domainError.message, details: nil))
            }
        }
    }
    
    static func requestPermissionsForWorkouts(result: @escaping FlutterResult) {
        let allTypes = Set(Self.workoutRequiredTypes)
        let healthStore = HKHealthStore()
        healthStore.requestAuthorization(
            toShare: allTypes, read: allTypes
        ) { success, error in
            if let err = error {
                let flutterError = WorkoutHealthKitErrors.requestingPermissionsForWorkoutsFailed(message: err.localizedDescription)
                result(flutterError)
            } else {
                result(true)
            }
        }
    }
    
    static func createWorkout(
        activityTypeIdentifier: String,
        metricsSupported: String,
        activitySegmentsString: String,
        startDate: Date,
        endDate: Date
    ) async throws {
        
        guard let activityTypeRawValue = UInt(activityTypeIdentifier),
              let activityType = HKWorkoutActivityType(rawValue: activityTypeRawValue) else {
            throw WorkoutHealthKitErrors.activityTypeNotFound;
        }
        let metricsSupportedArray = metricsSupported.split(separator: ",")
        let stepsSupported = metricsSupportedArray.contains("steps")
        let distanceSupported = metricsSupportedArray.contains("distance")
        
        do {
            let intervals = try activitySegmentsToDateIntervals(segmentsStr: activitySegmentsString)
            let stepSamples: [HKSample] = await samplesOnIntervalsFromIphone(
                intervals, hkSampleType: MetricType.step.getSampleType()
            )
            let distanceSamples: [HKSample] = await samplesOnIntervalsFromIphone(
                intervals, hkSampleType: activityType.supportedDistance().getSampleType()
            )
            var totalDistance: HKQuantity? = nil
            
            if (!distanceSamples.isEmpty && distanceSupported) {
                let distanceInMiles = distanceSamples.reduce(0.0) { $0 + $1.extractValueDouble() }
                totalDistance = HKQuantity(unit: HKUnit.mile(), doubleValue: distanceInMiles)
            }
            let segmentsDuration = intervals.reduce(0.0) { $0 + $1.duration }
            let workout = HKWorkout(activityType: activityType,
                                    start: startDate,
                                    end: endDate,
                                    duration: segmentsDuration,
                                    totalEnergyBurned: nil,
                                    totalDistance: totalDistance,
                                    metadata: nil)
            
            let hkStore = HKHealthStore()
            try await hkStore.save(workout)
            var samples: [HKSample] = []
            if stepsSupported {
                samples += stepSamples
            }
            
            if distanceSupported {
                samples += distanceSamples
            }
            
            if (samples.count > 0) {
                try await hkStore.addSamples(samples, to: workout)
            }
            WorkoutLiveActivityHandler.updateLiveActivity(status: "finished")
            Self.stopObserversWorkout(hkStore: hkStore)
        } catch {
            if let err = error as? NSError, err.domain == "com.apple.healthkit" && (err.code == 5 || err.code == 4) {
                throw WorkoutHealthKitErrors.workoutPermissionsMissing
            } else {
                throw WorkoutHealthKitErrors.creatingWorkoutFailed(message: error.localizedDescription)
            }
        }
    }
    
    static func stopObserversWorkout(hkStore: HKHealthStore? = nil){
        let healthKitStore: HKHealthStore = hkStore ?? HKHealthStore()
        if let stepsQuery = stepObserver?.observerQuery {
            healthKitStore.stop(stepsQuery)
        }
        
        if let distanceQuery = distanceObserver?.observerQuery {
            healthKitStore.stop(distanceQuery)
        }
        defaults.removeObject(forKey: currentWorkoutIntervalsKey)
        metricValuesCancellable?.cancel()
    }
    
    static func pauseWorkoutObservers(workoutIntervalsString: String) {
        WorkoutLiveActivityHandler.updateLiveActivity(status: "paused")
        defaults.setValue(workoutIntervalsString, forKey: currentWorkoutIntervalsKey)
    }
    
    static func resumeWorkoutObservers(workoutIntervalsString: String){
        WorkoutLiveActivityHandler.updateLiveActivity(status: "in progress")
        defaults.setValue(workoutIntervalsString, forKey: currentWorkoutIntervalsKey)
    }
    
    static func currentWorkoutIntervals() -> String? {
        if let currentWorkoutIntervalsStr = defaults.string(forKey: currentWorkoutIntervalsKey) {
            return currentWorkoutIntervalsStr
        } else if let currentWorkoutStartDate = defaults.object(forKey: currentWorkoutStartDate) as? Date {
            let startMillisecs = Int((currentWorkoutStartDate.timeIntervalSince1970 * 1000).rounded())
            let endMillisecs = Int((Date().timeIntervalSince1970 * 1000).rounded())
            return "\(startMillisecs):\(endMillisecs)"
        } else {
            return nil
        }
    }
    
    static func startObserversForWorkout(
        flutterMethodChannel: FlutterMethodChannel?,
        name: String,
        activityTypeIdentifier: String,
        imageUrlStr: String,
        metricsSupported: String
    ) async throws {
        
        guard let activityTypeRawValue = UInt(activityTypeIdentifier),
              let activityType = HKWorkoutActivityType(rawValue: activityTypeRawValue) else {
            throw WorkoutHealthKitErrors.activityTypeNotFound;
        }
        
        let metricsSupportedArray = metricsSupported.split(separator: ",")
        if (metricsSupportedArray.contains("steps") && metricsSupportedArray.contains("distance")) {
            let metricValues = ObservableMetricValues(steps: 0, distance: 0.0)
            Self.observableMetricValues = metricValues
            metricValuesCancellable = metricValues.$distance.combineLatest(metricValues.$steps).sink {
                WorkoutLiveActivityHandler.updateLiveActivity(
                    steps: $1, distance: $0
                )
            }
        }
        
        WorkoutLiveActivityHandler.startLiveActivity(
            name: name,
            imageUrl: imageUrlStr,
            metricsSupported: metricsSupported
        );
        
        defaults.setValue(Date(), forKey: currentWorkoutStartDate)
        
        if (metricsSupportedArray.contains("steps")) {
            Self.stepObserver = try GeneralMetricObserver(metricType: MetricType.step) {
                guard let activitySegmentsString = currentWorkoutIntervals(),
                let intervals = try? activitySegmentsToDateIntervals(segmentsStr: activitySegmentsString) else { return
                }

                let stepSamples = await samplesOnIntervalsFromIphone(
                    intervals, hkSampleType: MetricType.step.getSampleType()
                )
                let totalSteps = stepSamples.reduce(0) { $0 + $1.extractValue() }
                
                if totalSteps > 0 {
                    if let metricValues = Self.observableMetricValues {
                        metricValues.steps = totalSteps
                    } else {
                        WorkoutLiveActivityHandler.updateLiveActivity(steps: totalSteps)
                    }
                }
                
                flutterMethodChannel?.invokeMethod(
                    "current_workout_data_update",
                    arguments: ["type": "steps", "value": totalSteps]
                )
            }
        }
        
        if (metricsSupportedArray.contains("distance")) {
            let distanceMetric = activityType.supportedDistance()
            Self.distanceObserver = try GeneralMetricObserver(metricType: distanceMetric) {
                guard let activitySegmentsString = currentWorkoutIntervals(),
                      let intervals = try? activitySegmentsToDateIntervals(segmentsStr: activitySegmentsString) else { return
                }
                
                let distanceSamples = await samplesOnIntervalsFromIphone(
                    intervals, hkSampleType: distanceMetric.getSampleType()
                )
                let distanceInMiles = distanceSamples.reduce(0.0) { $0 + $1.extractValueDouble() }
                
                if distanceInMiles > 0.0 {
                    if let metricValues = Self.observableMetricValues {
                        metricValues.distance = distanceInMiles
                    } else {
                        WorkoutLiveActivityHandler.updateLiveActivity(distance: distanceInMiles)
                    }
                }
                
                flutterMethodChannel?.invokeMethod(
                    "current_workout_data_update",
                    arguments: ["type": "distance", "value": distanceInMiles]
                )
            }
        }
    }
    
    static func getExternalWorkoutsNotificationData() -> String? {
        let notificationData = defaults.string(forKey: externalWorkoutsNotificationDataKey)
        return notificationData
    }
    
    static func setExternalWorkoutsNotificationData(data: String?){
        if let notificationData = data {
            defaults.setValue(notificationData, forKey: externalWorkoutsNotificationDataKey)
        } else {
            defaults.removeObject(forKey: externalWorkoutsNotificationDataKey)
        }
    }
}

extension HKWorkout {
    override func toDictionary() -> [String: Any] {
        return [
            "sourceId": self.getSourceId(),
            "healthAppId": self.uuid.uuidString,
            "platformId": self.workoutActivityType.rawValue,
            "activityType": self.workoutActivityType.name,
            "durationInSecs": self.duration,
            "startDateInSecs": self.startDate.timeIntervalSince1970,
            "endDateInSecs": self.endDate.timeIntervalSince1970,
            "distanceInMiles": self.totalDistance?.doubleValue(for: HKUnit.mile()) ?? 0,
            "stepsCount": 0
        ]
    }
    
    func toDictionaryWithSteps() async -> [String: Any] {
        let stepsCount: Int = (try? await getSteps()) ?? 0
        print("stepscount \(stepsCount)")
        return [
            "sourceId": self.getSourceId(),
            "healthAppId": self.uuid.uuidString,
            "platformId": self.workoutActivityType.rawValue,
            "activityType": self.workoutActivityType.name,
            "durationInSecs": self.duration,
            "startDateInSecs": self.startDate.timeIntervalSince1970,
            "endDateInSecs": self.endDate.timeIntervalSince1970,
            "distanceInMiles": self.totalDistance?.doubleValue(for: HKUnit.mile()) ?? 0,
            "stepsCount": stepsCount
        ]
    }
    
    func getSteps() async throws -> Int {
        var stepsCount = 0
        
        guard let stepsCountType =
            HKObjectType.quantityType(forIdentifier:
                                        HKQuantityTypeIdentifier.stepCount) else {
            throw HKRetrievingDataErrors.quantityTypeNotCreatedError
        }
        let workoutPredicate = HKQuery.predicateForObjects(from: self)
        let startDateSort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Int, Error>) -> Void in
            
            let query = HKSampleQuery(sampleType: stepsCountType, predicate: workoutPredicate, limit: 0,
                                      sortDescriptors: [startDateSort]) { (sampleQuery, results, error) -> Void in
                guard let steps = results as? [HKQuantitySample], steps.count > 0 else {
                    continuation.resume(with: .success(0))
                    return
                }
                stepsCount = steps.reduce(0, { partialResult, sample in
                    partialResult + sample.extractValue()
                })
                continuation.resume(with: .success(stepsCount))
            }
            let hkStore = HKHealthStore()
            hkStore.execute(query)
        }
    }
}

extension [HKWorkout] {
    func toDictionariesWithSteps() async -> [[String: Any]] {
        var workoutsDictionaries: [[String: Any]] = []
        for workout in self {
            let workoutDictionary = await workout.toDictionaryWithSteps()
            workoutsDictionaries.append(workoutDictionary)
        }
        return workoutsDictionaries
    }
}

class ObservableMetricValues {
    @Published var steps: Int
    @Published var distance: Double
    
    init(steps: Int, distance: Double) {
        self.steps = steps
        self.distance = distance
    }
}

class WorkoutHealthKitErrors {
    static let convertingIntervalsFailed = GeneralError(
        code: "error_converting_intervals", message: "error converting intervals"
    )
    
    static func creatingWorkoutFailed (message: String) -> GeneralError {
        return GeneralError(code: "creating_workout_failed", message: message)
    }
    
    static let workoutPermissionsMissing = GeneralError(
        code: "workout_permissions_missing", message: "workout permissions missing"
    )
    
    static let activityTypeNotFound =  GeneralError(
        code: "activity_type_not_found", message: "activity type not found"
    )
    
    static func requestingPermissionsForWorkoutsFailed(message: String) -> GeneralError { GeneralError(code: "requesting_permissions_for_workouts_failed", message: message)
    }
    
    static func validatingPermissionsForWorkoutsFailed(message: String) -> GeneralError { GeneralError(code: "validating_permissions_for_workouts_failed", message: message)
    }
}
