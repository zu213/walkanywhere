//
//  DebugMenuSheet.swift
//  walkanywhere
//
//  Created by Zachary Upstone on 23/03/2026.
//

import SwiftUI

struct DebugMenuSheet: View {
  @Binding var isPresented: Bool
  let routeManager: RouteManager
  let stepMonitor: StepMonitor
  @State private var testHelper = HealthKitTestHelper()

  var body: some View {
    NavigationStack {
      List {
        Section("Simulate Walking") {
          Button("Add 100 Steps") {
            Task {
              try? await testHelper.addSteps(count: 100)
              await stepMonitor.fetchTodaySteps()
            }
          }

          Button("Add 500 Steps") {
            Task {
              try? await testHelper.addSteps(count: 500)
              await stepMonitor.fetchTodaySteps()
            }
          }

          Button("Add 1,000 Steps") {
            Task {
              try? await testHelper.addSteps(count: 1000)
              await stepMonitor.fetchTodaySteps()
            }
          }

          Button("Simulate Walking (100 steps/sec for 10 sec)") {
            Task {
              isPresented = false
              try? await testHelper.addStepsGradually(totalSteps: 1000, intervalSeconds: 0.1)
              await stepMonitor.fetchTodaySteps()
            }
          }
        }

        Section("Current Status") {
          if let mainRoute = routeManager.mainRoute,
             let progress = routeManager.getStepsProgress(for: mainRoute.id, currentSteps: stepMonitor.todaySteps) {
            if progress.isCompleted {
              Text("Status: ✓ Completed!")
                .foregroundStyle(.green)
            } else {
              Text("Completed: \(progress.completed) steps")
              Text("Goal: \(progress.total) steps")
              Text("Remaining: \(progress.total - progress.completed) steps")
            }
          }
        }

        Section("Route Management") {
          if let mainRoute = routeManager.mainRoute {
            Button("Reset Progress", role: .destructive) {
              routeManager.resetRouteProgress(mainRoute.id)
              isPresented = false
            }
          }
        }
      }
      .navigationTitle("Debug Menu")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Done") {
            isPresented = false
          }
        }
      }
    }
    .presentationDetents([.medium])
  }
}

#Preview {
  DebugMenuSheet(
    isPresented: .constant(true),
    routeManager: RouteManager(),
    stepMonitor: StepMonitor(routeManager: RouteManager(), healthKitManager: HealthKitManager())
  )
}
