//
//  HealthKitManager.swift
//  walkanywhere
//
//  Created by Zachary Upstone on 10/03/2026.
//

import Foundation
import HealthKit

@Observable
class HealthKitManager {
  var stepCount: Int = 0
  var stepHistory: [StepData] = []
  var isAuthorized: Bool = false
  var authorizationError: String?

  private let healthStore = HKHealthStore()

  func checkAuthorizationStatus() async {
    guard HKHealthStore.isHealthDataAvailable() else {
      return
    }

    let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
    let status = healthStore.authorizationStatus(for: stepType)

    await MainActor.run {
      self.isAuthorized = (status == .sharingAuthorized)
    }

    if isAuthorized {
      await fetchTodaySteps()
      await fetchStepHistory(days: 30)
    }
  }

  func requestAuthorization() async {
    guard HKHealthStore.isHealthDataAvailable() else {
      authorizationError = "Health data is not available on this device"
      return
    }

    let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!

    do {
      try await healthStore.requestAuthorization(toShare: [], read: [stepType])
      isAuthorized = true
      await fetchTodaySteps()
      await fetchStepHistory(days: 30)
    } catch {
      authorizationError = "Failed to authorize HealthKit: \(error.localizedDescription)"
      isAuthorized = false
    }
  }

  func fetchTodaySteps() async {
    guard isAuthorized else { return }

    let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
    let now = Date()
    let startOfDay = Calendar.current.startOfDay(for: now)

    let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)

    let query = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
      guard let result = result, let sum = result.sumQuantity() else {
        return
      }

      let steps = sum.doubleValue(for: HKUnit.count())
      Task { @MainActor in
        self.stepCount = Int(steps)
      }
    }

    healthStore.execute(query)
  }

  func fetchStepHistory(days: Int) async {
    guard isAuthorized else { return }

    let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
    let calendar = Calendar.current
    let now = Date()
    let startDate = calendar.date(byAdding: .day, value: -days, to: now)!

    var interval = DateComponents()
    interval.day = 1

    let query = HKStatisticsCollectionQuery(
      quantityType: stepType,
      quantitySamplePredicate: nil,
      options: .cumulativeSum,
      anchorDate: calendar.startOfDay(for: startDate),
      intervalComponents: interval
    )

    query.initialResultsHandler = { _, results, error in
      guard let results = results else { return }

      var history: [StepData] = []

      results.enumerateStatistics(from: startDate, to: now) { statistics, _ in
        let steps = statistics.sumQuantity()?.doubleValue(for: HKUnit.count()) ?? 0
        let stepData = StepData(date: statistics.startDate, stepCount: Int(steps))
        history.append(stepData)
      }

      Task { @MainActor in
        self.stepHistory = history.reversed()
      }
    }

    healthStore.execute(query)
  }
}
