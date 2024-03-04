//
//  LastDateSavedHandler.swift
//  health_metrics_observers
//
//  Created by Sudarshan Chakra on 14/03/22.
//

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
    
    static let apiUrlKey = "apiUrl"
    static let migratedToShrcrApiKey = "migratedToSharecareApi"
    
    static let lastCheckWorkoutsKey = "lastCheckWorkouts"
    
    // last saved date - shared across sources
    static func getLastDateSaved(metricType: String) -> Int? {
        let lastDateSavedKey = Self.getLastDateSavedKeyByMetricType(metricType: metricType)
        if let nextStartDate = defaults.object(forKey: lastDateSavedKey) as? Date {
            return Int(nextStartDate.timeIntervalSince1970 * 1000)
        } else {
            return nil
        }
    }
    
    static func getLastReferenceDate(metricType: MetricType) -> Date? {
        //reference date last check or saved
        let lastDateSavedKey = Self.getLastDateSavedKeyByMetricType(metricType: metricType.rawValue)
        return defaults.object(forKey: lastDateSavedKey) as? Date
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
        case "WORKOUT":
            return Self.lastCheckWorkoutsKey
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

    static func updateObserverCreated(_ created: Bool, metricType: MetricType) {
        let createdKey = metricType.getObserverCreatedKeyStr()
        defaults.set(created, forKey: createdKey)
    }
    
    static func hasObserverCreated(metricType: MetricType) -> Bool {
        let createdKey = metricType.getObserverCreatedKeyStr()
        return defaults.bool(forKey: createdKey)
    }
    
    static func updateApiUrl(_ newApiUrl: String){
        defaults.set(newApiUrl, forKey: Self.apiUrlKey)
    }
    
    static func getApiUrl() -> String? {
        return defaults.string(forKey: Self.apiUrlKey)
    }
    
    static func updateMigrated(_ migrated: Bool){
        defaults.set(migrated, forKey: Self.migratedToShrcrApiKey)
    }
    
    static func getMigrated() -> Bool {
        return defaults.bool(forKey: Self.migratedToShrcrApiKey)
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
            "created": Self.hasObserverCreated(metricType: .step),
            "observer_syncing": Self.isObserverSyncing(),
            "last_saved_sleep_date_across_sources": lastDateSavedSharedSleep,
            "workouts_observer_created": Self.hasObserverCreated(metricType: .workout),
            "api_url": Self.getApiUrl(),
            "migrated_to_shrcr_api": Self.getMigrated()
        ]
    }
    
}
