//
//  ContentView.swift
//  walkanywhere
//
//  Created by Zachary Upstone on 10/03/2026.
//

import SwiftUI

struct ContentView: View {
  @State private var routeManager = RouteManager()
  @State private var healthKitManager = HealthKitManager()
  @State private var stepMonitor: StepMonitor

  init() {
    let manager = RouteManager()
    let health = HealthKitManager()
    _routeManager = State(initialValue: manager)
    _healthKitManager = State(initialValue: health)
    _stepMonitor = State(initialValue: StepMonitor(routeManager: manager, healthKitManager: health))
  }

  var body: some View {
    TabView {
      MainRouteView(routeManager: routeManager, stepMonitor: stepMonitor)
        .tabItem {
          Label("Main Route", systemImage: "star.fill")
        }

      SavedRoutesView(routeManager: routeManager, healthKitManager: healthKitManager)
        .tabItem {
          Label("Routes", systemImage: "list.bullet")
        }

      StepHistoryView()
        .tabItem {
          Label("Steps", systemImage: "figure.walk")
        }
    }
    .task {
      await stepMonitor.startMonitoring()
    }
  }
}

#Preview {
  ContentView()
}
