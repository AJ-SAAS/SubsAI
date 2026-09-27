// Features/Onboarding/SplashView.swift
import SwiftUI

struct SplashView: View {

    // Logo starts fully visible, so it shows even if the phone is busy at launch
    @State private var scale: CGFloat = 0.92
    @State private var opacity: Double = 1.0
    @State private var glowOpacity: Double = 0.6
    @State private var shimmerPhase: CGFloat = -1.0

    var onComplete: () -> Void

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            // Subtle glow layer
            Circle()
                .fill(AppTheme.accent.opacity(0.12))
                .frame(width: 160, height: 160)
                .blur(radius: 30)
                .opacity(glowOpacity)

            Image("AppIconImage")
                .resizable()
                .scaledToFit()
                .frame(width: 110, height: 110)
                .cornerRadius(26)
                .shadow(color: AppTheme.accent.opacity(0.35), radius: 30, x: 0, y: 12)
                .scaleEffect(scale)
                .opacity(opacity)
                .overlay(
                    shimmerOverlay()
                        .clipShape(RoundedRectangle(cornerRadius: 26))
                        .opacity(opacity)
                )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            // Quick settle-in (0.35s)
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                scale = 1.0
                glowOpacity = 1.0
            }

            // One quick shimmer pass
            try? await Task.sleep(nanoseconds: 150_000_000)
            withAnimation(.easeInOut(duration: 0.5)) {
                shimmerPhase = 1.0
            }

            // Hold briefly, then fade out (whole splash is about 1 second)
            try? await Task.sleep(nanoseconds: 550_000_000)
            withAnimation(.easeOut(duration: 0.25)) {
                opacity = 0.0
                scale = 1.06
                glowOpacity = 0.0
            }

            try? await Task.sleep(nanoseconds: 250_000_000)
            onComplete()
        }
    }

    // MARK: - Shimmer Overlay
    private func shimmerOverlay() -> some View {
        GeometryReader { geo in
            let width = geo.size.width

            LinearGradient(
                colors: [
                    .clear,
                    Color.white.opacity(0.45),
                    Color.white.opacity(0.15),
                    .clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .rotationEffect(.degrees(35))
            .frame(width: width * 1.6)
            .offset(x: shimmerPhase * (width * 1.8))
            .blur(radius: 4)
        }
        .opacity(0.75)
    }
}
