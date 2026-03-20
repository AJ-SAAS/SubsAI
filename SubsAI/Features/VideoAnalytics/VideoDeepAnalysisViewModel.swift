// Features/VideoAnalytics/VideoDeepAnalysisViewModel.swift
import Foundation

@MainActor
final class VideoDeepAnalysisViewModel: ObservableObject {
    @Published var analysis: VideoDeepAnalysis?
    @Published var isLoading = false
    @Published var errorMessage: String?

    let video: Video

    init(video: Video) {
        self.video = video
    }

    func load() async {
        isLoading = true
        errorMessage = nil

        do {
            let token = try await AuthManager.shared.getValidToken()
            let curve = try await fetchRetentionCurve(videoId: video.videoId, accessToken: token)
            let channelAvg = simulatedChannelAvg()

            self.analysis = VideoDeepAnalysis(
                video: video,
                retentionCurve: curve,
                channelAvgCurve: channelAvg
            )
        } catch {
            self.analysis = VideoDeepAnalysis(
                video: video,
                retentionCurve: simulatedCurve(),
                channelAvgCurve: simulatedChannelAvg()
            )
            self.errorMessage = "Using estimated data — analytics may not be available yet for this video."
        }

        isLoading = false
    }

    // MARK: - Retention API
    private func fetchRetentionCurve(videoId: String, accessToken: String) async throws -> [RetentionDataPoint] {
        var components = URLComponents(string: "https://youtubeanalytics.googleapis.com/v2/reports")!
        components.queryItems = [
            .init(name: "ids",        value: "channel==MINE"),
            .init(name: "metrics",    value: "audienceWatchRatio"),
            .init(name: "filters",    value: "video==\(videoId)"),
            .init(name: "dimensions", value: "elapsedVideoTimeRatio"),
            .init(name: "startDate",  value: "2020-01-01"),
            .init(name: "endDate",    value: Date().youtubeAnalyticsDateString())
        ]

        let request = URLRequest(url: components.url!, bearerToken: accessToken)
        let (data, _) = try await URLSession.shared.data(for: request)

        // ✅ Use AnalyticsValue to handle mixed number/string rows
        struct Response: Codable {
            let rows: [[AnalyticsValue]]?
        }

        let response = try JSONDecoder().decode(Response.self, from: data)

        guard let rows = response.rows, !rows.isEmpty else {
            throw URLError(.zeroByteResource)
        }

        return rows.compactMap { row in
            guard row.count >= 2 else { return nil }
            return RetentionDataPoint(
                elapsedTimeRatio: row[0].doubleValue,
                audienceWatchRatio: row[1].doubleValue
            )
        }
    }

    // MARK: - Fallback curves
    private func simulatedCurve() -> [RetentionDataPoint] {
        [
            (0.00, 1.00), (0.05, 0.88), (0.10, 0.82), (0.15, 0.74),
            (0.20, 0.68), (0.25, 0.65), (0.30, 0.62), (0.35, 0.60),
            (0.40, 0.57), (0.45, 0.53), (0.50, 0.51), (0.55, 0.49),
            (0.60, 0.46), (0.65, 0.44), (0.70, 0.42), (0.75, 0.40),
            (0.80, 0.38), (0.85, 0.37), (0.90, 0.36), (0.95, 0.35),
            (1.00, 0.34)
        ].map { RetentionDataPoint(elapsedTimeRatio: $0.0, audienceWatchRatio: $0.1) }
    }

    private func simulatedChannelAvg() -> [RetentionDataPoint] {
        [
            (0.00, 1.00), (0.05, 0.82), (0.10, 0.74), (0.15, 0.68),
            (0.20, 0.63), (0.25, 0.59), (0.30, 0.56), (0.35, 0.54),
            (0.40, 0.51), (0.45, 0.48), (0.50, 0.46), (0.55, 0.44),
            (0.60, 0.42), (0.65, 0.40), (0.70, 0.38), (0.75, 0.37),
            (0.80, 0.36), (0.85, 0.35), (0.90, 0.34), (0.95, 0.33),
            (1.00, 0.32)
        ].map { RetentionDataPoint(elapsedTimeRatio: $0.0, audienceWatchRatio: $0.1) }
    }
}
