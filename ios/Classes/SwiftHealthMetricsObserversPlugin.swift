import Flutter
import UIKit

public class SwiftHealthMetricsObserversPlugin: NSObject, FlutterPlugin {
    private let createStepCountObserverKey = "createStepCountObserver"
    private let getLastSavedDateKey = "getLastDateSaved"
    private let updateLastSavedDateKey = "updateLastDateSaved"
    private let getObserverStatus = "getObserverStatus"
    private let isObserverSyncing = "isObserverSyncing"
    
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
        }
  }
}
