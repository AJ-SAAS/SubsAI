import SwiftUI
import UIKit

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
        GeometryReader { geo in
            ZStack {
                AppTheme.background.ignoresSafeArea()

                VStack(spacing: 0) {

                    // Main Content
                    TabView(selection: $currentPage) {
                        ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                            pageView(page, index: index, availableHeight: geo.size.height)
                                .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    // Haptic on swipe
                    .onChange(of: currentPage) { _ in
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }

                    // Page Indicators
                    HStack(spacing: 8) {
                        ForEach(0..<pages.count, id: \.self) { index in
                            RoundedRectangle(cornerRadius: 4)
                                .fill(index == currentPage ? AppTheme.accent : AppTheme.borderSubtle)
                                .frame(width: index == currentPage ? 28 : 8, height: 8)
                        }
                    }
                    .padding(.bottom, 24)

                    // CTA Button
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

                        if currentPage < pages.count - 1 {
                            withAnimation(.easeInOut(duration: 0.4)) {
                                currentPage += 1
                            }
                        } else {
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                            onContinue()
                        }
                    } label: {
                        Text(buttonTitle)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 58)
                            .background(AppTheme.accent)
                            .cornerRadius(16)
                            .animation(.easeInOut(duration: 0.25), value: buttonTitle)
                    }
                    .frame(maxWidth: 500)
                    .padding(.horizontal, 32)
                    .padding(.bottom, geo.safeAreaInsets.bottom > 0 ? 16 : 34)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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

    // MARK: - Dynamic CTA Text
    private var buttonTitle: String {
        if currentPage == pages.count - 1 {
            return "Launch 🚀"
        } else if currentPage == pages.count - 2 {
            return "Continue"
        } else {
            return "Next"
        }
    }

    private func pageView(_ page: WelcomePage, index: Int, availableHeight: CGFloat) -> some View {
        let imageHeight = min(availableHeight * 0.45, 420.0)

        return VStack(spacing: 0) {

            Spacer(minLength: 0)

            Image(page.imageName)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .frame(height: imageHeight)
                .clipShape(RoundedRectangle(cornerRadius: 40)) // 👈 more rounded
                .shadow(color: AppTheme.accent.opacity(0.12), radius: 30, x: 0, y: 15) // 👈 softer shadow
                .padding(.horizontal, 20)

            Spacer(minLength: 20)

            VStack(spacing: 14) {
                Text(page.headline)
                    .font(.system(size: 27, weight: .medium, design: .serif))
                    .foregroundColor(AppTheme.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 24)
                    .opacity(currentPage == index ? 1 : 0)
                    .offset(y: currentPage == index ? 0 : 20)
                    .animation(.easeOut(duration: 0.5), value: currentPage)

                Text(page.body)
                    .font(.system(size: 16))
                    .foregroundColor(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 36)
                    .opacity(currentPage == index ? 1 : 0)
                    .offset(y: currentPage == index ? 0 : 20)
                    .animation(.easeOut(duration: 0.6).delay(0.1), value: currentPage)
            }
            .frame(maxWidth: 540)

            Spacer(minLength: 60)
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
