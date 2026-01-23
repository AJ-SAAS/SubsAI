import SwiftUI

struct CoachVideoCard: View {
    let video: Video

    // Computed properties
    private var fix: CoachFix { video.primaryFix }
    private var score: Int { video.healthScore }

    var body: some View {
        HStack(spacing: 12) {

            VideoThumbnailMini(video: video)

            VStack(alignment: .leading, spacing: 4) {
                Text(video.title)
                    .font(.subheadline)
                    .lineLimit(2)

                Text("Health Score: \(score)")
                    .font(.caption)
                    .foregroundColor(score < 50 ? .red : .green)
            }

            Spacer()

            Image(systemName: fix.systemImage)
                .foregroundColor(.blue)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}
