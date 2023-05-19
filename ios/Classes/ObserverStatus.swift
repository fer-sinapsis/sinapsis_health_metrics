//
//  LastDateSavedHandler.swift
//  health_metrics_observers

import Foundation

class ObserverStatus {
    static let defaults = UserDefaults.standard
    
    //observer
    static let observerSyncingKey = "observerSyncing"
    static let observerCreatedKey = "observerCreated"
    //steps
    static let nextStartDateKey = "nextStartDate"
    static let lastStepCountSentKey = "lastStepCountSent"
    static let lastAttemptToSendKey = "lastAttemptToSend"
    static let observerOnlyLastSavedKey = "lastDateSavedObserver"
    //sleep
    static let lastSleepDateSavedKey = "lastSleepDateSaved"
    static let lastSleepValueSentKey = "lastSleepValueSent"
    
    // last saved date - shared across sources
    static func getLastDateSaved(metricType: String) -> Int? {
        let lastDateSavedKey = Self.getLastDateSavedKeyByMetricType(metricType: metricType)
        if let nextStartDate = defaults.object(forKey: lastDateSavedKey) as? Date {
            return Int(nextStartDate.timeIntervalSince1970 * 1000)
        } else {
            return nil
        }
    }
    
    static func updateLastDateSaved(newDateInMilliseconds: Int, metricType: String){
        let dateInSeconds = Double(newDateInMilliseconds/1000)
        let newDate = Date(timeIntervalSince1970: dateInSeconds)
        let lastDateSavedKey = Self.getLastDateSavedKeyByMetricType(metricType: metricType)
        defaults.set(newDate, forKey: lastDateSavedKey)
    }
    
    static func getLastDateSavedKeyByMetricType(metricType: String) -> String {
        switch (metricType) {
        case "STEP":
            return Self.nextStartDateKey
        case "SLEEP":
            return Self.lastSleepDateSavedKey
        default:
            return ""
        }
    }
    
    static func updateObserverSyncing(newValue: Bool) {
        defaults.set(newValue, forKey: observerSyncingKey)
    }
    
    static func isObserverSyncing() -> Bool {
       return defaults.bool(forKey: observerSyncingKey)
    }
    
    // last saved date - observer only
    static func getLastDateSavedObserverOnly() -> Int? {
        if let nextStartDate = defaults.object(forKey: Self.observerOnlyLastSavedKey) as? Date {
            return Int(nextStartDate.timeIntervalSince1970 * 1000)
        } else {
            return nil
        }
    }
    
    static func getLastAttemptDate() -> Int? {
        if let lastAttemptDate = defaults.object(forKey: Self.lastAttemptToSendKey) as? Date {
            return Int(lastAttemptDate.timeIntervalSince1970 * 1000)
        } else {
            return nil
        }
    }

    static func updateObserverCreated(_ created: Bool){
        defaults.set(created, forKey: Self.observerCreatedKey)
    }
    
    static func hasObserverCreated() -> Bool {
        return defaults.bool(forKey: Self.observerCreatedKey)
    }
    
    static func getObserverStatus() -> [String: Any?] {
        let lastDateSavedSharedStep = Self.getLastDateSaved(metricType: "STEP")
        let lastDateSavedSharedSleep = Self.getLastDateSaved(metricType: "SLEEP")
        return [
            "last_saved": lastDateSavedSharedStep,
            "last_saved_date_across_sources": lastDateSavedSharedStep,
            "last_saved_date_observer_only": Self.getLastDateSavedObserverOnly(),
            "last_steps_count_saved": defaults.integer(forKey: Self.lastStepCountSentKey),
            "last_attempt_timestamp": Self.getLastAttemptDate(),
            "created": Self.hasObserverCreated(),
            "observer_syncing": Self.isObserverSyncing(),
            "last_saved_sleep_date_across_sources": lastDateSavedSharedSleep,
        ]
    }
    
}
