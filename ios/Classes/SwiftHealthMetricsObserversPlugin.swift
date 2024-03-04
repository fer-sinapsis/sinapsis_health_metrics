import Flutter
import UIKit

public class SwiftHealthMetricsObserversPlugin: NSObject, FlutterPlugin, UNUserNotificationCenterDelegate {
    
    private let createObserverKey = "createObserver"
    private let getLastSavedDateKey = "getLastDateSaved"
    private let updateLastSavedDateKey = "updateLastDateSaved"
    private let getObserverStatus = "getObserverStatus"
    private let isObserverSyncing = "isObserverSyncing"
    private let updateApiUrl = "updateApiUrl"
    private let getWorkoutsInInterval = "getWorkoutsInInterval"
    private let getValidExternalWorkouts = "getValidExternalWorkouts"
    private let getDataForWorkoutInProgress = "getDataForWorkoutInProgress"
    private let createWorkout = "createWorkout"
    private let requestPermissionsForWorkouts = "requestPermissionsForWorkouts"
    private let validatePermissionsForWorkouts = "validatePermissionsForWorkouts"
    private let startWorkoutObservers = "startWorkoutObservers"
    private let pauseWorkoutObservers = "pauseWorkoutObservers"
    private let resumeWorkoutObservers = "resumeWorkoutObservers"
    private let stopWorkoutObservers = "stopWorkoutObservers"
    private let getExternalWorkoutsNotificationData = "getExternalWorkoutsNotificationData"
    static var flutterMethodChannel: FlutterMethodChannel?
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        var channel = FlutterMethodChannel(name: "health_metrics_observers", binaryMessenger: registrar.messenger())
        Self.flutterMethodChannel = channel
        let instance = SwiftHealthMetricsObserversPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
        registrar.addApplicationDelegate(instance)
    }
    
    public func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [AnyHashable : Any] = [:]) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        ObserverStatus.updateObserverSyncing(newValue: false)
        
        WorkoutLiveActivityHandler.checkIfActivityRunning()
        
        if (ObserverStatus.hasObserverCreated(metricType: .step)) {
            ObserverFactory.createBackgroundObserver(metricType: .step)
        }
        
        if (ObserverStatus.hasObserverCreated(metricType: .workout)) {
            ObserverFactory.createBackgroundObserver(metricType: .workout)
        }
        return true
    }
    
    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void)
    {
        if #available(iOS 14.0, *) {
            completionHandler(.list)
        }
    }
    
    public func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let content = response.notification.request.content
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: content.userInfo),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            WorkoutDataHandler.setExternalWorkoutsNotificationData(data: jsonString)
        }
        
        if content.categoryIdentifier == "newWorkoutsDetected" {
            Self.flutterMethodChannel?.invokeMethod(
                "workout_local_notification_tapped",
                arguments: content.userInfo
            )
        }
        completionHandler();
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if call.method == createObserverKey {
            guard let args = call.arguments as? [String: Any],
                  let metricType = MetricType(rawValue: args["metricType"] as? String ?? ""),
                  let shouldSyncToServer = args["shouldSyncToServer"] as? Bool
            else {
                let error = HKRetrievingDataErrors.missingCorrectParameters
                result(FlutterError(code: error.code, message: error.message, details: nil))
                return
            }
            
            if (shouldSyncToServer) {
                let defaults = UserDefaults.standard
                ObserverStatus.updateApiUrl(args["apiUrl"] as? String ?? "")
                defaults.set(args["userId"] ?? "", forKey: "userId")
                defaults.set(args["userApiKey"] ?? "", forKey: "userApiKey")
                defaults.set(args["xApiKey"] ?? "", forKey: "xApiKey")
            }
            
            if let metadata = args["metadata"] {
                let defaults = UserDefaults.standard
                defaults.set(metadata, forKey: "observerMetadata")
            }
            
            ObserverFactory.createBackgroundObserver(metricType: metricType) { completed in
                result(completed)
                print("observer created: \(completed)")
            }
        } else if call.method == getLastSavedDateKey {
            guard let args = call.arguments as? [String : Any],
            let metricType = args["metricType"] as? String
            else {
                let error = HKRetrievingDataErrors.missingCorrectParameters
                let flutterError = FlutterError(code: error.code, message: error.message, details: nil)
                result(flutterError)
                return
            }
            
            result(ObserverStatus.getLastDateSaved(metricType: metricType))
            
        } else if call.method == updateLastSavedDateKey {
            
            guard let args = call.arguments as? [String : Any],
            let newDate = args["newDateInMilliseconds"] as? Int,
            let metricType = args["metricType"] as? String
            else {
                let error = HKRetrievingDataErrors.missingCorrectParameters
                let flutterError = FlutterError(code: error.code, message: error.message, details: nil)
                result(flutterError)
                return
            }
            ObserverStatus.updateLastDateSaved(
                newDateInMilliseconds: newDate,
                metricType: metricType
            )
            result(true)
        } else if call.method == getObserverStatus {
            result(ObserverStatus.getObserverStatus())
        } else if call.method == isObserverSyncing {
            result(ObserverStatus.isObserverSyncing())
        } else if call.method == updateApiUrl {
            guard
            let args = call.arguments as? [String : String],
            let newApiUrl = args["newApiUrl"]
            else {
                let error = HKRetrievingDataErrors.missingCorrectParameters
                result(FlutterError(code: error.code, message: error.message, details: nil))
                return
            }
            
            ObserverStatus.updateApiUrl(newApiUrl)
            result(true)
        } else if call.method == getWorkoutsInInterval {
            guard let args = call.arguments as? [String : Any],
            let startDateInSecs = args["startDateInSecs"] as? Double,
            let endDateInSecs = args["endDateInSecs"] as? Double else {
                let error = HKRetrievingDataErrors.missingCorrectParameters
                result(FlutterError(code: error.code, message: error.message, details: nil))
                return
            }
            
            let startDate = Date(timeIntervalSince1970: TimeInterval(startDateInSecs))
            let endDate = Date(timeIntervalSince1970: TimeInterval(endDateInSecs))
            
            WorkoutDataHandler.allInRange(startDate: startDate, endDate: endDate, completion: { workouts in
                
                let workoutsDictionaries = workouts.map { workout in
                    return workout.toDictionary()
                }
                result(workoutsDictionaries)
            })
            
        } else if call.method == getValidExternalWorkouts {
            guard let args = call.arguments as? [String : Any],
            let startDateInSecs = args["startDateInSecs"] as? Double,
            let endDateInSecs = args["endDateInSecs"] as? Double else {
                let error = HKRetrievingDataErrors.missingCorrectParameters
                result(FlutterError(code: error.code, message: error.message, details: nil))
                return
            }
            
            let startDate = Date(timeIntervalSince1970: TimeInterval(startDateInSecs))
            let endDate = Date(timeIntervalSince1970: TimeInterval(endDateInSecs))
            
            WorkoutDataHandler.getValidExternalWorkouts(startDate: startDate, endDate: endDate, completion: { workouts in
                Task {
                    let workoutsDictionaries = await workouts.toDictionariesWithSteps()
                    result(workoutsDictionaries)
                }
            })
            
        } else if call.method == getDataForWorkoutInProgress {
            guard let args = call.arguments as? [String : Any],
                  let activitySegmentsStr = args["activitySegments"] as? String,
                  let metricsSupported = args["metricsSupported"] as? String
            else {
                let error = HKRetrievingDataErrors.missingCorrectParameters
                result(FlutterError(code: error.code, message: error.message, details: nil))
                return
            }
            Task {
                do {
                    let workoutData = try await WorkoutDataHandler.dataForWorkoutInProgress(
                        activitySegmentsString: activitySegmentsStr,
                        metricsSupported: metricsSupported
                    );
                    result(workoutData)
                } catch {
                    let err = error as! GeneralError
                    result(FlutterError(code: err.code, message: err.message, details: nil))
                }
            }
        } else if call.method == createWorkout {
            guard let args = call.arguments as? [String : Any],
                  let activitySegmentsStr = args["activitySegments"] as? String,
                  let activityPlatformId = args["activityPlatformId"] as? String,
                  let metricsSupported = args["metricsSupported"] as? String,
                  let startDateInSecs = args["startDateInSecs"] as? Double,
                  let endDateInSecs = args["endDateInSecs"] as? Double
            else {
                let error = HKRetrievingDataErrors.missingCorrectParameters
                result(FlutterError(code: error.code, message: error.message, details: nil))
                return
            }
            let startDate = Date(timeIntervalSince1970: TimeInterval(startDateInSecs))
            let endDate = Date(timeIntervalSince1970: TimeInterval(endDateInSecs))
            
            Task {
                do {
                    try await WorkoutDataHandler.createWorkout(
                        activityTypeIdentifier: activityPlatformId,
                        metricsSupported: metricsSupported,
                        activitySegmentsString: activitySegmentsStr,
                        startDate: startDate,
                        endDate: endDate
                    )
                    result(true)
                } catch {
                    let err = error as! GeneralError
                    result(FlutterError(code: err.code, message: err.message, details: nil))
                }
            }
        } else if call.method == requestPermissionsForWorkouts {
            WorkoutDataHandler.requestPermissionsForWorkouts(result: result)
        } else if call.method == validatePermissionsForWorkouts {
            WorkoutDataHandler.validatePermissionsForWorkouts(result: result)
        } else if call.method == startWorkoutObservers {
            guard let args = call.arguments as? [String : Any],
                  let activityPlatformId = args["activityPlatformId"] as? String,
                  let metricsSupported = args["metricsSupported"] as? String,
                  let activityName = args["name"] as? String,
                  let imageUrl = args["imageUrl"] as? String
            else {
                let error = HKRetrievingDataErrors.missingCorrectParameters
                result(FlutterError(code: error.code, message: error.message, details: nil))
                return
            }
            
            Task {
                do {
                    try await WorkoutDataHandler.startObserversForWorkout(
                        flutterMethodChannel: Self.flutterMethodChannel,
                        name: activityName,
                        activityTypeIdentifier: activityPlatformId,
                        imageUrlStr: imageUrl,
                        metricsSupported: metricsSupported
                    )
                    result(true)
                } catch {
                    let err = error as! GeneralError
                    result(FlutterError(code: err.code, message: err.message, details: nil))
                }
            }
        } else if call.method == pauseWorkoutObservers {
            guard let args = call.arguments as? [String : Any],
                  let activitySegmentsStr = args["activitySegments"] as? String
            else {
                let error = HKRetrievingDataErrors.missingCorrectParameters
                result(FlutterError(code: error.code, message: error.message, details: nil))
                return
            }
            WorkoutDataHandler.pauseWorkoutObservers(workoutIntervalsString: activitySegmentsStr)
            result(true)
        } else if call.method == resumeWorkoutObservers {
            guard let args = call.arguments as? [String : Any],
                  let activitySegmentsStr = args["activitySegments"] as? String
            else {
                let error = HKRetrievingDataErrors.missingCorrectParameters
                result(FlutterError(code: error.code, message: error.message, details: nil))
                return
            }
            WorkoutDataHandler.resumeWorkoutObservers(workoutIntervalsString: activitySegmentsStr)
            result(true)
        } else if call.method == stopWorkoutObservers {
            WorkoutLiveActivityHandler.updateLiveActivity(status: "discarded")
            WorkoutDataHandler.stopObserversWorkout()
            result(true)
        } else if call.method == getExternalWorkoutsNotificationData {
            let notificationData = WorkoutDataHandler.getExternalWorkoutsNotificationData()
            WorkoutDataHandler.setExternalWorkoutsNotificationData(data: nil)
            result(notificationData)
        }
  }
    
}
