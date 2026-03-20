// Models/AnalyticsValue.swift
import Foundation

enum AnalyticsValue: Codable {
    case string(String)
    case number(Double)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let number = try? container.decode(Double.self) {
            self = .number(number)
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else {
            self = .number(0)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .number(let d): try container.encode(d)
        case .string(let s): try container.encode(s)
        }
    }

    var doubleValue: Double {
        switch self {
        case .number(let d): return d
        case .string(let s): return Double(s) ?? 0
        }
    }

    var intValue: Int { Int(doubleValue) }
}
