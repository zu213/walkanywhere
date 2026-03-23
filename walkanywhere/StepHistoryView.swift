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
    NavigationStack {
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
              Button("Enable Health Access") {
                Task {
                  await healthKitManager.requestAuthorization()
                }
              }
              .buttonStyle(.borderedProminent)
            }
          }
          .padding(.vertical, 8)
        }

        if healthKitManager.isAuthorized && !healthKitManager.stepHistory.isEmpty {
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
      .navigationTitle("Step History")
      .navigationBarTitleDisplayMode(.inline)
      .task {
        if healthKitManager.isAuthorized {
          await healthKitManager.fetchTodaySteps()
          await healthKitManager.fetchStepHistory(days: 30)
        }
      }
      .refreshable {
        await healthKitManager.fetchTodaySteps()
        await healthKitManager.fetchStepHistory(days: 30)
      }
    }
  }
}

#Preview {
  StepHistoryView()
}
