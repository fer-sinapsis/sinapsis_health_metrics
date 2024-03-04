//
//  WorkoutObserver.swift
//  device_info_plus
//
//  Created by Sudarshan Chakra on 25/08/23.
//

import Foundation
import HealthKit

class WorkoutObserver: BackgroundMetricObserver {
    var observerQuery: HKObserverQuery?
    var metricType = MetricType.workout

    func newDataDetected(completion: @escaping () -> Void){
        let endDate = Date()
        let lastCheckWorkouts = ObserverStatus.getLastReferenceDate(metricType: .workout)
        let startDate = lastCheckWorkouts ?? Calendar.current.date(byAdding: Calendar.Component.day, value: -7, to: endDate)!
        
        WorkoutDataHandler.getValidExternalWorkouts(
            startDate: startDate,
            endDate: endDate
        ) { externalWorkouts in
            
            if !externalWorkouts.isEmpty {
                ObserverStatus.updateLastDateSaved(
                    newDateInMilliseconds: Int(Date().timeIntervalSince1970) * 1000,
                    metricType: MetricType.workout.rawValue
                )
                
                let categoryId = "newWorkoutsDetected"
                let total = externalWorkouts.count
                if total > 1 {
                    CustomNotificationManager.triggerLocalNotification(
                        title: "Workouts synced! 🔥",
                        subtitle: "Open WeCare to claim your points.",
                        payload: ["count": total],
                        categoryId: categoryId,
                        identifier: categoryId
                    )
                } else if let workout = externalWorkouts.first {
                    let workoutData = workout.toDictionary()
                    CustomNotificationManager.triggerLocalNotification(
                        title: "Activity synced! 🔥",
                        subtitle: "Open WeCare to claim your points.",
                        payload: ["count": total, "workout_data": workoutData],
                        categoryId: categoryId,
                        identifier: categoryId
                    )
                }
            }
            completion()
        }
    }
}


struct ActivitiesJson: Decodable {
    let activities: [ActivityInfo]

    enum CodingKeys: String, CodingKey {
        case activities = "content"
    }
}

struct ActivityInfo: Decodable {
    var id: String
    var name: String
    var mobileCategory: MobileCategory?
    var tracking: Tracking
    
    struct MobileCategory: Decodable {
        let iosIdentifier: String?
    }
    
    struct Tracking: Decodable {
        let minimumRequiredMinutes: Int?
    }
}
