//
//  StepHistoryView.swift
//  walkanywhere
//
//  Created by Zachary Upstone on 10/03/2026.
//

import SwiftUI

struct StepHistoryView: View {
  var routeManager: RouteManager
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
                VStack(alignment: .leading, spacing: 8) {
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

                  // Route contribution pills
                  let contributions = routeManager.getDailyContributions(for: stepData.date)
                  if !contributions.isEmpty {
                    FlowLayout(spacing: 6) {
                      ForEach(Array(contributions.enumerated()), id: \.offset) { index, contribution in
                        HStack(spacing: 4) {
                          Circle()
                            .fill(colorForRoute(index: index))
                            .frame(width: 8, height: 8)
                          Text(contribution.route.name)
                            .font(.caption2)
                            .lineLimit(1)
                          Text("\(contribution.steps)")
                            .font(.caption2)
                            .fontWeight(.semibold)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(colorForRoute(index: index).opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                      }
                    }
                  }
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

  private func colorForRoute(index: Int) -> Color {
    let colors: [Color] = [.blue, .green, .purple, .orange, .pink, .indigo, .teal, .cyan]
    return colors[index % colors.count]
  }
}

// FlowLayout for wrapping pills
struct FlowLayout: Layout {
  var spacing: CGFloat = 8

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    let result = FlowResult(
      in: proposal.replacingUnspecifiedDimensions().width,
      subviews: subviews,
      spacing: spacing
    )
    return result.size
  }

  func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
    let result = FlowResult(
      in: bounds.width,
      subviews: subviews,
      spacing: spacing
    )
    for (index, subview) in subviews.enumerated() {
      subview.place(at: CGPoint(x: bounds.minX + result.frames[index].minX, y: bounds.minY + result.frames[index].minY), proposal: .unspecified)
    }
  }

  struct FlowResult {
    var size: CGSize = .zero
    var frames: [CGRect] = []

    init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
      var currentX: CGFloat = 0
      var currentY: CGFloat = 0
      var lineHeight: CGFloat = 0

      for subview in subviews {
        let size = subview.sizeThatFits(.unspecified)

        if currentX + size.width > maxWidth && currentX > 0 {
          // New line
          currentX = 0
          currentY += lineHeight + spacing
          lineHeight = 0
        }

        frames.append(CGRect(x: currentX, y: currentY, width: size.width, height: size.height))
        lineHeight = max(lineHeight, size.height)
        currentX += size.width + spacing
      }

      self.size = CGSize(width: maxWidth, height: currentY + lineHeight)
    }
  }
}

#Preview {
  StepHistoryView(routeManager: RouteManager())
}
