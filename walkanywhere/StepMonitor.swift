//
//  StepMonitor.swift
//  walkanywhere
//
//  Created by Zachary Upstone on 10/03/2026.
//

import Foundation
import HealthKit
import UserNotifications

@Observable
class StepMonitor {
  var todaySteps: Int = 0
  private let healthStore = HKHealthStore()
  private var routeManager: RouteManager
  private var healthKitManager: HealthKitManager
  private var isMonitoring = false

  init(routeManager: RouteManager, healthKitManager: HealthKitManager) {
    self.routeManager = routeManager
    self.healthKitManager = healthKitManager
  }

  func startMonitoring() async {
    guard !isMonitoring else { return }
    isMonitoring = true

    // Request notification permission
    await requestNotificationPermission()

    // Start monitoring steps
    await fetchTodaySteps()

    // Set up background query for continuous monitoring
    setupBackgroundStepQuery()
  }

  private func requestNotificationPermission() async {
    do {
      try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
    } catch {
      print("Failed to request notification permission: \(error)")
    }
  }

  func fetchTodaySteps() async {
    guard HKHealthStore.isHealthDataAvailable() else { return }

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
        self.todaySteps = Int(steps)
        self.healthKitManager.stepCount = Int(steps)
        self.checkRouteCompletion()
      }
    }

    healthStore.execute(query)
  }

  private func setupBackgroundStepQuery() {
    let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
    let startOfDay = Calendar.current.startOfDay(for: Date())

    let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: nil, options: .strictStartDate)

    let query = HKObserverQuery(sampleType: stepType, predicate: predicate) { [weak self] _, completionHandler, error in
      guard error == nil else {
        completionHandler()
        return
      }

      Task {
        await self?.fetchTodaySteps()
      }

      completionHandler()
    }

    healthStore.execute(query)
  }

  private func checkRouteCompletion() {
    // Only check if there's actually a main route selected
    guard let mainRouteId = routeManager.mainRouteId else { return }

    // Check if this specific route is completed
    guard routeManager.checkCompletion(for: mainRouteId, currentSteps: todaySteps) else { return }

    // Mark route as completed
    routeManager.completeRoute(mainRouteId)

    // Send notification
    sendCompletionNotification(for: mainRouteId)

    // Clear the main route (but keep progress)
    routeManager.clearMainRoute(currentSteps: todaySteps)
  }

  private func sendCompletionNotification(for routeId: UUID) {
    guard let route = routeManager.savedRoutes.first(where: { $0.id == routeId }) else { return }

    let content = UNMutableNotificationContent()
    content.title = "Route Completed! 🎉"
    content.body = "Congratulations! You've completed your \(route.name) route with \(route.formattedSteps) steps!"
    content.sound = .default

    let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)

    UNUserNotificationCenter.current().add(request) { error in
      if let error = error {
        print("Failed to send notification: \(error)")
      }
    }
  }
}
