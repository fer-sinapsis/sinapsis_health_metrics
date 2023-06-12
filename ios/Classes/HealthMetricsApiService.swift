//
//  HealthMetricsApiService.swift
//  health_metrics_observers
//
//  Created by Sudarshan Chakra on 6/12/22.
//

import Foundation

class HealthMetricsApiService {
    
    static func defaultRequestWithHeaders(endpointPath: String) -> URLRequest? {
        let defaults = UserDefaults.standard
        guard let apiUrl = defaults.string(forKey: "apiUrl"),
              let userApiKey = defaults.string(forKey: "userApiKey"),
              let xApiKey = defaults.string(forKey: "xApiKey"),
              let userId = defaults.string(forKey: "userId"),
              let appVersion = Bundle.main.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String,
              let url = URL(string: apiUrl + endpointPath) else {
                  return nil
              }
        
        var request = URLRequest(url: url)
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(userId, forHTTPHeaderField: "we_uid")
        request.addValue(userApiKey, forHTTPHeaderField: "we_api_key")
        request.addValue(xApiKey, forHTTPHeaderField: "x-api-key")
        request.addValue(appVersion, forHTTPHeaderField: "app_version")
        return request
    }
    
    static func sendStepsToServer(
        stepRecords: [[String: Any]],
        completion: @escaping (Bool) -> Void
    ){
        let endpointMetrics = "/api/profile/public/metrics"
        guard var request = defaultRequestWithHeaders(endpointPath: endpointMetrics) else {
            completion(false)
            return
        }
        
        request.httpMethod = "POST"
        let dateFormatterIso = DateFormatter()
        dateFormatterIso.dateFormat = HealthMetricsSender.defaultDateFormat
        let bodyDictionary: [String: Any] = [
            "type": "STEP",
            "mobile_platform": "IOS",
            "source": "OBSERVER",
            "metrics": stepRecords,
        ]
        
        guard
            let httpbody = try? JSONSerialization.data(withJSONObject: bodyDictionary, options: []) else {
                completion(false)
                return
            }
        
        request.httpBody = httpbody
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("HTTP Request Failed \(error)")
                completion(false)
            } else if let _ = data {
                print(response ?? "no response")
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode < 299 {
                    completion(true)
                }else{
                    completion(false)
                }
            }
        }
        
        task.resume()
    }
    
    static func getLastTimeStepsSavedServer(
        completion: @escaping (Date?) -> Void
    ){
        let endpointLastSteps = "/api/profile/public/health_metrics/last_steps"
        guard var request = defaultRequestWithHeaders(endpointPath: endpointLastSteps) else {
            completion(nil)
            return
        }
        request.httpMethod = "GET"
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("HTTP Request Failed \(error)")
                completion(nil)
            } else if let responseData = data {
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode < 299 {
                    let decoder = JSONDecoder()
                    decoder.keyDecodingStrategy = .convertFromSnakeCase
                    let stepsRecord = try? decoder.decode(StepsRecord.self, from: responseData);
                    let dateFormatterIso = DateFormatter()
                    dateFormatterIso.dateFormat = HealthMetricsSender.defaultDateFormat
                    let lastTimeStepsSaved = dateFormatterIso.date(from: stepsRecord?.measurementEndDate ?? "")
                    completion(lastTimeStepsSaved)
                } else {
                    completion(nil)
                }
            }
        }
        task.resume()
    }
}

struct StepsRecord: Decodable {
    let id: String
    let value: String
    let type: String
    let measurementStartDate: String
    let measurementEndDate: String
    let mobilePlatform: String
}
