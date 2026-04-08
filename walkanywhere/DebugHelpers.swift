//
//  DebugHelpers.swift
//  walkanywhere
//
//  Created for testing and debugging purposes
//

import Foundation

#if DEBUG
struct DebugHelpers {

  // Simulate yesterday's incomplete data
  static func simulateYesterdayIncompleteData(routeManager: RouteManager, routeId: UUID, partialSteps: Int) {
    guard var progress = routeManager.allRouteProgress[routeId] else {
      print("❌ Route not found")
      return
    }

    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd"

    // Get yesterday's date string
    let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
    let yesterdayString = dateFormatter.string(from: yesterday)

    // Set partial steps for yesterday (simulating app was closed mid-day)
    progress.dailyContributions[yesterdayString] = partialSteps

    // Update the progress
    routeManager.allRouteProgress[routeId] = progress

    // Force save
    let allProgressPath = URL.documentsDirectory.appending(path: "allRouteProgress.json")
    let mainRoutePath = URL.documentsDirectory.appending(path: "mainRoute.json")

    do {
      let data = try JSONEncoder().encode(routeManager.allRouteProgress)
      try data.write(to: allProgressPath)

      // Also update mainRoute.json if this is the main route
      if let mainRouteId = routeManager.mainRouteId, mainRouteId == routeId {
        let mainRouteData = MainRouteData(routeId: routeId, progress: progress)
        let mainData = try JSONEncoder().encode(mainRouteData)
        try mainData.write(to: mainRoutePath)
      }

      print("✅ Simulated yesterday (\(yesterdayString)) with \(partialSteps) partial steps")
    } catch {
      print("❌ Failed to save: \(error)")
    }
  }

  // Simulate today having a different startingStepsDate to trigger recalculation
  static func resetStartingStepsDate(routeManager: RouteManager, routeId: UUID) {
    guard var progress = routeManager.allRouteProgress[routeId] else {
      print("❌ Route not found")
      return
    }

    // Clear the startingStepsDate to force recalculation
    progress.startingStepsDate = nil
    routeManager.allRouteProgress[routeId] = progress

    let allProgressPath = URL.documentsDirectory.appending(path: "allRouteProgress.json")

    do {
      let data = try JSONEncoder().encode(routeManager.allRouteProgress)
      try data.write(to: allProgressPath)
      print("✅ Reset startingStepsDate for testing")
    } catch {
      print("❌ Failed to save: \(error)")
    }
  }

  // Print current state for debugging
  static func printRouteState(routeManager: RouteManager, routeId: UUID, currentSteps: Int) {
    guard let progress = routeManager.allRouteProgress[routeId],
          let route = routeManager.savedRoutes.first(where: { $0.id == routeId }) else {
      print("❌ Route not found")
      return
    }

    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd"
    let todayString = dateFormatter.string(from: Date())

    print("\n📊 Route State Debug: \(route.name)")
    print("├─ Starting Steps: \(progress.startingSteps)")
    print("├─ Starting Steps Date: \(progress.startingStepsDate ?? "nil")")
    print("├─ Current HealthKit Steps (Today Total): \(currentSteps)")
    print("├─ Session Steps (current - starting): \(currentSteps - progress.startingSteps)")
    print("├─ Steps So Far On Selected Day: \(progress.stepsSoFarOnSelectedDay ?? 0)")
    print("├─ Selected Day String: \(progress.selectedDayString ?? "nil")")
    print("└─ Daily Contributions:")

    for (date, steps) in progress.dailyContributions.sorted(by: { $0.key > $1.key }) {
      let marker = date == todayString ? " ← TODAY" : ""
      print("   ├─ \(date): \(steps) steps\(marker)")
    }

    let totalFromContributions = progress.dailyContributions.values.reduce(0, +)
    print("   └─ Total: \(totalFromContributions) steps\n")

    // Show other routes' contributions for today
    print("📅 All Routes' Contributions for Today (\(todayString)):")
    for (otherRouteId, otherProgress) in routeManager.allRouteProgress {
      if let otherRoute = routeManager.savedRoutes.first(where: { $0.id == otherRouteId }),
         let todaySteps = otherProgress.dailyContributions[todayString] {
        let isMain = otherRouteId == routeManager.mainRouteId ? " ⭐️ MAIN" : ""
        print("├─ \(otherRoute.name): \(todaySteps) steps\(isMain)")
      }
    }

    // Calculate what's unaccounted for
    let allRoutesTodaySteps = routeManager.allRouteProgress.values
      .compactMap { $0.dailyContributions[todayString] }
      .reduce(0, +)
    let unaccounted = currentSteps - allRoutesTodaySteps
    print("└─ Unaccounted: \(unaccounted) steps (steps before any route was set today)\n")
  }

  // Clear today's contribution to simulate fresh day
  static func clearTodayContribution(routeManager: RouteManager, routeId: UUID) {
    guard var progress = routeManager.allRouteProgress[routeId] else {
      print("❌ Route not found")
      return
    }

    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd"
    let todayString = dateFormatter.string(from: Date())

    // Remove today's contribution
    let removedSteps = progress.dailyContributions.removeValue(forKey: todayString)
    routeManager.allRouteProgress[routeId] = progress

    let allProgressPath = URL.documentsDirectory.appending(path: "allRouteProgress.json")
    let mainRoutePath = URL.documentsDirectory.appending(path: "mainRoute.json")

    do {
      // Update allRouteProgress.json
      let data = try JSONEncoder().encode(routeManager.allRouteProgress)
      try data.write(to: allProgressPath)

      // If this is the main route, also update mainRoute.json
      if routeManager.mainRouteId == routeId {
        let mainRouteData = MainRouteData(routeId: routeId, progress: progress)
        let mainData = try JSONEncoder().encode(mainRouteData)
        try mainData.write(to: mainRoutePath)
      }

      print("✅ Cleared today's contribution (\(removedSteps ?? 0) steps removed)")
      print("📁 Updated both allRouteProgress.json and mainRoute.json")
    } catch {
      print("❌ Failed to save: \(error)")
    }
  }
}
#endif
