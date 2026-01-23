import SwiftUI

struct VideoThumbnailView: View {
    let video: Video

    var body: some View {
        if let urlString = video.thumbnailURL,
           let url = URL(string: urlString) {
            AsyncImage(url: url) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        Image(systemName: "play.fill")
                            .font(.largeTitle)
                            .foregroundColor(.white)
                    )
            }
        } else {
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .overlay(
                    Image(systemName: "play.fill")
                        .font(.largeTitle)
                        .foregroundColor(.white)
                )
        }
    }
}

struct VideoThumbnailMini: View {
    let video: Video

    var body: some View {
        if let urlString = video.thumbnailURL,
           let url = URL(string: urlString) {
            AsyncImage(url: url) { image in
                image
                    .resizable()
                    .scaledToFill()
                    .frame(width: 80, height: 45)
                    .clipped()
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 80, height: 45)
                    .overlay(
                        Image(systemName: "play.fill")
                            .font(.caption)
                            .foregroundColor(.white)
                    )
            }
        } else {
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
}
