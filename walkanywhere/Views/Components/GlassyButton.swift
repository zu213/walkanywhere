//
//  GlassyButton.swift
//  walkanywhere
//
//  Created by Zachary Upstone on 23/03/2026.
//

import SwiftUI

struct GlassyButton: View {
  let systemImage: String
  let action: () -> Void
  var tintColor: Color = .primary

  var body: some View {
    Button(action: action) {
      Image(systemName: systemImage)
        .font(.title3)
        .foregroundStyle(tintColor)
        .frame(width: 44, height: 44)
        .background(
          ZStack {
            // Glassmorphism background
            Circle()
              .fill(.ultraThinMaterial)
              .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)

            // Gradient overlay for liquid glass effect
            Circle()
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
            Circle()
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
}

#Preview {
  HStack(spacing: 16) {
    GlassyButton(systemImage: "plus", action: {})
    GlassyButton(systemImage: "ladybug.fill", action: {}, tintColor: .red)
    GlassyButton(systemImage: "star.fill", action: {}, tintColor: .yellow)
  }
  .padding()
  .background(Color.blue.opacity(0.3))
}
