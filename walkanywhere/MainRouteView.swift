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
    @State private var testHelper = HealthKitTestHelper()

    var body: some View {
        NavigationStack {
            if let mainRoute = routeManager.mainRoute {
                ZStack(alignment: .bottom) {
                    Map(position: $position, interactionModes: [.pan, .zoom]) {
                        Annotation("Start", coordinate: mainRoute.startCoordinate) {
                            ZStack {
                                Circle()
                                    .fill(.green)
                                    .frame(width: 30, height: 30)
                                Text("A")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                            }
                        }

                        Annotation("End", coordinate: mainRoute.endCoordinate) {
                            ZStack {
                                Circle()
                                    .fill(.red)
                                    .frame(width: 30, height: 30)
                                Text("B")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                            }
                        }

                        MapPolyline(mainRoute.createPolyline())
                            .stroke(.blue, lineWidth: 4)
                    }
                    .mapStyle(.standard)
                    .onAppear {
                        // Set the camera position to show the entire route
                        let polyline = mainRoute.createPolyline()
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

                    VStack(spacing: 12) {
                        VStack(spacing: 12) {
                            Text(mainRoute.name)
                                .font(.title2)
                                .fontWeight(.bold)

                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text(String(format: "%.2f", mainRoute.distance / 1000))
                                    .font(.system(size: 36, weight: .bold, design: .rounded))
                                Text("km")
                                    .font(.title3)
                                    .foregroundStyle(.secondary)
                            }

                            // Progress bar
                            if let progress = routeManager.getStepsProgress(for: mainRoute.id, currentSteps: stepMonitor.todaySteps) {
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
                                    Text(mainRoute.formattedTime)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }

                                VStack(spacing: 4) {
                                    Image(systemName: "shoeprints.fill")
                                        .font(.title3)
                                        .foregroundStyle(.secondary)
                                    Text(mainRoute.formattedSteps)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    Text("goal")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding()
                    }
                }
                .navigationTitle("Main Route")
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
                    NavigationStack {
                        List {
                            Section("Simulate Walking") {
                                Button("Add 100 Steps") {
                                    Task {
                                        try? await testHelper.addSteps(count: 100)
                                        await stepMonitor.fetchTodaySteps()
                                    }
                                }

                                Button("Add 500 Steps") {
                                    Task {
                                        try? await testHelper.addSteps(count: 500)
                                        await stepMonitor.fetchTodaySteps()
                                    }
                                }

                                Button("Add 1,000 Steps") {
                                    Task {
                                        try? await testHelper.addSteps(count: 1000)
                                        await stepMonitor.fetchTodaySteps()
                                    }
                                }

                                Button("Simulate Walking (100 steps/sec for 10 sec)") {
                                    Task {
                                        showingDebugMenu = false
                                        try? await testHelper.addStepsGradually(totalSteps: 1000, intervalSeconds: 0.1)
                                        await stepMonitor.fetchTodaySteps()
                                    }
                                }
                            }

                            Section("Current Status") {
                                if let mainRoute = routeManager.mainRoute,
                                   let progress = routeManager.getStepsProgress(for: mainRoute.id, currentSteps: stepMonitor.todaySteps) {
                                    if progress.isCompleted {
                                        Text("Status: ✓ Completed!")
                                            .foregroundStyle(.green)
                                    } else {
                                        Text("Completed: \(progress.completed) steps")
                                        Text("Goal: \(progress.total) steps")
                                        Text("Remaining: \(progress.total - progress.completed) steps")
                                    }
                                }
                            }

                            Section("Route Management") {
                                if let mainRoute = routeManager.mainRoute {
                                    Button("Reset Progress", role: .destructive) {
                                        routeManager.resetRouteProgress(mainRoute.id)
                                        showingDebugMenu = false
                                    }
                                }
                            }
                        }
                        .navigationTitle("Debug Menu")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Done") {
                                    showingDebugMenu = false
                                }
                            }
                        }
                    }
                    .presentationDetents([.medium])
                }
            } else {
                ContentUnavailableView(
                    "No Main Route Selected",
                    systemImage: "star.slash",
                    description: Text("Go to Routes and tap the star next to a route to set it as your main route.")
                )
                .navigationTitle("Main Route")
            }
        }
    }
}

#Preview {
//    let manager = RouteManager()
//  MainRouteView(routeManager: manager, stepMonitor: StepMonitor(routeManager: manager, healthKitManager: <#HealthKitManager#>))
}
