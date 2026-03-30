//
//  StepHistoryView.swift
//  walkanywhere
//
//  Created by Zachary Upstone on 10/03/2026.
//

import SwiftUI

struct StepHistoryView: View {
  @State private var healthKitManager = HealthKitManager()

  var body: some View {
    ZStack(alignment: .top) {
      List {
        Section {
          VStack(alignment: .leading, spacing: 8) {
            Text("Today's Steps")
              .font(.headline)

            if healthKitManager.isAuthorized {
              HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(healthKitManager.stepCount)")
                  .font(.system(size: 48, weight: .bold, design: .rounded))
                Text("steps")
                  .font(.title3)
                  .foregroundStyle(.secondary)
              }
            } else if let error = healthKitManager.authorizationError {
              Text(error)
                .foregroundStyle(.red)
                .font(.caption)
            } else {
              VStack(spacing: 8) {
                Button("Enable Health Access") {
                  Task {
                    await healthKitManager.requestAuthorization()
                  }
                }
                .buttonStyle(.borderedProminent)

                #if DEBUG
                Button("DEBUG: Force Enable (Simulator)") {
                  healthKitManager.isAuthorized = true
                  Task {
                    await healthKitManager.fetchTodaySteps()
                    await healthKitManager.fetchStepHistory(days: 30)
                  }
                }
                .buttonStyle(.bordered)
                .tint(.orange)

                Text("Debug: isAuthorized = \(healthKitManager.isAuthorized ? "true" : "false")")
                  .font(.caption2)
                  .foregroundStyle(.secondary)
                #endif
              }
            }
          }
          .padding(.vertical, 8)
        }

        if healthKitManager.isAuthorized {
          if healthKitManager.stepHistory.isEmpty {
            Section("Step History") {
              Text("No step history available")
                .foregroundStyle(.secondary)
                .font(.caption)
            }
          } else {
            Section("Step History") {
              ForEach(healthKitManager.stepHistory) { stepData in
              HStack {
                VStack(alignment: .leading, spacing: 4) {
                  Text(stepData.formattedDate)
                    .font(.body)
                  Text(stepData.dayOfWeek)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(stepData.stepCount)")
                  .font(.system(size: 20, weight: .semibold, design: .rounded))
                  .foregroundStyle(.blue)
              }
              .padding(.vertical, 4)
            }
          }
          }
        }
      }
      .listStyle(.plain)
      .contentMargins(.top, 100)
      .task {
        await healthKitManager.checkAuthorizationStatus()
      }
      .refreshable {
        await healthKitManager.fetchTodaySteps()
        await healthKitManager.fetchStepHistory(days: 30)
      }

      // Glassy navigation title at the top
      GlassyNavigationTitle(title: "Step History")
        .padding(.top, 60)
        .padding(.leading, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .ignoresSafeArea(edges: .top)
  }
}

#Preview {
  StepHistoryView()
}
