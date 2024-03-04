//
//  NotificationUtilities.swift
//  health_metrics_observers
//
//  Created by Sudarshan Chakra on 23/08/23.
//

import Foundation

class CustomNotificationManager {
    
    static func triggerLocalNotification(
        title: String,
        subtitle: String,
        payload: [String: Any] = [:],
        categoryId: String,
        identifier: String
    ){
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = subtitle
        content.userInfo = payload
        content.categoryIdentifier = categoryId
        
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: 1, repeats: false
        )
        
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )
        
        let notificationCenter = UNUserNotificationCenter.current()
        notificationCenter.add(request) { (error) in
            if error != nil {
                print(error?.localizedDescription)
            }
        }
    }
    
}
