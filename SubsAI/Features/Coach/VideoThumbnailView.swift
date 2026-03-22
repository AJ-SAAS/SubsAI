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
                case .failure:
                    placeholder
                default:
                    placeholder
                }
            }
        } else {
            placeholder
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
                case .failure:
                    miniPlaceholder
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
            .overlay(
                Image(systemName: "play.fill")
                    .font(.caption)
                    .foregroundColor(.white)
            )
    }
}
