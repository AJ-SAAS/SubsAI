import SwiftUI

struct VideoThumbnailView: View {
    let video: Video

    var body: some View {
        if let url = video.thumbnailURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(height: 180)
                        .clipped()
                        .cornerRadius(12)
                default:
                    placeholder
                        .frame(height: 180)
                        .cornerRadius(12)
                }
            }
        } else {
            placeholder
                .frame(height: 180)
                .cornerRadius(12)
        }
    }

    private var placeholder: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.3))
            .overlay(
                Image(systemName: "play.fill")
                    .font(.largeTitle)
                    .foregroundColor(.white)
            )
    }
}

struct VideoThumbnailMini: View {
    let video: Video

    var body: some View {
        if let url = video.thumbnailURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 80, height: 45)
                        .clipped()
                default:
                    miniPlaceholder
                }
            }
        } else {
            miniPlaceholder
        }
    }

    private var miniPlaceholder: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.3))
            .frame(width: 80, height: 45)
            .overlay(
                Image(systemName: "play.fill")
                    .font(.caption)
                    .foregroundColor(.white)
            )
    }
}
