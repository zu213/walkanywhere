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
  var healthKitManager: HealthKitManager  // Made public for debug access
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

    // Backfill any missing daily contributions for the main route
    await backfillMissingDays()

    // Set up background query for continuous monitoring
    setupBackgroundStepQuery()
  }

  private func requestNotificationPermission() async {
    do {
      try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
    } catch {
      // Failed to request notification permission
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
        self.updateDailyContributions()
        self.checkRouteCompletion()
      }
    }

    healthStore.execute(query)
  }

  private func updateDailyContributions() {
    let today = Date()

    // Update daily contribution for the active main route ONLY
    if let mainRouteId = routeManager.mainRouteId,
       let progress = routeManager.getProgress(for: mainRouteId) {
      // Calculate steps taken since this route became active (session steps)
      let todaySessionSteps = max(0, todaySteps - progress.startingSteps)

      // Save to today's contributions
      routeManager.updateDailyContribution(for: mainRouteId, date: today, steps: todaySessionSteps)
    }
  }

  private func backfillMissingDays() async {
    // Only backfill if there's an active main route
    guard let mainRouteId = routeManager.mainRouteId,
          var progress = routeManager.getProgress(for: mainRouteId),
          let selectedDayString = progress.selectedDayString,
          HKHealthStore.isHealthDataAvailable() else { return }

    let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
    let calendar = Calendar.current
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd"

    // Parse the day this route was MOST RECENTLY set as main
    guard let selectedDate = dateFormatter.date(from: selectedDayString) else { return }
    let selectedDayStart = calendar.startOfDay(for: selectedDate)
    let today = calendar.startOfDay(for: Date())
    let todayString = dateFormatter.string(from: today)

    // Only backfill from the day it was set as main until today (inclusive)
    var currentDate = selectedDayStart
    while currentDate <= today {
      let dateString = dateFormatter.string(from: currentDate)
      let startOfDay = calendar.startOfDay(for: currentDate)
      let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

      // Query HealthKit for this specific day
      let predicate = HKQuery.predicateForSamples(
        withStart: startOfDay,
        end: endOfDay,
        options: .strictStartDate
      )

      let result = await withCheckedContinuation { (continuation: CheckedContinuation<Double?, Never>) in
        let query = HKStatisticsQuery(
          quantityType: stepType,
          quantitySamplePredicate: predicate,
          options: .cumulativeSum
        ) { _, result, _ in
          let steps = result?.sumQuantity()?.doubleValue(for: HKUnit.count())
          continuation.resume(returning: steps)
        }
        healthStore.execute(query)
      }

      if let totalStepsForDay = result {
        // Calculate what this route should get for this day
        let contributionForDay: Int
        if dateString == progress.selectedDayString,
           let stepsSoFar = progress.stepsSoFarOnSelectedDay {
          // This is the day the route was selected - only count steps AFTER selection
          contributionForDay = Int(totalStepsForDay) - stepsSoFar
        } else {
          // Check how many steps OTHER routes got on this day
          let otherRoutesSteps = routeManager.allRouteProgress
            .filter { $0.key != mainRouteId }
            .compactMap { $0.value.dailyContributions[dateString] }
            .reduce(0, +)

          // This route gets: total steps - steps from other routes
          contributionForDay = max(0, Int(totalStepsForDay) - otherRoutesSteps)
        }

        // Get existing contribution (if any)
        let existingContribution = progress.dailyContributions[dateString] ?? 0

        // Only update if HealthKit shows more steps than we have recorded
        if contributionForDay > existingContribution {
          routeManager.updateDailyContribution(for: mainRouteId, date: currentDate, steps: contributionForDay)
        }
      }

      // Move to next day
      guard let nextDay = calendar.date(byAdding: .day, value: 1, to: currentDate) else { break }
      currentDate = nextDay
    }

    // After backfilling, update the route state to reflect today as the new "truth"
    // This ensures that if the route was selected days ago, we now treat today as the reference point
    progress = routeManager.getProgress(for: mainRouteId)! // Refresh after backfill updates

    // Update to today as the new selected day with current steps
    if progress.selectedDayString != todayString {
      routeManager.updateRouteStateForToday(
        routeId: mainRouteId,
        currentSteps: todaySteps,
        todayString: todayString
      )
    }
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

    UNUserNotificationCenter.current().add(request) { _ in
      // Notification sent
    }
  }
}
