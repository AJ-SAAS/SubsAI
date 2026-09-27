import SwiftUI
import RevenueCat

// =============================================================
// MARK: - PAYWALL CONTEXT
// Decides what the paywall is allowed to say.
// It only gets personal when the channel data is real and valid.
// =============================================================

struct SubMilestone {
    let target: Int
    let label: String          // "100", "1K", "10K", ...
    var isMonetize: Bool { target == 1_000 }
    
    /// Next sub milestone above the current count.
    static func next(after subs: Int) -> SubMilestone? {
        let ladder: [(Int, String)] = [
            (100, "100"),
            (1_000, "1K"),
            (10_000, "10K"),
            (100_000, "100K"),
            (1_000_000, "1M"),
            (10_000_000, "10M")
        ]
        guard let step = ladder.first(where: { subs < $0.0 }) else { return nil }
        return SubMilestone(target: step.0, label: step.1)
    }
}

enum PaywallContext {
    /// Real, connected channel with valid stats
    case personal(channelName: String, subscribers: Int, milestone: SubMilestone)
    /// Demo account (Apple Review + testing). Always labeled as a demo.
    case demo(channelName: String, subscribers: Int, milestone: SubMilestone)
    /// Not connected, data failed, or data looks wrong. Says nothing that could be wrong.
    case generic
}

@MainActor
enum PaywallContextBuilder {
    
    /// Builds the context from a channel the app already loaded (no waiting).
    static func build(from channel: Channel) -> PaywallContext {
        context(for: channel, isDemo: AuthManager.shared.isDemoMode)
    }

    /// Uses the channel the app already loaded if there is one.
    /// Otherwise loads it, and falls back to the generic paywall after `timeout` seconds.
    static func build(timeout: Double = 6) async -> PaywallContext {
        if let cached = YouTubeService.shared.lastChannel {
            return build(from: cached)
        }
        guard let channel = await YouTubeService.shared.fetchChannel(timeout: timeout) else {
            log("generic: the channel didn't load within \(Int(timeout))s")
            return .generic
        }
        return build(from: channel)
    }

    private static func context(for channel: Channel, isDemo: Bool) -> PaywallContext {
        guard isValid(channel) else { return .generic }
        guard let milestone = SubMilestone.next(after: channel.subscribers) else {
            log("generic: channel is past the last milestone")
            return .generic
        }
        
        let name = channel.name.trimmingCharacters(in: .whitespacesAndNewlines)
        log("\(isDemo ? "demo" : "personal"): \(name), \(channel.subscribers) subs, next \(milestone.label)")
        return isDemo
            ? .demo(channelName: name, subscribers: channel.subscribers, milestone: milestone)
            : .personal(channelName: name, subscribers: channel.subscribers, milestone: milestone)
    }
    
    /// Every check that keeps the paywall from showing wrong info.
    private static func isValid(_ channel: Channel) -> Bool {
        let name = channel.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty || name == "Unknown Channel" {
            log("generic: no channel name")
            return false
        }
        if channel.subscribersHidden == true {
            log("generic: the creator hides their sub count")
            return false
        }
        // Older saved channels don't have the hidden flag. Only trust those if the count is real.
        if channel.subscribersHidden == nil && channel.subscribers <= 0 {
            log("generic: no sub count")
            return false
        }
        if channel.subscribers < 0 {
            log("generic: bad sub count")
            return false
        }
        return true
    }
    
    /// Shows in the Xcode console only (not in the App Store build).
    private static func log(_ message: String) {
        #if DEBUG
        print("🧾 Paywall → \(message)")
        #endif
    }
}

// =============================================================
// MARK: - PAYWALL CONTAINER
// Use this wherever you show the paywall:
//     PaywallContainer()
//
// If the app has already loaded the channel (it usually has), it shows
// instantly. Otherwise it shows "Checking your channel..." for up to 6 seconds.
// You can also pass a channel in directly:  PaywallContainer(channel: someChannel)
// =============================================================

struct PaywallContainer: View {

