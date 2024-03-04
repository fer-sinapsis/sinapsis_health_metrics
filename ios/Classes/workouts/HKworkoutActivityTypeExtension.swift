//
//  HKworkoutExtension.swift
//  device_info_plus
//
//  Created by Sudarshan Chakra on 25/08/23.
//

import Foundation
import HealthKit

extension HKWorkoutActivityType {
    
    var name: String {
        get {
            switch self {
            case .americanFootball:
                return "american_football"
            case .archery:
                return "archery"
            case .australianFootball:
                return "australian_football"
            case .badminton:
                return "badminton"
            case .barre:
                return "barre"
            case .baseball:
                return "baseball"
            case .basketball:
                return "basketball"
            case .bowling:
                return "bowling"
            case .boxing:
                return "boxing"
            case .cardioDance:
                return "cardio_dance"
            case .climbing:
                return "climbing"
            case .cooldown:
                return "cooldown"
            case .coreTraining:
                return "core_training"
            case .cricket:
                return "cricket"
            case .crossCountrySkiing:
                return "cross_country_skiing"
            case .crossTraining:
                return "cross_Training"
            case .curling:
                return "curling"
            case .cycling:
                return "cycling"
            case .discSports:
                return "disc_sports"
            case .downhillSkiing:
                return "down_hill_skiing"
            case .elliptical:
                return "elliptical"
            case .equestrianSports:
                return "equestrian_sports"
            case .fencing:
                return "fencing"
            case .fishing:
                return "fishing"
            case .fitnessGaming:
                return "fitness_gaming"
            case .flexibility:
                return "flexibility"
            case .functionalStrengthTraining:
                return "functional_strength_training"
            case .golf:
                return "golf"
            case .gymnastics:
                return "gymnastics"
            case .handCycling:
                return "hand_cycling"
            case .handball:
                return "handball"
            case .highIntensityIntervalTraining:
                return "high_intensity_interval_training"
            case .hiking:
                return "hiking"
            case .hunting:
                return "hunting"
            case .hockey:
                return "hockey"
            case .jumpRope:
                return "jumpRope"
            case .kickboxing:
                return "kickboxing"
            case .lacrosse:
                return "lacrosse"
            case .martialArts:
                return "martial_arts"
            case .mindAndBody:
                return "mind_and_body"
            case .mixedCardio:
                return "mixed_cardio"
            case .other:
                return "other"
            case .paddleSports:
                return "paddle_sports"
            case .pickleball:
                return "pickleball"
            case .pilates:
                return "pilates"
            case .play:
                return "play"
            case .preparationAndRecovery:
                return "preparation_and_recovery"
            case .racquetball:
                return "racquetball"
            case .rowing:
                return "rowing"
            case .rugby:
                return "rugby"
            case .running:
                return "running"
            case .sailing:
                return "sailing"
            case .skatingSports:
                return "skating_sports"
            case .snowSports:
                return "snow_sports"
            case .snowboarding:
                return "snowboarding"
            case .soccer:
                return "soccer"
            case .socialDance:
                return "social_dance"
            case .softball:
                return "softball"
            case .squash:
                return "squash"
            case .stairClimbing:
                return "stair_climbing"
            case .stairs:
                return "stairs"
            case .stepTraining:
                return "step_training"
            case .surfingSports:
                return "surfing_sports"
            case .swimBikeRun:
                return "swim_bike_run"
            case .swimming:
                return "swimming"
            case .tableTennis:
                return "table_tennis"
            case .taiChi:
                return "taiChi"
            case .tennis:
                return "tennis"
            case .trackAndField:
                return "track_and_field"
            case .traditionalStrengthTraining:
                return "traditional_strength_training"
            case .transition:
                return "transition"
            case .volleyball:
                return "volleyball"
            case .walking:
                return "walking"
            case .waterFitness:
                return "water_fitness"
            case .waterPolo:
                return "water_polo"
            case .waterSports:
                return "water_sports"
            case .wheelchairRunPace:
                return "wheelchair_run_pace"
            case .wheelchairWalkPace:
                return "wheelchair_walk_pace"
            case .wrestling:
                return "wrestling"
            case .yoga:
                return "yoga"
            case .dance:
                return "dance"
            case .danceInspiredTraining:
                return "dance_inspired_training"
            case .mixedMetabolicCardioTraining:
                return "mixed_metabolic_cardio_training"
            @unknown default:
                fatalError()
            }
        }
    }
    
    func supportedDistance() -> MetricType {
        switch self {
        case .wheelchairRunPace, .wheelchairWalkPace:
            return .wheelChairDistance
        case .running, .walking, .hiking:
            return .walkRunDistance
        case .cycling:
            return .bikeDistance
        case .swimming:
            return .swimDistance
        case .snowboarding, .snowSports, .downhillSkiing:
            return .downhillSnowSportsDistance
        default:
            return .walkRunDistance
        }
    }
}
