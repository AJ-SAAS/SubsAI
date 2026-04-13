import SwiftUI

struct WelcomeView: View {

    @State private var currentPage = 0
    @State private var animateIn = false

    private let pages: [WelcomePage] = [
        WelcomePage(
            imageName: "subsaipw5",
            headline: "Know exactly what's working",
            body: "See which videos are growing your channel and which ones are holding you back — with real data from your own channel."
        ),
        WelcomePage(
            imageName: "subsaipw2",
            headline: "A coach, not just a dashboard",
            body: "SubsAI tells you exactly what to fix before your next upload — specific, actionable insights based on your patterns."
        ),
        WelcomePage(
            imageName: "subsaipw3",
            headline: "Built for creators who are serious",
            body: "Stop guessing why some videos pop and others don't. Your data already knows the answer."
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
                .frame(height: 420)                    // Big and impactful
                .cornerRadius(28)
                .shadow(color: AppTheme.accent.opacity(0.15), radius: 25, x: 0, y: 12)
                .padding(.horizontal, 20)

            VStack(spacing: 16) {
                Text(page.headline)
                    .font(.system(size: 27, weight: .medium, design: .serif))
                    .foregroundColor(AppTheme.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 20)

                Text(page.body)
                    .font(.system(size: 16))
                    .foregroundColor(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)
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
