//
//  RouteManager.swift
//  walkanywhere
//
//  Created by Zachary Upstone on 10/03/2026.
//

import Foundation

struct RouteProgress: Codable {
  let routeId: UUID
  var startingSteps: Int
  let startDate: Date
  var isCompleted: Bool
  var completedSteps: Int? // The actual steps when completed/paused
  var dailyContributions: [String: Int] = [:] // Date string (yyyy-MM-dd) -> steps contributed
}

// Stores both the main route ID and its current progress
struct MainRouteData: Codable {
  let routeId: UUID
  let progress: RouteProgress
}

@Observable
class RouteManager {
  var savedRoutes: [SavedRoute] = []
  var mainRouteId: UUID?
  var allRouteProgress: [UUID: RouteProgress] = [:]

  private let savePath = URL.documentsDirectory.appending(path: "savedRoutes.json")
  private let mainRoutePath = URL.documentsDirectory.appending(path: "mainRoute.json")
  private let allProgressPath = URL.documentsDirectory.appending(path: "allRouteProgress.json")

  var mainRoute: SavedRoute? {
    guard let id = mainRouteId else { return nil }
    return savedRoutes.first { $0.id == id }
  }

  init() {
    loadRoutes()
    loadAllProgress() // Load backup progress first
    loadMainRoute()   // Then load main route (overwrites with freshest data)
  }

  func getProgress(for routeId: UUID) -> RouteProgress? {
    return allRouteProgress[routeId]
  }

  func addRoute(_ route: SavedRoute) {
    savedRoutes.insert(route, at: 0)
    saveRoutes()
  }

  func deleteRoute(_ route: SavedRoute) {
    savedRoutes.removeAll { $0.id == route.id }
    // Remove progress for this route
    allRouteProgress.removeValue(forKey: route.id)
    // If we're deleting the main route, clear the main route
    if mainRouteId == route.id {
      mainRouteId = nil
      saveMainRoute()
    }
    saveRoutes()
    saveAllProgress()
  }

  func setMainRoute(_ route: SavedRoute, currentSteps: Int) {
    // If there's already a main route, pause it first
    if let oldMainRouteId = mainRouteId, oldMainRouteId != route.id {
      pauseRoute(oldMainRouteId, currentSteps: currentSteps)
    }

    mainRouteId = route.id

    // Create new progress or resume existing progress
    if allRouteProgress[route.id] == nil || allRouteProgress[route.id]?.isCompleted == true {
      // Brand new route or restarting a completed route
      allRouteProgress[route.id] = RouteProgress(
        routeId: route.id,
        startingSteps: currentSteps,
        startDate: Date(),
        isCompleted: false,
        completedSteps: nil,
        dailyContributions: [:]
      )
    } else if var progress = allRouteProgress[route.id] {
      // Resuming an existing route - just clear completedSteps and set new startingSteps
      // dailyContributions already contains all previous progress!
      progress.startingSteps = currentSteps
      progress.completedSteps = nil
      allRouteProgress[route.id] = progress
    }

    saveMainRoute()
    saveAllProgress()
  }

  func clearMainRoute(currentSteps: Int) {
    // Pause the current main route before clearing
    if let routeId = mainRouteId {
      pauseRoute(routeId, currentSteps: currentSteps)
    }
    mainRouteId = nil
    saveMainRoute()
  }

  func completeRoute(_ routeId: UUID) {
    if var progress = allRouteProgress[routeId] {
      progress.isCompleted = true
      // Store the final step count as sum of all daily contributions
      let totalStepsFromContributions = progress.dailyContributions.values.reduce(0, +)
      progress.completedSteps = totalStepsFromContributions
      allRouteProgress[routeId] = progress
      saveAllProgress()
    }
  }

  func pauseRoute(_ routeId: UUID, currentSteps: Int) {
    if var progress = allRouteProgress[routeId] {
      // Freeze the progress at the sum of all daily contributions
      let totalStepsFromContributions = progress.dailyContributions.values.reduce(0, +)
      progress.completedSteps = totalStepsFromContributions
      allRouteProgress[routeId] = progress
      saveAllProgress()
    }
  }

  func checkCompletion(for routeId: UUID, currentSteps: Int) -> Bool {
    guard let progress = allRouteProgress[routeId],
        !progress.isCompleted,
        let route = savedRoutes.first(where: { $0.id == routeId }) else { return false }

    // Calculate total steps from sum of all daily contributions
    let totalStepsFromContributions = progress.dailyContributions.values.reduce(0, +)
    return totalStepsFromContributions >= route.estimatedSteps
  }

