//
//  WorkoutLiveActivityHandler.swift
//  health_metrics_observers
//
//  Created by Sudarshan Chakra on 24/11/23.
//

import Foundation
import ActivityKit

class WorkoutLiveActivityHandler {
    
    @available(iOS 16.1, *)
    static var currentActivity: Activity<OngoingWorkoutAttributes>? = nil
    
    static func checkIfActivityRunning() {
        if #available(iOS 16.2, *) {
            if let lastActivity = Activity.activities.last as? Activity<OngoingWorkoutAttributes> {
                Self.currentActivity = lastActivity
            }
        }
    }
    
    static func startLiveActivity(
        name: String, imageUrl: String, metricsSupported: String
    ){
        if #available(iOS 16.2, *) {
            if ActivityAuthorizationInfo().areActivitiesEnabled {
                do {
                    let initialContentState = OngoingWorkoutAttributes.ContentState(
                        refStartDate: Date(),
                        durationInterval: 0.0,
                        durationInTimerFormat: "00:00",
                        status: "in progress",
                        metrics: ["steps": 0.0, "distance": 0.0]
                    )
                    let activityAttributes = OngoingWorkoutAttributes(
                        name: name,
                        imageUrl: imageUrl,
                        metricsSupported: metricsSupported.split(separator: ",").map{String($0)}
                    )
                    let activityContent = ActivityContent(state: initialContentState, staleDate: nil)
                    currentActivity = try Activity.request(
                        attributes: activityAttributes, content: activityContent
                    )
                } catch (let error) {
                    print("Error Live Activity \(error.localizedDescription).")
                }
            }
        }
    }
    
    static func updateLiveActivity(
        status: String? = nil,
        steps: Int? = nil,
        distance: Double? = nil
    ){
        if #available(iOS 16.2, *) {
            guard let currentState = currentActivity?.content.state else {
                return
            }
            
            var refStartDate = currentState.refStartDate
            var durationInTimerFormat = currentState.durationInTimerFormat
            var durationInterval = currentState.durationInterval
            
            if status == "paused" && steps == nil && distance == nil {
                durationInterval = abs(refStartDate.timeIntervalSince1970 - Date().timeIntervalSince1970)
                let formatter = DateComponentsFormatter()
                formatter.allowedUnits = [.minute, .second]
                durationInTimerFormat = formatter.string(from: durationInterval) ?? "--:--"
                print("paused")
                print(durationInterval)
                print(durationInTimerFormat)
            }
            
            if status == "in progress" && steps == nil && distance == nil {
                let originalDate = Date()
                let calendar = Calendar.current
                refStartDate = calendar.date(
                    byAdding: .second,
                    value: Int(-durationInterval),
                    to: originalDate
                ) ?? refStartDate
                print("resumed")
                print(refStartDate)
            }
            
            let contentUpdated = OngoingWorkoutAttributes.ContentState(
                refStartDate: refStartDate,
                durationInterval: durationInterval,
                durationInTimerFormat: durationInTimerFormat,
                status: status ?? currentState.status,
                metrics: [
                    "steps": (steps != nil) ? Double(steps ?? 0) : (currentState.metrics["steps"] ?? 0.0),
                    "distance": distance ?? (currentState.metrics["distance"] ?? 0.0)
                ]
            )
            
            let activityContent = ActivityContent(
                state: contentUpdated, staleDate: nil
            )
            Task {
                if status == "finished" || status == "discarded" {
                    await currentActivity?.end(activityContent, dismissalPolicy: .immediate)
                } else {
                    await currentActivity?.update(activityContent)
                }
                
            }
        }
    }
}

struct OngoingWorkoutAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var refStartDate: Date // for timer
        var durationInterval: TimeInterval
        var durationInTimerFormat: String
        var status: String
        var metrics: [String: Double]
    }
    var name: String
    var imageUrl: String
    var metricsSupported: [String]
}
