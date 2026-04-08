//
//  RouteManagerTests.swift
//  walkanywhereTests
//
//  Tests for RouteManager step tracking logic
//

import XCTest
import MapKit
@testable import walkanywhere

final class RouteManagerTests: XCTestCase {

  var routeManager: RouteManager!
  var testRoute: SavedRoute!

  override func setUp() {
    super.setUp()
    routeManager = RouteManager()

    // Create a test route
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

  // MARK: - Bug Fix #1: startingSteps recalculation

  func testStartingStepsNotRecalculatedOnSameDay() {
    // Given: Set main route with 100 current steps
    routeManager.setMainRoute(testRoute, currentSteps: 100)

    guard let progress = routeManager.getProgress(for: testRoute.id) else {
      XCTFail("Progress should exist")
      return
    }

    let originalStartingSteps = progress.startingSteps
    XCTAssertEqual(originalStartingSteps, 100, "Initial startingSteps should be 100")

    // When: Call setMainRoute again on the same day with 500 current steps
    // (simulating app reopening or route being set again)
    routeManager.setMainRoute(testRoute, currentSteps: 500)

    // Then: startingSteps should NOT change (preventing loss of 400 steps)
    guard let updatedProgress = routeManager.getProgress(for: testRoute.id) else {
      XCTFail("Progress should exist")
      return
    }

    XCTAssertEqual(
      updatedProgress.startingSteps,
      originalStartingSteps,
      "startingSteps should NOT be recalculated on the same day"
    )

    // Verify the session steps calculation is correct
    let sessionSteps = 500 - updatedProgress.startingSteps
    XCTAssertEqual(sessionSteps, 400, "Session steps should be 400 (500 - 100)")
  }

  func testStartingStepsRecalculatedOnNewDay() {
    // Given: Set main route yesterday with 100 steps
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd"

    let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
    let yesterdayString = dateFormatter.string(from: yesterday)

    routeManager.setMainRoute(testRoute, currentSteps: 100)

    // Manually set the startingStepsDate to yesterday
    if var progress = routeManager.allRouteProgress[testRoute.id] {
      progress.startingStepsDate = yesterdayString
      progress.dailyContributions[yesterdayString] = 500  // Did 500 steps yesterday
      routeManager.allRouteProgress[testRoute.id] = progress
    }

    // When: Set main route today with 200 current steps (today)
    routeManager.setMainRoute(testRoute, currentSteps: 200)

    // Then: startingSteps should be recalculated for the new day
    guard let updatedProgress = routeManager.getProgress(for: testRoute.id) else {
      XCTFail("Progress should exist")
      return
    }

    let todayString = dateFormatter.string(from: Date())
    XCTAssertEqual(
      updatedProgress.startingStepsDate,
      todayString,
      "startingStepsDate should be updated to today"
    )

    // Since we have 0 steps for today, startingSteps should equal currentSteps
    let todayContribution = updatedProgress.dailyContributions[todayString] ?? 0
    XCTAssertEqual(
      updatedProgress.startingSteps,
      200 - todayContribution,
      "startingSteps should be recalculated for new day"
    )
  }

  // MARK: - Daily Contributions

  func testDailyContributionPreservesExistingStepsOnResume() {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd"
    let todayString = dateFormatter.string(from: Date())

    // Given: Set main route with 100 steps and do some walking
    routeManager.setMainRoute(testRoute, currentSteps: 100)
    routeManager.updateDailyContribution(for: testRoute.id, date: Date(), steps: 400)

    // Verify we have 400 steps recorded
    var progress = routeManager.getProgress(for: testRoute.id)!
    XCTAssertEqual(progress.dailyContributions[todayString], 400)

    // When: Resume the route later in the day with 600 total steps
    routeManager.setMainRoute(testRoute, currentSteps: 600)

    // Then: The startingSteps should account for the 400 we already walked
    progress = routeManager.getProgress(for: testRoute.id)!
    XCTAssertEqual(
      progress.startingSteps,
      200,
      "startingSteps should be 200 (600 current - 400 already walked)"
    )

    // And session steps should correctly reflect new steps only
    let sessionSteps = 600 - progress.startingSteps
    XCTAssertEqual(sessionSteps, 400, "Session steps should match existing contribution")
  }

  func testMultipleDayContributions() {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd"

    let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
    let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: Date())!

    let yesterdayString = dateFormatter.string(from: yesterday)
    let twoDaysAgoString = dateFormatter.string(from: twoDaysAgo)
    let todayString = dateFormatter.string(from: Date())

    // Given: A route with contributions over multiple days
    routeManager.setMainRoute(testRoute, currentSteps: 100)

    routeManager.updateDailyContribution(for: testRoute.id, date: twoDaysAgo, steps: 3000)
    routeManager.updateDailyContribution(for: testRoute.id, date: yesterday, steps: 2500)
    routeManager.updateDailyContribution(for: testRoute.id, date: Date(), steps: 1000)

    // When: Get progress
    let progressResult = routeManager.getStepsProgress(
      for: testRoute.id,
      currentSteps: 100
    )

    // Then: Total should be sum of all daily contributions
    XCTAssertNotNil(progressResult)
    XCTAssertEqual(
      progressResult?.completed,
      6500,
      "Total progress should be sum of all daily contributions (3000 + 2500 + 1000)"
    )

    // Verify individual contributions are preserved
    let progress = routeManager.getProgress(for: testRoute.id)!
    XCTAssertEqual(progress.dailyContributions[twoDaysAgoString], 3000)
    XCTAssertEqual(progress.dailyContributions[yesterdayString], 2500)
    XCTAssertEqual(progress.dailyContributions[todayString], 1000)
  }

