//
//  MapDistanceView.swift
//  walkanywhere
//
//  Created by Zachary Upstone on 10/03/2026.
//

import SwiftUI
import MapKit

struct MapDistanceView: View {
  @State private var position: MapCameraPosition = .region(MKCoordinateRegion(
    center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
    span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
  ))
  @State private var startLocation: CLLocationCoordinate2D?
  @State private var endLocation: CLLocationCoordinate2D?
  @State private var distance: Double = 0
  @State private var routePolyline: MKPolyline?
  @State private var estimatedTime: TimeInterval = 0
  @State private var isCalculatingRoute = false
  @State private var showingSaveSheet = false
  @State private var routeName = ""
  @State private var isDrawerExpanded = true

  var routeManager: RouteManager

  var body: some View {
    NavigationStack {
      ZStack(alignment: .bottom) {
        MapReader { proxy in
          Map(position: $position, interactionModes: .all) {
            if let start = startLocation {
              Annotation("Start", coordinate: start) {
                ZStack {
                  Circle()
                    .fill(.green)
                    .frame(width: 30, height: 30)
                  Text("A")
                    .font(.headline)
                    .foregroundStyle(.white)
                }
              }
            }

            if let end = endLocation {
              Annotation("End", coordinate: end) {
                ZStack {
                  Circle()
                    .fill(.red)
                    .frame(width: 30, height: 30)
                  Text("B")
                    .font(.headline)
                    .foregroundStyle(.white)
                }
              }
            }

            if let polyline = routePolyline {
              MapPolyline(polyline)
                .stroke(.blue, lineWidth: 4)
            }
          }
          .mapStyle(.standard)
          .onTapGesture { screenCoordinate in
            if let coordinate = proxy.convert(screenCoordinate, from: .local) {
              setPoint(coordinate: coordinate)
            }
          }
        }

        if startLocation != nil || endLocation != nil {
          RouteDetailsDrawer(
            isExpanded: $isDrawerExpanded,
            startLocation: startLocation,
            endLocation: endLocation,
            distance: distance,
            estimatedTime: estimatedTime,
            isCalculatingRoute: isCalculatingRoute,
            routePolyline: routePolyline,
            onSaveRoute: {
              showingSaveSheet = true
            },
            onClearPoints: clearPoints
          )
        } else {
          Text("Tap on the map to set two points")
            .font(.subheadline)
            .padding()
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding()
        }
      }
      .navigationTitle("Create a route")
      .navigationBarTitleDisplayMode(.inline)
      .sheet(isPresented: $showingSaveSheet) {
        NavigationStack {
          Form {
            Section("Route Name") {
              TextField("Enter route name", text: $routeName)
            }
          }
          .navigationTitle("Save Route")
          .navigationBarTitleDisplayMode(.inline)
          .toolbar {
            ToolbarItem(placement: .cancellationAction) {
              Button("Cancel") {
                showingSaveSheet = false
                routeName = ""
              }
            }
            ToolbarItem(placement: .confirmationAction) {
              Button("Save") {
                saveRoute()
              }
              .disabled(routeName.isEmpty)
            }
          }
        }
        .presentationDetents([.medium])
      }
    }
  }

  private func setPoint(coordinate: CLLocationCoordinate2D) {
    if startLocation == nil {
      startLocation = coordinate
      // Center on the first point
      position = .region(MKCoordinateRegion(
        center: coordinate,
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
      ))
    } else if endLocation == nil {
      endLocation = coordinate
      Task {
        await calculateWalkingRoute()
      }
    }
  }

  private func calculateWalkingRoute() async {
    guard let start = startLocation, let end = endLocation else { return }

    isCalculatingRoute = true

    let request = MKDirections.Request()
    request.source = MKMapItem(placemark: MKPlacemark(coordinate: start))
    request.destination = MKMapItem(placemark: MKPlacemark(coordinate: end))
    request.transportType = .walking

    let directions = MKDirections(request: request)

    do {
      let response = try await directions.calculate()

      if let route = response.routes.first {
        await MainActor.run {
          self.routePolyline = route.polyline
          self.distance = route.distance
          self.estimatedTime = route.expectedTravelTime

          // Adjust view to show the entire route
          let rect = route.polyline.boundingMapRect
          let region = MKCoordinateRegion(rect)

          // Add some padding
          let expandedRegion = MKCoordinateRegion(
            center: region.center,
            span: MKCoordinateSpan(
              latitudeDelta: region.span.latitudeDelta * 1.3,
              longitudeDelta: region.span.longitudeDelta * 1.3
            )
          )

          position = .region(expandedRegion)
          isCalculatingRoute = false
        }
      }
    } catch {
      // If routing fails, try to route from both ends and connect with straight line
      await tryHybridRoute(start: start, end: end)
    }
  }

