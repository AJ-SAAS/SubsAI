// Features/Onboarding/SplashView.swift
import SwiftUI

struct SplashView: View {

    @State private var scale: CGFloat = 0.85
    @State private var opacity: Double = 0
    @State private var shimmer = false

    var onComplete: () -> Void

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            Image("AppIconImage")
                .resizable()
                .scaledToFit()
                .frame(width: 110, height: 110)
                .cornerRadius(26)
                .shadow(color: AppTheme.accent.opacity(0.25), radius: 25, x: 0, y: 10)
                .scaleEffect(scale)
                .opacity(opacity)
                .overlay(
                    shimmerOverlay()
                        .clipShape(RoundedRectangle(cornerRadius: 26))
                        .opacity(shimmer ? 1 : 0)
                )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .onAppear {
            // Entry animation
            withAnimation(.spring(response: 0.55, dampingFraction: 0.75)) {
                scale = 1.0
                opacity = 1.0
            }

            // Start shimmer slightly after appearance
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.easeInOut(duration: 1.2)) {
                    shimmer = true
                }
            }

            // Exit animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                withAnimation(.easeInOut(duration: 0.35)) {
                    opacity = 0
                    scale = 1.05
                    shimmer = false
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    onComplete()
                }
            }
        }
    }

    // MARK: - Shimmer Effect
    @ViewBuilder
    private func shimmerOverlay() -> some View {
        GeometryReader { geo in
            let width = geo.size.width

            LinearGradient(
                colors: [
                    .clear,
                    Color.white.opacity(0.25),
                    .clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .rotationEffect(.degrees(20))
            .offset(x: shimmer ? width : -width)
        }
    }
}
