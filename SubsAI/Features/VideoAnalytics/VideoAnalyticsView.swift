import SwiftUI

struct VideoAnalyticsView: View {
    @StateObject var vm = VideoAnalyticsViewModel()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Video Analytics")
                .font(.title2).bold()
            
            if vm.videos.isEmpty {
                Text("No videos loaded")
                    .foregroundColor(.secondary)
            } else {
                ForEach(vm.videos) { video in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(video.title)
                            .font(.headline)
                        
                        HStack {
                            StatLabel(
                                name: "Views",
                                value: "\(video.views)",
                                color: vm.statusColor(video, metric: "Views")
                            )
                            StatLabel(
                                name: "Watch Hours",
                                value: String(format: "%.1f", video.watchTime) + "h",
                                color: vm.statusColor(video, metric: "Watch Time")
                            )
                            StatLabel(
                                name: "Thumbnail CTR",
                                value: String(format: "%.1f", video.thumbnailCTR) + "%",
                                color: vm.statusColor(video, metric: "Thumbnail CTR")
                            )
                            StatLabel(
                                name: "Drop-Off",
                                value: "\(video.dropOffSeconds)s",
                                color: vm.statusColor(video, metric: "Drop-off")
                            )
                        }
                        
                        let issues = vm.needsImprovement(video)
                        if !issues.isEmpty {
                            Text("Needs improvement: \(issues.joined(separator: ", "))")
                                .font(.subheadline)
                                .foregroundColor(.red)
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                }
            }
        }
        .padding()
        .task {
            await vm.loadVideos()
        }
    }
}

struct StatLabel: View {
    let name: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack {
            Text(name)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .bold()
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
    }
}
