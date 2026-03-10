//
//  HealthKitTestHelper.swift
//  walkanywhere
//
//  Created by Zachary Upstone on 10/03/2026.
//

import Foundation
import HealthKit

class HealthKitTestHelper {
    private let healthStore = HKHealthStore()

    func addSteps(count: Int, date: Date = Date()) async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw NSError(domain: "HealthKit", code: 1, userInfo: [NSLocalizedDescriptionKey: "HealthKit not available"])
        }

        let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!

        // Request write permission
        try await healthStore.requestAuthorization(toShare: [stepType], read: [])

        // Create the step sample
        let quantity = HKQuantity(unit: .count(), doubleValue: Double(count))
        let sample = HKQuantitySample(
            type: stepType,
            quantity: quantity,
            start: date,
            end: date
        )

        // Save to HealthKit
        try await healthStore.save(sample)
    }

    func addStepsGradually(totalSteps: Int, intervalSeconds: Double = 1.0) async throws {
        let stepsPerInterval = 10
        let intervals = totalSteps / stepsPerInterval

        for _ in 0..<intervals {
            try await addSteps(count: stepsPerInterval)
            try await Task.sleep(nanoseconds: UInt64(intervalSeconds * 1_000_000_000))
        }

        // Add remaining steps
        let remainder = totalSteps % stepsPerInterval
        if remainder > 0 {
            try await addSteps(count: remainder)
        }
    }
}
