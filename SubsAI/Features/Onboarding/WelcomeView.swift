import SwiftUI

struct WelcomeView: View {

    @State private var currentPage = 0
    @State private var animateIn = false

    private let pages: [WelcomePage] = [
        WelcomePage(
            imageName: "subsaipw5",
            headline: "Most of your videos are losing you subscribers",
            body: "Find out which ones — in 60 seconds."
        ),
        WelcomePage(
            imageName: "subsaipw2",
            headline: "Your next video could 10x your channel",
            body: "We tell you exactly what to fix. You go film it."
        ),
        WelcomePage(
            imageName: "subsaipw3",
            headline: "More views. More subscribers. Less guessing.",
            body: "Your data knows why. We'll show you."
        )
    ]

    var onContinue: () -> Void

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {

                // Skip Button
                HStack {
                    Spacer()
                    Button("Skip") {
                        onContinue()
                    }
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(AppTheme.textTertiary)
                    .padding(.top, 20)
                    .padding(.trailing, 24)
                }

                Spacer()

                // Main Content with Big Images
                TabView(selection: $currentPage) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        pageView(page)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                Spacer()

                // Page Indicators
                HStack(spacing: 8) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(index == currentPage ? AppTheme.accent : AppTheme.borderSubtle)
                            .frame(width: index == currentPage ? 28 : 8, height: 8)
                    }
                }
                .padding(.bottom, 40)

                // CTA Button
                Button {
                    if currentPage < pages.count - 1 {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            currentPage += 1
                        }
                    } else {
                        onContinue()
                    }
                } label: {
                    Text(currentPage < pages.count - 1 ? "Next" : "Get Started")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 58)
                        .background(AppTheme.accent)
                        .cornerRadius(16)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 50)
            }
        }
        .opacity(animateIn ? 1 : 0)
        .offset(y: animateIn ? 0 : 30)
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                animateIn = true
            }
        }
    }

    private func pageView(_ page: WelcomePage) -> some View {
        VStack(spacing: 32) {

            // Large Image with subtle glow
            Image(page.imageName)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .frame(height: 420)
                .cornerRadius(28)
                .shadow(color: AppTheme.accent.opacity(0.15), radius: 25, x: 0, y: 12)
                .padding(.horizontal, 20)

            VStack(spacing: 16) {

                // HEADLINE FIXED
                Text(page.headline)
                    .font(.system(size: 27, weight: .medium, design: .serif))
                    .foregroundColor(AppTheme.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 20)

                // BODY FIXED
                Text(page.body)
                    .font(.system(size: 16))
                    .foregroundColor(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 32)
            }

            Spacer(minLength: 20)
        }
        .padding(.top, 10)
    }
}

// MARK: - Model
struct WelcomePage {
    let imageName: String
    let headline: String
    let body: String
}