    @State private var context: PaywallContext?

    init(channel: Channel? = nil) {
        let known = channel ?? YouTubeService.shared.lastChannel
        _context = State(initialValue: known.map { PaywallContextBuilder.build(from: $0) })
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if let context {
                PaywallView(context: context)
                    .transition(.opacity)
            } else {
                VStack(spacing: 14) {
                    ProgressView()
                        .tint(.white)
                    Text("Checking your channel...")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color.white.opacity(0.75))
                }
            }
        }
        .animation(.easeOut(duration: 0.25), value: context != nil)
        .task {
            if context == nil {
                context = await PaywallContextBuilder.build()
            }
        }
    }
}

// =============================================================
// MARK: - PAYWALL VIEW
// =============================================================

struct PaywallView: View {
    
    var context: PaywallContext = .generic
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = PurchaseViewModel()
    
    @State private var selectedPlan: PlanType = .yearly
    @State private var barFilled = false
    
    // Loaded once when the paywall opens, so every tap buys the plan that's selected
    @State private var yearlyPackage: Package?
    @State private var weeklyPackage: Package?
    @State private var isPurchasing = false
    @State private var errorMessage: String?
    
    /// Only turn this on once the app really sends a reminder before the trial ends.
    private let trialReminderEnabled = false
    
    private let gold = Color(red: 0.96, green: 0.72, blue: 0.24)
    
    private let bullets = [
        "Turn more viewers into subs",
        "Know what to post next",
        "Keep people watching longer",
        "A new growth plan every week"
    ]
    
    enum PlanType {
        case yearly, weekly
    }
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    
                    Spacer().frame(height: 100)
                    
                    // MARK: Header + progress
                    VStack(spacing: 20) {
                        if case .demo = context {
                            Text("DEMO CHANNEL")
                                .font(.system(size: 11, weight: .heavy))
                                .kerning(0.6)
                                .foregroundColor(Color.white.opacity(0.7))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .overlay(Capsule().stroke(Color.white.opacity(0.25), lineWidth: 1))
                        }
                        
                        headline
                            .font(.system(size: 28, weight: .heavy))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                            .minimumScaleFactor(0.75)
                            .padding(.horizontal, 24)
                        
                        if let progress = progressInfo {
                            progressBar(progress)
                                .padding(.horizontal, 26)
                        }
                    }
                    .padding(.bottom, 26)
                    
