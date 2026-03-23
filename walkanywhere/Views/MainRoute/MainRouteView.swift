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
    NavigationStack {
      Group {
        if let mainRoute = routeManager.mainRoute {
          ZStack(alignment: .bottom) {
          Map(position: $position, interactionModes: [.pan, .zoom]) {
            Annotation("Start", coordinate: mainRoute.startCoordinate) {
              MapMarker(label: "A", color: .green)
            }

            Annotation("End", coordinate: mainRoute.endCoordinate) {
              MapMarker(label: "B", color: .red)
            }

            MapPolyline(mainRoute.createPolyline())
              .stroke(.blue, lineWidth: 4)
          }
          .mapStyle(.standard)
          .onAppear {
            setupMapPosition(for: mainRoute)
          }

          RouteInfoCard(
            route: mainRoute,
            progress: routeManager.getStepsProgress(for: mainRoute.id, currentSteps: stepMonitor.todaySteps)
          )
        }
        .toolbar {
          #if DEBUG
          ToolbarItem(placement: .topBarTrailing) {
            Button {
              showingDebugMenu = true
            } label: {
              Image(systemName: "ladybug.fill")
                .foregroundStyle(.red)
            }
          }
          #endif
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
      }
      .navigationTitle("Current Journey")
      .navigationBarTitleDisplayMode(.inline)
    }
  }

  private func setupMapPosition(for route: SavedRoute) {
    let polyline = route.createPolyline()
    let rect = polyline.boundingMapRect
    let region = MKCoordinateRegion(rect)

    let expandedRegion = MKCoordinateRegion(
      center: region.center,
      span: MKCoordinateSpan(
        latitudeDelta: region.span.latitudeDelta * 1.3,
        longitudeDelta: region.span.longitudeDelta * 1.3
      )
    )

    position = .region(expandedRegion)
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
//  let manager = RouteManager()
//  MainRouteView(routeManager: manager, stepMonitor: StepMonitor(routeManager: manager, healthKitManager: <#HealthKitManager#>))
}
