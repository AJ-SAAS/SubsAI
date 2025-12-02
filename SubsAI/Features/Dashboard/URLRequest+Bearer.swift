// URLRequest+Bearer.swift
import Foundation

extension URLRequest {
    init(url: URL, bearerToken: String) {
        self.init(url: url)
        setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
    }
}
