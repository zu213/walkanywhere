//
//  RouteDetailView.swift
//  walkanywhere
//
//  Created by Zachary Upstone on 10/03/2026.
//

import SwiftUI
import MapKit

struct RouteDetailView: View {
  let route: SavedRoute
  var routeManager: RouteManager

  @State private var position: MapCameraPosition
  @State private var healthKitManager = HealthKitManager()

  init(route: SavedRoute, routeManager: RouteManager) {
    self.route = route
    self.routeManager = routeManager

    // Calculate the region to show the entire route
    let polyline = route.createPolyline()
    let rect = polyline.boundingMapRect
    let region = MKCoordinateRegion(rect)

    // Add some padding
    let expandedRegion = MKCoordinateRegion(
      center: region.center,
      span: MKCoordinateSpan(
        latitudeDelta: region.span.latitudeDelta * 1.3,
        longitudeDelta: region.span.longitudeDelta * 1.3
      )
    )

    _position = State(initialValue: .region(expandedRegion))
  }

  var body: some View {
    VStack(spacing: 0) {
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
      .frame(maxWidth: .infinity, maxHeight: .infinity)

      VStack(spacing: 16) {
        VStack(spacing: 12) {
          Text("Route Details")
            .font(.headline)
            .foregroundStyle(.secondary)

          HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(String(format: "%.2f", route.distance / 1000))
              .font(.system(size: 36, weight: .bold, design: .rounded))
            Text("km")
              .font(.title3)
              .foregroundStyle(.secondary)
          }

          Text(String(format: "%.0f meters", route.distance))
            .font(.caption)
            .foregroundStyle(.secondary)

          Divider()
            .padding(.vertical, 4)

          HStack(spacing: 20) {
            VStack(spacing: 4) {
              Image(systemName: "figure.walk")
                .foregroundStyle(.secondary)
              Text(route.formattedTime)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            VStack(spacing: 4) {
              Image(systemName: "shoeprints.fill")
                .foregroundStyle(.secondary)
              Text(route.formattedSteps)
                .font(.subheadline)
                .foregroundStyle(.secondary)
              Text("steps")
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
          }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.regularMaterial)
      }
    }
    .navigationTitle(route.name)
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button {
          if routeManager.mainRouteId == route.id {
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
            .foregroundStyle(routeManager.mainRouteId == route.id ? .yellow : .primary)
        }
      }
    }
  }
}

#Preview {
  let sampleRoute = SavedRoute(
    name: "Morning Walk",
    startCoordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
    endCoordinate: CLLocationCoordinate2D(latitude: 37.7849, longitude: -122.4094),
    distance: 1500,
    estimatedTime: 1080,
    polyline: {
      var coords = [
        CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        CLLocationCoordinate2D(latitude: 37.7849, longitude: -122.4094)
      ]
      return MKPolyline(coordinates: &coords, count: coords.count)
    }()
  )

  NavigationStack {
    RouteDetailView(route: sampleRoute, routeManager: RouteManager())
  }
}
