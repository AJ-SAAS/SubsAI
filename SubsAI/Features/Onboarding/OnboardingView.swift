import SwiftUI
import FirebaseAuth

struct OnboardingView: View {
    @StateObject private var viewModel = OnboardingViewModel()
    @State private var errorMessage: String?
    @State private var isLoading = false

    var body: some View {
        VStack {
            Text("Subs AI")
                .font(.largeTitle)
                .bold()

            Text("Connect your YouTube channel")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Button("Sign in with Google") {
                print("OnboardingView: Sign in button tapped")
                isLoading = true
                viewModel.signInWithGoogle { result in
                    isLoading = false
                    switch result {
                    case .success:
                        print("OnboardingView: Sign-in successful")
                    case .failure(let error):
                        errorMessage = error.localizedDescription
                        print("OnboardingView: Sign-in failed: \(error.localizedDescription) (Code: \((error as NSError).code))")
                    }
                }
            }
            .font(.headline)
            .padding()
            .frame(maxWidth: .infinity)
            .background(isLoading ? Color.gray : Color.blue)
            .foregroundColor(.white)
            .cornerRadius(12)
            .padding()
            .disabled(isLoading)

            if let error = errorMessage {
                Text("Error: \(error)")
                    .foregroundColor(.red)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
            }

            if isLoading {
                ProgressView("Signing in...")
                    .padding()
            }
        }
        .padding()
        .fullScreenCover(isPresented: $viewModel.isAuthenticated) {
            DashboardView()
        }
        .onAppear {
            print("OnboardingView: View appeared")
        }
    }
}

#if DEBUG
struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView()
    }
}
#endif
