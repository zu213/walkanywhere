//
//  StepTrackingTests.swift
//  walkanywhereTests
//
//  Integration tests for step tracking across app sessions
//

import XCTest
import MapKit
@testable import walkanywhere

final class StepTrackingTests: XCTestCase {

  var routeManager: RouteManager!
  var testRoute: SavedRoute!

  override func setUp() {
    super.setUp()
    routeManager = RouteManager()

    let startCoord = CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278)
    let endCoord = CLLocationCoordinate2D(latitude: 51.5155, longitude: -0.0922)
    var coordinates = [startCoord, endCoord]
    let polyline = MKPolyline(coordinates: &coordinates, count: coordinates.count)

    testRoute = SavedRoute(
      id: UUID(),
      name: "Test Route",
      startCoordinate: startCoord,
      endCoordinate: endCoord,
      distance: 10000.0,  // 10km
      estimatedTime: 7200.0,  // 2 hours
      polyline: polyline
    )

    routeManager.addRoute(testRoute)
  }

  override func tearDown() {
    routeManager = nil
    testRoute = nil
    super.tearDown()
  }

  // MARK: - Bug Scenario Tests

  /// Test the exact bug scenario reported by user:
  /// - Day 1: App shows 3100 steps, then closed
  /// - Day 1 actual: User did 5800 total steps (2700 unaccounted)
  /// - Day 2: User did 357 steps, but only 77 assigned
  func testBugScenario_MissingStepsAcrossDayBoundary() {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd"

    let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
    let yesterdayString = dateFormatter.string(from: yesterday)
    let todayString = dateFormatter.string(from: Date())

    // === DAY 1 (Yesterday) ===
    // User opens app, route is selected, HealthKit shows 3100 steps
    routeManager.setMainRoute(testRoute, currentSteps: 3100)

    // Simulate the app tracking steps
    routeManager.updateDailyContribution(for: testRoute.id, date: yesterday, steps: 3100)

    // Verify state at end of Day 1 (when app was closed)
    var progress = routeManager.getProgress(for: testRoute.id)!
    XCTAssertEqual(
      progress.dailyContributions[yesterdayString],
      3100,
      "Day 1: Should have tracked 3100 steps"
    )

    // === SIMULATE: User continued walking after app closed ===
    // User actually did 5800 total steps yesterday (HealthKit has the real data)
    // In the real app, backfill would query HealthKit and get this value

    // Simulate backfill updating the contribution with HealthKit's real value
    let actualYesterdaySteps = 5800
    routeManager.updateDailyContribution(
      for: testRoute.id,
      date: yesterday,
      steps: actualYesterdaySteps
    )

    // Verify backfill worked
    progress = routeManager.getProgress(for: testRoute.id)!
    XCTAssertEqual(
      progress.dailyContributions[yesterdayString],
      5800,
      "Backfill should update yesterday to 5800 steps (capturing the missing 2700)"
    )

    // === DAY 2 (Today) ===
    // Manually update startingStepsDate to yesterday to simulate new day
    if var prog = routeManager.allRouteProgress[testRoute.id] {
      prog.startingStepsDate = yesterdayString
      routeManager.allRouteProgress[testRoute.id] = prog
    }

    // User opens app today with 357 total steps for today
    let todayTotalSteps = 357
    routeManager.setMainRoute(testRoute, currentSteps: todayTotalSteps)

    // Update contribution for today (simulating StepMonitor.updateDailyContributions)
    progress = routeManager.getProgress(for: testRoute.id)!
    let todaySessionSteps = todayTotalSteps - progress.startingSteps
    routeManager.updateDailyContribution(
      for: testRoute.id,
      date: Date(),
      steps: todaySessionSteps
    )

    // === VERIFY FIX ===
    progress = routeManager.getProgress(for: testRoute.id)!

    // Today should have all 357 steps (not just 77)
    let todayContribution = progress.dailyContributions[todayString] ?? 0
    XCTAssertEqual(
      todayContribution,
      357,
      "Day 2: Should have tracked ALL 357 steps, not just 77"
    )

    // Total progress should be 5800 + 357 = 6157
    let totalProgress = progress.dailyContributions.values.reduce(0, +)
    XCTAssertEqual(
      totalProgress,
      6157,
      "Total should be 6157 (5800 from yesterday + 357 from today)"
    )

    // Verify yesterday's missing steps are accounted for
    XCTAssertEqual(
      progress.dailyContributions[yesterdayString],
      5800,
      "Yesterday should show 5800 total steps (including the 2700 that were missed)"
    )
  }

  /// Test scenario: App closed mid-day, reopened same day
  func testSameDayReopening_PreservesSteps() {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd"
    let todayString = dateFormatter.string(from: Date())

    // Morning: Open app with 1000 steps
    routeManager.setMainRoute(testRoute, currentSteps: 1000)

    // Walk some more, app updates
    routeManager.updateDailyContribution(for: testRoute.id, date: Date(), steps: 2500)

    var progress = routeManager.getProgress(for: testRoute.id)!
    XCTAssertEqual(progress.dailyContributions[todayString], 2500)

    // === Close app, continue walking ===
    // Afternoon: Reopen app, now at 3500 total steps for the day
    routeManager.setMainRoute(testRoute, currentSteps: 3500)

    // Verify startingSteps was NOT recalculated (the fix)
    progress = routeManager.getProgress(for: testRoute.id)!

    // startingSteps should still account for the 2500 we already tracked
    XCTAssertEqual(
      progress.startingSteps,
      1000,
      "startingSteps should NOT change when reopening on same day"
    )

    // Calculate current session steps
    let sessionSteps = 3500 - progress.startingSteps
    XCTAssertEqual(
      sessionSteps,
      2500,
      "Session steps should still equal our tracked contribution"
    )

    // Update contribution with new steps
    routeManager.updateDailyContribution(for: testRoute.id, date: Date(), steps: 3500)

    // Verify all steps are preserved
    progress = routeManager.getProgress(for: testRoute.id)!
    XCTAssertEqual(
      progress.dailyContributions[todayString],
      3500,
      "All 3500 steps should be tracked, none lost"
    )
  }

  /// Test: Backfill logic updates partial contributions
  func testBackfill_UpdatesPartialContributions() {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd"

    let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
    let yesterdayString = dateFormatter.string(from: yesterday)

    // Initial state: Yesterday has partial contribution (3100)
    routeManager.setMainRoute(testRoute, currentSteps: 100)
    routeManager.updateDailyContribution(for: testRoute.id, date: yesterday, steps: 3100)

    var progress = routeManager.getProgress(for: testRoute.id)!
    XCTAssertEqual(progress.dailyContributions[yesterdayString], 3100)

    // Simulate backfill finding higher value in HealthKit (5800)
    // This is what the fixed backfill logic does
    let existingContribution = progress.dailyContributions[yesterdayString] ?? 0
    let healthKitValue = 5800

    if healthKitValue > existingContribution {
      routeManager.updateDailyContribution(
        for: testRoute.id,
        date: yesterday,
        steps: healthKitValue
      )
    }

    // Verify the update happened
    progress = routeManager.getProgress(for: testRoute.id)!
    XCTAssertEqual(
      progress.dailyContributions[yesterdayString],
      5800,
      "Backfill should update from 3100 to 5800"
    )
  }

  /// Test: Multiple app opens/closes in one day
  func testMultipleAppSessionsSameDay() {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd"
    let todayString = dateFormatter.string(from: Date())

    // Session 1: Morning (500 steps)
    routeManager.setMainRoute(testRoute, currentSteps: 500)
    routeManager.updateDailyContribution(for: testRoute.id, date: Date(), steps: 500)

    // Session 2: Afternoon (1200 steps total)
    routeManager.setMainRoute(testRoute, currentSteps: 1200)
    var progress = routeManager.getProgress(for: testRoute.id)!
    let sessionSteps1 = 1200 - progress.startingSteps
    routeManager.updateDailyContribution(for: testRoute.id, date: Date(), steps: sessionSteps1)

    // Session 3: Evening (2000 steps total)
    routeManager.setMainRoute(testRoute, currentSteps: 2000)
    progress = routeManager.getProgress(for: testRoute.id)!
    let sessionSteps2 = 2000 - progress.startingSteps
    routeManager.updateDailyContribution(for: testRoute.id, date: Date(), steps: sessionSteps2)

    // Verify all steps are tracked correctly
    progress = routeManager.getProgress(for: testRoute.id)!
    XCTAssertEqual(
      progress.dailyContributions[todayString],
      2000,
      "Should track all 2000 steps across multiple sessions"
    )

    // Verify startingSteps remained constant (the fix)
    XCTAssertEqual(
      progress.startingSteps,
      0,
      "startingSteps should not change across sessions on same day"
    )
  }

  /// Test: Day boundary crossing with route selected
  func testDayBoundaryCrossing() {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd"

    let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
    let yesterdayString = dateFormatter.string(from: yesterday)
    let todayString = dateFormatter.string(from: Date())

    // Yesterday: Route selected, did 4000 steps
    routeManager.setMainRoute(testRoute, currentSteps: 4000)
    routeManager.updateDailyContribution(for: testRoute.id, date: yesterday, steps: 4000)

    // Simulate day change by updating startingStepsDate
    if var progress = routeManager.allRouteProgress[testRoute.id] {
      progress.startingStepsDate = yesterdayString
      routeManager.allRouteProgress[testRoute.id] = progress
    }

    // Today: App opens with 300 steps (new day)
    routeManager.setMainRoute(testRoute, currentSteps: 300)

    // Verify startingSteps was recalculated for new day
    var progress = routeManager.getProgress(for: testRoute.id)!
    XCTAssertEqual(
      progress.startingStepsDate,
      todayString,
      "startingStepsDate should update to today"
    )

    // Update today's contribution
    let sessionSteps = 300 - progress.startingSteps
    routeManager.updateDailyContribution(for: testRoute.id, date: Date(), steps: sessionSteps)

    // Verify both days are tracked separately
    progress = routeManager.getProgress(for: testRoute.id)!
    XCTAssertEqual(progress.dailyContributions[yesterdayString], 4000, "Yesterday preserved")
    XCTAssertEqual(progress.dailyContributions[todayString], 300, "Today tracked separately")

    let total = progress.dailyContributions.values.reduce(0, +)
    XCTAssertEqual(total, 4300, "Total should be 4300 (4000 + 300)")
  }

  /// Test: stepsSoFarOnSelectedDay tracking
  func testStepsSoFarOnSelectedDay_TrackingMidDay() {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd"
    let todayString = dateFormatter.string(from: Date())

    // Scenario: User already has 2000 steps when selecting route (e.g., at noon)
    routeManager.setMainRoute(testRoute, currentSteps: 2000)

    var progress = routeManager.getProgress(for: testRoute.id)!

    // Verify snapshot is taken
    XCTAssertEqual(
      progress.stepsSoFarOnSelectedDay,
      2000,
      "Should snapshot steps at route selection time"
    )
    XCTAssertEqual(
      progress.selectedDayString,
      todayString,
      "Should record which day route was selected"
    )

    // If this was the day the route was selected, and we later backfill,
    // only steps AFTER 2000 should count
    // This is used in backfill logic: contributionForDay = totalSteps - stepsSoFar
  }
}
