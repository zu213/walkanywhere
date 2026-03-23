//
//  GlassyNavigationTitle.swift
//  walkanywhere
//
//  Created by Zachary Upstone on 23/03/2026.
//

import SwiftUI

struct GlassyNavigationTitle: View {
  let title: String

  var body: some View {
    Text(title)
      .font(.title2)
      .fontWeight(.bold)
      .foregroundStyle(.primary)
      .padding(.horizontal, 20)
      .padding(.vertical, 12)
      .background(
        ZStack {
          // Glassmorphism background
          Capsule()
            .fill(.ultraThinMaterial)
            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)

          // Gradient overlay for liquid glass effect
          Capsule()
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
          Capsule()
            .strokeBorder(
              LinearGradient(
                gradient: Gradient(colors: [
                  .white.opacity(0.5),
                  .white.opacity(0.2)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
              ),
              lineWidth: 1
            )
        }
      )
  }
}

#Preview {
  VStack {
    GlassyNavigationTitle(title: "Current Journey")
    GlassyNavigationTitle(title: "My Routes")
    GlassyNavigationTitle(title: "Step History")
  }
  .padding()
  .background(Color.blue.opacity(0.3))
}