  private func tryHybridRoute(start: CLLocationCoordinate2D, end: CLLocationCoordinate2D) async {
    // Calculate midpoint
    let midLat = (start.latitude + end.latitude) / 2
    let midLon = (start.longitude + end.longitude) / 2
    let midpoint = CLLocationCoordinate2D(latitude: midLat, longitude: midLon)

    // Try to get walking route from start to midpoint
    let startToMidRequest = MKDirections.Request()
    startToMidRequest.source = MKMapItem(placemark: MKPlacemark(coordinate: start))
    startToMidRequest.destination = MKMapItem(placemark: MKPlacemark(coordinate: midpoint))
    startToMidRequest.transportType = .walking

    // Try to get walking route from midpoint to end
    let midToEndRequest = MKDirections.Request()
    midToEndRequest.source = MKMapItem(placemark: MKPlacemark(coordinate: midpoint))
    midToEndRequest.destination = MKMapItem(placemark: MKPlacemark(coordinate: end))
    midToEndRequest.transportType = .walking

    var startPolyline: MKPolyline?
    var startDistance: Double = 0
    var startTime: TimeInterval = 0
    var endPolyline: MKPolyline?
    var endDistance: Double = 0
    var endTime: TimeInterval = 0

    // Try route from start
    if let startResponse = try? await MKDirections(request: startToMidRequest).calculate(),
       let startRoute = startResponse.routes.first {
      startPolyline = startRoute.polyline
      startDistance = startRoute.distance
      startTime = startRoute.expectedTravelTime
    }

    // Try route from end
    if let endResponse = try? await MKDirections(request: midToEndRequest).calculate(),
       let endRoute = endResponse.routes.first {
      endPolyline = endRoute.polyline
      endDistance = endRoute.distance
      endTime = endRoute.expectedTravelTime
    }

    await MainActor.run {
      // Combine the routes
      var allCoordinates: [CLLocationCoordinate2D] = []
      var totalDistance: Double = 0
      var totalTime: TimeInterval = 0

      // Add start route if available
      if let startPoly = startPolyline {
        let pointCount = startPoly.pointCount
        let points = startPoly.points()
        for i in 0..<pointCount {
          allCoordinates.append(points[i].coordinate)
        }
        totalDistance += startDistance
        totalTime += startTime
      } else {
        // No start route available, use start point
        allCoordinates.append(start)
      }

      // Add straight line segment in the middle
      let lastStartPoint = allCoordinates.last ?? start
      let firstEndPoint: CLLocationCoordinate2D

      if let endPoly = endPolyline {
        firstEndPoint = endPoly.points()[0].coordinate
      } else {
        firstEndPoint = end
      }

      // Calculate straight line distance for the gap
      let gapStart = CLLocation(latitude: lastStartPoint.latitude, longitude: lastStartPoint.longitude)
      let gapEnd = CLLocation(latitude: firstEndPoint.latitude, longitude: firstEndPoint.longitude)
      let gapDistance = gapStart.distance(from: gapEnd)
      totalDistance += gapDistance
      totalTime += gapDistance / (5000.0 / 3600.0) // Walking speed estimate

      // Add the gap point if it's different from what we have
      if lastStartPoint.latitude != firstEndPoint.latitude || lastStartPoint.longitude != firstEndPoint.longitude {
        allCoordinates.append(firstEndPoint)
      }

      // Add end route if available
      if let endPoly = endPolyline {
        let pointCount = endPoly.pointCount
        let points = endPoly.points()
        // Skip first point as it's already added
        for i in 1..<pointCount {
          allCoordinates.append(points[i].coordinate)
        }
        totalDistance += endDistance
        totalTime += endTime
      } else {
        // No end route available, use end point
        if allCoordinates.last?.latitude != end.latitude || allCoordinates.last?.longitude != end.longitude {
          allCoordinates.append(end)
        }
      }

      // If we couldn't get any routes, fall back to simple straight line
      if allCoordinates.count < 2 {
        allCoordinates = [start, end]
        let startCL = CLLocation(latitude: start.latitude, longitude: start.longitude)
        let endCL = CLLocation(latitude: end.latitude, longitude: end.longitude)
        totalDistance = startCL.distance(from: endCL)
        totalTime = totalDistance / (5000.0 / 3600.0)
      }

      // Create polyline from all coordinates
      routePolyline = MKPolyline(coordinates: allCoordinates, count: allCoordinates.count)
      distance = totalDistance
      estimatedTime = totalTime

      // Adjust view to show both points
      let spanLat = abs(start.latitude - end.latitude) * 1.5
      let spanLon = abs(start.longitude - end.longitude) * 1.5

      position = .region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: midLat, longitude: midLon),
        span: MKCoordinateSpan(latitudeDelta: max(spanLat, 0.01), longitudeDelta: max(spanLon, 0.01))
      ))

      isCalculatingRoute = false
    }
  }

  private func saveRoute() {
    guard let start = startLocation,
        let end = endLocation,
        let polyline = routePolyline else { return }

    let route = SavedRoute(
      name: routeName,
      startCoordinate: start,
      endCoordinate: end,
      distance: distance,
      estimatedTime: estimatedTime,
      polyline: polyline
    )

    routeManager.addRoute(route)

    showingSaveSheet = false
    routeName = ""
    clearPoints()
  }

  private func clearPoints() {
    startLocation = nil
    endLocation = nil
    distance = 0
    routePolyline = nil
    estimatedTime = 0
  }
}

#Preview {
  MapDistanceView(routeManager: RouteManager())
}