                    // MARK: Bullets
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(bullets, id: \.self) { bullet in
                            HStack(spacing: 12) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 22))
                                    .foregroundColor(AppTheme.accent)
                                Text(bullet)
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 36)
                    .padding(.bottom, 30)
                    
                    // MARK: Plans
                    VStack(spacing: 14) {
                        PlanCardView(
                            title: "Yearly Plan",
                            subtitle: "Best value (Only $1.15/week)",
                            price: "$59.99 / year",
                            badge: "Save 80% 💰",
                            isSelected: selectedPlan == .yearly,
                            onTap: {
                                guard !isPurchasing else { return }
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
                                guard !isPurchasing else { return }
                                selectedPlan = .weekly
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            }
                        )
                        
                        // Trial timeline on weekly, simple line on yearly
                        ZStack {
                            if selectedPlan == .weekly {
                                trialTimeline
                                    .transition(.opacity)
                            } else {
                                HStack(spacing: 6) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(.white)
                                    Text("No commitment. Cancel anytime.")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.white)
                                }
                                .transition(.opacity)
                            }
                        }
                        .frame(height: 66)
                        .animation(.easeInOut(duration: 0.2), value: selectedPlan)
                        
                        Button {
                            startPurchase()
                        } label: {
                            ZStack {
                                if isPurchasing {
                                    ProgressView().tint(.white)
                                } else {
                                    Text(ctaTitle)
                                        .font(.system(size: 18, weight: .heavy))
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 58)
                            .background(AppTheme.accent)
                            .cornerRadius(16)
                        }
                        .disabled(isPurchasing)
                        
                        Text(selectedPlan == .weekly
                             ? "No payment today. Cancel anytime in Settings."
                             : "Cancel anytime in Settings.")
                            .font(.system(size: 13))
                            .foregroundColor(Color.white.opacity(0.7))
                        
                        HStack(spacing: 30) {
                            Button("Restore") {
                                Task { await viewModel.restorePurchases() }
                            }
                            .foregroundColor(.white)
                            
                            Link("Terms", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                                .foregroundColor(.white)
                            
                            Link("Privacy", destination: URL(string: "https://www.trysubsai.com/r/privacy")!)
                                .foregroundColor(.white)
                        }
                        .font(.system(size: 13))
                        .padding(.top, 4)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
            
            // Close Button
            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 34))
                    .foregroundColor(.white.opacity(0.85))
                    .background(
                        Circle()
                            .fill(Color.black.opacity(0.6))
                            .frame(width: 44, height: 44)
                    )
            }
            .accessibilityLabel("Close")
            .padding(.top, 54)
            .padding(.leading, 20)
        }
        .background(Color.black)
        .ignoresSafeArea(edges: .top)
        .onAppear {
            withAnimation(.easeOut(duration: 1.1).delay(0.2)) { barFilled = true }
        }
        .task {
            await loadPackages()
        }
        .alert(
            "Oops",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }
    
    // MARK: - Headline (never says anything that could be wrong)
    
    private var headline: Text {
        switch context {
        case .personal(let name, _, let milestone), .demo(let name, _, let milestone):
            return Text("Let's get ")
                + Text(name)
                + Text(" to ")
                + Text("\(milestone.label) subs").foregroundColor(gold)
        case .generic:
            return Text("Let's grow ")
                + Text("your channel").foregroundColor(gold)
        }
    }
    
    private var ctaTitle: String {
        if selectedPlan == .weekly { return "Start Growing Free" }
        switch context {
        case .personal(_, _, let milestone):
            return "Get Me to \(milestone.label) Subs"
        case .demo, .generic:
            return "Start Growing"
        }
    }
    
    // MARK: - Progress bar
    
    private struct ProgressInfo {
        let currentLabel: String
        let targetLabel: String
        let fraction: CGFloat
        let toGoLabel: String
    }
    
    private var progressInfo: ProgressInfo? {
        switch context {
        case .personal(_, let subs, let m), .demo(_, let subs, let m):
            let remaining = max(m.target - subs, 0)
            // YouTube rounds counts of 1,000+, so say "about" for bigger channels
            let toGo = subs < 1_000
                ? "\(remaining) subs to go"
                : "About \(compact(remaining)) subs to go"
            return ProgressInfo(
                currentLabel: "\(compact(subs)) subs",
                targetLabel: m.isMonetize ? "\(m.label) 💰" : m.label,
                fraction: min(max(CGFloat(subs) / CGFloat(m.target), 0.03), 1),
                toGoLabel: toGo
            )
        case .generic:
            return nil
        }
    }
    
    private func progressBar(_ info: ProgressInfo) -> some View {
        VStack(spacing: 8) {
            HStack {
                Text(info.currentLabel)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Text(info.targetLabel)
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundColor(gold)
            }
            
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(red: 0.12, green: 0.10, blue: 0.20))
                    Capsule()
                        .fill(LinearGradient(
                            colors: [Color(red: 0.55, green: 0.30, blue: 1.0), Color(red: 1.0, green: 0.45, blue: 0.80)],
                            startPoint: .leading, endPoint: .trailing))
                        .frame(width: g.size.width * (barFilled ? info.fraction : 0))
                        .shadow(color: Color(red: 1.0, green: 0.45, blue: 0.80).opacity(0.6), radius: 6)
                }
            }
            .frame(height: 12)
            
            Text(info.toGoLabel)
                .font(.system(size: 13))
                .foregroundColor(Color.white.opacity(0.65))
        }
    }
    
    /// 742 -> "742", 8,760 -> "8.8K", 124,800 -> "125K", 1,250,000 -> "1.3M"
    private func compact(_ n: Int) -> String {
        switch n {
        case ..<1_000:
            return "\(n)"
        case ..<10_000:
            return String(format: "%.1fK", Double(n) / 1_000).replacingOccurrences(of: ".0K", with: "K")
        case ..<1_000_000:
            return "\(Int((Double(n) / 1_000).rounded()))K"
        default:
            return String(format: "%.1fM", Double(n) / 1_000_000).replacingOccurrences(of: ".0M", with: "M")
        }
    }
    
    // MARK: - Trial timeline (weekly plan)
    
    private var trialTimeline: some View {
        HStack(alignment: .top, spacing: 0) {
            timelineStep(color: AppTheme.accent, title: "Today", text: "Full access, free")
            if trialReminderEnabled {
                timelineStep(color: Color.white.opacity(0.6), title: "Day 5", text: "We remind you")
            }
            timelineStep(color: Color.white.opacity(0.35), title: "Day 7", text: "$5.99/week starts")
        }
        .background(alignment: .top) {
            Capsule()
                .fill(LinearGradient(colors: [AppTheme.accent, Color.white.opacity(0.25)], startPoint: .leading, endPoint: .trailing))
                .frame(height: 3)
                .padding(.horizontal, trialReminderEnabled ? 60 : 90)
                .padding(.top, 6)
        }
    }
    
    private func timelineStep(color: Color, title: String, text: String) -> some View {
        VStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 14, height: 14)
                .overlay(Circle().stroke(Color.black, lineWidth: 2))
            Text(title)
                .font(.system(size: 13, weight: .heavy))
                .foregroundColor(.white)
            Text(text)
                .font(.system(size: 12))
                .foregroundColor(Color.white.opacity(0.65))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Purchase
    
    /// Loads both plans once, up front.
    private func loadPackages() async {
        guard let current = try? await Purchases.shared.offerings().current else { return }
        yearlyPackage = current.package(identifier: "$rc_annual")
        weeklyPackage = current.package(identifier: "$rc_weekly")
    }
    
    private func startPurchase() {
        guard !isPurchasing else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        
        // Lock in the plan that is selected RIGHT NOW, before anything async happens
        let plan = selectedPlan
        isPurchasing = true
        
        Task {
            defer { isPurchasing = false }
            
            // Use the preloaded plan; load it now only if it isn't ready yet
            if yearlyPackage == nil || weeklyPackage == nil {
                await loadPackages()
            }
            guard let package = (plan == .yearly ? yearlyPackage : weeklyPackage) else {
                errorMessage = "Couldn't load plans. Please try again."
                return
            }
            
            #if DEBUG
            print("🧾 Paywall → buying \(package.storeProduct.productIdentifier) (\(plan == .yearly ? "yearly" : "weekly") selected)")
            #endif
            
            do {
                let result = try await Purchases.shared.purchase(package: package)
                if result.userCancelled { return }
                if result.customerInfo.entitlements["premium"]?.isActive == true {
                    dismiss()
                }
            } catch let error as ErrorCode where error == .purchaseCancelledError {
                return
            } catch {
                errorMessage = "Something went wrong. Please try again."
            }
        }
    }
}

// MARK: - Supporting Views

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
                .background(Color(hex: "#1a1a1a"))
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
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        ZStack {
                            AppTheme.accent
                            ShimmerBadge()
                        }
                    )
                    .cornerRadius(10)
                    .offset(x: -12, y: -10)
            }
        }
    }
}

struct ShimmerBadge: View {
    @State private var phase: CGFloat = -1.0
    
    var body: some View {
        LinearGradient(
            colors: [
                .clear,
                Color.white.opacity(0.40),
                .clear
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
        .rotationEffect(.degrees(30))
        .offset(x: phase * 140)
        .animation(
            .linear(duration: 2.6)
                .repeatForever(autoreverses: false),
            value: phase
        )
        .onAppear {
            phase = 1.0
        }
        .mask(
            RoundedRectangle(cornerRadius: 10)
        )
    }
}
