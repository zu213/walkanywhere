//
//  DebugTestView.swift
//  walkanywhere
//
//  Debug view for testing step tracking logic
//

import SwiftUI

#if DEBUG
struct DebugTestView: View {
  @Environment(\.dismiss) var dismiss
  var routeManager: RouteManager
  var healthKitManager: HealthKitManager

  var body: some View {
    NavigationView {
      List {
        if let mainRouteId = routeManager.mainRouteId {
          Section("Current Main Route Tests") {
            Button("📊 Print Current State") {
              DebugHelpers.printRouteState(
                routeManager: routeManager,
                routeId: mainRouteId,
                currentSteps: healthKitManager.stepCount
              )
            }

            Button("🕐 Simulate Yesterday with 3100 Steps") {
              DebugHelpers.simulateYesterdayIncompleteData(
                routeManager: routeManager,
                routeId: mainRouteId,
                partialSteps: 3100
              )
              print("Now restart the app to see backfill in action!")
            }

            Button("🔄 Reset startingStepsDate (force recalc)") {
              DebugHelpers.resetStartingStepsDate(
                routeManager: routeManager,
                routeId: mainRouteId
              )
            }

            Button("🧹 Clear Today's Contribution") {
              DebugHelpers.clearTodayContribution(
                routeManager: routeManager,
                routeId: mainRouteId
              )
            }
          }

          Section("Testing Scenario: Missing Steps Bug") {
            VStack(alignment: .leading, spacing: 8) {
              Text("Test the bug fix:")
                .font(.headline)
              Text("1. Tap 'Simulate Yesterday with 3100 Steps'")
                .font(.caption)
              Text("2. Close and reopen the app")
                .font(.caption)
              Text("3. Check if yesterday now shows 5800 total")
                .font(.caption)
              Text("   (assuming you actually did 5800 steps)")
                .font(.caption)
            }
            .padding(.vertical, 4)
          }

          Section("Testing Scenario: Same Day Reopening") {
            VStack(alignment: .leading, spacing: 8) {
              Text("Test the bug fix:")
                .font(.headline)
              Text("1. Note your current steps")
                .font(.caption)
              Text("2. Tap 'Clear Today's Contribution'")
                .font(.caption)
              Text("3. Close and reopen the app")
                .font(.caption)
              Text("4. All steps should still be counted")
                .font(.caption)
            }
            .padding(.vertical, 4)
          }
        } else {
          Text("No main route selected")
            .foregroundStyle(.secondary)
        }
      }
      .navigationTitle("Debug Tests")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button("Done") {
            dismiss()
          }
        }
      }
    }
  }
}
#endif
