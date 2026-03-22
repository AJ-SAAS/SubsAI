// Features/Onboarding/SplashView.swift
import SwiftUI

struct SplashView: View {

    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0

    var onComplete: () -> Void

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            VStack(spacing: 16) {
                Image("AppIconImage")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .cornerRadius(24)
                    .shadow(color: AppTheme.accent.opacity(0.3), radius: 20, x: 0, y: 8)
                    .scaleEffect(scale)
                    .opacity(opacity)

                Text("SubsAI")
                    .font(.system(size: 28, weight: .medium, design: .serif))
                    .foregroundColor(AppTheme.textPrimary)
                    .opacity(opacity)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                scale = 1.0
                opacity = 1.0
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    opacity = 0
                    scale = 1.05
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    onComplete()
                }
            }
        }
    }
}
