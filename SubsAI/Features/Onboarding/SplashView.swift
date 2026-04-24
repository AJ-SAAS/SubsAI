// Features/Onboarding/SplashView.swift
import SwiftUI

struct SplashView: View {

    @State private var scale: CGFloat = 0.78
    @State private var opacity: Double = 0.0
    @State private var glowOpacity: Double = 0.0
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
                )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            // Gentle entrance
            withAnimation(.spring(response: 0.65, dampingFraction: 0.78, blendDuration: 0.4)) {
                scale = 1.0
                opacity = 1.0
                glowOpacity = 1.0
            }

            // Start shimmer with a nice delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                withAnimation(.linear(duration: 2.4).repeatForever(autoreverses: false)) {
                    shimmerPhase = 1.0
                }
            }

            // Exit sequence
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.1) {
                withAnimation(.easeOut(duration: 0.45)) {
                    opacity = 0.0
                    scale = 1.08
                    glowOpacity = 0.0
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                    onComplete()
                }
            }
        }
    }

    // MARK: - Improved Shimmer Overlay
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
