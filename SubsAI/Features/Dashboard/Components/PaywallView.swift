import SwiftUI
import RevenueCat

struct PaywallView: View {
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = PurchaseViewModel()
    
    @State private var selectedPlan: PlanType = .yearly
    @State private var currentCardIndex: Int = 0
    @State private var timer = Timer.publish(every: 2.5, on: .main, in: .common).autoconnect()
    
    private let benefitCards: [BenefitCard] = [
        BenefitCard(imageName: "subsaipw1", title: "GROW FASTER", description: "Stop guessing. Know exactly what works on your channel."),
        BenefitCard(imageName: "subsaipw2", title: "REAL SUBSCRIBER GROWTH", description: "See which videos actually bring subscribers — not just views."),
        BenefitCard(imageName: "subsaipw3", title: "FIX DROP-OFFS", description: "Discover exactly why viewers leave and how to keep them watching."),
        BenefitCard(imageName: "subsaipw4", title: "REPEAT YOUR WINNERS", description: "Find your best performing patterns and replicate them."),
        BenefitCard(imageName: "subsaipw5", title: "POST WITH CONFIDENCE", description: "Every upload backed by your own channel data.")
    ]
    
    enum PlanType {
        case yearly, weekly
    }
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    
                    // Hero Header
                    Color.black
                        .ignoresSafeArea(edges: .top)
                        .frame(height: 300)
                        .overlay(
                            VStack(spacing: 10) {
                                Spacer().frame(height: 40)
                                
                                Image("subsai1")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 180, height: 180)
                                    .cornerRadius(20)
                                
                                (
                                    Text("SubsAI Premium creators grow ")
                                        .foregroundColor(.white)
                                    +
                                    Text("3x")
                                        .font(.system(size: 22, weight: .bold))
                                        .foregroundStyle(
                                            LinearGradient(
                                                colors: [Color.orange, Color.yellow],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                    +
                                    Text(" faster")
                                        .foregroundColor(.white)
                                )
                                .font(.system(size: 20, weight: .bold))
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .minimumScaleFactor(0.8)
                                .padding(.horizontal, 40)
                            }
                        )
                    
                    // Benefit Cards - Dark Purple
                    VStack(spacing: 12) {
                        TabView(selection: $currentCardIndex) {
                            ForEach(Array(benefitCards.enumerated()), id: \.element.id) { index, card in
                                BenefitCardView(card: card)
                                    .tag(index)
                            }
                        }
                        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                        .frame(height: 125)
                        .padding(.horizontal, 20)
                        .onReceive(timer) { _ in
                            withAnimation {
                                currentCardIndex = (currentCardIndex + 1) % benefitCards.count
                            }
                        }
                        
                        HStack(spacing: 7) {
                            ForEach(0..<benefitCards.count, id: \.self) { index in
                                Circle()
                                    .fill(index == currentCardIndex ? AppTheme.accent : Color.gray.opacity(0.5))
                                    .frame(width: index == currentCardIndex ? 9 : 7,
                                           height: index == currentCardIndex ? 9 : 7)
                            }
                        }
                        .padding(.top, 0)
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 6)
                    
                    // Plan Selection
                    VStack(spacing: 14) {
                        PlanCardView(
                            title: "Yearly Plan",
                            subtitle: "Best value (Only $1.92/week)",
                            price: "$99.99 / year",
                            badge: "Save 63% 💰",
                            isSelected: selectedPlan == .yearly,
                            onTap: {
                                selectedPlan = .yearly
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            }
                        )
                        
                        PlanCardView(
                            title: "Weekly Plan",
                            subtitle: "7-day free trial, then $5.99/week",
                            price: "$5.99 / week",
                            badge: nil,
                            isSelected: selectedPlan == .weekly,
                            onTap: {
                                selectedPlan = .weekly
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            }
                        )
                        
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.white)
                            Text("No payment required now")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.white)
                        }
                        .padding(.top, 4)
                        
                        Button(action: handleContinue) {
                            Text("Continue")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 58)
                                .background(AppTheme.accent)
                                .cornerRadius(16)
                        }
                        .padding(.top, 8)
                        
                        Text("Cancel anytime. No commitment.")
                            .font(.system(size: 13))
                            .foregroundColor(Color.white.opacity(0.7))
                            .padding(.top, 6)
                        
                        HStack(spacing: 30) {
                            Button("Restore") {
                                Task { await viewModel.restorePurchases() }
                            }
                            .foregroundColor(.white)
                            
                            Link("Terms", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                                .foregroundColor(.white)
                            
                            Link("Privacy", destination: URL(string: "https://subsai.app/privacy")!)
                                .foregroundColor(.white)
                        }
                        .font(.system(size: 13))
                        .padding(.top, 8)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
            }
            
            // X Close Button
            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.white.opacity(0.9))
                    .shadow(radius: 3)
            }
            .padding(.top, 54)
            .padding(.leading, 20)
        }
        .background(Color.black)
        .ignoresSafeArea(edges: .top)
    }
    
    private func handleContinue() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        
        let packageId = selectedPlan == .yearly ? "$rc_annual" : "$rc_weekly"
        
        Purchases.shared.getOfferings { offerings, error in
            guard let package = offerings?.current?.package(identifier: packageId) else { return }
            
            Purchases.shared.purchase(package: package) { _, customerInfo, _, _ in
                if customerInfo?.entitlements["premium"]?.isActive == true {
                    dismiss()
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct BenefitCardView: View {
    let card: BenefitCard
    
    var body: some View {
        HStack(spacing: 16) {
            Image(card.imageName)
                .resizable()
                .scaledToFit()
                .frame(width: 72, height: 72)
            
            VStack(alignment: .leading, spacing: 6) {
                Text(card.title)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
                    .textCase(.uppercase)
                
                Text(card.description)
                    .font(.system(size: 13.5))
                    .foregroundColor(Color.white.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(16)
        .background(AppTheme.darkCardPurple)
        .cornerRadius(20)
    }
}

struct PlanCardView: View {
    let title: String
    let subtitle: String
    let price: String
    let badge: String?
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: onTap) {
                HStack {
                    Circle()
                        .stroke(isSelected ? AppTheme.accent : Color.gray.opacity(0.5), lineWidth: 2.5)
                        .frame(width: 26, height: 26)
                        .overlay {
                            if isSelected {
                                Circle().fill(AppTheme.accent).frame(width: 16, height: 16)
                            }
                        }
                    
                    VStack(alignment: .leading, spacing: 3) {
                        Text(title)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                        Text(subtitle)
                            .font(.system(size: 13))
                            .foregroundColor(Color.white.opacity(0.7))
                            .multilineTextAlignment(.leading)
                    }
                    
                    Spacer()
                    
                    Text(price)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
                .background(Color(hex: "#1a1a1a"))   // Solid dark grey — not opacity-based
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(isSelected ? AppTheme.accent : Color.clear, lineWidth: 2)
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            if let badge = badge {
                Text(badge)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(AppTheme.accent)
                    .cornerRadius(10)
                    .offset(x: -12, y: -10)
            }
        }
    }
}

struct BenefitCard: Identifiable {
    let id = UUID()
    let imageName: String
    let title: String
    let description: String
}