  // MARK: - Route Switching

  func testSwitchingRoutesDoesNotTransferSteps() {
    let startCoord2 = CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)
    let endCoord2 = CLLocationCoordinate2D(latitude: 40.7580, longitude: -73.9855)
    var coordinates2 = [startCoord2, endCoord2]
    let polyline2 = MKPolyline(coordinates: &coordinates2, count: coordinates2.count)

    let route2 = SavedRoute(
      id: UUID(),
      name: "Second Route",
      startCoordinate: startCoord2,
      endCoordinate: endCoord2,
      distance: 8000.0,  // 8km
      estimatedTime: 5760.0,  // 1.6 hours
      polyline: polyline2
    )
    routeManager.addRoute(route2)

    // Given: First route with 500 steps
    routeManager.setMainRoute(testRoute, currentSteps: 500)
    routeManager.updateDailyContribution(for: testRoute.id, date: Date(), steps: 500)

    let route1Progress = routeManager.getStepsProgress(for: testRoute.id, currentSteps: 500)
    XCTAssertEqual(route1Progress?.completed, 500)

    // When: Switch to second route (still 500 total steps in HealthKit)
    routeManager.setMainRoute(route2, currentSteps: 500)

    // Then: First route should keep its 500 steps (frozen)
    let route1FinalProgress = routeManager.getStepsProgress(for: testRoute.id, currentSteps: 500)
    XCTAssertEqual(
      route1FinalProgress?.completed,
      500,
      "First route should retain its 500 steps"
    )

    // And: Second route should start with 0 steps
    let route2Progress = routeManager.getStepsProgress(for: route2.id, currentSteps: 500)
    XCTAssertEqual(
      route2Progress?.completed,
      0,
      "Second route should start with 0 steps (all 500 steps belong to first route)"
    )

    // Verify second route's startingSteps accounts for the 500 steps from route1
    let route2ProgressData = routeManager.getProgress(for: route2.id)!
    XCTAssertEqual(
      route2ProgressData.startingSteps,
      500,
      "Second route startingSteps should be 500 to offset existing steps"
    )
  }

  // MARK: - Edge Cases

  func testResettingRouteProgress() {
    // Given: Route with progress
    routeManager.setMainRoute(testRoute, currentSteps: 100)
    routeManager.updateDailyContribution(for: testRoute.id, date: Date(), steps: 1000)

    XCTAssertNotNil(routeManager.getProgress(for: testRoute.id))

    // When: Reset progress
    routeManager.resetRouteProgress(testRoute.id)

    // Then: Progress should be cleared
    XCTAssertNil(routeManager.getProgress(for: testRoute.id))
  }

  func testCompletedRouteTracking() {
    // Given: Route near completion
    routeManager.setMainRoute(testRoute, currentSteps: 100)
    routeManager.updateDailyContribution(
      for: testRoute.id,
      date: Date(),
      steps: testRoute.estimatedSteps
    )

    // When: Check completion
    let isCompleted = routeManager.checkCompletion(
      for: testRoute.id,
      currentSteps: testRoute.estimatedSteps + 100
    )

    // Then: Should be marked as complete
    XCTAssertTrue(isCompleted, "Route should be completed")

    // And: Completed steps should be frozen
    routeManager.completeRoute(testRoute.id)
    let progress = routeManager.getProgress(for: testRoute.id)!
    XCTAssertTrue(progress.isCompleted)
    XCTAssertEqual(progress.completedSteps, testRoute.estimatedSteps)
  }

  // MARK: - Persistence Tests

  func testProgressPersistence() {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd"
    let todayString = dateFormatter.string(from: Date())

    // Given: Route with progress
    routeManager.setMainRoute(testRoute, currentSteps: 100)
    routeManager.updateDailyContribution(for: testRoute.id, date: Date(), steps: 500)

    let originalProgress = routeManager.getProgress(for: testRoute.id)!

    // When: Create new RouteManager instance (simulating app restart)
    let newRouteManager = RouteManager()

    // Then: Progress should be loaded from disk
    let loadedProgress = newRouteManager.getProgress(for: testRoute.id)

    XCTAssertNotNil(loadedProgress, "Progress should persist across app restarts")
    XCTAssertEqual(
      loadedProgress?.dailyContributions[todayString],
      originalProgress.dailyContributions[todayString],
      "Daily contributions should persist"
    )
    XCTAssertEqual(
      loadedProgress?.startingSteps,
      originalProgress.startingSteps,
      "Starting steps should persist"
    )
  }
}
