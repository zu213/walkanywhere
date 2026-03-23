//
//  SavedRoutesView.swift
//  walkanywhere
//
//  Created by Zachary Upstone on 10/03/2026.
//

import SwiftUI

struct SavedRoutesView: View {
  var routeManager: RouteManager
  var healthKitManager: HealthKitManager
  @State private var showingMapSheet = false

  var body: some View {
    ZStack(alignment: .top) {
      List {
        if routeManager.savedRoutes.isEmpty {
          ContentUnavailableView(
            "No Saved Routes",
            systemImage: "map",
            description: Text("Tap the + button to create your first route.")
          )
        } else {
          ForEach(routeManager.savedRoutes) { route in
            HStack(spacing: 12) {
              Button {
                if routeManager.mainRouteId == route.id {
                  // Unfavorite - pause and clear main route
                  Task {
                    await healthKitManager.fetchTodaySteps()
                    routeManager.clearMainRoute(currentSteps: healthKitManager.stepCount)
                  }
                } else {
                  Task {
                    await healthKitManager.fetchTodaySteps()
                    routeManager.setMainRoute(route, currentSteps: healthKitManager.stepCount)
                  }
                }
              } label: {
                Image(systemName: routeManager.mainRouteId == route.id ? "star.fill" : "star")
                  .foregroundStyle(routeManager.mainRouteId == route.id ? .yellow : .gray)
                  .font(.title3)
              }
              .buttonStyle(.plain)

              NavigationLink(destination: RouteDetailView(route: route, routeManager: routeManager)) {
                VStack(alignment: .leading, spacing: 8) {
                  HStack {
                    Text(route.name)
                      .font(.headline)
                    Spacer()
                    if let progress = routeManager.getProgress(for: route.id) {
                      if progress.isCompleted {
                        Image(systemName: "checkmark.circle.fill")
                          .foregroundStyle(.green)
                      } else if let progressData = routeManager.getStepsProgress(for: route.id, currentSteps: healthKitManager.stepCount) {
                        Text("\(Int(Double(progressData.completed) / Double(progressData.total) * 100))%")
                          .font(.caption)
                          .foregroundStyle(.blue)
                          .padding(.horizontal, 6)
                          .padding(.vertical, 2)
                          .background(.blue.opacity(0.1))
                          .clipShape(RoundedRectangle(cornerRadius: 4))
                      }
                    }
                  }

                  HStack(spacing: 16) {
                    HStack(spacing: 4) {
                      Image(systemName: "figure.walk")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                      Text(route.formattedDistance)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 4) {
                      Image(systemName: "clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                      Text(route.formattedTime)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 4) {
                      Image(systemName: "shoeprints.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                      Text("\(route.formattedSteps) steps")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                  }

                  // Progress bar for routes with progress
                  if let progress = routeManager.getProgress(for: route.id), !progress.isCompleted,
                     let progressData = routeManager.getStepsProgress(for: route.id, currentSteps: healthKitManager.stepCount) {
                    GeometryReader { geometry in
                      ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                          .fill(.gray.opacity(0.2))
                          .frame(height: 4)

                        RoundedRectangle(cornerRadius: 4)
                          .fill(.blue)
                          .frame(width: min(CGFloat(progressData.completed) / CGFloat(progressData.total) * geometry.size.width, geometry.size.width), height: 4)
                      }
                    }
                    .frame(height: 4)
                  }
                }
              }
            }
            .padding(.vertical, 4)
          }
          .onDelete(perform: deleteRoutes)
        }
      }
      .listStyle(.plain)
      .contentMargins(.top, 100)
      .sheet(isPresented: $showingMapSheet) {
        MapDistanceView(routeManager: routeManager, onRouteSaved: {
          showingMapSheet = false
        })
      }

      // Glassy navigation title at the top
      HStack {
        GlassyNavigationTitle(title: "My Routes")
        Spacer()
        GlassyButton(systemImage: "plus", action: {
          showingMapSheet = true
        })
        .padding(.trailing, 20)
      }
      .padding(.top, 60)
      .padding(.leading, 20)
    }
    .ignoresSafeArea(edges: .top)
  }

  private func deleteRoutes(at offsets: IndexSet) {
    for index in offsets {
      let route = routeManager.savedRoutes[index]
      routeManager.deleteRoute(route)
    }
  }
}

#Preview {
  SavedRoutesView(routeManager: RouteManager(), healthKitManager: HealthKitManager())
}
