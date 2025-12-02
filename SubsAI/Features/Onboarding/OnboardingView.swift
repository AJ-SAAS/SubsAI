// Features/Onboarding/OnboardingView.swift
import SwiftUI
import GoogleSignInSwift

struct OnboardingView: View {
    @StateObject private var viewModel = OnboardingViewModel()

    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            Image(systemName: "play.rectangle.fill")
                .font(.system(size: 100))
                .foregroundColor(.red)

            Text("SubsAI")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Sign in with your YouTube channel to see real-time stats")
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            if viewModel.isLoading {
                ProgressView("Signing in…")
                    .progressViewStyle(.circular)
            } else {
                GoogleSignInButton(scheme: .dark, style: .wide, state: .normal) {
                    Task { await viewModel.signInWithGoogle() }
                }
                .frame(height: 50)
                .padding(.horizontal, 40)
            }

            if let error = viewModel.errorMessage {
                Text("Error: \(error)")
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding()
            }

            Spacer()
        }
        .padding()
    }
}
