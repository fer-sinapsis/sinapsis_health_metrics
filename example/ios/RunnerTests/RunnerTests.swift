//
//  RunnerTests.swift
//  RunnerTests
//
//  Created by Sudarshan Chakra on 8/02/23.
//

import XCTest
@testable import health_metrics_observers
import HealthKit

final class RunnerTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    func testCreateWorkout(){

            let distance = HKQuantity(unit: HKUnit.mile(), doubleValue: 3.2)
            let dateFormatterIso = DateFormatter()
            dateFormatterIso.dateFormat = "yyyy-MM-dd HH:mm:ss"
            let dateConverted = dateFormatterIso.date(from: "2023-09-07 02:00:00")

            let now = Date()
            let run = HKWorkout(activityType: HKWorkoutActivityType.running,
                                start: dateConverted!,
                                end: now,
                                duration: 0,
                                totalEnergyBurned: nil,
                                totalDistance: distance,
                                metadata: nil)

            HKHealthStore().save(run) { (success, error) -> Void in
                guard success else {
                    // Perform proper error handling here.
                    print(error?.localizedDescription)
                    return
                }

                // Add detail samples here.
                
                let stepSample = self.createStepPoint(value: 130, start: now, duration: 1, sourceId: "iphonee")

                // if not already created is created in hk
                HKHealthStore().add([stepSample], to: run) { (success, error) -> Void in
                    guard success else {
                        // Perform proper error handling here.
                        print(error?.localizedDescription)
                        return
                    }
                    print("SUCCESSSSS")
                }
            }

    }
    
    func testDateFormatWithMillis(){
        let dateStr = "2022-10-05T16:15:23.343Z"
        let format = HealthMetricsApiService.getDateFormatForDateStr(dateStr)
        
        let dateFormatterIso = DateFormatter()
        dateFormatterIso.dateFormat = format
        let dateConverted = dateFormatterIso.date(from: dateStr)
        
        XCTAssert(format == "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ")
        XCTAssertNotNil(dateConverted)
    }
    
    func testDateFormatNoMillis(){
        let dateStr = "2023-06-27T16:00:00Z"
        let format = HealthMetricsApiService.getDateFormatForDateStr(dateStr)
        
        let dateFormatterIso = DateFormatter()
        dateFormatterIso.dateFormat = format
        let dateConverted = dateFormatterIso.date(from: dateStr)
        
        XCTAssert(format == "yyyy-MM-dd'T'HH:mm:ssZZZZZ")
        XCTAssertNotNil(dateConverted)
    }

    func testSameSourcesNoConsolidation() throws {
        let now = Date()
        let p1 = createStepPoint(value: 150, start: now, duration: 3, sourceId: "iphone")
        let p2 = createStepPoint(value: 50, start: now.addHours(5), duration: 1, sourceId: "iphone")
        let p3 = createStepPoint(value: 80, start: now.addHours(2), duration: 2, sourceId: "iphone")
        let consolidated = HealthMetricsSender().consolidateIfNeeded(samples: [p1, p2, p3])
        XCTAssert(consolidated.count == 3)
    }
    
    func testConsolidatedContainedPoints() throws {
        let now = Date()
        let p1 = createStepPoint(value: 150, start: now, duration: 3, sourceId: "iphone")
        let p2 = createStepPoint(value: 25, start: now.addHours(1), duration: 1, sourceId: "watch")
        let p3 = createStepPoint(value: 50, start: now.addHours(5), duration: 1, sourceId: "iphone")
        let p4 = createStepPoint(value: 50, start: now.addHours(2), duration: 1, sourceId: "watch")
        let consolidated = HealthMetricsSender().consolidateIfNeeded(samples: [p1, p2, p3, p4])
        XCTAssert(consolidated.count == 2)
        XCTAssert(consolidated.first?.extractValue() == 150)
    }
    
    func testConsolidateEscalatedPoints() throws {
        let now = Date()
        let p1 = createStepPoint(value: 150, start: now, duration: 3, sourceId: "iphone")
        let p2 = createStepPoint(value: 25, start: now.addHours(1), duration: 3, sourceId: "watch")
        let p3 = createStepPoint(value: 50, start: now.addHours(5), duration: 1, sourceId: "iphone")
        let p4 = createStepPoint(value: 200, start: now.addHours(2), duration: 2, sourceId: "watch")
        let consolidated = HealthMetricsSender().consolidateIfNeeded(samples: [p1, p2, p3, p4])
        XCTAssert(consolidated.count == 2)
        XCTAssert(consolidated.first?.extractValue() == 200)
    }
    
    func testConsolidateSameStartPoints() throws {
        let now = Date()
        let p1 = createStepPoint(value: 150, start: now, duration: 3, sourceId: "iphone")
        let p3 = createStepPoint(value: 100, start: now, duration: 2, sourceId: "watch")
        let p2 = createStepPoint(value: 50, start: now.addHours(5), duration: 1, sourceId: "iphone")
        let consolidated = HealthMetricsSender().consolidateIfNeeded(samples: [p1, p2, p3])
        XCTAssert(consolidated.count == 2)
        XCTAssert(consolidated.first?.extractValue() == 150)
    }
    
    func testConsolidateAll() throws {
        let now = Date()
        let p1 = createStepPoint(value: 150, start: now, duration: 3, sourceId: "iphone")
        let p2 = createStepPoint(value: 50, start: now.addHours(1), duration: 1, sourceId: "watch")
        let p3 = createStepPoint(value: 50, start: now.addHours(5), duration: 1, sourceId: "phone")
        let p4 = createStepPoint(value: 100, start: now.addHours(2), duration: 2, sourceId: "watch")
        let consolidated = HealthMetricsSender().consolidateIfNeeded(samples: [p1, p2, p3, p4])
        XCTAssert(consolidated.count == 2)
        XCTAssert(consolidated.first?.extractValue() == 150)
    }
    
    func createStepPoint(value: Int, start: Date, duration: Double, sourceId: String) -> HKQuantitySample {
        let quantityType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        return HKQuantitySample(
            type: quantityType,
            quantity: HKQuantity(unit: HKUnit.count(), doubleValue: Double(value)),
            start: start,
            end: start.addHours(duration),
            device: nil,
            metadata: ["source_id": sourceId, "unit_test": true]
        )
    }
}

extension Date {
    func addHours(_ hours: Double) -> Date {
        return self.addingTimeInterval(TimeInterval(3600 * hours))
    }
}
