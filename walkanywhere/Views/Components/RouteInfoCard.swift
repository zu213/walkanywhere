//
//  RouteInfoCard.swift
//  walkanywhere
//
//  Created by Zachary Upstone on 23/03/2026.
//

import SwiftUI
import MapKit

struct RouteInfoCard: View {
  let route: SavedRoute
  let progress: (completed: Int, total: Int, isCompleted: Bool)?

  var body: some View {
    VStack(spacing: 12) {
      Text(route.name)
        .font(.title2)
        .fontWeight(.bold)

      HStack(alignment: .firstTextBaseline, spacing: 4) {
        Text(String(format: "%.2f", route.distance / 1000))
          .font(.system(size: 36, weight: .bold, design: .rounded))
        Text("km")
          .font(.title3)
          .foregroundStyle(.secondary)
      }

      // Progress bar
      if let progress = progress {
        VStack(spacing: 6) {
          GeometryReader { geometry in
            ZStack(alignment: .leading) {
              RoundedRectangle(cornerRadius: 8)
                .fill(.gray.opacity(0.2))
                .frame(height: 12)

              RoundedRectangle(cornerRadius: 8)
                .fill(progress.isCompleted ? .green : .blue)
                .frame(width: min(CGFloat(progress.completed) / CGFloat(progress.total) * geometry.size.width, geometry.size.width), height: 12)
            }
          }
          .frame(height: 12)

          HStack {
            if progress.isCompleted {
              Text("✓ Completed!")
                .font(.caption)
                .foregroundStyle(.green)
                .fontWeight(.semibold)
              Spacer()
            } else {
              Text("\(progress.completed) / \(progress.total) steps")
                .font(.caption)
                .foregroundStyle(.secondary)
              Spacer()
              Text("\(Int(Double(progress.completed) / Double(progress.total) * 100))%")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fontWeight(.semibold)
            }
          }
        }
      }

      Divider()
        .padding(.vertical, 4)

      HStack(spacing: 24) {
        VStack(spacing: 4) {
          Image(systemName: "figure.walk")
            .font(.title3)
            .foregroundStyle(.secondary)
          Text(route.formattedTime)
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }

        VStack(spacing: 4) {
          Image(systemName: "shoeprints.fill")
            .font(.title3)
            .foregroundStyle(.secondary)
          Text(route.formattedSteps)
            .font(.subheadline)
            .foregroundStyle(.secondary)
          Text("goal")
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
      }
    }
    .padding(20)
    .frame(maxWidth: .infinity)
    .background(
      ZStack {
        // Glassmorphism background
        RoundedRectangle(cornerRadius: 30)
          .fill(.ultraThinMaterial)
          .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)

        // Gradient overlay for liquid glass effect
        RoundedRectangle(cornerRadius: 30)
          .fill(
            LinearGradient(
              gradient: Gradient(colors: [
                .white.opacity(0.3),
                .white.opacity(0.1)
              ]),
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            )
          )

        // Subtle border
        RoundedRectangle(cornerRadius: 30)
          .strokeBorder(
            LinearGradient(
              gradient: Gradient(colors: [
                .white.opacity(0.5),
                .white.opacity(0.2)
              ]),
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            ),
            lineWidth: 1.5
          )
      }
    )
    .padding(.horizontal, 20)
    .padding(.vertical, 16)
  }
}

#Preview {
  RouteInfoCard(
    route: SavedRoute(
      name: "Test Route",
      startCoordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
      endCoordinate: CLLocationCoordinate2D(latitude: 37.8049, longitude: -122.4494),
      distance: 5000,
      estimatedTime: 3600,
      polyline: MKPolyline()
    ),
    progress: (completed: 2500, total: 5000, isCompleted: false)
  )
}
