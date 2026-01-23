import SwiftUI

struct CoachView: View {
    @StateObject private var vm = CoachViewModel()

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 32) {

                    // MARK: - Latest Video Coach Card
                    if let latest = vm.latestVideo {
                        Section {
                            NavigationLink {
                                CoachReviewView(video: latest)
                            } label: {
                                LatestCoachCard(video: latest)
                            }
                        }
                        .padding(.bottom, 8)
                    }

                    // MARK: - All Videos List
                    if !vm.videos.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("All Videos")
                                .font(.headline)
                                .padding(.horizontal, 4)

                            ForEach(vm.videos) { video in
                                NavigationLink {
                                    CoachReviewView(video: video)
                                } label: {
                                    CoachVideoCard(video: video)
                                }
                            }
                        }
                    } else {
                        Text("No videos available")
                            .foregroundColor(.secondary)
                            .padding(.top, 20)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 16)
            }
            .navigationTitle("Coach")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

struct CoachView_Previews: PreviewProvider {
    static var previews: some View {
        CoachView()
    }
}