  func getStepsProgress(for routeId: UUID, currentSteps: Int) -> (completed: Int, total: Int, isCompleted: Bool)? {
    guard let progress = allRouteProgress[routeId],
        let route = savedRoutes.first(where: { $0.id == routeId }) else { return nil }

    // Calculate total steps from sum of all daily contributions
    let totalStepsFromContributions = progress.dailyContributions.values.reduce(0, +)

    // For completed routes, use the frozen completedSteps
    let stepsSinceStart: Int
    if progress.isCompleted, let completedSteps = progress.completedSteps {
      stepsSinceStart = completedSteps
    } else {
      // Use sum of daily contributions (works for both active and paused routes)
      stepsSinceStart = totalStepsFromContributions
    }

    let completed = min(stepsSinceStart, route.estimatedSteps)
    return (completed, route.estimatedSteps, progress.isCompleted)
  }

  func resetRouteProgress(_ routeId: UUID) {
    allRouteProgress.removeValue(forKey: routeId)
    saveAllProgress()
  }

  func updateDailyContribution(for routeId: UUID, date: Date, steps: Int) {
    guard var progress = allRouteProgress[routeId] else { return }

    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd"
    let dateString = dateFormatter.string(from: date)

    progress.dailyContributions[dateString] = steps
    allRouteProgress[routeId] = progress
    saveAllProgress()
    saveMainRoute()
  }

  func getDailyContributions(for date: Date) -> [(route: SavedRoute, steps: Int)] {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd"
    let dateString = dateFormatter.string(from: date)

    var contributions: [(route: SavedRoute, steps: Int)] = []

    for (routeId, progress) in allRouteProgress {
      if let steps = progress.dailyContributions[dateString],
         steps > 0,
         let route = savedRoutes.first(where: { $0.id == routeId }) {
        contributions.append((route: route, steps: steps))
      }
    }

    return contributions.sorted { $0.steps > $1.steps }
  }
  
  func sumDailyContribution(since date: Date, routeId: UUID) -> Int {
    /// I will implement this at some point
    return 0
  }

  private func saveRoutes() {
    do {
      let data = try JSONEncoder().encode(savedRoutes)
      try data.write(to: savePath)
    } catch {
      // Failed to save routes
    }
  }

  private func loadRoutes() {
    do {
      let data = try Data(contentsOf: savePath)
      savedRoutes = try JSONDecoder().decode([SavedRoute].self, from: data)
    } catch {
      // No saved routes yet, start with empty array
      savedRoutes = []
    }
  }

  private func saveMainRoute() {
    do {
      if let id = mainRouteId, let progress = allRouteProgress[id] {
        // Save both the route ID and its current progress (including dailyContributions)
        let mainRouteData = MainRouteData(routeId: id, progress: progress)
        let data = try JSONEncoder().encode(mainRouteData)
        try data.write(to: mainRoutePath)
      } else {
        // Remove the file if no main route is set
        try? FileManager.default.removeItem(at: mainRoutePath)
      }
    } catch {
      // Failed to save main route
    }
  }

  private func loadMainRoute() {
    do {
      let data = try Data(contentsOf: mainRoutePath)

      // Try to load new format (MainRouteData with progress)
      if let mainRouteData = try? JSONDecoder().decode(MainRouteData.self, from: data) {
        mainRouteId = mainRouteData.routeId
        // IMPORTANT: Overwrite allRouteProgress with the saved data from mainRoute.json
        // This ensures dailyContributions are preserved even if app crashed before saveAllProgress()
        allRouteProgress[mainRouteData.routeId] = mainRouteData.progress
      } else {
        // Fall back to old format (just UUID) for backwards compatibility
        mainRouteId = try JSONDecoder().decode(UUID.self, from: data)
      }
    } catch {
      // No main route set
      mainRouteId = nil
    }
  }

  private func saveAllProgress() {
    do {
      let data = try JSONEncoder().encode(allRouteProgress)
      try data.write(to: allProgressPath)
    } catch {
      // Failed to save all progress
    }
  }

  private func loadAllProgress() {
    do {
      let data = try Data(contentsOf: allProgressPath)
      allRouteProgress = try JSONDecoder().decode([UUID: RouteProgress].self, from: data)
    } catch {
      allRouteProgress = [:]
    }
  }
}
