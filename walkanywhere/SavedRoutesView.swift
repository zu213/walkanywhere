//
//  SavedRoutesView.swift
//  walkanywhere
//
//  Created by Zachary Upstone on 10/03/2026.
//

import SwiftUI
import MapKit

struct SavedRoutesView: View {
  var routeManager: RouteManager
  var healthKitManager: HealthKitManager
  @State private var showingMapSheet = false
  @State private var selectedRoute: SavedRoute?

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

              Button(action: {
                selectedRoute = route
              }) {
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
              .buttonStyle(.plain)
              .foregroundStyle(.primary)
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
        .presentationDragIndicator(.visible)
      }
      .sheet(item: $selectedRoute) { route in
        RouteViewSheet(route: route, routeManager: routeManager)
          .presentationDragIndicator(.visible)
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

struct RouteViewSheet: View {
  let route: SavedRoute
  let routeManager: RouteManager
  @State private var position: MapCameraPosition = .automatic

  var body: some View {
    ZStack(alignment: .top) {
      ZStack(alignment: .bottom) {
        Map(position: $position, interactionModes: [.pan, .zoom]) {
          Annotation("Start", coordinate: route.startCoordinate) {
            ZStack {
              Circle()
                .fill(.green)
                .frame(width: 30, height: 30)
              Text("A")
                .font(.headline)
                .foregroundStyle(.white)
            }
          }

          Annotation("End", coordinate: route.endCoordinate) {
            ZStack {
              Circle()
                .fill(.red)
                .frame(width: 30, height: 30)
              Text("B")
                .font(.headline)
                .foregroundStyle(.white)
            }
          }

          MapPolyline(route.createPolyline())
            .stroke(.blue, lineWidth: 4)
        }
        .mapStyle(.standard)
        .onAppear {
          setupMapPosition()
        }

        // Route info card at bottom
        RouteInfoCard(
          route: route,
          progress: routeManager.getStepsProgress(for: route.id, currentSteps: 0),
          onRecentre: {
            withAnimation {
              setupMapPosition()
            }
          },
          initiallyMinimized: false,
          bottomPadding: 20
        )
      }

      // Glassy navigation title at the top
      VStack {
        GlassyNavigationTitle(title: route.name)
          .padding(.top, 20)
          .padding(.leading, 20)
          .frame(maxWidth: .infinity, alignment: .leading)
        Spacer()
      }
    }
    .ignoresSafeArea()
  }

  private func setupMapPosition() {
    let polyline = route.createPolyline()
    let rect = polyline.boundingMapRect
    let baseRegion = MKCoordinateRegion(rect)

    // Account for UI elements
    let bottomUIHeight: CGFloat = 150
    let topUIHeight: CGFloat = 100
    let estimatedScreenHeight: CGFloat = 850
    let availableHeight = estimatedScreenHeight - bottomUIHeight - topUIHeight
    let visibleHeightRatio = Double(estimatedScreenHeight / availableHeight)
    let netUIOffset = bottomUIHeight - topUIHeight
    let verticalShiftRatio = Double(netUIOffset / estimatedScreenHeight)

    let shiftedCenter = CLLocationCoordinate2D(
      latitude: baseRegion.center.latitude - (baseRegion.span.latitudeDelta * verticalShiftRatio),
      longitude: baseRegion.center.longitude
    )

    let totalZoomFactor = visibleHeightRatio * 1.3
    let adjustedRegion = MKCoordinateRegion(
      center: shiftedCenter,
      span: MKCoordinateSpan(
        latitudeDelta: baseRegion.span.latitudeDelta * totalZoomFactor,
        longitudeDelta: baseRegion.span.longitudeDelta * totalZoomFactor
      )
    )

    position = .region(adjustedRegion)
  }
}

#Preview {
  SavedRoutesView(routeManager: RouteManager(), healthKitManager: HealthKitManager())
}
