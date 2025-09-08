import SwiftUI

struct DashboardView: View {
    @StateObject private var viewModel = DashboardViewModel()
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("How You're Doing")
                        .font(.title2)
                        .bold()

                    if let error = errorMessage {
                        Text("Error: \(error)")
                            .foregroundColor(.red)
                            .padding()
                    }

                    HStack(spacing: 10) {
                        StatCard(title: "Subscribers", value: viewModel.subscribers, icon: "person.3.fill")
                        StatCard(title: "Views", value: viewModel.views, icon: "eye.fill")
                        StatCard(title: "Videos", value: viewModel.videos, icon: "video.fill")
                    }

                    Text("Milestones")
                        .font(.title2)
                        .bold()
                    Text("Ready to smash your next goals?")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    VStack(spacing: 10) {
                        GoalCard(title: "Subscribers", current: viewModel.subscribers, goal: 10000)
                        GoalCard(title: "Views", current: viewModel.views, goal: 1000000)
                        GoalCard(title: "Videos", current: viewModel.videos, goal: 100)
                    }
                }
                .padding()
            }
            .navigationTitle("Dashboard")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink("Monetization", destination: MonetizationView())
                }
            }
            .onAppear {
                print("DashboardView: View appeared")
                viewModel.fetchStats { error in
                    if let error = error {
                        errorMessage = error.localizedDescription
                        print("DashboardView: Error from viewModel: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
}

#if DEBUG
struct DashboardView_Previews: PreviewProvider {
    static var previews: some View {
        DashboardView()
    }
}
#endif
