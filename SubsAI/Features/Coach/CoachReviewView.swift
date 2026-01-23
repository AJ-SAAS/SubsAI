import SwiftUI

struct CoachReviewView: View {
    let video: Video

    var body: some View {
        let fix = CoachViewModel().primaryFix(for: video)

        VStack(spacing: 24) {

            VideoThumbnailView(video: video)

            VStack(spacing: 12) {
                Image(systemName: fix.systemImage)
                    .font(.largeTitle)
                    .foregroundColor(.blue)

                Text(fix.title)
                    .font(.title2)
                    .fontWeight(.bold)

                Text(fix.description)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button("Show Me How") {
                // Future: AI tips / checklist
            }
            .buttonStyle(.borderedProminent)

            Spacer()
        }
        .padding()
        .navigationTitle("Video Review")
    }
}
