import SwiftUI

struct MonetizationView: View {
    @StateObject private var viewModel = MonetizationViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Monetization Overview")
                    .font(.title2)
                    .bold()

                HStack(spacing: 10) {
                    MonetizationCard(
                        title: "Subscribers",
                        subtitle: "All Time",
                        current: viewModel.subscribers, // Use raw Int value
                        required: 1000,
                        unit: "subs"
                    )
                    MonetizationCard(
                        title: "Watch Hours",
                        subtitle: "Last 365 days",
                        current: viewModel.watchTimeMinutes / 60, // Convert minutes to hours
                        required: 4000,
                        unit: "hours"
                    )
                    MonetizationCard(
                        title: "Views",
                        subtitle: "Last 90 days",
                        current: viewModel.views, // Use raw Int value
                        required: 10000000,
                        unit: "views"
                    )
                }
            }
            .padding()
        }
        .navigationTitle("Monetization")
        .onAppear {
            viewModel.fetchMonetizationStats()
        }
    }
}

#if DEBUG
struct MonetizationView_Previews: PreviewProvider {
    static var previews: some View {
        MonetizationView()
    }
}
#endif
