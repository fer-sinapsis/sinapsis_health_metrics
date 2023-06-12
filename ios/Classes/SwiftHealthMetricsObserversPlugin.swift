import Flutter
import UIKit

public class SwiftHealthMetricsObserversPlugin: NSObject, FlutterPlugin {
    private let createStepCountObserverKey = "createStepCountObserver"
    private let getLastSavedDateKey = "getLastDateSaved"
    private let updateLastSavedDateKey = "updateLastDateSaved"
    private let getObserverStatus = "getObserverStatus"
    private let isObserverSyncing = "isObserverSyncing"
    private let getStepsCountByIntervals = "getStepsCountByIntervals"
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "health_metrics_observers", binaryMessenger: registrar.messenger())
        let instance = SwiftHealthMetricsObserversPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
        registrar.addApplicationDelegate(instance)
    }
    
    public func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [AnyHashable : Any] = [:]) -> Bool {
        ObserverStatus.updateObserverSyncing(newValue: false)
        
        let defaults = UserDefaults.standard
        let hkPermissionsAlreadyGiven = defaults.bool(forKey: HealthKitObserverFactory.hkPermissionsAlreadyGiven)
        
        if hkPermissionsAlreadyGiven {
            //if already have permissions recreate observers
            HealthKitObserverFactory.createStepsCountBackgroundObserver(startingActivity: false) { created in
                print(created)
            }
        }
        return true
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if call.method == createStepCountObserverKey {
            guard let args = call.arguments as? [String : String] else {
                let error = HKRetrievingDataErrors.missingCorrectParameters
                result(FlutterError(code: error.code, message: error.message, details: nil))
                return
            }
            
            let defaults = UserDefaults.standard
            defaults.set(args["apiUrl"] ?? "", forKey: "apiUrl")
            defaults.set(args["userId"] ?? "", forKey: "userId")
            defaults.set(args["userApiKey"] ?? "", forKey: "userApiKey")
            defaults.set(args["xApiKey"] ?? "", forKey: "xApiKey")
            defaults.set(true, forKey: HealthKitObserverFactory.hkPermissionsAlreadyGiven)
            
            HealthKitObserverFactory.createStepsCountBackgroundObserver(startingActivity: true) { completed in
                //if completed && defaults.object(forKey: HealthMetricsSender.nextStartDateKey) == nil {
                    //defaults.set(Date(), forKey: HealthMetricsSender.nextStartDateKey) // initial start date
                //}
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
        } else if call.method == getStepsCountByIntervals {
            
            guard let args = call.arguments as? [String : Any],
            let startDateMillisecs = args["startDateMillisecs"] as? Int,
            let endDateMillisecs = args["endDateMillisecs"] as? Int,
            let interval = args["interval"] as? String,
            let timespan = TimeSpan(rawValue: interval)
            else {
                let error = HKRetrievingDataErrors.missingCorrectParameters
                let flutterError = FlutterError(code: error.code, message: error.message, details: nil)
                result(flutterError)
                return
            }
            
            let startDate = Date(timeIntervalSince1970: TimeInterval(startDateMillisecs/1000))
            let endDate = Date(timeIntervalSince1970: TimeInterval(endDateMillisecs/1000))
            
            HealthMetricsSender().getStepsCountByIntervals(
                startDate: startDate,
                endDate: endDate,
                timeSpan: timespan
            ) { stepsCountResult in
                    switch stepsCountResult {
                    case .success(let samples):
                        let samplesAsDict = samples.map({ sample in
                            sample.toDictionary()
                        })
                        result(samplesAsDict)
                    case .failure(let err):
                        let error = HKRetrievingDataErrors.noDataError
                        let flutterError = FlutterError(code: error.code, message: err.localizedDescription, details: nil)
                        result(flutterError)
                    }
                }
        }
  }
}
