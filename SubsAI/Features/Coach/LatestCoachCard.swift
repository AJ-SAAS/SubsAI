import SwiftUI

struct LatestCoachCard: View {
    let video: Video

    // Computed properties inside the card
    private var fix: CoachFix { video.primaryFix }
    private var score: Int { video.healthScore }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VideoThumbnailView(video: video)
                .frame(height: 180)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.blue.opacity(0.3), lineWidth: 2)
                )

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(video.title)
                        .font(.headline)
                        .lineLimit(2)

                    Text("Health Score: \(score)")
                        .font(.subheadline)
                        .foregroundColor(score < 50 ? .red : .green)
                }

                Spacer()

                Image(systemName: fix.systemImage)
                    .font(.title)
                    .foregroundColor(.blue)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}
