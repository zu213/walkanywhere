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
    loadMainRoute()
    loadAllProgress()
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

    // Only create new progress if this route doesn't have progress yet or was completed
    if allRouteProgress[route.id] == nil || allRouteProgress[route.id]?.isCompleted == true {
      allRouteProgress[route.id] = RouteProgress(
        routeId: route.id,
        startingSteps: currentSteps,
        startDate: Date(),
        isCompleted: false,
        completedSteps: nil
      )
    } else if var progress = allRouteProgress[route.id], let frozenSteps = progress.completedSteps {
      // If resuming a paused route, adjust the starting point
      // New starting point = current steps - frozen progress
      progress.startingSteps = currentSteps - frozenSteps
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
      allRouteProgress[routeId] = progress
      saveAllProgress()
    }
  }

  func pauseRoute(_ routeId: UUID, currentSteps: Int) {
    if var progress = allRouteProgress[routeId] {
      // Freeze the progress at the current step count
      let stepsSinceStart = max(0, currentSteps - progress.startingSteps)
      progress.completedSteps = stepsSinceStart
      allRouteProgress[routeId] = progress
      saveAllProgress()
    }
  }

  func checkCompletion(for routeId: UUID, currentSteps: Int) -> Bool {
    guard let progress = allRouteProgress[routeId],
        !progress.isCompleted,
        let route = savedRoutes.first(where: { $0.id == routeId }) else { return false }

    let stepsSinceStart = currentSteps - progress.startingSteps
    return stepsSinceStart >= route.estimatedSteps
  }

  func getStepsProgress(for routeId: UUID, currentSteps: Int) -> (completed: Int, total: Int, isCompleted: Bool)? {
    guard let progress = allRouteProgress[routeId],
        let route = savedRoutes.first(where: { $0.id == routeId }) else { return nil }

    // Only update live steps for the currently active main route
    // All other routes use their frozen progress
    let stepsSinceStart: Int
    if routeId == mainRouteId && progress.completedSteps == nil {
      // This is the active main route - calculate live progress
      stepsSinceStart = max(0, currentSteps - progress.startingSteps)
    } else if let completedSteps = progress.completedSteps {
      // This route is paused/inactive - use frozen progress
      stepsSinceStart = completedSteps
    } else {
      // Route has progress but is not active - freeze it at 0
      stepsSinceStart = 0
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

  private func saveRoutes() {
    do {
      let data = try JSONEncoder().encode(savedRoutes)
      try data.write(to: savePath)
    } catch {
      print("Failed to save routes: \(error)")
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
      if let id = mainRouteId {
        let data = try JSONEncoder().encode(id)
        try data.write(to: mainRoutePath)
      } else {
        // Remove the file if no main route is set
        try? FileManager.default.removeItem(at: mainRoutePath)
      }
    } catch {
      print("Failed to save main route: \(error)")
    }
  }

  private func loadMainRoute() {
    do {
      let data = try Data(contentsOf: mainRoutePath)
      mainRouteId = try JSONDecoder().decode(UUID.self, from: data)
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
      print("Failed to save all progress: \(error)")
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
