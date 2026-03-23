//
//  RouteDetailsDrawer.swift
//  walkanywhere
//
//  Created by Zachary Upstone on 23/03/2026.
//

import SwiftUI
import MapKit

struct RouteDetailsDrawer: View {
    @Binding var isExpanded: Bool
    let startLocation: CLLocationCoordinate2D?
    let endLocation: CLLocationCoordinate2D?
    let distance: Double
    let estimatedTime: TimeInterval
    let isCalculatingRoute: Bool
    let routePolyline: MKPolyline?
    let onSaveRoute: () -> Void
    let onClearPoints: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Drawer handle
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isExpanded.toggle()
                }
            }) {
                VStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 2.5)
                        .fill(Color.secondary.opacity(0.5))
                        .frame(width: 36, height: 5)
                        .padding(.top, 8)

                    HStack {
                        Text("Route Details")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.up")
                            .foregroundStyle(.secondary)
                            .imageScale(.small)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: 8) {
                    if startLocation != nil && endLocation != nil {
                        if isCalculatingRoute {
                            ProgressView("Calculating route...")
                                .padding()
                        } else {
                            VStack(spacing: 8) {
                                Text("Create a route")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                HStack(alignment: .firstTextBaseline, spacing: 4) {
                                    Text(String(format: "%.2f", distance / 1000))
                                        .font(.system(size: 36, weight: .bold, design: .rounded))
                                    Text("km")
                                        .font(.title3)
                                        .foregroundStyle(.secondary)
                                }
                                Text(String(format: "%.0f meters", distance))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                if estimatedTime > 0 {
                                    Divider()
                                        .padding(.vertical, 4)
                                    HStack(spacing: 4) {
                                        Image(systemName: "figure.walk")
                                            .foregroundStyle(.secondary)
                                        Text(formatTime(estimatedTime))
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    } else {
                        Text("Tap on the map to set \(startLocation == nil ? "start" : "end") point")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 12) {
                        if startLocation != nil && endLocation != nil && routePolyline != nil {
                            Button(action: onSaveRoute) {
                                Label("Save Route", systemImage: "plus.circle.fill")
                            }
                            .buttonStyle(.borderedProminent)
                        }

                        Button("Clear Points", action: onClearPoints)
                            .buttonStyle(.bordered)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding()
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)min"
        } else {
            return "\(minutes) min"
        }
    }
}

#Preview {
    RouteDetailsDrawer(
        isExpanded: .constant(true),
        startLocation: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        endLocation: CLLocationCoordinate2D(latitude: 37.8049, longitude: -122.4494),
        distance: 5000,
        estimatedTime: 3600,
        isCalculatingRoute: false,
        routePolyline: MKPolyline(),
        onSaveRoute: {},
        onClearPoints: {}
    )
}
