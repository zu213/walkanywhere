//
//  MainRouteView.swift
//  walkanywhere
//
//  Created by Zachary Upstone on 10/03/2026.
//

import SwiftUI
import MapKit

struct MainRouteView: View {
  var routeManager: RouteManager
  var stepMonitor: StepMonitor
  @State private var position: MapCameraPosition = .automatic
  @State private var showingDebugMenu = false

  var body: some View {
    ZStack(alignment: .top) {
      if let mainRoute = routeManager.mainRoute {
        GeometryReader { geometry in
          ZStack(alignment: .bottom) {
            Map(position: $position, interactionModes: [.pan, .zoom]) {
              Annotation("Start", coordinate: mainRoute.startCoordinate) {
                MapMarker(label: "A", color: .green)
              }

              Annotation("End", coordinate: mainRoute.endCoordinate) {
                MapMarker(label: "B", color: .red)
              }

              // Progress marker
              if let progress = routeManager.getStepsProgress(for: mainRoute.id, currentSteps: stepMonitor.todaySteps),
                 !progress.isCompleted,
                 let progressCoordinate = calculateProgressCoordinate(for: mainRoute, progress: Double(progress.completed) / Double(progress.total)) {
                Annotation("Your Progress", coordinate: progressCoordinate) {
                  ZStack {
                    Circle()
                      .fill(.white)
                      .frame(width: 20, height: 20)
                    Circle()
                      .fill(.blue)
                      .frame(width: 16, height: 16)
                  }
                  .shadow(radius: 4)
                }
              }

              MapPolyline(mainRoute.createPolyline())
                .stroke(.blue, lineWidth: 4)
            }
            .mapStyle(.standard)
            .onAppear {
              setupMapPosition(for: mainRoute, screenHeight: geometry.size.height)
            }

            RouteInfoCard(
              route: mainRoute,
              progress: routeManager.getStepsProgress(for: mainRoute.id, currentSteps: stepMonitor.todaySteps),
              onRecentre: {
                withAnimation {
                  setupMapPosition(for: mainRoute, screenHeight: geometry.size.height)
                }
              }
            )
          }
        }
        .sheet(isPresented: $showingDebugMenu) {
          DebugMenuSheet(
            isPresented: $showingDebugMenu,
            routeManager: routeManager,
            stepMonitor: stepMonitor
          )
        }
      } else {
        ContentUnavailableView(
          "No Main Route Selected",
          systemImage: "star.slash",
          description: Text("Go to Routes and tap the star next to a route to set it as your main route.")
        )
      }

      // Glassy navigation title at the top
      HStack {
        GlassyNavigationTitle(title: "Current Journey")
        Spacer()
        #if DEBUG
        GlassyButton(systemImage: "ladybug.fill", action: {
          showingDebugMenu = true
        }, tintColor: .red)
        .padding(.trailing, 20)
        .hidden()
        #endif
      }
      .padding(.top, 60)
      .padding(.leading, 20)
    }
    .ignoresSafeArea()
  }

  private func setupMapPosition(for route: SavedRoute, screenHeight: CGFloat? = nil) {
    let polyline = route.createPolyline()
    let rect = polyline.boundingMapRect
    let baseRegion = MKCoordinateRegion(rect)

    // Calculate UI elements heights
    // Tab bar (~50pt) + Route card when minimized (~80pt) + some padding (20pt) = ~150pt total
    // Top navigation (~100pt for title area)
    let bottomUIHeight: CGFloat = 150
    let topUIHeight: CGFloat = 100
    let totalUIHeight = bottomUIHeight + topUIHeight

    // Calculate how much to zoom out to compensate for UI elements
    let visibleHeightRatio: Double
    let verticalShiftRatio: Double

    if let height = screenHeight {
      // Calculate what fraction of the screen is actually available for the map
      let availableHeight = height - totalUIHeight
      // We need to zoom out so the route fits in the available height
      visibleHeightRatio = Double(height / availableHeight)
      // Shift the center to account for more UI at bottom than top
      // Net shift is (bottomUI - topUI) / 2, then add extra 10% for more clearance
      let netUIOffset = bottomUIHeight - topUIHeight
      verticalShiftRatio = Double(netUIOffset / height) + 0.10
    } else {
      // Default values if screen height not provided
      visibleHeightRatio = 1.4  // Zoom out by 40%
      verticalShiftRatio = 0.15  // Shift up by 15%
    }

    // Shift the center downward (subtract from latitude) to make content appear higher on screen
    let shiftedCenter = CLLocationCoordinate2D(
      latitude: baseRegion.center.latitude - (baseRegion.span.latitudeDelta * verticalShiftRatio),
      longitude: baseRegion.center.longitude
    )

    // Expand the region to account for UI elements blocking the view
    // Plus additional 30% padding for aesthetics
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

  private func calculateProgressCoordinate(for route: SavedRoute, progress: Double) -> CLLocationCoordinate2D? {
    let polyline = route.createPolyline()
    let points = polyline.points()
    let pointCount = polyline.pointCount

    guard pointCount > 1 else { return nil }

    // Calculate total distance
    var totalDistance: CLLocationDistance = 0
    for i in 0..<(pointCount - 1) {
      let startCoord = points[i].coordinate
      let endCoord = points[i + 1].coordinate
      let startLocation = CLLocation(latitude: startCoord.latitude, longitude: startCoord.longitude)
      let endLocation = CLLocation(latitude: endCoord.latitude, longitude: endCoord.longitude)
      totalDistance += startLocation.distance(from: endLocation)
    }

    let targetDistance = totalDistance * progress
    var accumulatedDistance: CLLocationDistance = 0

    // Find the segment containing the target distance
    for i in 0..<(pointCount - 1) {
      let startCoord = points[i].coordinate
      let endCoord = points[i + 1].coordinate
      let startLocation = CLLocation(latitude: startCoord.latitude, longitude: startCoord.longitude)
      let endLocation = CLLocation(latitude: endCoord.latitude, longitude: endCoord.longitude)
      let segmentDistance = startLocation.distance(from: endLocation)

      if accumulatedDistance + segmentDistance >= targetDistance {
        // Target is in this segment
        let remainingDistance = targetDistance - accumulatedDistance
        let segmentProgress = remainingDistance / segmentDistance

        // Interpolate between start and end coordinates
        let lat = startCoord.latitude + (endCoord.latitude - startCoord.latitude) * segmentProgress
        let lon = startCoord.longitude + (endCoord.longitude - startCoord.longitude) * segmentProgress

        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
      }

      accumulatedDistance += segmentDistance
    }

    // If we've gone past the end, return the last coordinate
    return points[pointCount - 1].coordinate
  }
}

struct MapMarker: View {
  let label: String
  let color: Color

  var body: some View {
    ZStack {
      Circle()
        .fill(color)
        .frame(width: 30, height: 30)
      Text(label)
        .font(.headline)
        .foregroundStyle(.white)
    }
  }
}

#Preview {
  let routeManager = RouteManager()
  let healthKitManager = HealthKitManager()
  let stepMonitor = StepMonitor(routeManager: routeManager, healthKitManager: healthKitManager)
  return MainRouteView(routeManager: routeManager, stepMonitor: stepMonitor)
}
