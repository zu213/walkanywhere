//
//  SavedRoute.swift
//  walkanywhere
//
//  Created by Zachary Upstone on 10/03/2026.
//

import Foundation
import MapKit

struct SavedRoute: Identifiable, Codable {
  let id: UUID
  let name: String
  let startLatitude: Double
  let startLongitude: Double
  let endLatitude: Double
  let endLongitude: Double
  let distance: Double
  let estimatedTime: TimeInterval
  let polylineCoordinates: [CoordinatePair]
  let dateCreated: Date

  var startCoordinate: CLLocationCoordinate2D {
    CLLocationCoordinate2D(latitude: startLatitude, longitude: startLongitude)
  }

  var endCoordinate: CLLocationCoordinate2D {
    CLLocationCoordinate2D(latitude: endLatitude, longitude: endLongitude)
  }

  var formattedDistance: String {
    String(format: "%.2f km", distance / 1000)
  }

  var formattedTime: String {
    let hours = Int(estimatedTime) / 3600
    let minutes = (Int(estimatedTime) % 3600) / 60

    if hours > 0 {
      return "\(hours)h \(minutes)min"
    } else {
      return "\(minutes) min"
    }
  }

  var estimatedSteps: Int {
    // Average stride length is approximately 0.762 meters (2.5 feet)
    // This varies by height and gender, but it's a reasonable estimate
    let averageStrideLength = 0.762
    return Int(distance / averageStrideLength)
  }

  var formattedSteps: String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.groupingSeparator = ","
    return formatter.string(from: NSNumber(value: estimatedSteps)) ?? "\(estimatedSteps)"
  }

  init(id: UUID = UUID(), name: String, startCoordinate: CLLocationCoordinate2D, endCoordinate: CLLocationCoordinate2D, distance: Double, estimatedTime: TimeInterval, polyline: MKPolyline, dateCreated: Date = Date()) {
    self.id = id
    self.name = name
    self.startLatitude = startCoordinate.latitude
    self.startLongitude = startCoordinate.longitude
    self.endLatitude = endCoordinate.latitude
    self.endLongitude = endCoordinate.longitude
    self.distance = distance
    self.estimatedTime = estimatedTime
    self.dateCreated = dateCreated

    // Convert polyline coordinates to codable format
    var coordinates: [CoordinatePair] = []
    let pointCount = polyline.pointCount
    let points = polyline.points()
    for i in 0..<pointCount {
      let coordinate = points[i].coordinate
      coordinates.append(CoordinatePair(latitude: coordinate.latitude, longitude: coordinate.longitude))
    }
    self.polylineCoordinates = coordinates
  }

  func createPolyline() -> MKPolyline {
    var coordinates = polylineCoordinates.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
    return MKPolyline(coordinates: &coordinates, count: coordinates.count)
  }
}

struct CoordinatePair: Codable {
  let latitude: Double
  let longitude: Double
}
